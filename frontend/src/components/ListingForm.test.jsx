import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ListingForm } from './ListingForm';

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: { id: 1 } }),
}));

let mockApiFetch;
vi.mock('../lib/useApiFetch', () => ({
  useApiFetch: () => mockApiFetch,
}));

function renderForm(props = {}) {
  render(
    <MemoryRouter>
      <ListingForm
        initialValues={{}}
        onSubmit={vi.fn()}
        submitLabel="Save listing"
        {...props}
      />
    </MemoryRouter>
  );
}

describe('ListingForm', () => {
  beforeEach(() => {
    mockApiFetch = vi.fn().mockResolvedValue({ res: { ok: true }, data: {} });
  });
  it('renders all required fields and the submit button', () => {
    renderForm();

    expect(screen.getByLabelText(/title/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/description/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/rv type/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/town/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/state/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/postcode/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/price per day/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/max guests/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/pet friendly/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /save listing/i })).toBeInTheDocument();
  });

  it('populates fields from initialValues', () => {
    renderForm({
      initialValues: {
        title: 'My Caravan',
        description: 'Great for families',
        rv_type: 'caravan',
        town: 'Byron Bay',
        state: 'NSW',
        postcode: '2481',
        price_per_day: 120,
        max_guests: 4,
        pet_friendly: true,
      },
    });

    expect(screen.getByLabelText(/title/i)).toHaveValue('My Caravan');
    expect(screen.getByLabelText(/description/i)).toHaveValue('Great for families');
    expect(screen.getByLabelText(/rv type/i)).toHaveValue('caravan');
    expect(screen.getByLabelText(/town/i)).toHaveValue('Byron Bay');
    expect(screen.getByLabelText(/state/i)).toHaveValue('NSW');
    expect(screen.getByLabelText(/postcode/i)).toHaveValue('2481');
    expect(screen.getByLabelText(/price per day/i)).toHaveValue(120);
    expect(screen.getByLabelText(/max guests/i)).toHaveValue(4);
    expect(screen.getByLabelText(/pet friendly/i)).toBeChecked();
  });

  it('calls onSubmit with field values and empty images array when submitted', async () => {
    const onSubmit = vi.fn().mockResolvedValue();
    renderForm({
      initialValues: { title: 'My Caravan', rv_type: 'caravan', town: 'Sydney',
        state: 'NSW', postcode: '2000', price_per_day: 100, max_guests: 2 },
      onSubmit,
    });

    fireEvent.click(screen.getByRole('button', { name: /save listing/i }));

    await waitFor(() => expect(onSubmit).toHaveBeenCalledOnce());
    const [fields, images] = onSubmit.mock.calls[0];
    expect(fields.title).toBe('My Caravan');
    expect(fields.rv_type).toBe('caravan');
    expect(images).toEqual([]);
  });

  it('renders existing image thumbnails from initialValues.images', () => {
    renderForm({
      initialValues: {
        images: [
          { id: 10, url: 'https://example.com/a.jpg' },
          { id: 11, url: 'https://example.com/b.jpg' },
        ],
      },
    });

    expect(screen.getByAltText('Photo 1')).toHaveAttribute('src', 'https://example.com/a.jpg');
    expect(screen.getByAltText('Photo 2')).toHaveAttribute('src', 'https://example.com/b.jpg');
  });

  it('calls DELETE endpoint immediately when a thumbnail X button is clicked', async () => {
    renderForm({
      listingId: 99,
      initialValues: {
        images: [{ id: 10, url: 'https://example.com/a.jpg' }],
      },
    });

    fireEvent.click(screen.getByRole('button', { name: /delete image/i }));

    await waitFor(() =>
      expect(mockApiFetch).toHaveBeenCalledWith(
        '/api/v1/listings/99/images/10',
        expect.objectContaining({ method: 'DELETE' })
      )
    );
    expect(screen.queryByAltText('Photo 1')).not.toBeInTheDocument();
  });
});
