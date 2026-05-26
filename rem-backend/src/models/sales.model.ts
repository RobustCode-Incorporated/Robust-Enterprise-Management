import { db } from '../config/db';

export interface SalesSyncItemInput {
  productId: string | null;
  product_id?: string | null; // Support snake_case du mobile
  quantity: number;
  unitPrice: number;
  unit_price?: number;
  lineTotal?: number;
}

export interface SalesSyncInput {
  id: string;
  type: string;
  number: string;
  status: string;
  totalAmount: number;
  companyId: string;
  items: SalesSyncItemInput[]; // 📦 AJOUT : On force la transmission des articles
}

export class SalesModel {
  
  static async syncMobileDocument(doc: SalesSyncInput): Promise<void> {
    // 🛡️ DEV SENIOR : Utilisation impérative d'un client dédié pour la transaction ACID
    const client = await db.connect();
    
    try {
      await client.query('BEGIN');

      // 1. Insertion du document principal
      const docQuery = `
        INSERT INTO documents (id, company_id, type, number, status, total_amount, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, NOW())
        ON CONFLICT (id) DO NOTHING; -- Évite les crashs si déjà synchronisé
      `;
      await client.query(docQuery, [doc.id, doc.companyId, doc.type, doc.number, doc.status, doc.totalAmount]);

      // 2. Traitement des lignes d'articles et mise à jour des stocks Neon
      for (const item of doc.items) {
        const rawProductId = item.productId || item.product_id;
        const finalProductId = (rawProductId === '00000000-0000-0000-0000-000000000000' || !rawProductId)
          ? null 
          : rawProductId;
          
        const qty = item.quantity || 1;
        const price = item.unitPrice !== undefined ? item.unitPrice : (item.unit_price || 0);
        const lineTotal = item.lineTotal || (qty * price);

        // a) Insertion de la ligne de facture
        const itemQuery = `
          INSERT INTO document_items (document_id, product_id, quantity, unit_price, total_price)
          VALUES ($1, $2, $3, $4, $5);
        `;
        await client.query(itemQuery, [doc.id, finalProductId, qty, price, lineTotal]);

        // b) 🔄 DÉDUCTION DU STOCK REEL DANS NEON (Crucial pour le portail Vue 3)
        if (finalProductId && doc.status === 'PAID') {
          const updateStockQuery = `
            UPDATE products 
            SET stock_quantity = stock_quantity - $1, updated_at = NOW()
            WHERE id = $2 AND company_id = $3;
          `;
          await client.query(updateStockQuery, [qty, finalProductId, doc.companyId]);
        }
      }

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release(); // Libération immédiate de la connexion au pool Neon (Serverless friendly)
    }
  }

  static async getIdempotencyRecord(key: string): Promise<{ status: number; body: any } | null> {
    const query = 'SELECT response_status, response_body FROM idempotency_keys WHERE key = $1';
    const result = await db.query(query, [key]);
    if (result.rows.length === 0) return null;
    return {
      status: result.rows[0].response_status,
      body: JSON.parse(result.rows[0].response_body)
    };
  }

  static async saveIdempotencyRecord(key: string, status: number, body: any): Promise<void> {
    const query = `
      INSERT INTO idempotency_keys (key, response_status, response_body)
      VALUES ($1, $2, $3)
    `;
    await db.query(query, [key, JSON.stringify(body)]);
  }
}