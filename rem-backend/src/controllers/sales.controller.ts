import { Request, Response } from 'express';
import { db } from '../config/db';
import pino from 'pino';

const logger = pino({ transport: { target: 'pino-pretty' } });

// ==========================================
// 1. CRÉATION DE DOCUMENTS COMMERCIAUX
// ==========================================
export const createSalesDocument = async (req: Request, res: Response): Promise<void> => {
  const { clientId, type, items, status, company_id } = req.body;
  const companyId = company_id || req.body.companyId || (req as any).user?.companyId;

  logger.info({ companyId, clientId, type }, '[REM SALES] Tentative de génération de pièce commerciale');

  if (!companyId || companyId === 'bf30cd12-9c1d-4074-b4a0-000000000000') {
    res.status(400).json({ error: 'Le paramètre company_id est obligatoire ou invalide.' });
    return;
  }

  try {
    let totalAmount = 0;
    const computedItems = items.map((item: any) => {
      const unitPrice = item.unitPrice !== undefined ? item.unitPrice : (item.unit_price || 0);
      const quantity = item.quantity || 1;
      const lineTotal = quantity * unitPrice;
      totalAmount += lineTotal;
      return { ...item, quantity, unitPrice, lineTotal };
    });

    const timestamp = Date.now();
    const docNumber = `${type === 'QUOTE' ? 'DEVIS' : 'FACT'}-${timestamp.toString().slice(-6)}`;

    await db.query('BEGIN');

    const docQuery = `
      INSERT INTO documents (company_id, client_id, type, number, status, total_amount)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, number, type, status, total_amount, created_at;
    `;
    const docValues = [companyId, clientId || null, type || 'INVOICE', docNumber, status || 'DRAFT', totalAmount];
    const docResult = await db.query(docQuery, docValues);
    const newDocument = docResult.rows[0];

    for (const item of computedItems) {
      const rawProductId = item.productId || item.product_id;
      const finalProductId = (rawProductId === '00000000-0000-0000-0000-000000000000' || !rawProductId)
        ? null 
        : rawProductId;

      const itemQuery = `
        INSERT INTO document_items (document_id, product_id, quantity, unit_price, total_price)
        VALUES ($1, $2, $3, $4, $5);
      `;
      await db.query(itemQuery, [
        newDocument.id, 
        finalProductId, 
        item.quantity, 
        item.unitPrice, 
        item.lineTotal
      ]);

      if ((status === 'PAID' || newDocument.status === 'PAID') && finalProductId) {
        const updateStockQuery = `
          UPDATE products 
          SET stock_quantity = stock_quantity - $1 
          WHERE id = $2 AND company_id = $3;
        `;
        await db.query(updateStockQuery, [item.quantity, finalProductId, companyId]);
        logger.info({ finalProductId, qty: item.quantity }, '[REM STOCK] Déduction de stock effectuée');
      }
    }

    await db.query('COMMIT');
    logger.info({ documentId: newDocument.id, number: docNumber }, '[REM SALES SUCCESS] Document enregistré et stock ajusté.');

    res.status(201).json({
      message: 'Document commercial créé avec succès',
      document: newDocument,
      items: computedItems
    });
  } catch (error) {
    await db.query('ROLLBACK');
    logger.error(error, '[REM SALES ERROR] Échec de la transaction commerciale');
    res.status(500).json({ error: 'Erreur fatale lors de la création du document commercial.' });
  }
};

// ==========================================
// 2. CRÉATION DE CLIENTS - AVEC ADRESSE (REM-204)
// ==========================================
export const createClient = async (req: Request, res: Response): Promise<void> => {
  // 📦 Extraction complète incluant désormais 'address'
  const { name, email, phone, address, company_id } = req.body;
  const companyId = company_id || (req as any).user?.companyId;

  logger.info({ companyId, name, email }, '[REM CLIENTS] Tentative de création de client avec données complètes');

  if (!name || name.trim() === '') {
    res.status(400).json({ error: 'Le nom du client est obligatoire.' });
    return;
  }

  if (!companyId || companyId === 'bf30cd12-9c1d-4074-b4a0-000000000000') {
     res.status(400).json({ error: 'ID entreprise manquant ou invalide.' });
     return;
  }

  try {
    // Requête ajustée pour écrire dans la colonne address
    const clientQuery = `
      INSERT INTO clients (company_id, name, email, phone, address, created_at)
      VALUES ($1, $2, $3, $4, $5, NOW())
      RETURNING id, company_id, name, email, phone, address, created_at;
    `;
    
    const clientValues = [companyId, name, email || null, phone || null, address || null];
    const result = await db.query(clientQuery, clientValues);
    const newClient = result.rows[0];

    logger.info({ clientId: newClient.id, name: newClient.name }, '[REM CLIENTS SUCCESS] Profil complet du client créé en base.');

    res.status(201).json({
      message: 'Client créé avec succès',
      client: newClient
    });
  } catch (error: any) {
    logger.error(error, '[REM CLIENTS ERROR] Échec de la création du client');
    
    if (error.code === '23505') {
       res.status(409).json({ error: 'Un client avec cet identifiant ou email existe déjà.' });
       return;
    }

    res.status(500).json({ error: 'Erreur fatale lors de la création du client.' });
  }
};

// ==========================================
// 3. ENCAISSEMENT VENTE (REM-205)
// ==========================================
export const updateDocumentStatus = async (req: Request, res: Response): Promise<void> => {
  const { id } = req.params;
  const { status } = req.body;
  const companyId = (req as any).user?.companyId;

  logger.info({ documentId: id, status, companyId }, '[REM SALES] Tentative de mise à jour du statut');

  const allowedStatuses = ['DRAFT', 'SENT', 'PAID', 'CANCELLED'];
  if (!allowedStatuses.includes(status)) {
     res.status(400).json({ error: `Statut invalide. Choisir parmi : ${allowedStatuses.join(', ')}` });
     return;
  }

  try {
    const query = `
      UPDATE documents 
      SET status = $1, updated_at = NOW()
      WHERE id = $2 AND company_id = $3
      RETURNING id, number, type, status, total_amount, updated_at;
    `;
    
    const result = await db.query(query, [status, id, companyId]);

    if (result.rows.length === 0) {
       res.status(404).json({ error: 'Document introuvable ou non autorisé.' });
       return;
    }

    logger.info({ documentId: id, status }, '[REM SALES SUCCESS] Statut mis à jour avec succès');

    res.status(200).json({
      message: 'Statut du document mis à jour avec succès',
      document: result.rows[0]
    });
  } catch (error) {
    logger.error(error, '[REM SALES ERROR] Échec de la mise à jour du statut');
    res.status(500).json({ error: 'Erreur fatale lors de la modification du statut.' });
  }
};

// ==========================================
// 4. SYNCHRONISATION OFFLINE-FIRST (MOBILE)
// ==========================================
export const syncOfflineDocument = async (req: Request, res: Response): Promise<void> => {
  const { id, type, number, status, totalAmount, items } = req.body;
  const companyId = (req as any).user?.companyId;

  logger.info({ companyId, documentId: id, number }, '[REM SALES SYNC] Réception d\'un document et de ses articles');

  if (!id || !type || !number || !status || totalAmount === undefined || !items || !Array.isArray(items)) {
    res.status(400).json({ error: 'Champs de synchronisation ou tableau d\'articles obligatoires manquants.' });
    return;
  }

  try {
    await SalesModel.syncMobileDocument({
      id,
      companyId,
      type,
      number,
      status,
      totalAmount: Number(totalAmount),
      items
    });

    logger.info({ documentId: id, number }, '[REM SALES SYNC SUCCESS] Document et stocks synchronisés dans Neon');

    res.status(201).json({
      success: true,
      message: 'Document de vente et stocks synchronisés avec succès',
      documentId: id
    });
  } catch (error: any) {
    logger.error(error, '[REM SALES SYNC ERROR] Échec de la transaction de synchronisation');
    
    if (error.code === '23505') {
      res.status(409).json({ error: 'Un document avec ce numéro ou cet identifiant existe déjà.' });
      return;
    }

    res.status(500).json({ error: 'Erreur fatale lors de l\'écriture synchronisée en base.' });
  }
};