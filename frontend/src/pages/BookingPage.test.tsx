import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { BookingPage } from './BookingPage';

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: { id: 1 } }),
}));

vi.mock('../lib/useApiFetch', () => ({
  useApiFetch: () => vi.fn().mockResolvedValue({
    res: { ok: true },
    data: { id: 103, title: 'Blue Mountains Caravan', price_per_day: 120, owner: { id: 2 } },
  }),
}));

function renderBookingPage(search = '') {
  render(
    <MemoryRouter initialEntries={[`/listings/103/book${search}`]}>
      <Routes>
        <Route path="/listings/:id/book" element={<BookingPage />} />
      </Routes>
    </MemoryRouter>
  );
}

describe('BookingPage date pre-population', () => {
  it('pre-populates Date From and Date To inputs from URL params', async () => {
    renderBookingPage('?dateFrom=2026-08-01&dateTo=2026-08-07');

    const dateFromInput = await screen.findByLabelText(/date from/i);
    const dateToInput = await screen.findByLabelText(/date to/i);

    expect(dateFromInput).toHaveValue('2026-08-01');
    expect(dateToInput).toHaveValue('2026-08-07');
  });

  it('does not pre-populate when dateFrom is in the past', async () => {
    renderBookingPage('?dateFrom=2020-01-01&dateTo=2020-01-07');

    const dateFromInput = await screen.findByLabelText(/date from/i);
    const dateToInput = await screen.findByLabelText(/date to/i);

    expect(dateFromInput).toHaveValue('');
    expect(dateToInput).toHaveValue('');
  });
});
