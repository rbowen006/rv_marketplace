import { FormEvent, useEffect, useRef, useState, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import type { ChatDetail, Message, MessageGroupItem } from '../types/chat';

const ONE_HOUR_MS = 60 * 60 * 1000;

function formatTimestampLabel(date: Date): string {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterdayStart = new Date(todayStart.getTime() - 24 * 60 * 60 * 1000);
  const weekAgoStart = new Date(todayStart.getTime() - 6 * 24 * 60 * 60 * 1000);
  const timeStr = date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });

  if (date >= todayStart) return `Today at ${timeStr}`;
  if (date >= yesterdayStart) return `Yesterday at ${timeStr}`;
  if (date >= weekAgoStart)
    return `${date.toLocaleDateString([], { weekday: 'long' })} at ${timeStr}`;

  const dateStr = date.toLocaleDateString([], {
    month: 'short',
    day: 'numeric',
    ...(date.getFullYear() !== now.getFullYear() ? { year: 'numeric' } : {}),
  });
  return `${dateStr} at ${timeStr}`;
}

function groupMessages(messages: Message[]): MessageGroupItem[] {
  const result: MessageGroupItem[] = [];
  let prevDate: Date | null = null;
  for (const msg of messages) {
    const msgDate = new Date(msg.created_at);
    if (prevDate === null || msgDate.getTime() - prevDate.getTime() >= ONE_HOUR_MS) {
      result.push({ type: 'label', key: `label-${msg.id}`, text: formatTimestampLabel(msgDate) });
    }
    result.push({ type: 'message', ...msg });
    prevDate = msgDate;
  }
  return result;
}

export function ChatPage() {
  const { id } = useParams();
  const { token, user } = useAuth();
  const apiFetch = useApiFetch();

  const [chat, setChat] = useState<ChatDetail | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const authHeaders = { Authorization: `Bearer ${token}` };

  const loadChat = useCallback(async () => {
    try {
      const { res, data } = await apiFetch<ChatDetail>(`/api/v1/chats/${id}`, {
        headers: authHeaders,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setChat(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [id, token]);

  useEffect(() => {
    loadChat();
  }, [loadChat]);

  // Fetch messages immediately on mount, then poll every 5 seconds to catch new messages
  useEffect(() => {
    const poll = async () => {
      try {
        const { res, data } = await apiFetch<Message[]>(`/api/v1/chats/${id}/messages`, {
          headers: authHeaders,
        });
        if (!res.ok) return;
        setMessages(data);
      } catch {
        // silent — don't surface poll errors
      }
    };
    poll();
    const interval = setInterval(poll, 5000);
    return () => clearInterval(interval);
  }, [id, token]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function handleSend(e: FormEvent) {
    e.preventDefault();
    if (!draft.trim()) return;
    setSending(true);
    try {
      const { res, data: msg } = await apiFetch<Message>(`/api/v1/chats/${id}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...authHeaders },
        body: JSON.stringify({ message: { content: draft.trim() } }),
      });
      if (!res.ok) throw new Error('Failed to send');
      setMessages((prev) => [...prev, msg]);
      setDraft('');
      inputRef.current?.focus();
    } catch {
      // Keep draft so the user can retry
    } finally {
      setSending(false);
    }
  }

  if (loading) return <div className="p-8 text-gray-500">Loading…</div>;
  if (error) return <div className="p-8 text-red-500">Error: {error}</div>;
  if (!chat) return null;

  const otherParticipant = user?.id === chat.hirer_id ? chat.owner : chat.hirer;

  return (
    <div className="max-w-2xl mx-auto flex flex-col" style={{ height: 'calc(100vh - 64px)' }}>
      {/* Header */}
      <div className="flex items-center gap-3 px-6 py-4 border-b border-gray-200 flex-shrink-0">
        <Link to="/chats" className="text-gray-400 hover:text-gray-700 text-sm mr-1">
          ←
        </Link>
        <div className="w-9 h-9 rounded-full bg-rose-100 flex items-center justify-center text-rose-500 font-semibold text-sm flex-shrink-0">
          {otherParticipant?.name?.[0]?.toUpperCase() ?? '?'}
        </div>
        <div>
          <p className="font-semibold text-gray-900 text-sm">{otherParticipant?.name ?? 'Owner'}</p>
          {chat.listing_title && (
            <p className="text-xs text-gray-400 truncate">{chat.listing_title}</p>
          )}
        </div>
      </div>

      {/* Message thread */}
      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-3">
        {messages.length === 0 && (
          <p className="text-center text-sm text-gray-400 py-8">No messages yet.</p>
        )}
        {groupMessages(messages).map((item) => {
          if (item.type === 'label') {
            return (
              <div key={item.key} className="text-xs text-gray-400 text-center py-1 select-none">
                {item.text}
              </div>
            );
          }
          const mine = item.user_id === user?.id;
          return (
            <div key={item.id} className={`flex ${mine ? 'justify-end' : 'justify-start'}`}>
              <div
                className={`max-w-xs lg:max-w-sm px-4 py-2 rounded-2xl text-sm leading-relaxed ${
                  mine
                    ? 'bg-rose-500 text-white rounded-br-sm'
                    : 'bg-gray-100 text-gray-900 rounded-bl-sm'
                }`}
              >
                {item.content}
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <form
        onSubmit={handleSend}
        className="flex items-center gap-3 px-6 py-4 border-t border-gray-200 flex-shrink-0"
      >
        <input
          ref={inputRef}
          type="text"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="Type a message…"
          className="flex-1 border border-gray-300 rounded-full px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
        />
        <button
          type="submit"
          disabled={sending || !draft.trim()}
          className="bg-rose-500 hover:bg-rose-600 disabled:bg-rose-300 text-white font-semibold px-5 py-2 rounded-full text-sm transition-colors"
        >
          {sending ? '…' : 'Send'}
        </button>
      </form>
    </div>
  );
}
