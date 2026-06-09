import { db } from '../config/db';
import { v4 as uuidv4 } from 'uuid';

export const runDataSimulation = async (companyId: string) => {
  console.log("🚀 [DATA ENGINEERING] Début du nettoyage et de la réinitialisation des données...");

  try {
    // ==========================================
    // 1. NETTOYAGE ORDONNÉ DE LA BASE DE DONNÉES
    // ==========================================
    // Ordre strict pour respecter l'intégrité référentielle (Clés étrangères)
    await db.query(`DELETE FROM document_items`);
    await db.query(`DELETE FROM documents`);
    await db.query(`DELETE FROM clients WHERE company_id = $1`, [companyId]);
    await db.query(`DELETE FROM products WHERE company_id = $1`, [companyId]);
    await db.query(`DELETE FROM resellers WHERE company_id = $1`, [companyId]);
    
    console.log("🧹 [DATA ENGINEERING] Base de données nettoyée avec succès.");

    // ==========================================
    // 2. INSERTION DES REVENDEURS (GÉO-LOCALISÉS)
    // ==========================================
    // Coordonnées de base (Exemple : Centre de Bruxelles ou de Kinshasa selon ton implémentation)
    const baseLat = 50.8503;
    const baseLng = 4.3517;

    const resellers = [
      { name: 'Distributeur Centre-Ville', deposit: 'Dépôt Principal Alpha', email: 'alpha@rem.com' },
      { name: 'Revendeur Nord Logistique', deposit: 'Dépôt Logistique Nord', email: 'nord@rem.com' },
      { name: 'Mini-Dépôt Express', deposit: 'Dépôt Relais Express', email: 'express@rem.com' },
      { name: 'Alimentation Générale & Fils', deposit: 'Dépôt Sud Éco', email: 'sud@rem.com' },
      { name: 'Boutique Horizon', deposit: 'Dépôt Ouest Hub', email: 'ouest@rem.com' }
    ];

    const resellerIds: string[] = [];

    for (const res of resellers) {
      const id = uuidv4();
      // Génération de coordonnées aléatoires dans un rayon d'environ 5 à 10 km autour de la base
      const randomLat = baseLat + (Math.random() - 0.5) * 0.15;
      const randomLng = baseLng + (Math.random() - 0.5) * 0.25;
      const phone = `+32 499 ${Math.floor(100000 + Math.random() * 900000)}`;

      await db.query(`
        INSERT INTO resellers (id, company_id, name, email, phone, deposit_name, latitude, longitude, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
      `, [id, companyId, res.name, res.email, phone, res.deposit, randomLat, randomLng]);

      resellerIds.push(id);
    }
    console.log(`📌 [DATA ENGINEERING] ${resellerIds.length} revendeurs insérés avec positions GPS valides.`);

    // ==========================================
    // 3. INSERTION DU CATALOGUE DE PRODUITS & STOCKS
    // ==========================================
    const products = [
      { designation: 'Produit Premium Pack A', code: 'PROD-A', price: 150.0, qty: 500 },
      { designation: 'Produit Standard Pack B', code: 'PROD-B', price: 75.0, qty: 1200 },
      { designation: 'Kit Accessoires Expert', code: 'PROD-C', price: 45.5, qty: 800 },
      { designation: 'Recharge Énergie Max', code: 'PROD-D', price: 20.0, qty: 2500 }
    ];

    const productData: Array<{ id: string, price: number }> = [];

    for (const prod of products) {
      const productId = uuidv4();
      
      // Insertion Produit
      await db.query(`
        INSERT INTO products (id, company_id, designation, code, sale_price, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
      `, [productId, companyId, prod.designation, prod.code, prod.price]);

      // Insertion Stock associé
      await db.query(`
        INSERT INTO stocks (id, company_id, product_id, current_quantity, updated_at)
        VALUES ($1, $2, $3, $4, NOW())
      `, [uuidv4(), companyId, productId, prod.qty]);

      productData.push({ id: productId, price: prod.price });
    }
    console.log(`📦 [DATA ENGINEERING] Catalogue de produits et inventaire initial de stocks créés.`);

    // ==========================================
    // 4. ENREGISTREMENT DES CLIENTS
    // ==========================================
    const clients = ['Société Générale de Négoce', 'Établissements Malik', 'Centrale d’Achats Horizon', 'M. Jean-Pierre Dupont'];
    const clientIds: string[] = [];

    for (const clientName of clients) {
      const clientId = uuidv4();
      await db.query(`
        INSERT INTO clients (id, company_id, fullname, email, created_at)
        VALUES ($1, $2, $3, $4, NOW())
      `, [clientId, companyId, clientName, `${clientName.toLowerCase().replace(/[^a-z]/g, '')}@client.com`]);
      
      clientIds.push(clientId);
    }
    console.log(`👤 [DATA ENGINEERING] ${clientIds.length} fiches clients générées.`);

    // ==========================================
    // 5. SIMULATION TRANSACTIONNELLE & DIMINUTION DU STOCK
    // ==========================================
    console.log("💸 [DATA ENGINEERING] Déclenchement de la simulation de transactions réelles...");

    // On simule 15 ventes aléatoires réparties sur nos revendeurs
    for (let i = 0; i < 15; i++) {
      const documentId = uuidv4();
      const randomResellerId = resellerIds[Math.floor(Math.random() * resellerIds.length)];
      const randomClientId = clientIds[Math.floor(Math.random() * clientIds.length)];
      
      // Sélection de 1 à 2 produits aléatoires par vente
      const randomProduct = productData[Math.floor(Math.random() * productData.length)];
      const quantitySold = Math.floor(Math.random() * 5) + 1; // Quantité entre 1 et 5
      const totalAmount = randomProduct.price * quantitySold;

      // A. Enregistrement de l'en-tête de la facture (Document)
      await db.query(`
        INSERT INTO documents (id, company_id, reseller_id, client_id, type, total_amount, created_at)
        VALUES ($1, $2, $3, $4, 'INVOICE', $5, NOW())
      `, [documentId, companyId, randomResellerId, randomClientId, totalAmount]);

      // B. Enregistrement du détail de la facture (Document Items)
      await db.query(`
        INSERT INTO document_items (id, document_id, product_id, quantity, unit_price, total_price)
        VALUES ($1, $2, $3, $4, $5, $6)
      `, [uuidv4(), documentId, randomProduct.id, quantitySold, randomProduct.price, totalAmount]);

      // C. SÉCURISATION DU STOCK : Diminution directe de la quantité
      await db.query(`
        UPDATE stocks 
        SET current_quantity = current_quantity - $1, updated_at = NOW()
        WHERE company_id = $2 AND product_id = $3
      `, [quantitySold, companyId, randomProduct.id]);
    }

    console.log("✅ [DATA ENGINEERING SIMULATION COMPLETE] Opération réussie. Données ordonnées, cohérentes et prêtes pour l'affichage cartographique.");
  } catch (error) {
    console.error("❌ [DATA ENGINEERING CRITICAL ERROR] Échec de la simulation :", error);
    throw error;
  }
};