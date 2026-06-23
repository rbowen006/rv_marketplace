import { useEffect, useRef, useState, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function ChatPage() {
  const { id } = useParams();
  const { token, user } = useAuth();

  const [chat, setChat] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const bottomRef = useRef(null);
  const inputRef = useRef(null);

  const authHeaders = { Authorization: `Bearer ${token}` };

  const loadChat = useCallback(async () => {
    try {
      const res = await fetch(`/api/v1/chats/${id}`, { headers: authHeaders });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setChat(data);
      setMessages(data.messages ?? []);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [id, token]);

  useEffect(() => {
    loadChat();
  }, [loadChat]);

  // Poll for new messages every 5 seconds
  useEffect(() => {
    const interval = setInterval(async () => {
      try {
        const res = await fetch(`/api/v1/chats/${id}/messages`, { headers: authHeaders });
        if (!res.ok) return;
        const data = await res.json();
        setMessages(data);
      } catch {
        // silent — don't surface poll errors
      }
    }, 5000);
    return () => clearInterval(interval);
  }, [id, token]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function handleSend(e) {
    e.preventDefault();
    if (!draft.trim()) return;
    setSending(true);
    try {
      const res = await fetch(`/api/v1/chats/${id}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...authHeaders },
        body: JSON.stringify({ message: { content: draft.trim() } }),
      });
      if (!res.ok) throw new Error('Failed to send');
      const msg = await res.json();
      setMessages(prev => [...prev, msg]);
      setDraft('');
      inputRef.current?.focus();
    } catch (err) {
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
        <Link to="/" className="text-gray-400 hover:text-gray-700 text-sm mr-1">←</Link>
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
        {messages.map(msg => {
          const mine = msg.user_id === user?.id;
          return (
            <div key={msg.id} className={`flex ${mine ? 'justify-end' : 'justify-start'}`}>
              <div
                className={`max-w-xs lg:max-w-sm px-4 py-2 rounded-2xl text-sm leading-relaxed ${
                  mine
                    ? 'bg-rose-500 text-white rounded-br-sm'
                    : 'bg-gray-100 text-gray-900 rounded-bl-sm'
                }`}
              >
                {msg.content}
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <form onSubmit={handleSend} className="flex items-center gap-3 px-6 py-4 border-t border-gray-200 flex-shrink-0">
        <input
          ref={inputRef}
          type="text"
          value={draft}
          onChange={e => setDraft(e.target.value)}
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
