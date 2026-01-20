import { Router, type Request, type Response } from 'express';
import { loadConversation } from '../services/memory.js';
import type { Conversation } from '../types/index.js';

const router = Router();

/**
 * GET /conversation/:sessionId - Get conversation history
 */
router.get(
  '/conversation/:sessionId',
  async (req: Request<{ sessionId: string }>, res: Response<Conversation | { error: string }>) => {
    try {
      const { sessionId } = req.params;

      if (!sessionId) {
        res.status(400).json({ error: 'Session ID is required' });
        return;
      }

      const messages = await loadConversation(sessionId);

      const response: Conversation = {
        session_id: sessionId,
        messages,
      };

      res.json(response);
    } catch (error) {
      console.error('Error getting conversation:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

export default router;
