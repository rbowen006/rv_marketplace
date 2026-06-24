import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { NewListingPage } from './NewListingPage';
import * as AuthContext from '../context/AuthContext';

vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

function renderPage() {
  render(
    <MemoryRouter initialEntries={['/listings/new']}>
      <Routes>
        <Route path="/listings/new" element={<NewListingPage />} />
      </Routes>
    </MemoryRouter>
  );
}

describe('NewListingPage', () => {
  it('renders all required form fields when signed in', () => {
    vi.mocked(AuthContext.useAuth).mockReturnValue({ token: 'test-token', user: { id: 1, name: 'Owner' } });
    renderPage();

    expect(screen.getByLabelText(/title/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/description/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/rv type/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/town/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/state/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/postcode/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/price per day/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/max guests/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/pet friendly/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/photos/i)).toBeInTheDocument();
  });

  it('shows sign-in prompt when unauthenticated', () => {
    vi.mocked(AuthContext.useAuth).mockReturnValue({ token: null, user: null });
    renderPage();

    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
    expect(screen.queryByLabelText(/title/i)).not.toBeInTheDocument();
  });
});
