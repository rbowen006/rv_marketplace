import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { BookingDetailPage } from './BookingDetailPage';

const { authState } = vi.hoisted(() => ({
  authState: { user: { id: 1, name: 'Hirer' } as { id: number; name: string } },
}));

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: authState.user }),
}));

const booking = {
  id: 154,
  hirer_id: 1,
  listing_title: 'Great Ocean Road Classic',
  start_date: '2026-09-01',
  end_date: '2026-09-04',
  status: 'confirmed',
  hirer: { id: 1, name: 'Hirer' },
  owner: { id: 2, name: 'Owner' },
  trip_planning_available: true,
};

interface FetchOpts {
  available?: boolean;
  plan?: Record<string, unknown>;
}

function mockFetch({ available = true, plan = { status: 'none' } }: FetchOpts = {}) {
  globalThis.fetch = vi.fn((url: string) => {
    if ((url as string).includes('/trip_plan')) {
      return Promise.resolve({
        ok: true,
        text: () => Promise.resolve(JSON.stringify({ status: 'success', data: plan })),
      });
    }
    return Promise.resolve({
      ok: true,
      text: () =>
        Promise.resolve(JSON.stringify({ ...booking, trip_planning_available: available })),
    });
  }) as unknown as typeof fetch;
}

function renderPage() {
  render(
    <MemoryRouter initialEntries={['/bookings/154']}>
      <Routes>
        <Route path="/bookings/:id" element={<BookingDetailPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('BookingDetailPage', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    authState.user = { id: 1, name: 'Hirer' };
  });

  it('shows the booking details', async () => {
    mockFetch();
    renderPage();

    expect(await screen.findByText('Great Ocean Road Classic')).toBeInTheDocument();
  });

  it('shows the trip planner when trip planning is available', async () => {
    mockFetch({ available: true });
    renderPage();

    expect(await screen.findByRole('heading', { name: /plan my trip/i })).toBeInTheDocument();
  });

  it('hides the trip planner when trip planning is not available', async () => {
    mockFetch({ available: false });
    renderPage();

    await screen.findByText('Great Ocean Road Classic');
    expect(screen.queryByRole('heading', { name: /plan my trip/i })).not.toBeInTheDocument();
  });

  it('hides the trip planner for the owner (only the hirer plans)', async () => {
    authState.user = { id: 2, name: 'Owner' }; // booking.hirer_id is 1
    mockFetch({ available: true });
    renderPage();

    await screen.findByText('Great Ocean Road Classic');
    expect(screen.queryByRole('heading', { name: /plan my trip/i })).not.toBeInTheDocument();
  });
});
