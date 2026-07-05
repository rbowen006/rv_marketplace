export interface ChatParticipant {
  id: number;
  name?: string;
}

export interface ChatSummary {
  id: number;
  owner?: ChatParticipant;
  hirer?: ChatParticipant;
  last_message_at?: string | null;
  last_message_content?: string | null;
  hirer_last_read_at?: string | null;
  owner_last_read_at?: string | null;
}

export interface ChatDetail extends ChatSummary {
  hirer_id: number;
  owner_id: number;
  listing_title?: string | null;
}

export interface Message {
  id: number;
  content: string;
  user_id: number;
  created_at: string;
  read_at?: string | null;
}

export type ChatRole = 'hirer' | 'owner';

export type MessageGroupItem =
  | { type: 'label'; key: string; text: string }
  | ({ type: 'message' } & Message);
