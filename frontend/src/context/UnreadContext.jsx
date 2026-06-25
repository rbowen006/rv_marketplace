import { createContext, useContext, useEffect, useState } from 'react';
import { useAuth } from './AuthContext';

const UnreadContext = createContext(0);
const ChatsContext = createContext({ chats: { as_hirer: [], as_owner: [] }, initialized: false });

export function UnreadProvider({ children }) {
  const { token, user } = useAuth();
  const [unreadCount, setUnreadCount] = useState(0);
  const [chats, setChats] = useState({ as_hirer: [], as_owner: [] });
  const [initialized, setInitialized] = useState(false);

  useEffect(() => {
    if (!token || !user) {
      setUnreadCount(0);
      setChats({ as_hirer: [], as_owner: [] });
      setInitialized(false);
      return;
    }

    async function fetchUnread() {
      try {
        const res = await fetch('/api/v1/chats', {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!res.ok) {
          setInitialized(true);
          return;
        }
        const data = await res.json();
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
    }

    fetchUnread();
    const interval = setInterval(fetchUnread, 30_000);
    return () => clearInterval(interval);
  }, [token, user]);

  return (
    <UnreadContext.Provider value={unreadCount}>
      <ChatsContext.Provider value={{ chats, initialized }}>
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
