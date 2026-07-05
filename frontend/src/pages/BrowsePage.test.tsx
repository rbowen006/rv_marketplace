import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, useSearchParams, useNavigate } from 'react-router-dom';
import { BrowsePage } from './BrowsePage';
import { useApiFetch } from '../lib/useApiFetch';

// Stands in for the header SearchBar (which lives outside BrowsePage): a
// structured search is just a navigation with URL params (and no ?q=).
function StructuredSearch() {
  const [, setSearchParams] = useSearchParams();
  return <button onClick={() => setSearchParams({ location: 'Perth' })}>run-structured</button>;
}

function Nav() {
  const navigate = useNavigate();
  return <button onClick={() => navigate('/')}>go-home</button>;
}

vi.mock('../lib/useApiFetch', () => ({ useApiFetch: vi.fn() }));

const request = vi.fn();
const browseListing = {
  id: 99,
  title: 'Browse Van',
  town: 'Perth',
  state: 'WA',
  max_guests: 2,
  price_per_day: 80,
};
const nlListing = {
  id: 1,
  title: 'NL Result Van',
  town: 'Byron Bay',
  state: 'NSW',
  max_guests: 4,
  price_per_day: 120,
  score: 0.12,
};

beforeEach(() => {
  globalThis.fetch = vi.fn().mockResolvedValue({ ok: true, json: async () => [browseListing] });
  request.mockReset();
  request.mockResolvedValue({ res: { ok: true }, data: [nlListing] });
  vi.mocked(useApiFetch).mockReturnValue(request);
});

function renderPage() {
  render(
    <MemoryRouter initialEntries={['/']}>
      <BrowsePage />
      <StructuredSearch />
      <Nav />
    </MemoryRouter>,
  );
}

describe('BrowsePage', () => {
  it('renders the natural-language search box', async () => {
    renderPage();
    expect(screen.getByPlaceholderText(/describe/i)).toBeInTheDocument();
    await waitFor(() => expect(globalThis.fetch).toHaveBeenCalledWith('/api/v1/listings'));
  });

  it('shows NL results and hides the browse grid during an NL search, and restores it on Clear', async () => {
    renderPage();
    expect(await screen.findByText('Browse Van')).toBeInTheDocument();

    fireEvent.change(screen.getByPlaceholderText(/describe/i), { target: { value: 'beach' } });
    fireEvent.click(screen.getByRole('button', { name: /^search$/i }));

    expect(await screen.findByText('NL Result Van')).toBeInTheDocument();
    expect(screen.queryByText('Browse Van')).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: /clear/i }));

    expect(await screen.findByText('Browse Van')).toBeInTheDocument();
    expect(screen.queryByText('NL Result Van')).not.toBeInTheDocument();
  });

  it('a structured search clears an active NL search (mutual exclusion via the URL)', async () => {
    renderPage();
    expect(await screen.findByText('Browse Van')).toBeInTheDocument();

    fireEvent.change(screen.getByPlaceholderText(/describe/i), { target: { value: 'beach' } });
    fireEvent.click(screen.getByRole('button', { name: /^search$/i }));
    expect(await screen.findByText('NL Result Van')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'run-structured' }));

    expect(await screen.findByText('Browse Van')).toBeInTheDocument();
    expect(screen.queryByText('NL Result Van')).not.toBeInTheDocument();
    expect(screen.getByPlaceholderText(/describe/i)).toHaveValue('');
  });

  it('a failed NL search shows an error', async () => {
    request.mockResolvedValue({ res: { ok: false, status: 503 }, data: {} });
    renderPage();
    expect(await screen.findByText('Browse Van')).toBeInTheDocument();

    fireEvent.change(screen.getByPlaceholderText(/describe/i), { target: { value: 'beach' } });
    fireEvent.click(screen.getByRole('button', { name: /^search$/i }));

    expect(await screen.findByText(/something went wrong|try again/i)).toBeInTheDocument();
  });

  it('returns to the browse grid when the NL query is dropped by navigation', async () => {
    renderPage();
    await screen.findByText('Browse Van');

    fireEvent.change(screen.getByPlaceholderText(/describe/i), { target: { value: 'beach' } });
    fireEvent.click(screen.getByRole('button', { name: /^search$/i }));
    expect(await screen.findByText('NL Result Van')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'go-home' }));

    expect(await screen.findByText('Browse Van')).toBeInTheDocument();
    expect(screen.queryByText('NL Result Van')).not.toBeInTheDocument();
  });
});
