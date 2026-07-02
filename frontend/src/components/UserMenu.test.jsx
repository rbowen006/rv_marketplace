import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { UserMenu } from './UserMenu';

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ user: { name: 'Olly', email: 'olly@example.com' }, signOut: vi.fn() }),
}));

vi.mock('../context/UnreadContext', () => ({
  useUnreadCount: () => 0,
}));

function openMenu() {
  render(
    <MemoryRouter>
      <UserMenu />
    </MemoryRouter>
  );
  fireEvent.click(screen.getByRole('button'));
}

describe('UserMenu', () => {
  it('shows a "My listings" link to /my-listings', () => {
    openMenu();
    const link = screen.getByRole('link', { name: 'My listings' });
    expect(link).toHaveAttribute('href', '/my-listings');
  });
});
