import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter, useSearchParams } from 'react-router-dom';
import { SearchBar } from './SearchBar';
import * as ReactRouterDom from 'react-router-dom';

vi.mock('react-router-dom', async (importOriginal) => {
  const actual = await importOriginal<typeof ReactRouterDom>();
  return { ...actual, useNavigate: vi.fn() };
});

const mockNavigate = vi.fn();

beforeEach(() => {
  vi.mocked(ReactRouterDom.useNavigate).mockReturnValue(mockNavigate);
  mockNavigate.mockClear();
});

function renderSearchBar(initialUrl = '/') {
  render(
    <MemoryRouter initialEntries={[initialUrl]}>
      <SearchBar />
    </MemoryRouter>,
  );
}

describe('SearchBar collapsed pill', () => {
  it('shows "Anywhere" when no location is set', () => {
    renderSearchBar();
    expect(screen.getByText('Anywhere')).toBeInTheDocument();
  });

  it('shows "Any week" when no dates are set', () => {
    renderSearchBar();
    expect(screen.getByText('Any week')).toBeInTheDocument();
  });

  it('shows "Add guests" when no guests or pets are set', () => {
    renderSearchBar();
    expect(screen.getByText('Add guests')).toBeInTheDocument();
  });
});

describe('SearchBar panels', () => {
  it('clicking "Anywhere" opens the Where panel with a text input', () => {
    renderSearchBar();
    fireEvent.click(screen.getByText('Anywhere'));
    expect(screen.getByPlaceholderText('Search destinations')).toBeInTheDocument();
  });

  it('typing in the Where panel updates the pill label', () => {
    renderSearchBar();
    fireEvent.click(screen.getByText('Anywhere'));
    fireEvent.change(screen.getByPlaceholderText('Search destinations'), {
      target: { value: 'Byron' },
    });
    expect(screen.getByText('Byron')).toBeInTheDocument();
  });

  it('clicking "Any week" opens the When panel showing a month name', () => {
    renderSearchBar();
    fireEvent.click(screen.getByText('Any week'));
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const found = monthNames.some((m) => screen.queryByText(new RegExp(m)));
    expect(found).toBe(true);
  });

  it('clicking "Add guests" opens the Who panel with an add guest button', () => {
    renderSearchBar();
    fireEvent.click(screen.getByText('Add guests'));
    expect(screen.getByLabelText('Add guest')).toBeInTheDocument();
  });

  it('clicking + in Who panel increments guest count shown in pill', () => {
    renderSearchBar();
    fireEvent.click(screen.getByText('Add guests'));
    fireEvent.click(screen.getByLabelText('Add guest'));
    expect(screen.getByText('1 guest')).toBeInTheDocument();
  });

  it('search button navigates to / with location param', () => {
    renderSearchBar();
    fireEvent.click(screen.getByText('Anywhere'));
    fireEvent.change(screen.getByPlaceholderText('Search destinations'), {
      target: { value: 'Byron' },
    });
    fireEvent.click(screen.getByRole('button', { name: /search/i }));
    expect(mockNavigate).toHaveBeenCalledWith('/?location=Byron');
  });

  it('toggling pets in Who panel replaces "Add guests" with "Pets" in pill', () => {
    renderSearchBar();
    fireEvent.click(screen.getByText('Add guests'));
    fireEvent.click(screen.getByLabelText('Enable pets filter'));
    expect(screen.queryByText('Add guests')).not.toBeInTheDocument();
    expect(screen.getAllByText('Pets').length).toBeGreaterThanOrEqual(1);
  });

  it('search button navigates with dateFrom and dateTo params', () => {
    renderSearchBar('/?dateFrom=2026-08-01&dateTo=2026-08-07');
    fireEvent.click(screen.getByRole('button', { name: /search/i }));
    expect(mockNavigate).toHaveBeenCalledWith(expect.stringContaining('dateFrom=2026-08-01'));
    expect(mockNavigate).toHaveBeenCalledWith(expect.stringContaining('dateTo=2026-08-07'));
  });
});

describe('SearchBar URL seeding', () => {
  it('seeds the date pill from dateFrom and dateTo URL params on mount', () => {
    renderSearchBar('/?dateFrom=2026-08-01&dateTo=2026-08-07');
    expect(screen.queryByText('Any week')).not.toBeInTheDocument();
  });
});

describe('SearchBar mirrors the URL', () => {
  // Stands in for a natural-language search elsewhere: navigate to ?q= (which
  // carries no structured params).
  function GoNlSearch() {
    const [, setSearchParams] = useSearchParams();
    return <button onClick={() => setSearchParams({ q: 'beach' })}>go-nl</button>;
  }

  it('clears its location when the URL switches to a natural-language search', () => {
    render(
      <MemoryRouter initialEntries={['/?location=Byron']}>
        <SearchBar />
        <GoNlSearch />
      </MemoryRouter>,
    );
    expect(screen.getByText('Byron')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'go-nl' }));

    expect(screen.queryByText('Byron')).not.toBeInTheDocument();
    expect(screen.getByText('Anywhere')).toBeInTheDocument();
  });
});
