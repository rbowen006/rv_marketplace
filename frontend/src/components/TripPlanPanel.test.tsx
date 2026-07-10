import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TripPlanPanel } from './TripPlanPanel';

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: { id: 1 } }),
}));

const completedPlan = {
  status: 'completed',
  interests: 'quiet beaches',
  itinerary: {
    summary: 'A relaxed coastal trip.',
    disclaimer: 'Verify opening hours locally before you go.',
    days: [
      {
        date: '2026-09-01',
        title: 'Arrive in Lorne',
        segments: [
          { part_of_day: 'morning', activity: 'Drive the Great Ocean Road', detail: 'Take it slow.' },
        ],
      },
    ],
  },
  error: null,
};

interface MockOpts {
  getQueue?: Array<Record<string, unknown>>;
  post?: Record<string, unknown>;
  postOk?: boolean;
}

function mockApi({ getQueue = [{ status: 'none' }], post = { status: 'pending' }, postOk = true }: MockOpts = {}) {
  const queue = [...getQueue];
  globalThis.fetch = vi.fn((_url: string, options?: { method?: string }) => {
    const method = options?.method ?? 'GET';
    const ok = method === 'POST' ? postOk : true;
    const data = method === 'POST' ? post : queue.length > 1 ? queue.shift() : queue[0];
    return Promise.resolve({
      ok,
      status: ok ? 200 : 422,
      text: () => Promise.resolve(JSON.stringify({ status: ok ? 'success' : 'fail', data })),
    });
  }) as unknown as typeof fetch;
}

function renderPanel() {
  render(<TripPlanPanel bookingId={154} pollIntervalMs={5} />);
}

afterEach(() => vi.restoreAllMocks());

describe('TripPlanPanel', () => {
  it('renders an existing completed itinerary on mount', async () => {
    mockApi({ getQueue: [completedPlan] });
    renderPanel();

    expect(await screen.findByText('A relaxed coastal trip.')).toBeInTheDocument();
    expect(screen.getByText('Arrive in Lorne')).toBeInTheDocument();
    expect(screen.getByText(/Drive the Great Ocean Road/)).toBeInTheDocument();
    expect(screen.getByText(/Verify opening hours locally/)).toBeInTheDocument();
  });

  it('generates an itinerary: submit → poll while processing → render on completion', async () => {
    mockApi({
      getQueue: [{ status: 'none' }, { status: 'processing' }, completedPlan],
      post: { status: 'pending' },
    });
    renderPanel();

    const field = await screen.findByLabelText(/your interests/i);
    await userEvent.type(field, 'quiet beaches');
    await userEvent.click(screen.getByRole('button', { name: /generate itinerary/i }));

    expect(await screen.findByRole('status')).toHaveTextContent(/generating/i);
    expect(await screen.findByText('A relaxed coastal trip.')).toBeInTheDocument();
  });

  it('shows an error and a Try again action when generation failed', async () => {
    mockApi({ getQueue: [{ status: 'failed', error: 'Claude is unavailable', itinerary: null }] });
    renderPanel();

    expect(await screen.findByText(/couldn't generate your itinerary/i)).toBeInTheDocument();
    expect(screen.getByText(/Claude is unavailable/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument();
  });

  it('shows a busy indicator immediately on click, before the request resolves', async () => {
    // Hang the POST so we can observe the interim (submitting) state.
    globalThis.fetch = vi.fn((_url: string, options?: { method?: string }) => {
      if (options?.method === 'POST') return new Promise(() => {});
      return Promise.resolve({
        ok: true,
        text: () => Promise.resolve(JSON.stringify({ status: 'success', data: { status: 'none' } })),
      });
    }) as unknown as typeof fetch;

    render(<TripPlanPanel bookingId={1} pollIntervalMs={5} />);

    const button = await screen.findByRole('button', { name: /generate itinerary/i });
    await userEvent.click(button);

    expect(await screen.findByRole('status')).toHaveTextContent(/generating/i);
    expect(screen.getByRole('button')).toBeDisabled();
  });

  it('surfaces an error when the generate request is rejected', async () => {
    mockApi({ getQueue: [{ status: 'none' }], postOk: false });
    renderPanel();

    await screen.findByLabelText(/your interests/i);
    await userEvent.click(screen.getByRole('button', { name: /generate itinerary/i }));

    expect(await screen.findByText(/couldn't start planning/i)).toBeInTheDocument();
  });
});
