import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors'; // 🛡️ AJOUT : Import de la sécurité CORS
import pino from 'pino';
import { db } from './config/db';
import { salesRouter } from './routes/sales.routes';
import { authRouter } from './routes/auth.routes'; // 🔑 À décommenter dès que ton fichier de routes d'authentification existe

const logger = pino({ transport: { target: 'pino-pretty' } });
const app = express();

// 🛡️ AJOUT : Configuration du middleware CORS pour autoriser l'application mobile
app.use(cors({
  origin: '*', // En développement, on autorise toutes les connexions (Mobile, Web-server, GitHub Codespaces)
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());

// Middleware de Log des requêtes HTTP
app.use((req: Request, res: Response, next: NextFunction) => {
  logger.info({ method: req.method, url: req.url }, 'Requête HTTP entrante');
  next();
});

// 📁 Déclaration des Routes
app.use('/api/sales', salesRouter);
app.use('/api/auth', authRouter); // 🔑 Branchement des routes d'authentification pour le mobile

// Endpoint de diagnostic de santé (Healthcheck)
app.get('/health', async (req: Request, res: Response) => {
  try {
    // Test rapide de la connexion Neon
    await db.query('SELECT NOW()');
    res.status(200).json({ status: 'UP', database: 'CONNECTED', timestamp: new Date() });
  } catch (error) {
    logger.error(error, 'Erreur lors du healthcheck');
    res.status(500).json({ status: 'DOWN', error: 'Database connection failed' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`[SERVER] Le REM Core tourne sur le port ${PORT}`);
});