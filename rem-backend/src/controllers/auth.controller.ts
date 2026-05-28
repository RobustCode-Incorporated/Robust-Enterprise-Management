import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { db } from '../config/db';
import pino from 'pino';

const logger = pino({ transport: { target: 'pino-pretty' } });
const SALT_ROUNDS = 12;
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_local_key_for_africa_market';

// --- LOGIQUE INITIALE : ENREGISTREMENT ADMIN ---
export const registerCompanyAndUser = async (req: Request, res: Response): Promise<void> => {
  const { companyName, country, firstName, lastName, email, password } = req.body;
  
  logger.info({ email }, '[AUTH] Tentative d inscription pour : ' + companyName);

  try {
    const checkUser = await db.query('SELECT id FROM users WHERE email = $1', [email]);
    if (checkUser.rowCount && checkUser.rowCount > 0) {
      res.status(400).json({ error: 'Cet e-mail est déjà utilisé.' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    await db.query('BEGIN');

    const companyResult = await db.query(
      'INSERT INTO companies (name, country) VALUES ($1, $2) RETURNING id',
      [companyName, country]
    );
    const companyId = companyResult.rows[0].id;

    const userResult = await db.query(
      'INSERT INTO users (company_id, first_name, last_name, email, password_hash, role) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, email, role',
      [companyId, firstName, lastName, email, passwordHash, 'ADMIN']
    );
    
    await db.query('COMMIT');

    const user = userResult.rows[0];
    const token = jwt.sign({ userId: user.id, companyId, role: user.role }, JWT_SECRET, { expiresIn: '90d' });

    res.status(201).json({ message: 'Compte créé avec succès', token });

  } catch (error) {
    await db.query('ROLLBACK');
    logger.error(error, '[AUTH ERROR] Échec transactionnel');
    res.status(500).json({ error: 'Erreur interne lors de la création.' });
  }
};

// --- LOGIQUE MISE À JOUR : LOGIN GÉNÉRIQUE ---
export const loginUser = async (req: Request, res: Response): Promise<void> => {
  const { email, password } = req.body;

  try {
    const userResult = await db.query('SELECT * FROM users WHERE email = $1 LIMIT 1', [email]);
    if (userResult.rowCount === 0) {
      res.status(401).json({ message: 'Identifiants incorrects.' });
      return;
    }

    const user = userResult.rows[0];
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    
    if (!isPasswordValid) {
      res.status(401).json({ message: 'Identifiants incorrects.' });
      return;
    }

    // Récupération de l'ID spécifique si c'est un revendeur
    let resellerId = null;
    if (user.role === 'RESELLER') {
      const resellerData = await db.query('SELECT id FROM resellers WHERE email = $1', [email]);
      if (resellerData.rowCount && resellerData.rowCount > 0) {
        resellerId = resellerData.rows[0].id;
      }
    }

    const token = jwt.sign(
      { userId: user.id, companyId: user.company_id, role: user.role },
      JWT_SECRET,
      { expiresIn: '90d' }
    );

    res.status(200).json({
      token,
      user: { 
        id: user.id, 
        resellerId: resellerId, // On envoie le vrai ID de la table 'resellers'
        firstName: user.first_name, 
        companyId: user.company_id, 
        role: user.role 
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// --- NOUVELLE FONCTIONNALITÉ : CRÉATION COMPLÈTE RESELLER (MÉTIER + ACCÈS) ---
export const createResellerWithAccess = async (req: Request, res: Response): Promise<void> => {
  const { companyId, firstName, lastName, email, password, phone, deposit_name } = req.body;
  
  logger.info({ email }, '[AUTH] Création complète d un revendeur');

  try {
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    await db.query('BEGIN'); // Début de la transaction

    // 1. Inscription dans la table 'resellers' (Gestion métier)
    // Correspond aux colonnes : company_id, name, email, password_hash, phone, deposit_name
    await db.query(
      `INSERT INTO resellers (company_id, name, email, password_hash, phone, deposit_name) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [companyId, firstName + ' ' + lastName, email, passwordHash, phone, deposit_name]
    );

    // 2. Inscription dans la table 'users' (Accès login)
    await db.query(
      `INSERT INTO users (company_id, first_name, last_name, email, password_hash, role) 
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [companyId, firstName, lastName, email, passwordHash, 'RESELLER']
    );

    await db.query('COMMIT'); // Validation des deux insertions

    res.status(201).json({ message: 'Revendeur créé avec succès et accès généré.' });
  } catch (error) {
    await db.query('ROLLBACK'); // Annulation en cas d'erreur
    console.error("ERREUR DÉTAILLÉE LORS DE LA CRÉATION RESELLER :", error);
    res.status(500).json({ error: 'Erreur lors de la création du revendeur.' });
  }
};