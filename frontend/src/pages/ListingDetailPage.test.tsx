import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { ListingDetailPage } from './ListingDetailPage';
import * as AuthContext from '../context/AuthContext';
import type { AuthContextValue } from '../types/auth';

const setAuth = (v: Partial<AuthContextValue>) =>
  vi.mocked(AuthContext.useAuth).mockReturnValue(v as AuthContextValue);

vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

vi.mock('../context/UnreadContext', () => ({
  useChats: () => ({ refreshChats: vi.fn() }),
}));

const LISTING = {
  id: 1,
  title: 'Beach Caravan',
  description: 'Nice',
  town: 'Bondi',
  state: 'NSW',
  postcode: '2026',
  price_per_day: 150,
  max_guests: 4,
  pet_friendly: false,
  images: [],
  owner: { id: 7, name: 'Alice' },
};

function renderPage() {
  globalThis.fetch = vi.fn().mockResolvedValue({
    ok: true,
    json: () => Promise.resolve(LISTING),
  });
  render(
    <MemoryRouter initialEntries={['/listings/1']}>
      <Routes>
        <Route path="/listings/:id" element={<ListingDetailPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('ListingDetailPage', () => {
  it('shows an Edit listing link when the current user is the owner', async () => {
    setAuth({ user: { id: 7 }, token: 'tok' });
    renderPage();
    await waitFor(() =>
      expect(screen.getByRole('link', { name: /edit listing/i })).toBeInTheDocument(),
    );
    expect(screen.getByRole('link', { name: /edit listing/i })).toHaveAttribute(
      'href',
      '/listings/1/edit',
    );
  });

  it('does not show the Edit listing link for non-owners', async () => {
    setAuth({ user: { id: 99 }, token: 'tok' });
    renderPage();
    await waitFor(() => screen.getByText('Beach Caravan'));
    expect(screen.queryByRole('link', { name: /edit listing/i })).not.toBeInTheDocument();
  });
});
