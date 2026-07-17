import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ListingForm } from './ListingForm';
import type { ListingFormProps } from '../types/listing-form';

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: { id: 1 } }),
}));

let mockApiFetch: ReturnType<typeof vi.fn>;
vi.mock('../lib/useApiFetch', () => ({
  useApiFetch: () => mockApiFetch,
}));

function renderForm(props: Partial<ListingFormProps> = {}) {
  render(
    <MemoryRouter>
      <ListingForm initialValues={{}} onSubmit={vi.fn()} submitLabel="Save listing" {...props} />
    </MemoryRouter>,
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
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    renderForm({
      initialValues: {
        title: 'My Caravan',
        rv_type: 'caravan',
        town: 'Sydney',
        state: 'NSW',
        postcode: '2000',
        price_per_day: 100,
        max_guests: 2,
      },
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
        expect.objectContaining({ method: 'DELETE' }),
      ),
    );
    expect(screen.queryByAltText('Photo 1')).not.toBeInTheDocument();
  });

  describe('Generate description button', () => {
    it('is disabled until rv_type, town, state, and max_guests are filled', () => {
      renderForm();
      expect(screen.getByRole('button', { name: /generate description/i })).toBeDisabled();
    });

    it('is enabled once rv_type, town, state, and max_guests are filled', () => {
      renderForm();
      fireEvent.change(screen.getByLabelText(/rv type/i), { target: { value: 'caravan' } });
      fireEvent.change(screen.getByLabelText(/town/i), { target: { value: 'Byron Bay' } });
      fireEvent.change(screen.getByLabelText(/state/i), { target: { value: 'NSW' } });
      fireEvent.change(screen.getByLabelText(/max guests/i), { target: { value: '4' } });

      expect(screen.getByRole('button', { name: /generate description/i })).toBeEnabled();
    });

    it('calls the generate endpoint and fills in the description on success', async () => {
      mockApiFetch = vi.fn().mockResolvedValue({
        res: { ok: true },
        data: { status: 'success', data: { description: 'A lovely caravan in Byron Bay.' } },
      });
      renderForm();
      fireEvent.change(screen.getByLabelText(/rv type/i), { target: { value: 'caravan' } });
      fireEvent.change(screen.getByLabelText(/town/i), { target: { value: 'Byron Bay' } });
      fireEvent.change(screen.getByLabelText(/state/i), { target: { value: 'NSW' } });
      fireEvent.change(screen.getByLabelText(/max guests/i), { target: { value: '4' } });

      fireEvent.click(screen.getByRole('button', { name: /generate description/i }));

      await waitFor(() =>
        expect(mockApiFetch).toHaveBeenCalledWith(
          '/api/v1/listings/generate_description',
          expect.objectContaining({
            method: 'POST',
            headers: expect.objectContaining({
              'Content-Type': 'application/json',
              Authorization: 'Bearer test-token',
            }),
          }),
        ),
      );
      const [, options] = mockApiFetch.mock.calls[0];
      expect(JSON.parse(options.body)).toEqual(
        expect.objectContaining({
          rv_type: 'caravan',
          town: 'Byron Bay',
          state: 'NSW',
          max_guests: '4',
        }),
      );

      await waitFor(() =>
        expect(screen.getByLabelText(/description/i)).toHaveValue('A lovely caravan in Byron Bay.'),
      );
    });

    it('does not call the API when the description is non-empty and the user cancels the confirm dialog', async () => {
      renderForm({
        initialValues: {
          description: 'Existing description',
          rv_type: 'caravan',
          town: 'Byron Bay',
          state: 'NSW',
          max_guests: 4,
        },
      });

      fireEvent.click(screen.getByRole('button', { name: /generate description/i }));
      fireEvent.click(screen.getByRole('button', { name: 'Cancel' }));

      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
      expect(mockApiFetch).not.toHaveBeenCalled();
      expect(screen.getByLabelText(/description/i)).toHaveValue('Existing description');
    });

    it('calls the API when the description is non-empty and the user confirms', async () => {
      mockApiFetch = vi.fn().mockResolvedValue({
        res: { ok: true },
        data: { status: 'success', data: { description: 'A fresh new description.' } },
      });
      renderForm({
        initialValues: {
          description: 'Existing description',
          rv_type: 'caravan',
          town: 'Byron Bay',
          state: 'NSW',
          max_guests: 4,
        },
      });

      fireEvent.click(screen.getByRole('button', { name: /generate description/i }));
      fireEvent.click(screen.getByRole('button', { name: 'Replace description' }));

      await waitFor(() =>
        expect(screen.getByLabelText(/description/i)).toHaveValue('A fresh new description.'),
      );
    });

    it('shows "Generating…", and disables both the Generate and Submit buttons, while the call is in flight', async () => {
      let resolveFetch: (value: unknown) => void;
      mockApiFetch = vi.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveFetch = resolve;
        }),
      );
      renderForm({
        initialValues: { rv_type: 'caravan', town: 'Byron Bay', state: 'NSW', max_guests: 4 },
      });

      fireEvent.click(screen.getByRole('button', { name: /generate description/i }));

      expect(await screen.findByRole('button', { name: /generating/i })).toBeDisabled();
      expect(screen.getByRole('button', { name: /save listing/i })).toBeDisabled();

      resolveFetch!({
        res: { ok: true },
        data: { status: 'success', data: { description: 'Done.' } },
      });
      await waitFor(() =>
        expect(screen.getByRole('button', { name: /generate description/i })).toBeEnabled(),
      );
      expect(screen.getByRole('button', { name: /save listing/i })).toBeEnabled();
    });

    it('shows the API error near the Generate button, not in the form-submit error banner', async () => {
      mockApiFetch = vi.fn().mockResolvedValue({
        res: { ok: false, status: 503 },
        data: { status: 'error', message: 'Claude API error: Overloaded' },
      });
      renderForm({
        initialValues: { rv_type: 'caravan', town: 'Byron Bay', state: 'NSW', max_guests: 4 },
      });

      fireEvent.click(screen.getByRole('button', { name: /generate description/i }));

      expect(await screen.findByText('Claude API error: Overloaded')).toBeInTheDocument();
      expect(screen.queryByText(/failed to (save|create) listing/i)).not.toBeInTheDocument();
    });

    it('shows a generic error near the button when the request itself throws (e.g. network failure)', async () => {
      mockApiFetch = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));
      renderForm({
        initialValues: { rv_type: 'caravan', town: 'Byron Bay', state: 'NSW', max_guests: 4 },
      });

      fireEvent.click(screen.getByRole('button', { name: /generate description/i }));

      expect(await screen.findByText(/failed to generate description/i)).toBeInTheDocument();
      await waitFor(() =>
        expect(screen.getByRole('button', { name: /generate description/i })).toBeEnabled(),
      );
    });

    it('disables the description textarea while generating, so a manual edit cannot be silently clobbered', async () => {
      let resolveFetch: (value: unknown) => void;
      mockApiFetch = vi.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveFetch = resolve;
        }),
      );
      renderForm({
        initialValues: { rv_type: 'caravan', town: 'Byron Bay', state: 'NSW', max_guests: 4 },
      });

      fireEvent.click(screen.getByRole('button', { name: /generate description/i }));

      await waitFor(() => expect(screen.getByLabelText(/description/i)).toBeDisabled());

      resolveFetch!({
        res: { ok: true },
        data: { status: 'success', data: { description: 'Done.' } },
      });
      await waitFor(() => expect(screen.getByLabelText(/description/i)).toBeEnabled());
    });
  });
});
