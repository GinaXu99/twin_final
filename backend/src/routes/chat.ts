import { Router, type Request, type Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import type { ChatRequest, ChatResponse, ConversationMessage } from '../types/index.js';
import { loadConversation, saveConversation } from '../services/memory.js';
import { callOpenAI } from '../services/openai.js';

const router = Router();

/**
 * POST /chat - Chat endpoint
 */
router.post('/chat', async (req: Request<object, ChatResponse, ChatRequest>, res: Response) => {
  try {
    const { message, session_id } = req.body;

    if (!message || typeof message !== 'string') {
      res.status(400).json({ error: 'Message is required' });
      return;
    }

    // Generate session ID if not provided
    const sessionId = session_id ?? uuidv4();

    // Load conversation history
    const conversation = await loadConversation(sessionId);

    // Call OpenAI for response
    const assistantResponse = await callOpenAI(conversation, message);

    // Create new messages
    const timestamp = new Date().toISOString();

    const userMessage: ConversationMessage = {
      role: 'user',
      content: message,
      timestamp,
    };

    const assistantMessage: ConversationMessage = {
      role: 'assistant',
      content: assistantResponse,
      timestamp,
    };

    // Update conversation history
    conversation.push(userMessage, assistantMessage);

    // Save conversation
    await saveConversation(sessionId, conversation);

    // Return response
    const response: ChatResponse = {
      response: assistantResponse,
      session_id: sessionId,
    };

    res.json(response);
  } catch (error) {
    console.error('Error in chat endpoint:', error);

    if (error instanceof Error) {
      if (error.message.includes('Access denied')) {
        res.status(403).json({ error: error.message });
        return;
      }
      if (error.message.includes('Invalid message format')) {
        res.status(400).json({ error: error.message });
        return;
      }
    }

    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
