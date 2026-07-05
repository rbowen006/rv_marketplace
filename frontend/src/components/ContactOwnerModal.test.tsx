import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ContactOwnerModal } from './ContactOwnerModal';

const mockNavigate = vi.fn();
const mockRefreshChats = vi.fn();

vi.mock('react-router-dom', async (importOriginal) => ({
  ...(await importOriginal()),
  useNavigate: () => mockNavigate,
}));

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token' }),
}));

vi.mock('../context/UnreadContext', () => ({
  useChats: () => ({ refreshChats: mockRefreshChats }),
}));

vi.mock('../lib/useApiFetch', () => ({
  useApiFetch: () => mockApiFetch,
}));

let mockApiFetch: ReturnType<typeof vi.fn>;

function renderModal() {
  render(
    <MemoryRouter>
      <ContactOwnerModal listingId={1} listingTitle="Test RV" onClose={() => {}} />
    </MemoryRouter>,
  );
}

describe('ContactOwnerModal', () => {
  beforeEach(() => {
    mockNavigate.mockReset();
    mockRefreshChats.mockReset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('navigates to the new chat on success', async () => {
    mockApiFetch = vi.fn(() =>
      Promise.resolve({ res: { ok: true, status: 200 }, data: { id: 5 } }),
    );

    renderModal();
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'Hello!' } });
    fireEvent.click(screen.getByRole('button', { name: /send message/i }));

    await waitFor(() => expect(mockNavigate).toHaveBeenCalledWith('/chats/5'));
  });

  it('calls refreshChats after navigating to the new chat', async () => {
    mockApiFetch = vi.fn(() =>
      Promise.resolve({ res: { ok: true, status: 200 }, data: { id: 5 } }),
    );

    renderModal();
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'Hello!' } });
    fireEvent.click(screen.getByRole('button', { name: /send message/i }));

    await waitFor(() => expect(mockRefreshChats).toHaveBeenCalledOnce());
  });

  it('shows an error and does not call refreshChats when the request fails', async () => {
    mockApiFetch = vi.fn(() =>
      Promise.resolve({ res: { ok: false, status: 422 }, data: { error: 'Not allowed' } }),
    );

    renderModal();
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'Hello!' } });
    fireEvent.click(screen.getByRole('button', { name: /send message/i }));

    await waitFor(() => expect(screen.getByText('Not allowed')).toBeInTheDocument());
    expect(mockRefreshChats).not.toHaveBeenCalled();
  });
});
