import type { ChatSummary } from './chat';

export interface AuthUser {
  id?: number;
  name?: string;
  email?: string;
}

export interface AuthContextValue {
  token: string | null;
  user: AuthUser | null;
  signIn: (email: string, password: string) => Promise<AuthUser>;
  signUp: (name: string, email: string, password: string) => Promise<AuthUser>;
  signOut: () => Promise<void>;
}

export interface ChatsCollection {
  as_hirer: ChatSummary[];
  as_owner: ChatSummary[];
}

export interface ChatsContextValue {
  chats: ChatsCollection;
  initialized: boolean;
  refreshChats: () => Promise<void>;
}
