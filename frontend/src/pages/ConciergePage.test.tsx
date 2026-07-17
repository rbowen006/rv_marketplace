import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { ConciergePage } from './ConciergePage';

const { auth } = vi.hoisted(() => ({
  auth: { current: { token: 'test-token', user: { id: 1, name: 'Traveller' }, signOut: () => {} } },
}));

vi.mock('../context/AuthContext', () => ({ useAuth: () => auth.current }));

interface FetchStub {
  get?: unknown;
  post?: unknown;
  del?: unknown;
}

function stubFetch({ get, post, del }: FetchStub) {
  const fetchMock = vi.fn((_url: string, options?: { method?: string }) => {
    const method = options?.method ?? 'GET';
    const body = method === 'POST' ? post : method === 'DELETE' ? del : get;
    return Promise.resolve({ ok: true, status: 200, text: () => Promise.resolve(JSON.stringify(body)) });
  });
  globalThis.fetch = fetchMock as unknown as typeof fetch;
  return fetchMock;
}

function renderPage() {
  return render(
    <MemoryRouter>
      <ConciergePage />
    </MemoryRouter>,
  );
}

beforeEach(() => {
  auth.current = { token: 'test-token', user: { id: 1, name: 'Traveller' }, signOut: () => {} };
});

afterEach(() => vi.restoreAllMocks());

const noneEnvelope = { status: 'success', data: { status: 'none' } };

const conversationEnvelope = {
  status: 'success',
  data: {
    status: 'idle',
    messages: [
      { role: 'user', text: 'find me a van' },
      { role: 'assistant', text: 'Here is a great option.' },
    ],
    recommendations: [{ id: 7, title: 'Beach van', price_per_day: 150, max_guests: 4, images: [] }],
  },
};

it('shows the empty state with example prompts', async () => {
  stubFetch({ get: noneEnvelope });

  renderPage();

  await waitFor(() =>
    expect(screen.getByText(/pet-friendly van for two near Byron Bay/i)).toBeInTheDocument(),
  );
});

it('renders assistant messages and hydrated recommendation cards', async () => {
  stubFetch({ get: conversationEnvelope });

  renderPage();

  await waitFor(() => expect(screen.getByText('Here is a great option.')).toBeInTheDocument());
  expect(screen.getByText('find me a van')).toBeInTheDocument();
  expect(screen.getByText('Beach van')).toBeInTheDocument();
});

it('sends a message and optimistically shows it', async () => {
  const fetchMock = stubFetch({
    get: noneEnvelope,
    post: { status: 'success', data: { status: 'processing', step_status: 'Thinking…', messages: [{ role: 'user', text: 'a camper for two' }] } },
  });

  renderPage();
  await waitFor(() => expect(screen.getByText(/Byron Bay/i)).toBeInTheDocument());

  await userEvent.type(screen.getByLabelText('Message'), 'a camper for two');
  await userEvent.click(screen.getByRole('button', { name: 'Send' }));

  expect(screen.getByText('a camper for two')).toBeInTheDocument();
  await waitFor(() =>
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/concierge/messages',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ message: 'a camper for two' }) }),
    ),
  );
});

it('keeps the conversation when Start over is cancelled', async () => {
  const fetchMock = stubFetch({ get: conversationEnvelope });

  renderPage();
  await waitFor(() => expect(screen.getByText('Here is a great option.')).toBeInTheDocument());

  await userEvent.click(screen.getByRole('button', { name: 'Start over' }));
  await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Cancel' }));

  expect(fetchMock).not.toHaveBeenCalledWith('/api/v1/concierge', expect.objectContaining({ method: 'DELETE' }));
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  expect(screen.getByText('Here is a great option.')).toBeInTheDocument();
});

it('deletes the conversation when Start over is confirmed', async () => {
  const fetchMock = stubFetch({ get: conversationEnvelope, del: noneEnvelope });

  renderPage();
  await waitFor(() => expect(screen.getByText('Here is a great option.')).toBeInTheDocument());

  await userEvent.click(screen.getByRole('button', { name: 'Start over' }));
  await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Start over' }));

  await waitFor(() =>
    expect(fetchMock).toHaveBeenCalledWith('/api/v1/concierge', expect.objectContaining({ method: 'DELETE' })),
  );
  await waitFor(() => expect(screen.queryByText('Here is a great option.')).not.toBeInTheDocument());
  expect(screen.getByText(/Byron Bay/i)).toBeInTheDocument();
});

it('gates on authentication when signed out', () => {
  auth.current = { token: null, user: null, signOut: () => {} } as never;
  stubFetch({ get: noneEnvelope });

  renderPage();

  expect(screen.getByText(/Sign in to chat with your personal RV concierge/i)).toBeInTheDocument();
});
