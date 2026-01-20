// Environment configuration with type-safe defaults
export const config = {
  // CORS origins (comma-separated)
  corsOrigins: process.env['CORS_ORIGINS']?.split(',') ?? ['http://localhost:3000'],

  // AWS region
  awsRegion: process.env['DEFAULT_AWS_REGION'] ?? 'us-east-1',

  // OpenAI configuration
  openaiApiKey: process.env['OPENAI_API_KEY'] ?? '',
  // Options: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo
  openaiModel: process.env['OPENAI_MODEL'] ?? 'gpt-4o-mini',

  // Memory storage
  useS3: process.env['USE_S3']?.toLowerCase() === 'true',
  s3Bucket: process.env['S3_BUCKET'] ?? '',
  memoryDir: process.env['MEMORY_DIR'] ?? '../memory',

  // Server port (for local development)
  port: Number.parseInt(process.env['PORT'] ?? '8000', 10),
} as const;

export type Config = typeof config;
