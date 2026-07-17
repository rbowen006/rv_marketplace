import { FormEvent, KeyboardEvent, useEffect, useRef, useState, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import { ConfirmDialog } from '../components/ConfirmDialog';
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
  const [suggesting, setSuggesting] = useState(false);
  const [suggestError, setSuggestError] = useState<string | null>(null);
  const [confirmingSuggest, setConfirmingSuggest] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

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

  // Auto-grow the compose textarea to fit its content (e.g. a multi-line drafted reply).
  useEffect(() => {
    const el = inputRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${el.scrollHeight}px`;
  }, [draft]);

  async function sendMessage() {
    if (!draft.trim()) return;
    setSuggestError(null);
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

  function handleSend(e: FormEvent) {
    e.preventDefault();
    sendMessage();
  }

  // Enter sends; Shift+Enter inserts a newline (so drafted replies can be multi-line).
  function handleKeyDown(e: KeyboardEvent<HTMLTextAreaElement>) {
    // isComposing guards against sending mid-IME-composition (e.g. Enter confirming a candidate).
    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault();
      sendMessage();
    }
  }

  // An existing draft is worth protecting; suggesting over an empty one needs no ceremony.
  function handleSuggest() {
    if (draft.trim()) {
      setConfirmingSuggest(true);
      return;
    }
    runSuggest();
  }

  async function runSuggest() {
    setConfirmingSuggest(false);
    setSuggesting(true);
    setSuggestError(null);
    try {
      const { res, data } = await apiFetch<{ status: string; data: { reply: string } }>(
        `/api/v1/chats/${id}/suggest_reply`,
        { method: 'POST', headers: authHeaders },
      );
      if (!res.ok) throw new Error('Failed to suggest');
      setDraft(data.data.reply);
    } catch {
      setSuggestError("Couldn't suggest a reply. Please try again.");
    } finally {
      setSuggesting(false);
    }
  }

  if (loading) return <div className="p-8 text-gray-500">Loading…</div>;
  if (error) return <div className="p-8 text-red-500">Error: {error}</div>;
  if (!chat) return null;

  const otherParticipant = user?.id === chat.hirer_id ? chat.owner : chat.hirer;
  const isOwner = user?.id === chat.owner_id;
  const hasHirerMessage = messages.some((m) => m.user_id === chat.hirer_id);

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

      {confirmingSuggest && (
        <ConfirmDialog
          title="Replace your draft?"
          message="Suggesting a reply will overwrite the message you've started writing."
          confirmLabel="Replace draft"
          onConfirm={runSuggest}
          onCancel={() => setConfirmingSuggest(false)}
        />
      )}

      {/* Input */}
      {suggestError && (
        <p className="px-6 pt-2 text-xs text-red-500 flex-shrink-0">{suggestError}</p>
      )}
      <form
        onSubmit={handleSend}
        className="flex items-center gap-3 px-6 py-4 border-t border-gray-200 flex-shrink-0"
      >
        <textarea
          ref={inputRef}
          rows={1}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type a message…"
          className="flex-1 resize-none max-h-32 overflow-y-auto border border-gray-300 rounded-2xl px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
        />
        {isOwner && (
          <button
            type="button"
            onClick={handleSuggest}
            disabled={suggesting || !hasHirerMessage}
            title={hasHirerMessage ? undefined : 'Waiting on a message from the hirer'}
            className="text-rose-500 hover:text-rose-600 disabled:text-rose-300 font-semibold px-3 py-2 text-sm whitespace-nowrap transition-colors"
          >
            {suggesting ? '…' : 'Suggest reply'}
          </button>
        )}
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
