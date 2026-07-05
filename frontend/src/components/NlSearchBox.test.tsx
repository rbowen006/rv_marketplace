import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { NlSearchBox } from './NlSearchBox';
import { useApiFetch } from '../lib/useApiFetch';

vi.mock('../lib/useApiFetch', () => ({ useApiFetch: vi.fn() }));

const request = vi.fn();

function renderBox(initialEntries: string[] = ['/']) {
  render(
    <MemoryRouter initialEntries={initialEntries}>
      <NlSearchBox />
    </MemoryRouter>
  );
}

function search(text: string) {
  fireEvent.change(screen.getByPlaceholderText(/describe/i), { target: { value: text } });
  fireEvent.click(screen.getByRole('button', { name: /search/i }));
}

beforeEach(() => {
  request.mockReset();
  request.mockResolvedValue({ res: { ok: true }, data: [] });
  vi.mocked(useApiFetch).mockReturnValue(request);
});

describe('NlSearchBox', () => {
  it('renders a natural-language text input and a search button', () => {
    renderBox();
    expect(screen.getByPlaceholderText(/describe/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /search/i })).toBeInTheDocument();
  });

  it('POSTs the query to /api/v1/listings/search when submitted', async () => {
    renderBox();
    search('pet friendly caravan near the beach');

    await waitFor(() => expect(request).toHaveBeenCalledTimes(1));
    expect(request).toHaveBeenCalledWith('/api/v1/listings/search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'pet friendly caravan near the beach' }),
    });
  });

  it('fetches immediately when the URL already carries a ?q= query', async () => {
    request.mockResolvedValue({
      res: { ok: true },
      data: [{ id: 1, title: 'Deep-linked Van', town: 'A', state: 'X', max_guests: 2, price_per_day: 50 }],
    });
    renderBox(['/?q=beach']);
    expect(await screen.findByRole('heading', { level: 3, name: 'Deep-linked Van' })).toBeInTheDocument();
  });

  it('renders the returned listings through ListingCard in ranked order', async () => {
    request.mockResolvedValue({
      res: { ok: true },
      data: [
        { id: 1, title: 'Beachside Caravan', town: 'Byron Bay', state: 'NSW', max_guests: 4, price_per_day: 120, score: 0.12 },
        { id: 2, title: 'Coastal Camper', town: 'Torquay', state: 'VIC', max_guests: 2, price_per_day: 90, score: 0.34 },
      ],
    });
    renderBox();
    search('beach trip');

    const cards = await screen.findAllByRole('heading', { level: 3 });
    expect(cards.map(c => c.textContent)).toEqual(['Beachside Caravan', 'Coastal Camper']);
  });

  it('shows a loading indicator while the request is in flight', async () => {
    let resolve: (value: unknown) => void;
    request.mockReturnValue(new Promise(r => { resolve = r; }));
    renderBox();
    search('beach trip');

    expect(await screen.findByText(/searching/i)).toBeInTheDocument();

    resolve!({ res: { ok: true }, data: [] });
    await waitFor(() => expect(screen.queryByText(/searching/i)).not.toBeInTheDocument());
  });

  it('shows an error message when the search request fails', async () => {
    request.mockResolvedValue({ res: { ok: false, status: 503 }, data: { message: 'Ollama is unavailable' } });
    renderBox();
    search('beach trip');

    expect(await screen.findByText(/something went wrong|unavailable|try again/i)).toBeInTheDocument();
  });

  it('does not fire a request for a blank query', async () => {
    renderBox();
    search('   ');

    await waitFor(() => {});
    expect(request).not.toHaveBeenCalled();
  });

  it('does not fetch for a whitespace-only ?q= (e.g. a crafted deep link)', async () => {
    renderBox(['/?q=%20%20']);

    await waitFor(() => {});
    expect(request).not.toHaveBeenCalled();
  });

  it('retries when the same query is resubmitted after a failure', async () => {
    request.mockResolvedValueOnce({ res: { ok: false, status: 503 }, data: {} });
    renderBox();
    search('beach trip');
    expect(await screen.findByText(/something went wrong|try again/i)).toBeInTheDocument();

    request.mockResolvedValueOnce({
      res: { ok: true },
      data: [{ id: 1, title: 'Recovered Van', town: 'A', state: 'X', max_guests: 2, price_per_day: 50 }],
    });
    fireEvent.click(screen.getByRole('button', { name: /^search$/i }));

    expect(await screen.findByRole('heading', { level: 3, name: 'Recovered Van' })).toBeInTheDocument();
    expect(request).toHaveBeenCalledTimes(2);
  });

  it('clears the query and results when Clear is clicked', async () => {
    request.mockResolvedValue({
      res: { ok: true },
      data: [{ id: 1, title: 'Beachside Caravan', town: 'Byron Bay', state: 'NSW', max_guests: 4, price_per_day: 120 }],
    });
    renderBox();
    search('beach trip');
    await screen.findByRole('heading', { level: 3, name: 'Beachside Caravan' });

    fireEvent.click(screen.getByRole('button', { name: /clear/i }));

    expect(screen.queryByRole('heading', { level: 3, name: 'Beachside Caravan' })).not.toBeInTheDocument();
    expect(screen.getByPlaceholderText(/describe/i)).toHaveValue('');
  });

  it('ignores a response for a query that was cleared before it resolved', async () => {
    let resolve: (value: unknown) => void;
    request.mockReturnValue(new Promise(r => { resolve = r; }));
    renderBox();
    search('beach trip');
    fireEvent.click(screen.getByRole('button', { name: /clear/i }));

    resolve!({ res: { ok: true }, data: [{ id: 9, title: 'Late Van', town: 'B', state: 'Y', max_guests: 3, price_per_day: 60 }] });
    await waitFor(() => {});

    expect(screen.queryByRole('heading', { level: 3, name: 'Late Van' })).not.toBeInTheDocument();
  });
});
