import 'dotenv/config';  // Must be first - loads .env before other imports
import express, { type Express } from 'express';
import cors from 'cors';
import { config } from './utils/config.js';
import { loadResources } from './services/context.js';
import healthRoutes from './routes/health.js';
import chatRoutes from './routes/chat.js';
import conversationRoutes from './routes/conversation.js';
// Create Express app
export const app: Express = express();

// Middleware
app.use(express.json());

// Configure CORS
app.use(
  cors({
    origin: config.corsOrigins,
    credentials: false,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['*'],
  })
);

// Routes
app.use('/', healthRoutes);
app.use('/', chatRoutes);
app.use('/', conversationRoutes);

// Initialize resources
let resourcesLoaded = false;

export const initializeApp = async (): Promise<void> => {
  if (!resourcesLoaded) {
    await loadResources();
    resourcesLoaded = true;
  }
};

// Start server (for local development)
// ES Module entry point detection
const isMainModule = import.meta.url === `file://${process.argv[1]}`;

if (isMainModule) {
  initializeApp().then(() => {
    app.listen(config.port, () => {
      console.log(`Server running on http://localhost:${config.port}`);
      console.log(`Storage: ${config.useS3 ? 'S3' : 'local'}`);
      console.log(`OpenAI model: ${config.openaiModel}`);
    });
  });
}
