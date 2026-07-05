import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { ChatPage } from './ChatPage';

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: { id: 1, name: 'Hirer' } }),
}));

const chatData = {
  id: 1,
  hirer_id: 1,
  owner_id: 2,
  listing_title: 'Cozy Campervan',
  hirer: { id: 1, name: 'Hirer' },
  owner: { id: 2, name: 'Owner' },
  last_message_at: null,
  hirer_last_read_at: null,
  owner_last_read_at: null,
};

const messagesData = [
  { id: 10, content: 'Hello!', user_id: 2, created_at: '2026-06-24T05:00:00Z', read_at: null },
];

function renderChatPage() {
  globalThis.fetch = vi.fn((url: string) => {
    if (url.includes('/messages')) {
      return Promise.resolve({
        ok: true,
        text: () => Promise.resolve(JSON.stringify(messagesData)),
      });
    }
    return Promise.resolve({ ok: true, text: () => Promise.resolve(JSON.stringify(chatData)) });
  }) as unknown as typeof fetch;

  render(
    <MemoryRouter initialEntries={['/chats/1']}>
      <Routes>
        <Route path="/chats/:id" element={<ChatPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('ChatPage', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('calls the messages endpoint immediately on mount, without waiting for the poll interval', async () => {
    renderChatPage();

    await waitFor(
      () => {
        const calls = vi.mocked(globalThis.fetch).mock.calls.map(([url]) => url as string);
        expect(calls.some((url) => url.includes('/messages'))).toBe(true);
      },
      { timeout: 500 },
    );
  });

  it('displays messages from the messages endpoint, not from the chat show response', async () => {
    renderChatPage();

    await waitFor(() => {
      expect(screen.getByText('Hello!')).toBeInTheDocument();
    });
  });

  it('displays chat metadata (participant name, listing title) from the chat show response', async () => {
    renderChatPage();

    await waitFor(() => {
      expect(screen.getByText('Owner')).toBeInTheDocument();
      expect(screen.getByText('Cozy Campervan')).toBeInTheDocument();
    });
  });
});
