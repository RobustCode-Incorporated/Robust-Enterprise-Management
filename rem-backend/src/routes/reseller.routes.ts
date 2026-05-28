import { Router, Request, Response } from 'express';
import { db } from '../config/db';
import bcrypt from 'bcrypt';
import { createResellerWithAccess } from '../controllers/auth.controller'; // Import de la fonction transactionnelle

export const resellerRouter = Router();

// --- NOUVELLE ROUTE : Création complète avec accès login ---
// Appelée par le frontend via : /api/resellers/create-with-access
resellerRouter.post('/create-with-access', createResellerWithAccess);

// Création d'un revendeur (Route existante)
resellerRouter.post('/', async (req: Request, res: Response): Promise<void> => {
  const { company_id, name, email, password, phone, deposit_name } = req.body;

  try {
    // Hasher le mot de passe
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);
    
    const result = await db.query(
      `INSERT INTO resellers (company_id, name, email, password_hash, phone, deposit_name) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [company_id, name, email, passwordHash, phone, deposit_name]
    );
    
    res.status(201).json({ message: 'Revendeur créé avec succès', id: result.rows[0].id });
  } catch (error) {
    console.error('Erreur création revendeur:', error);
    res.status(500).json({ error: 'Erreur serveur lors de la création du revendeur.' });
  }
});

// Récupération des revendeurs d'une entreprise
resellerRouter.get('/', async (req: Request, res: Response): Promise<void> => {
  const companyId = req.query.company_id as string;
  try {
    const result = await db.query(
      'SELECT id, name, email, phone, deposit_name, latitude, longitude FROM resellers WHERE company_id = $1',
      [companyId]
    );
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Erreur lors de la récupération des revendeurs.' });
  }
});
resellerRouter.patch('/:id/location', async (req: Request, res: Response): Promise<void> => {
  const { id } = req.params;
  const { latitude, longitude } = req.body;
  try {
    await db.query(
      'UPDATE resellers SET latitude = $1, longitude = $2 WHERE id = $3',
      [latitude, longitude, id]
    );
    res.status(200).json({ message: 'Position mise à jour' });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
});