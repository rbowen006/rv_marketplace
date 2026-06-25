import { render, screen, fireEvent } from '@testing-library/react';
import { SearchBar } from './SearchBar';
import * as ReactRouterDom from 'react-router-dom';

vi.mock('react-router-dom', async (importOriginal) => {
  const actual = await importOriginal();
  return { ...actual, useNavigate: vi.fn() };
});

const mockNavigate = vi.fn();

beforeEach(() => {
  vi.mocked(ReactRouterDom.useNavigate).mockReturnValue(mockNavigate);
  mockNavigate.mockClear();
});

describe('SearchBar collapsed pill', () => {
  it('shows "Anywhere" when no location is set', () => {
    render(<SearchBar />);
    expect(screen.getByText('Anywhere')).toBeInTheDocument();
  });

  it('shows "Any week" when no dates are set', () => {
    render(<SearchBar />);
    expect(screen.getByText('Any week')).toBeInTheDocument();
  });

  it('shows "Add guests" when no guests or pets are set', () => {
    render(<SearchBar />);
    expect(screen.getByText('Add guests')).toBeInTheDocument();
  });
});

describe('SearchBar panels', () => {
  it('clicking "Anywhere" opens the Where panel with a text input', () => {
    render(<SearchBar />);
    fireEvent.click(screen.getByText('Anywhere'));
    expect(screen.getByPlaceholderText('Search destinations')).toBeInTheDocument();
  });

  it('typing in the Where panel updates the pill label', () => {
    render(<SearchBar />);
    fireEvent.click(screen.getByText('Anywhere'));
    fireEvent.change(screen.getByPlaceholderText('Search destinations'), { target: { value: 'Byron' } });
    expect(screen.getByText('Byron')).toBeInTheDocument();
  });

  it('clicking "Any week" opens the When panel showing a month name', () => {
    render(<SearchBar />);
    fireEvent.click(screen.getByText('Any week'));
    const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    const found = monthNames.some(m => screen.queryByText(new RegExp(m)));
    expect(found).toBe(true);
  });

  it('clicking "Add guests" opens the Who panel with an add guest button', () => {
    render(<SearchBar />);
    fireEvent.click(screen.getByText('Add guests'));
    expect(screen.getByLabelText('Add guest')).toBeInTheDocument();
  });

  it('clicking + in Who panel increments guest count shown in pill', () => {
    render(<SearchBar />);
    fireEvent.click(screen.getByText('Add guests'));
    fireEvent.click(screen.getByLabelText('Add guest'));
    expect(screen.getByText('1 guest')).toBeInTheDocument();
  });

  it('search button navigates to / with location param', () => {
    render(<SearchBar />);
    fireEvent.click(screen.getByText('Anywhere'));
    fireEvent.change(screen.getByPlaceholderText('Search destinations'), { target: { value: 'Byron' } });
    fireEvent.click(screen.getByRole('button', { name: /search/i }));
    expect(mockNavigate).toHaveBeenCalledWith('/?location=Byron');
  });

  it('toggling pets in Who panel replaces "Add guests" with "Pets" in pill', () => {
    render(<SearchBar />);
    fireEvent.click(screen.getByText('Add guests'));
    fireEvent.click(screen.getByLabelText('Enable pets filter'));
    expect(screen.queryByText('Add guests')).not.toBeInTheDocument();
    expect(screen.getAllByText('Pets').length).toBeGreaterThanOrEqual(1);
  });
});
