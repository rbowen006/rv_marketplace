import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ListingCard } from './ListingCard';

const listing = {
  id: 42,
  title: 'Blue Mountains Caravan',
  town: 'Katoomba',
  state: 'NSW',
  price_per_day: 120,
  max_guests: 4,
  pet_friendly: false,
  images: [],
  owner: { id: 1, name: 'Jane' },
};

describe('ListingCard', () => {
  it('link includes current search params from the URL', () => {
    render(
      <MemoryRouter initialEntries={['/?location=Katoomba&dateFrom=2026-08-01&dateTo=2026-08-07&guests=2']}>
        <ListingCard listing={listing} />
      </MemoryRouter>
    );
    const link = screen.getByRole('link');
    expect(link.getAttribute('href')).toContain('/listings/42');
    expect(link.getAttribute('href')).toContain('location=Katoomba');
    expect(link.getAttribute('href')).toContain('dateFrom=2026-08-01');
    expect(link.getAttribute('href')).toContain('dateTo=2026-08-07');
  });

  it('link has no query string when no search params are present', () => {
    render(
      <MemoryRouter initialEntries={['/']}>
        <ListingCard listing={listing} />
      </MemoryRouter>
    );
    const link = screen.getByRole('link');
    expect(link.getAttribute('href')).toBe('/listings/42');
  });

  it('shows a dev score badge when the listing has a score', () => {
    render(
      <MemoryRouter>
        <ListingCard listing={{ ...listing, score: 0.1234 }} />
      </MemoryRouter>
    );
    expect(screen.getByTestId('score-badge')).toHaveTextContent('0.123');
  });

  it('renders no score badge when the listing has no score', () => {
    render(
      <MemoryRouter>
        <ListingCard listing={listing} />
      </MemoryRouter>
    );
    expect(screen.queryByTestId('score-badge')).not.toBeInTheDocument();
  });
});
