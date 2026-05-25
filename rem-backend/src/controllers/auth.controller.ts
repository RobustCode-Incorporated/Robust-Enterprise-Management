import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { db } from '../config/db';
import pino from 'pino';

const logger = pino({ transport: { target: 'pino-pretty' } });
const SALT_ROUNDS = 12;

// 🛡️ UNIFICATION DU SECRET JWT (On garde ta clé robuste du marché africain)
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_local_key_for_africa_market';

/**
 * @desc    Enregistre une nouvelle entreprise et son administrateur principal (Multi-tenant)
 * @route   POST /api/auth/register
 * @access  Public
 */
export const registerCompanyAndUser = async (req: Request, res: Response): Promise<void> => {
  const { companyName, country, firstName, lastName, email, password } = req.body;
  
  logger.info({ email }, '[AUTH LOG] Tentative d inscription reçue');

  try {
    // 1. Vérification de l'existence de l'utilisateur (Sécurité & Intégrité)
    const checkUser = await db.query('SELECT id FROM users WHERE email = $1', [email]);
    if (checkUser.rowCount && checkUser.rowCount > 0) {
      logger.warn({ email }, '[AUTH LOG] Échec de l inscription : Email déjà existant');
      res.status(400).json({ error: 'Cet e-mail est déjà utilisé.' });
      return;
    }

    // 2. Chiffrement du mot de passe via Bcrypt
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    // 3. Transaction SQL pour garantir la cohérence des données (Entreprise + Admin)
    const companyResult = await db.query(
      'INSERT INTO companies (name, country) VALUES ($1, $2) RETURNING id',
      [companyName, country]
    );
    const companyId = companyResult.rows[0].id;

    // Création de l'utilisateur rattaché
    const userResult = await db.query(
      'INSERT INTO users (company_id, first_name, last_name, email, password_hash, role) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, email, role',
      [companyId, firstName, lastName, email, passwordHash, 'ADMIN']
    );
    const user = userResult.rows[0];

    // 4. Génération du Token de session JWT (Expire dans 90 jours pour le réseau instable)
    const token = jwt.sign(
      { userId: user.id, companyId: companyId, role: user.role },
      JWT_SECRET,
      { expiresIn: '90d' }
    );

    logger.info({ userId: user.id }, '[AUTH SUCCESS] Entreprise et administrateur créés avec succès');
    
    res.status(201).json({
      message: 'Compte créé avec succès',
      token,
      user: { id: user.id, email: user.email, role: user.role }
    });

  } catch (error) {
    logger.error(error, '[AUTH ERROR] Erreur critique lors de l inscription');
    res.status(500).json({ error: 'Une erreur serveur est survenue lors de l inscription.' });
  }
};

/**
 * @desc    Authentifie un utilisateur (commercial/admin) et retourne son Token JWT
 * @route   POST /api/auth/login
 * @access  Public
 */
export const loginUser = async (req: Request, res: Response): Promise<void> => {
  const { email, password } = req.body;

  logger.info({ email }, '[AUTH LOG] Tentative de connexion reçue du mobile');

  try {
    // 1. Chercher l'utilisateur dans la base Neon par son email
    const userQuery = 'SELECT * FROM users WHERE email = $1 LIMIT 1';
    const userResult = await db.query(userQuery, [email]);

    if (userResult.rowCount === 0) {
      logger.warn({ email }, '[AUTH LOG] Échec connexion : Utilisateur introuvable');
      res.status(401).json({ message: 'Identifiants ou mot de passe incorrects.' });
      return;
    }

    const user = userResult.rows[0];

    // 2. Vérifier si le mot de passe est correct (on s'adapte à ton champ password_hash)
    const isPasswordValid = await bcrypt.compare(password, user.password_hash || user.password);
    if (!isPasswordValid) {
      logger.warn({ email }, '[AUTH LOG] Échec connexion : Mot de passe incorrect');
      res.status(401).json({ message: 'Identifiants ou mot de passe incorrects.' });
      return;
    }

    // 3. Générer le Token JWT incluant les données Multi-Tenant (90 jours pour être raccord avec ton registre)
    const token = jwt.sign(
      { 
        userId: user.id, 
        companyId: user.company_id, // Isoler les ventes de sa boutique
        role: user.role 
      },
      JWT_SECRET,
      { expiresIn: '90d' }
    );

    logger.info({ userId: user.id, companyId: user.company_id }, '[AUTH SUCCESS] Connexion mobile réussie');

    // 4. Réponse structurée au mobile avec le Token et les infos
    res.status(200).json({
      message: 'Connexion réussie',
      token,
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        companyId: user.company_id,
        role: user.role
      }
    });

  } catch (error) {
    logger.error(error, '[AUTH ERROR] Erreur critique lors de la connexion');
    res.status(500).json({ message: 'Une erreur serveur est survenue lors de l\'authentification.' });
  }
};