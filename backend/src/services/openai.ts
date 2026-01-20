import OpenAI from 'openai';
import { config } from '../utils/config.js';
import type { ConversationMessage } from '../types/index.js';
import { buildPrompt } from './context.js';

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: config.openaiApiKey,
});

/**
 * Call OpenAI with conversation history
 */
export const callOpenAI = async (
  conversation: ConversationMessage[],
  userMessage: string
): Promise<string> => {
  // Build messages in OpenAI format
  const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    // System prompt
    {
      role: 'system',
      content: buildPrompt(),
    },
    // Add conversation history (limit to last 20 messages for context management)
    ...conversation.slice(-20).map((msg) => ({
      role: msg.role as 'user' | 'assistant',
      content: msg.content,
    })),
    // Add current user message
    {
      role: 'user',
      content: userMessage,
    },
  ];

  try {
    const response = await openai.chat.completions.create({
      model: config.openaiModel,
      messages,
      max_tokens: 2000,
      temperature: 0.7,
      top_p: 0.9,
    });

    // Extract the response text
    const content = response.choices[0]?.message?.content;
    if (!content) {
      throw new Error('Empty response from OpenAI');
    }

    return content;
  } catch (error) {
    if (error instanceof OpenAI.APIError) {
      const { status, message } = error;

      if (status === 401) {
        console.error('OpenAI authentication error:', error);
        throw new Error('Invalid OpenAI API key');
      }

      if (status === 429) {
        console.error('OpenAI rate limit error:', error);
        throw new Error('OpenAI rate limit exceeded. Please try again later.');
      }

      if (status === 400) {
        console.error('OpenAI validation error:', error);
        throw new Error('Invalid message format for OpenAI');
      }

      console.error('OpenAI error:', error);
      throw new Error(`OpenAI error: ${message}`);
    }

    throw error;
  }
};
