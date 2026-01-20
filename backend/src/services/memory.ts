import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { config } from '../utils/config.js';
import type { ConversationMessage } from '../types/index.js';

// Initialize S3 client
const s3Client = new S3Client({ region: config.awsRegion });

/**
 * Get the storage path/key for a session
 */
const getMemoryPath = (sessionId: string): string => `${sessionId}.json`;

/**
 * Load conversation history from storage (S3 or local file)
 */
export const loadConversation = async (sessionId: string): Promise<ConversationMessage[]> => {
  return config.useS3 ? loadFromS3(sessionId) : loadFromFile(sessionId);
};

/**
 * Save conversation history to storage (S3 or local file)
 */
export const saveConversation = async (
  sessionId: string,
  messages: ConversationMessage[]
): Promise<void> => {
  return config.useS3 ? saveToS3(sessionId, messages) : saveToFile(sessionId, messages);
};

/**
 * Load conversation from S3
 */
const loadFromS3 = async (sessionId: string): Promise<ConversationMessage[]> => {
  try {
    const command = new GetObjectCommand({
      Bucket: config.s3Bucket,
      Key: getMemoryPath(sessionId),
    });

    const response = await s3Client.send(command);
    const bodyString = await response.Body?.transformToString();

    if (!bodyString) {
      return [];
    }

    return JSON.parse(bodyString) as ConversationMessage[];
  } catch (error) {
    // If the key doesn't exist, return empty array
    if (error instanceof Error && error.name === 'NoSuchKey') {
      return [];
    }
    throw error;
  }
};

/**
 * Save conversation to S3
 */
const saveToS3 = async (sessionId: string, messages: ConversationMessage[]): Promise<void> => {
  const command = new PutObjectCommand({
    Bucket: config.s3Bucket,
    Key: getMemoryPath(sessionId),
    Body: JSON.stringify(messages, null, 2),
    ContentType: 'application/json',
  });

  await s3Client.send(command);
};

/**
 * Load conversation from local file
 */
const loadFromFile = async (sessionId: string): Promise<ConversationMessage[]> => {
  const filePath = join(config.memoryDir, getMemoryPath(sessionId));

  try {
    const data = await readFile(filePath, 'utf-8');
    return JSON.parse(data) as ConversationMessage[];
  } catch (error) {
    // If file doesn't exist, return empty array
    if (error instanceof Error && (error as NodeJS.ErrnoException).code === 'ENOENT') {
      return [];
    }
    throw error;
  }
};

/**
 * Save conversation to local file
 */
const saveToFile = async (sessionId: string, messages: ConversationMessage[]): Promise<void> => {
  // Ensure directory exists
  await mkdir(config.memoryDir, { recursive: true });

  const filePath = join(config.memoryDir, getMemoryPath(sessionId));
  await writeFile(filePath, JSON.stringify(messages, null, 2), 'utf-8');
};
