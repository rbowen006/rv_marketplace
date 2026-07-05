import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { MyListingsPage } from './MyListingsPage';
import * as AuthContext from '../context/AuthContext';
import type { AuthContextValue } from '../types/auth';
import type { ListingSummary } from '../types/listing';

const setAuth = (v: Partial<AuthContextValue>) =>
  vi.mocked(AuthContext.useAuth).mockReturnValue(v as AuthContextValue);

vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

vi.mock('../lib/useApiFetch', () => ({
  useApiFetch: () => mockApiFetch,
}));

vi.mock('../components/ListingCard', () => ({
  ListingCard: ({ listing }: { listing: ListingSummary }) => (
    <div data-testid="listing-card">{listing.title}</div>
  ),
}));

let mockApiFetch: ReturnType<typeof vi.fn>;
const mockNavigate = vi.fn();

vi.mock('react-router-dom', async (importOriginal) => ({
  ...(await importOriginal()),
  useNavigate: () => mockNavigate,
}));

function renderPage() {
  render(
    <MemoryRouter initialEntries={['/my-listings']}>
      <Routes>
        <Route path="/my-listings" element={<MyListingsPage />} />
        <Route path="/" element={<div>Home</div>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('MyListingsPage', () => {
  beforeEach(() => {
    mockApiFetch = vi.fn().mockResolvedValue({ res: { ok: true }, data: [] });
    mockNavigate.mockReset();
  });

  it('redirects to / when not authenticated', async () => {
    setAuth({ user: null, token: null });
    renderPage();
    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith('/'));
  });

  it('renders each listing with an Edit listing link', async () => {
    setAuth({ user: { id: 1, name: 'Olly' }, token: 't' });
    mockApiFetch.mockResolvedValue({
      res: { ok: true },
      data: [
        { id: 7, title: 'Desert Dreamer' },
        { id: 8, title: 'Coastal Cruiser' },
      ],
    });
    renderPage();

    expect(await screen.findByText('Desert Dreamer')).toBeInTheDocument();
    expect(screen.getByText('Coastal Cruiser')).toBeInTheDocument();

    const editLinks = screen.getAllByRole('link', { name: /edit listing/i });
    expect(editLinks.map((l) => l.getAttribute('href'))).toEqual([
      '/listings/7/edit',
      '/listings/8/edit',
    ]);
  });

  it('shows an empty state linking to /listings/new when there are no listings', async () => {
    setAuth({ user: { id: 1, name: 'Olly' }, token: 't' });
    mockApiFetch.mockResolvedValue({ res: { ok: true }, data: [] });
    renderPage();

    const cta = await screen.findByRole('link', { name: /list your rv/i });
    expect(cta).toHaveAttribute('href', '/listings/new');
    expect(screen.queryByTestId('listing-card')).not.toBeInTheDocument();
  });
});
