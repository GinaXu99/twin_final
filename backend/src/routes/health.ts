import { Router, type Request, type Response } from 'express';
import { config } from '../utils/config.js';
import type { HealthResponse, RootResponse } from '../types/index.js';

const router = Router();

/**
 * GET / - Root endpoint
 */
router.get('/', (_req: Request, res: Response<RootResponse>) => {
  res.json({
    message: 'AI Digital Twin API (Powered by OpenAI)',
    memory_enabled: true,
    storage: config.useS3 ? 'S3' : 'local',
    ai_model: config.openaiModel,
  });
});

/**
 * GET /health - Health check endpoint
 */
router.get('/health', (_req: Request, res: Response<HealthResponse>) => {
  res.json({
    status: 'healthy',
    use_s3: config.useS3,
    openai_model: config.openaiModel,
  });
});

export default router;
