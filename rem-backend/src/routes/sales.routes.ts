import { Router } from 'express';
import { createSalesDocument } from '../controllers/sales.controller';
import { requireAuth } from '../middlewares/auth.middleware'; // Import du verrou de sécurité

const router = Router();

/**
 * @route   POST /api/sales/documents
 * @desc    Création d'un devis ou d'une facture multi-tenant sécurisée
 * @access  Protégé (Requiert une session active et un Token JWT valide)
 */
// Nous ajoutons 'requireAuth' juste avant le contrôleur pour intercepter et valider la requête
router.post('/documents', requireAuth, createSalesDocument);

export const salesRouter = router;