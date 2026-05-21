import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import pino from 'pino';

const logger = pino({ transport: { target: 'pino-pretty' } });
const JWT_SECRET = process.env.JWT_SECRET || 'votre_cle_secrete_super_secure';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    companyId: string;
    role: string;
  };
}

export const requireAuth = (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('[AUTH MIDDLEWARE] Tentative d accès refusée : Token manquant');
    res.status(401).json({ error: 'Accès refusé. Token d authentification manquant ou invalide.' });
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    // Vérification et décodage du jeton JWT
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    
    // Injection des données de session de l'entreprise africaine dans la requête
    req.user = {
      id: decoded.id,
      email: decoded.email,
      companyId: decoded.companyId,
      role: decoded.role
    };

    logger.info({ companyId: req.user.companyId }, '[AUTH MIDDLEWARE] Utilisateur authentifié avec succès');
    next();
  } catch (error) {
    logger.error(error, '[AUTH MIDDLEWARE] Échec de la vérification du Token');
    res.status(403).json({ error: 'Token invalide ou expiré.' });
  }
};