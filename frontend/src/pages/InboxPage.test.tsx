import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { InboxPage } from './InboxPage';
import * as AuthContext from '../context/AuthContext';
import type { AuthContextValue } from '../types/auth';

const setAuth = (v: Partial<AuthContextValue>) =>
  vi.mocked(AuthContext.useAuth).mockReturnValue(v as AuthContextValue);
import * as UnreadContext from '../context/UnreadContext';

vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

vi.mock('../context/UnreadContext', () => ({
  useChats: vi.fn(),
}));

function renderPage() {
  render(
    <MemoryRouter initialEntries={['/inbox']}>
      <Routes>
        <Route path="/inbox" element={<InboxPage />} />
      </Routes>
    </MemoryRouter>
  );
}

describe('InboxPage', () => {
  beforeEach(() => {
    setAuth({ user: { id: 1, name: 'Hirer' }, token: 'test-token' });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('shows spinner while chats are not yet initialized', () => {
    vi.mocked(UnreadContext.useChats).mockReturnValue({
      chats: { as_hirer: [], as_owner: [] },
      initialized: false,
      refreshChats: vi.fn(),
    });
    renderPage();
    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });

  it('shows empty state when initialized with no chats', () => {
    vi.mocked(UnreadContext.useChats).mockReturnValue({
      chats: { as_hirer: [], as_owner: [] },
      initialized: true,
      refreshChats: vi.fn(),
    });
    renderPage();
    expect(screen.getByText(/message inbox is empty/i)).toBeInTheDocument();
  });

  it('renders a chat row when initialized with chats', () => {
    vi.mocked(UnreadContext.useChats).mockReturnValue({
      chats: {
        as_hirer: [{
          id: 1,
          owner: { id: 2, name: 'Van Owner' },
          hirer: { id: 1, name: 'Hirer' },
          last_message_at: '2026-06-25T10:00:00Z',
          last_message_content: 'Is the van available?',
          hirer_last_read_at: null,
          owner_last_read_at: null,
        }],
        as_owner: [],
      },
      initialized: true,
      refreshChats: vi.fn(),
    });
    renderPage();
    expect(screen.getByText('Van Owner')).toBeInTheDocument();
    expect(screen.getByText('Is the van available?')).toBeInTheDocument();
  });
});
