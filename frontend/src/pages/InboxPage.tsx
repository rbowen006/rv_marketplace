import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useChats } from '../context/UnreadContext';
import type { ChatRole, ChatSummary } from '../types/chat';

function formatTimestamp(isoString: string | null | undefined): string {
  if (!isoString) return '';
  const date = new Date(isoString);
  const now = new Date();
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  if (date.getFullYear() === now.getFullYear()) {
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
  }
  return date.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' });
}

function isUnread(chat: ChatSummary, role: ChatRole): boolean {
  if (!chat.last_message_at) return false;
  const readAt = role === 'hirer' ? chat.hirer_last_read_at : chat.owner_last_read_at;
  if (!readAt) return true;
  return new Date(chat.last_message_at) > new Date(readAt);
}

interface ChatRowProps {
  chat: ChatSummary;
  role: ChatRole;
}

function ChatRow({ chat, role }: ChatRowProps) {
  const other = role === 'hirer' ? chat.owner : chat.hirer;
  const unread = isUnread(chat, role);

  return (
    <Link
      to={`/chats/${chat.id}`}
      className="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 border-b border-gray-100 no-underline"
    >
      {/* Unread dot */}
      <div className="flex-shrink-0 w-2.5 h-2.5">
        {unread && <div className="w-2.5 h-2.5 rounded-full bg-rose-500" />}
      </div>

      {/* Avatar */}
      <div className="flex-shrink-0 w-11 h-11 rounded-full bg-rose-100 flex items-center justify-center text-rose-500 font-semibold text-base">
        {other?.name?.[0]?.toUpperCase() ?? '?'}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-baseline justify-between gap-2">
          <span className={`text-sm ${unread ? 'font-semibold text-gray-900' : 'font-medium text-gray-700'}`}>
            {other?.name ?? 'Unknown'}
          </span>
          <span className="flex-shrink-0 text-xs text-gray-400">
            {formatTimestamp(chat.last_message_at)}
          </span>
        </div>
        <p className={`text-sm truncate mt-0.5 ${unread ? 'font-semibold text-gray-800' : 'text-gray-500'}`}>
          {chat.last_message_content ?? 'No messages yet'}
        </p>
      </div>
    </Link>
  );
}

export function InboxPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const { chats, initialized } = useChats();
  const [activeTab, setActiveTab] = useState<ChatRole>('hirer');

  useEffect(() => {
    if (!user) { navigate('/'); return; }
  }, [user, navigate]);

  const tabs = [
    { key: 'hirer' as const, label: 'As Hirer', chats: chats.as_hirer },
    { key: 'owner' as const, label: 'As Owner', chats: chats.as_owner },
  ];

  const activeChats = tabs.find(t => t.key === activeTab)?.chats ?? [];

  return (
    <div className="max-w-2xl mx-auto py-8">
      <h1 className="text-2xl font-bold text-gray-900 px-6 mb-6">Messages</h1>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 px-6 mb-0">
        {tabs.map(tab => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`pb-3 px-4 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab.key
                ? 'border-rose-500 text-rose-500'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {!initialized ? (
        <p className="px-6 py-12 text-center text-sm text-gray-400">Loading…</p>
      ) : activeChats.length === 0 ? (
        <p className="px-6 py-12 text-center text-sm text-gray-400">Message inbox is empty</p>
      ) : (
        <div>
          {activeChats.map(chat => (
            <ChatRow key={chat.id} chat={chat} role={activeTab} />
          ))}
        </div>
      )}
    </div>
  );
}
