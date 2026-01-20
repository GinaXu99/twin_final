import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { config } from './utils/config.js';
import { loadResources } from './services/context.js';
import { loadConversation, saveConversation } from './services/memory.js';
import { callOpenAI } from './services/openai.js';
import type { ChatRequest, ConversationMessage } from './types/index.js';

let initialized = false;

/**
 * Initialize resources on cold start
 */
const initialize = async (): Promise<void> => {
  if (!initialized) {
    await loadResources();
    initialized = true;
    console.log('Lambda initialized');
  }
};

/**
 * Create CORS headers
 */
const getCorsHeaders = (origin?: string): Record<string, string> => {
  const allowedOrigin = config.corsOrigins.includes(origin ?? '')
    ? origin!
    : config.corsOrigins[0] ?? '*';

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Max-Age': '300',
    'Content-Type': 'application/json',
  };
};

/**
 * Create JSON response helper
 */
const jsonResponse = (
  statusCode: number,
  body: unknown,
  headers: Record<string, string>
): APIGatewayProxyResultV2 => ({
  statusCode,
  headers,
  body: JSON.stringify(body),
});

/**
 * Lambda handler for API Gateway HTTP API (v2)
 */
export const handler = async (
  event: APIGatewayProxyEventV2,
  _context: Context
): Promise<APIGatewayProxyResultV2> => {
  // Initialize on cold start
  await initialize();

  const method = event.requestContext.http.method;
  const path = event.rawPath || '/';
  const origin = event.headers?.['origin'];
  const corsHeaders = getCorsHeaders(origin);

  // Handle CORS preflight
  if (method === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    // Route: GET /
    if (method === 'GET' && path === '/') {
      return jsonResponse(200, {
        message: 'AI Digital Twin API (Powered by OpenAI)',
        memory_enabled: true,
        storage: config.useS3 ? 'S3' : 'local',
        ai_model: config.openaiModel,
      }, corsHeaders);
    }

    // Route: GET /health
    if (method === 'GET' && path === '/health') {
      return jsonResponse(200, {
        status: 'healthy',
        use_s3: config.useS3,
        openai_model: config.openaiModel,
      }, corsHeaders);
    }

    // Route: POST /chat
    if (method === 'POST' && path === '/chat') {
      const body = event.body
        ? event.isBase64Encoded
          ? Buffer.from(event.body, 'base64').toString()
          : event.body
        : '{}';

      const request = JSON.parse(body) as ChatRequest;

      if (!request.message || typeof request.message !== 'string') {
        return jsonResponse(400, { error: 'Message is required' }, corsHeaders);
      }

      // Generate session ID if not provided
      const sessionId = request.session_id ?? uuidv4();

      // Load conversation history
      const conversation = await loadConversation(sessionId);

      // Call OpenAI for response
      const assistantResponse = await callOpenAI(conversation, request.message);

      // Create new messages
      const timestamp = new Date().toISOString();

      const userMessage: ConversationMessage = {
        role: 'user',
        content: request.message,
        timestamp,
      };

      const assistantMessage: ConversationMessage = {
        role: 'assistant',
        content: assistantResponse,
        timestamp,
      };

      // Update and save conversation
      conversation.push(userMessage, assistantMessage);
      await saveConversation(sessionId, conversation);

      return jsonResponse(200, {
        response: assistantResponse,
        session_id: sessionId,
      }, corsHeaders);
    }

    // Route: GET /conversation/:sessionId
    if (method === 'GET' && path.startsWith('/conversation/')) {
      const sessionId = path.replace('/conversation/', '');

      if (!sessionId) {
        return jsonResponse(400, { error: 'Session ID is required' }, corsHeaders);
      }

      const messages = await loadConversation(sessionId);

      return jsonResponse(200, {
        session_id: sessionId,
        messages,
      }, corsHeaders);
    }

    // 404 Not Found
    return jsonResponse(404, { error: 'Not found' }, corsHeaders);

  } catch (error) {
    console.error('Lambda error:', error);

    const errorMessage = error instanceof Error ? error.message : 'Unknown error';

    if (errorMessage.includes('Access denied')) {
      return jsonResponse(403, { error: errorMessage }, corsHeaders);
    }

    if (errorMessage.includes('Invalid message format')) {
      return jsonResponse(400, { error: errorMessage }, corsHeaders);
    }

    return jsonResponse(500, { error: 'Internal server error' }, corsHeaders);
  }
};
