import { Router } from 'express';
import { registerCompanyAndUser, loginUser } from '../controllers/auth.controller'; // 🔑 AJOUT : loginUser

const router = Router();

/**
 * @route   POST /api/auth/register
 * @desc    Enregistre une nouvelle entreprise et son administrateur principal (Multi-tenant)
 * @access  Public
 */
router.post('/register', registerCompanyAndUser);

/**
 * @route   POST /api/auth/login
 * @desc    Authentifie un utilisateur (commercial/admin) et retourne son Token JWT
 * @access  Public
 */
router.post('/login', loginUser); // 🚀 AJOUT : Route cruciale pour l'application mobile

export const authRouter = router;