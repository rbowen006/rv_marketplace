import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { ChatPage } from './ChatPage';

// Current user is the OWNER (id 2) of the chat below.
vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: { id: 2, name: 'Owner' } }),
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

// One inbound message from the hirer (user_id 1) — there is something to reply to.
const messagesWithHirer = [
  { id: 10, content: 'Is it pet friendly?', user_id: 1, created_at: '2026-06-24T05:00:00Z', read_at: null },
];

function mockFetch({
  messages = messagesWithHirer,
  suggestReply = 'Yes, absolutely — well-behaved pets are welcome!',
  suggestOk = true,
}: {
  messages?: typeof messagesWithHirer;
  suggestReply?: string;
  suggestOk?: boolean;
} = {}) {
  globalThis.fetch = vi.fn((url: string, options?: { method?: string }) => {
    if (url.includes('/suggest_reply')) {
      return Promise.resolve({
        ok: suggestOk,
        text: () =>
          Promise.resolve(JSON.stringify({ status: 'success', data: { reply: suggestReply } })),
      });
    }
    if (url.includes('/messages')) {
      if (options?.method === 'POST') {
        const created = { id: 99, content: 'sent', user_id: 2, created_at: '2026-06-24T06:00:00Z', read_at: null };
        return Promise.resolve({ ok: true, text: () => Promise.resolve(JSON.stringify(created)) });
      }
      return Promise.resolve({ ok: true, text: () => Promise.resolve(JSON.stringify(messages)) });
    }
    return Promise.resolve({ ok: true, text: () => Promise.resolve(JSON.stringify(chatData)) });
  }) as unknown as typeof fetch;

  function postMessageCalls() {
    return vi
      .mocked(globalThis.fetch)
      .mock.calls.filter(
        ([url, opts]) =>
          (url as string).includes('/messages') &&
          (opts as { method?: string } | undefined)?.method === 'POST',
      );
  }
  return { postMessageCalls };
}

function renderChatPage() {
  render(
    <MemoryRouter initialEntries={['/chats/1']}>
      <Routes>
        <Route path="/chats/:id" element={<ChatPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('ChatPage — Suggest reply (owner)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('inserts the suggested reply into the compose field when the owner clicks Suggest reply', async () => {
    mockFetch();
    renderChatPage();

    const button = await screen.findByRole('button', { name: /suggest reply/i });
    await userEvent.click(button);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('Type a message…')).toHaveValue(
        'Yes, absolutely — well-behaved pets are welcome!',
      );
    });
  });

  it('disables Suggest reply when the thread has no hirer message to reply to', async () => {
    const onlyOwnerMessage = [
      { id: 20, content: 'Hi, still interested?', user_id: 2, created_at: '2026-06-24T05:00:00Z', read_at: null },
    ];
    mockFetch({ messages: onlyOwnerMessage });
    renderChatPage();

    await waitFor(() => expect(screen.getByText('Hi, still interested?')).toBeInTheDocument());
    expect(screen.getByRole('button', { name: /suggest reply/i })).toBeDisabled();
  });

  it('keeps the existing draft and makes no request when the owner cancels the overwrite confirm', async () => {
    mockFetch();
    renderChatPage();

    const field = await screen.findByPlaceholderText('Type a message…');
    await userEvent.type(field, 'my own words');

    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false);
    await userEvent.click(screen.getByRole('button', { name: /suggest reply/i }));

    expect(confirmSpy).toHaveBeenCalled();
    expect(field).toHaveValue('my own words');
    const suggestCalls = vi
      .mocked(globalThis.fetch)
      .mock.calls.filter(([url]) => (url as string).includes('/suggest_reply'));
    expect(suggestCalls).toHaveLength(0);
  });

  it('shows an inline error and preserves the draft when the suggest request fails', async () => {
    mockFetch({ suggestOk: false });
    renderChatPage();

    const field = await screen.findByPlaceholderText('Type a message…');
    await userEvent.click(screen.getByRole('button', { name: /suggest reply/i }));

    await waitFor(() => expect(screen.getByText(/couldn't suggest a reply/i)).toBeInTheDocument());
    expect(field).toHaveValue('');
  });

  it('inserts a newline on Shift+Enter without sending', async () => {
    const { postMessageCalls } = mockFetch();
    renderChatPage();

    const field = await screen.findByPlaceholderText('Type a message…');
    await userEvent.type(field, 'line one{Shift>}{Enter}{/Shift}line two');

    expect(field).toHaveValue('line one\nline two');
    expect(postMessageCalls()).toHaveLength(0);
  });

  it('sends the message on Enter', async () => {
    const { postMessageCalls } = mockFetch();
    renderChatPage();

    const field = await screen.findByPlaceholderText('Type a message…');
    await userEvent.type(field, 'quick reply{Enter}');

    await waitFor(() => expect(postMessageCalls()).toHaveLength(1));
  });
});
