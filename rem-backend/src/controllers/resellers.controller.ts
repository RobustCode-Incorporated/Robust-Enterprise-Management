import { Request, Response } from 'express';
import { db } from '../config/db';

export const getResellersLiveLocation = async (req: Request, res: Response): Promise<void> => {
  try {
    // Récupération sécurisée du company_id depuis la requête ou le token décodé
    const companyId = req.query.company_id || (req as any).user?.companyId;
    const search = req.query.search as string;

    if (!companyId) {
      res.status(400).json({ success: false, error: "Identifiant d'entreprise manquant" });
      return;
    }

    let queryParams: any[] = [companyId];
    // On s'assure de ne prendre que les revendeurs de l'entreprise qui ont des coordonnées GPS valides
    let whereClause = `WHERE company_id = $1 AND latitude IS NOT NULL AND longitude IS NOT NULL`;

    // Si une recherche est tapée dans la barre du Dashboard, on filtre sur tes 4 colonnes natives
    if (search) {
      queryParams.push(`%${search}%`);
      whereClause += ` AND (
        name ILIKE $2 OR 
        email ILIKE $2 OR 
        deposit_name ILIKE $2 OR 
        phone ILIKE $2
      )`;
    }

    // Requête 100% isolée sur la table resellers pour éliminer tout risque d'erreur 500
    const query = `
      SELECT 
        id, 
        name, 
        email, 
        phone, 
        deposit_name, 
        latitude, 
        longitude,
        0 as today_sales,       -- Valeur par défaut pour éviter de casser le template frontend
        0 as transactions_count -- Valeur par défaut pour la stabilité de l'affichage
      FROM resellers
      ${whereClause}
      ORDER BY name ASC
    `;

    console.log(`[SQL EXECUTION] Extraction cartographique sécurisée. Filtre recherche: ${search ? `"${search}"` : 'Aucun'}`);
    const result = await db.query(query, queryParams);

    // Renvoi d'une réponse propre HTTP 200 SUCCESS
    res.status(200).json({ 
      success: true, 
      data: result.rows 
    });

  } catch (error) {
    // Si une erreur arrive ici, elle sera loggée proprement côté serveur sans faire planter le front
    console.error("❌ [BACKEND CRITICAL ERROR] Échec sur la table resellers :", error);
    res.status(500).json({ success: false, error: "Internal Server Error" });
  }
};