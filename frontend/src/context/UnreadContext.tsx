import { createContext, useCallback, useContext, useEffect, useState, ReactNode } from 'react';
import { useAuth } from './AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import type { ChatsCollection, ChatsContextValue } from '../types/auth';

const EMPTY_CHATS: ChatsCollection = { as_hirer: [], as_owner: [] };

const UnreadContext = createContext<number>(0);
const ChatsContext = createContext<ChatsContextValue>({
  chats: EMPTY_CHATS,
  initialized: false,
  refreshChats: async () => {},
});

export function UnreadProvider({ children }: { children: ReactNode }) {
  const { token, user } = useAuth();
  const apiFetch = useApiFetch();
  const [unreadCount, setUnreadCount] = useState(0);
  const [chats, setChats] = useState<ChatsCollection>(EMPTY_CHATS);
  const [initialized, setInitialized] = useState(false);

  const fetchUnread = useCallback(async () => {
    if (!token || !user) return;
    try {
      const { res, data } = await apiFetch<ChatsCollection>('/api/v1/chats', {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) {
        setInitialized(true);
        return;
      }
      setChats(data);
      let count = 0;
      for (const chat of data.as_hirer ?? []) {
        if (chat.last_message_at && chat.last_message_at > (chat.hirer_last_read_at ?? '')) count++;
      }
      for (const chat of data.as_owner ?? []) {
        if (chat.last_message_at && chat.last_message_at > (chat.owner_last_read_at ?? '')) count++;
      }
      setUnreadCount(count);
      setInitialized(true);
    } catch {
      setInitialized(true);
    }
  }, [token, user]);

  useEffect(() => {
    if (!token || !user) {
      setUnreadCount(0);
      setChats(EMPTY_CHATS);
      setInitialized(false);
      return;
    }
    fetchUnread();
    const interval = setInterval(fetchUnread, 30_000);
    return () => clearInterval(interval);
  }, [token, user, fetchUnread]);

  return (
    <UnreadContext.Provider value={unreadCount}>
      <ChatsContext.Provider value={{ chats, initialized, refreshChats: fetchUnread }}>
        {children}
      </ChatsContext.Provider>
    </UnreadContext.Provider>
  );
}

export function useUnreadCount() {
  return useContext(UnreadContext);
}

export function useChats() {
  return useContext(ChatsContext);
}
