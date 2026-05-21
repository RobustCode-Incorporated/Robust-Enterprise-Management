import request from 'supertest';
import express from 'express';
import { salesRouter } from '../src/routes/sales.routes';
import { db } from '../src/config/db';

// 1. On configure l'application Express de test
const app = express();
app.use(express.json());

// 2. On court-circuite le middleware d'authentification UNIQUEMENT pour ce test
jest.mock('../src/middlewares/auth.middleware', () => ({
  requireAuth: (req: any, res: any, next: any) => {
    // On simule un utilisateur africain connecté et injecté par le middleware
    req.user = {
      id: 'user-uuid-999',
      email: 'test@boutique.sn',
      companyId: 'bf30cd12-9c1d-4074-b4a0-000000000000',
      role: 'ADMIN'
    };
    next(); // On laisse passer la requête vers le contrôleur
  },
}));

// 3. On mock le module de base de données Neon
jest.mock('../src/config/db', () => ({
  db: {
    query: jest.fn(),
    end: jest.fn(),
  },
}));

const mockedDbQuery = jest.mocked(db.query);

// On déclare les routes APRÈS avoir mocké le middleware pour que les changements soient pris en compte
app.use('/api/sales', salesRouter);

describe('📈 Suite de Tests TDD - Module REM Sales', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterAll(async () => {
    await db.end();
  });

  it('RED -> GREEN: Devrait générer une facture avec ses lignes d articles associés', async () => {
    // Simulation du retour Neon : Enregistrement du document (Invoice)
    mockedDbQuery.mockResolvedValueOnce({
      rows: [{ id: 'doc-12345', number: 'FAC-2026-001', total_amount: 150000 }],
    } as any);

    // Simulation du retour Neon : Enregistrement des lignes d'articles (Items)
    mockedDbQuery.mockResolvedValueOnce({ rowCount: 2 } as any);

    const response = await request(app)
      .post('/api/sales/documents')
      .send({
        clientId: 'client-999',
        type: 'INVOICE',
        items: [
          { description: 'Ordinateur Portable', quantity: 1, unitPrice: 100000 },
          { description: 'Souris Sans Fil', quantity: 2, unitPrice: 25000 },
        ],
      });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('document');
    expect(response.body.document).toHaveProperty('number');
    expect(response.body.document.total_amount).toBe(150000);
  });
});