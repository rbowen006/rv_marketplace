import type { ListingSummary } from './listing';

export type ConciergeStatus = 'none' | 'idle' | 'processing' | 'failed';

export interface ConciergeMessage {
  role: 'user' | 'assistant';
  text: string;
}

export interface ConciergeData {
  status: ConciergeStatus;
  step_status?: string | null;
  error?: string | null;
  messages?: ConciergeMessage[];
  recommendations?: ListingSummary[];
}

export interface ConciergeEnvelope {
  status: string;
  data: ConciergeData;
  message?: string;
}
