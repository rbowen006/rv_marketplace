import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { EditListingPage } from './EditListingPage';
import * as AuthContext from '../context/AuthContext';
import type { AuthContextValue } from '../types/auth';

const setAuth = (v: Partial<AuthContextValue>) =>
  vi.mocked(AuthContext.useAuth).mockReturnValue(v as AuthContextValue);

vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

vi.mock('../lib/useApiFetch', () => ({
  useApiFetch: () => mockApiFetch,
}));

vi.mock('../components/ListingForm', () => ({
  ListingForm: ({ initialValues, onSubmit, submitLabel }) => (
    <form
      onSubmit={e => { e.preventDefault(); onSubmit({ title: initialValues.title }, []); }}
      data-testid="listing-form"
    >
      <span data-testid="form-title">{initialValues.title}</span>
      <button type="submit">{submitLabel}</button>
    </form>
  ),
}));

let mockApiFetch;
const mockNavigate = vi.fn();

vi.mock('react-router-dom', async (importOriginal) => ({
  ...(await importOriginal()),
  useNavigate: () => mockNavigate,
}));

const LISTING = {
  id: 42,
  title: 'Desert Dreamer',
  description: 'A lovely van',
  rv_type: 'motorhome',
  town: 'Alice Springs',
  state: 'NT',
  postcode: '0870',
  price_per_day: 200,
  max_guests: 3,
  pet_friendly: false,
  images: [],
  owner: { id: 7, name: 'Alice' },
};

function renderPage(listingId = '42') {
  render(
    <MemoryRouter initialEntries={[`/listings/${listingId}/edit`]}>
      <Routes>
        <Route path="/listings/:id/edit" element={<EditListingPage />} />
        <Route path="/" element={<div>Home</div>} />
        <Route path="/listings/:id" element={<div>Listing Detail</div>} />
      </Routes>
    </MemoryRouter>
  );
}

describe('EditListingPage', () => {
  beforeEach(() => {
    mockApiFetch = vi.fn().mockResolvedValue({ res: { ok: true }, data: LISTING });
    mockNavigate.mockReset();
  });

  it('redirects to / when not authenticated', async () => {
    setAuth({ user: null, token: null });
    renderPage();
    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith('/'));
  });

  it('redirects to /listings/:id when logged in as non-owner', async () => {
    setAuth({ user: { id: 99 }, token: 'tok' });
    renderPage();
    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith('/listings/42'));
  });

  it('renders the form with listing data when authenticated as owner', async () => {
    setAuth({ user: { id: 7 }, token: 'tok' });
    renderPage();
    await waitFor(() => expect(screen.getByTestId('form-title')).toHaveTextContent('Desert Dreamer'));
  });

  it('calls PUT on save and redirects to /listings/:id', async () => {
    setAuth({ user: { id: 7 }, token: 'tok' });
    renderPage();
    await waitFor(() => screen.getByTestId('listing-form'));

    fireEvent.submit(screen.getByTestId('listing-form'));

    await waitFor(() =>
      expect(mockApiFetch).toHaveBeenCalledWith(
        '/api/v1/listings/42',
        expect.objectContaining({ method: 'PUT' })
      )
    );
    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith('/listings/42'));
  });
});
