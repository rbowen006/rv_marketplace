import { createContext, useContext, useEffect, useState } from 'react';
import { useAuth } from './AuthContext';

const UnreadContext = createContext(0);

export function UnreadProvider({ children }) {
  const { token, user } = useAuth();
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    if (!token || !user) {
      setUnreadCount(0);
      return;
    }

    async function fetchUnread() {
      try {
        const res = await fetch('/api/v1/chats', {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!res.ok) return;
        const data = await res.json();
        let count = 0;
        for (const chat of data.as_hirer ?? []) {
          if (chat.last_message_at && chat.last_message_at > (chat.hirer_last_read_at ?? '')) count++;
        }
        for (const chat of data.as_owner ?? []) {
          if (chat.last_message_at && chat.last_message_at > (chat.owner_last_read_at ?? '')) count++;
        }
        setUnreadCount(count);
      } catch {
        // silent — don't surface poll errors
      }
    }

    fetchUnread();
    const interval = setInterval(fetchUnread, 30_000);
    return () => clearInterval(interval);
  }, [token, user]);

  return (
    <UnreadContext.Provider value={unreadCount}>
      {children}
    </UnreadContext.Provider>
  );
}

export function useUnreadCount() {
  return useContext(UnreadContext);
}
