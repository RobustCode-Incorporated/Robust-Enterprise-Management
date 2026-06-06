// scripts/seed.ts
import { v4 as uuidv4 } from 'uuid';
import { faker } from '@faker-js/faker';
import { Client } from 'pg';

require('dotenv').config();

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.error("❌ Erreur : La variable d'environnement DATABASE_URL n'est pas définie dans ton .env");
  process.exit(1);
}

const client = new Client({ 
  connectionString,
  ssl: { rejectUnauthorized: false } 
});

const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * 1. Générateur de Produits aligné sur le schéma (Laisse la base gérer le DEFAULT pour alert_threshold)
 */
const generateProducts = (companyId: string, count: number) => {
  return Array.from({ length: count }).map(() => {
    const sellingPrice = parseFloat(faker.commerce.price({ min: 10, max: 500, dec: 2 }));
    const purchasePrice = parseFloat((sellingPrice * 0.6).toFixed(2));

    return ({
      id: uuidv4(),
      company_id: companyId,
      name: faker.commerce.productName(),
      sku: faker.string.alphanumeric({ length: 8, casing: 'upper' }),
      barcode: faker.string.numeric({ length: 13 }),
      stock_quantity: faker.number.int({ min: 20, max: 500 }),
      purchase_price: purchasePrice,
      selling_price: sellingPrice,
    });
  });
};

/**
 * 2. Générateur de Documents (Ventes) et Lignes de Vente (Garantie d'unicité par séquence)
 */
const generateSalesData = (companyId: string, clientIds: string[], productIds: string[], docCount: number) => {
  const documents: any[] = [];
  const documentItems: any[] = [];

  for (let i = 0; i < docCount; i++) {
    const docId = uuidv4();
    const status = faker.helpers.arrayElement(['PAID', 'DRAFT', 'CANCELLED']);
    const createdAt = faker.date.past({ years: 1 });

    // 💡 Utilisation de l'index 'i' pour garantir un numéro de facture 100% unique (FACT-000001, etc.)
    const sequenceNumber = String(i + 1).padStart(6, '0');

    documents.push({
      id: docId,
      company_id: companyId,
      client_id: faker.helpers.arrayElement(clientIds),
      type: 'INVOICE',
      number: `FACT-${sequenceNumber}`,
      status: status,
      total_amount: 0,
      created_at: createdAt
    });

    const itemsCount = faker.number.int({ min: 1, max: 4 });
    let docTotal = 0;

    for (let j = 0; j < itemsCount; j++) {
      const prodId = faker.helpers.arrayElement(productIds);
      const quantity = faker.number.int({ min: 1, max: 5 });
      const unitPrice = parseFloat(faker.commerce.price({ min: 10, max: 500, dec: 2 }));
      const totalPrice = quantity * unitPrice;
      docTotal += totalPrice;

      documentItems.push({
        id: uuidv4(),
        document_id: docId,
        product_id: prodId,
        quantity,
        unit_price: unitPrice,
        total_price: totalPrice
      });
    }

    documents[i].total_amount = parseFloat(docTotal.toFixed(2));
  }

  return { documents, documentItems };
};

/**
 * Moteurs d'injection par lots (Bulk Inserts)
 */
async function bulkInsertProducts(products: any[]) {
  const batchSize = 500;
  for (let i = 0; i < products.length; i += batchSize) {
    const batch = products.slice(i, i + batchSize);
    const values = batch.flatMap(p => [
      p.id, p.company_id, p.name, p.sku, p.barcode, p.stock_quantity, p.purchase_price, p.selling_price
    ]);
    
    const placeholders = batch.map((_, idx) => 
      `($${idx*8+1}, $${idx*8+2}, $${idx*8+3}, $${idx*8+4}, $${idx*8+5}, $${idx*8+6}, $${idx*8+7}, $${idx*8+8})`
    ).join(',');

    const query = `
      INSERT INTO products (id, company_id, name, sku, barcode, stock_quantity, purchase_price, selling_price) 
      VALUES ${placeholders} 
      ON CONFLICT (id) DO NOTHING;
    `;

    await client.query(query, values);
    console.log(`[DATA ENG] Produits injectés : ${Math.min(i + batchSize, products.length)}/${products.length}`);
    await delay(200);
  }
}

async function bulkInsertDocuments(documents: any[]) {
  const batchSize = 500;
  for (let i = 0; i < documents.length; i += batchSize) {
    const batch = documents.slice(i, i + batchSize);
    const values = batch.flatMap(d => [d.id, d.company_id, d.client_id, d.type, d.number, d.status, d.total_amount, d.created_at]);
    const placeholders = batch.map((_, idx) => `($${idx*8+1}, $${idx*8+2}, $${idx*8+3}, $${idx*8+4}, $${idx*8+5}, $${idx*8+6}, $${idx*8+7}, $${idx*8+8})`).join(',');
    
    // Ajout d'une clause de sécurité ON CONFLICT sur le numéro si nécessaire
    await client.query(`INSERT INTO documents (id, company_id, client_id, type, number, status, total_amount, created_at) VALUES ${placeholders} ON CONFLICT (id) DO NOTHING;`, values);
    console.log(`[DATA ENG] Factures injectées : ${Math.min(i + batchSize, documents.length)}/${documents.length}`);
    await delay(200);
  }
}

async function bulkInsertDocumentItems(items: any[]) {
  const batchSize = 500;
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const values = batch.flatMap(it => [it.id, it.document_id, it.product_id, it.quantity, it.unit_price, it.total_price]);
    const placeholders = batch.map((_, idx) => `($${idx*6+1}, $${idx*6+2}, $${idx*6+3}, $${idx*6+4}, $${idx*6+5}, $${idx*6+6})`).join(',');
    await client.query(`INSERT INTO document_items (id, document_id, product_id, quantity, unit_price, total_price) VALUES ${placeholders} ON CONFLICT (id) DO NOTHING;`, values);
    console.log(`[DATA ENG] Lignes d'articles injectées : ${Math.min(i + batchSize, items.length)}/${items.length}`);
    await delay(100);
  }
}

/**
 * Orchestrateur Principal
 */
async function main() {
  try {
    console.log("[DATA ENG] Connexion à la base de données Neon PostgreSQL...");
    await client.connect();

    const companyResult = await client.query("SELECT id FROM companies LIMIT 1;");
    if (companyResult.rows.length === 0) throw new Error("Aucune entreprise trouvée.");
    const targetCompanyId = companyResult.rows[0].id;
    console.log(`[DATA ENG] Target Tenant ID : ${targetCompanyId}`);

    const clientResult = await client.query("SELECT id FROM clients WHERE company_id = $1;", [targetCompanyId]);
    const clientIds = clientResult.rows.map(r => r.id);
    console.log(`[DATA ENG] Récupération de ${clientIds.length} clients pour lier les ventes.`);

    console.log("[DATA ENG] Génération et injection de 1000 produits...");
    const produits = generateProducts(targetCompanyId, 1000);
    await bulkInsertProducts(produits);
    
    const productResult = await client.query("SELECT id FROM products WHERE company_id = $1;", [targetCompanyId]);
    const productIds = productResult.rows.map(r => r.id);

    const volumeVentes = 15000;
    console.log(`[DATA ENG] Génération de ${volumeVentes} factures et de leurs lignes transactionnelles...`);
    const { documents, documentItems } = generateSalesData(targetCompanyId, clientIds, productIds, volumeVentes);

    const startTime = Date.now();
    
    console.log("[DATA ENG] Pipeline - Étape A : Injection des en-têtes de factures...");
    await bulkInsertDocuments(documents);

    console.log("[DATA ENG] Pipeline - Étape B : Injection des lignes d'articles...");
    await bulkInsertDocumentItems(documentItems);
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`\n✨ [DATA ENG] Écosystème transactionnel complet injecté avec succès en ${duration} secondes !`);

  } catch (error: any) {
    console.error("❌ [DATA ENG] Échec critique du pipeline :", error.message || error);
  } finally {
    await client.end();
    console.log("[DATA ENG] Connexion PostgreSQL fermée proprement.");
  }
}

main();