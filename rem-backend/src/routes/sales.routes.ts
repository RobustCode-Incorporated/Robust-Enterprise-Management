import { Router, Request, Response } from 'express';
import { 
  createSalesDocument, 
  createClient, 
  updateDocumentStatus, 
  syncOfflineDocument,
  getSalesDocuments, 
} from '../controllers/sales.controller';
import { getResellersLiveLocation } from '../controllers/resellers.controller'; // 🛰️ Importation du contrôleur de cartographie
import { requireAuth } from '../middlewares/auth.middleware'; // Notre verrou de sécurité
import { idempotencyMiddleware } from '../middlewares/idempotency.middleware'; // Le bouclier anti-doublons
import { runDataSimulation } from '../scripts/seed-simulation'; // 🚀 Importation du script de data engineering

const router = Router();

/**
 * @route   GET /api/sales/resellers-location
 * @desc    Extraction cartographique synchrone multi-critères des revendeurs (Nom, Email, Dépôt, Tél)
 * @access  Protégé (Requiert une session active et un Token JWT valide)
 */
router.get('/resellers-location', requireAuth, getResellersLiveLocation); // 🎯 RECOUVREMENT DE LA ROUTE CARTOGRAPHIQUE

/**
 * @route   GET /api/sales/documents
 * @desc    Liste des documents de vente avec pagination, filtres et recherche dynamique
 * @access  Protégé (Requiert une session active et un Token JWT valide)
 */
router.get('/documents', requireAuth, getSalesDocuments); 

/**
 * @route   POST /api/sales/documents
 * @desc    Création d'un devis ou d'une facture multi-tenant sécurisée
 * @access  Protégé (Requiert une session active et un Token JWT valide)
 */
router.post('/documents', requireAuth, createSalesDocument);

/**
 * @route   POST /api/sales/clients
 * @desc    Création d'un client rattaché à l'entreprise (Multi-tenant)
 * @access  Protégé (Requiert une session active et un Token JWT valide)
 */
router.post('/clients', requireAuth, createClient);

/**
 * @route   PATCH /api/sales/documents/:id/status
 * @desc    Encaisser ou changer le statut d'un document commercial
 * @access  Protégé (Requiert une session active et un Token JWT valide)
 */
router.patch('/documents/:id/status', requireAuth, updateDocumentStatus);

/**
 * @route   POST /api/sales/sync
 * @desc    Synchronisation Offline-First depuis l'application mobile (Gère l'idempotence)
 * @access  Protégé (Requiert Token JWT valide + clé d'idempotence X-Idempotency-Key dans les headers)
 */
router.post('/sync', requireAuth, idempotencyMiddleware, syncOfflineDocument);

/**
 * @route   GET /api/sales/maintenance/seed-simulation
 * @desc    Nettoyage complet de la DB et injection ordonnée de données de simulation (Revendeurs GPS, Produits, Clients, Ventes et Stocks)
 * @access  Public (Réservé au développement local / Environnement Dev)
 */
router.get('/maintenance/seed-simulation', async (req: Request, res: Response) => {
  try {
    // ID d'entreprise par défaut utilisé pour ton espace de travail
    const companyId = '943e411e-9c4c-484f-9dde-9db708f5159a';

    console.log(`[MAINTENANCE] Déclenchement manuel de la simulation par l'ingénieur.`);
    
    // Lancement du moteur de traitement de données
    await runDataSimulation(companyId);

    res.status(200).json({
      success: true,
      message: "Base de données réinitialisée et simulation injectée avec succès ! Stocks mis à jour et synchronisés."
    });
  } catch (error: any) {
    console.error("❌ [MAINTENANCE CRITICAL] Échec du seed :", error);
    res.status(500).json({
      success: false,
      error: "Échec de la réinitialisation des données",
      details: error.message
    });
  }
});

export const salesRouter = router;