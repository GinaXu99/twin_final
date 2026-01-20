// Request/Response types
export interface ChatRequest {
  message: string;
  session_id?: string;
}

export interface ChatResponse {
  response: string;
  session_id: string;
}

export interface HealthResponse {
  status: string;
  use_s3: boolean;
  openai_model: string;
}

export interface RootResponse {
  message: string;
  memory_enabled: boolean;
  storage: string;
  ai_model: string;
}

// Conversation types
export interface ConversationMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

export interface Conversation {
  session_id: string;
  messages: ConversationMessage[];
}

// Facts data structure
export interface Facts {
  full_name: string;
  name: string;
  current_role: string;
  location: string;
  email: string;
  linkedin: string;
  specialties: string[];
  years_experience: number;
  education: Array<{
    degree: string;
    institution: string;
    year: string;
  }>;
}

// Error types
export interface ApiError {
  error: string;
  statusCode?: number;
}
