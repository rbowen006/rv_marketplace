import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import { ListingForm } from '../components/ListingForm';
import type { ListingFormFields } from '../types/listing-form';
import type { ListingDetail } from '../types/listing';
import type { ApiErrorBody } from '../types/api';

interface NewListingPageProps {
  onSignInRequired?: () => void;
}

export function NewListingPage({ onSignInRequired }: NewListingPageProps) {
  const { token, user } = useAuth();
  const apiFetch = useApiFetch();
  const navigate = useNavigate();

  if (!user) {
    return (
      <div className="max-w-lg mx-auto py-20 text-center">
        <p className="text-gray-600 mb-4">You need to sign in to list your RV.</p>
        <button
          onClick={onSignInRequired}
          className="bg-rose-500 hover:bg-rose-600 text-white font-semibold px-6 py-2 rounded-full text-sm"
        >
          Sign in
        </button>
      </div>
    );
  }

  async function handleCreate(fields: ListingFormFields, images: File[]) {
    if (!images.length) throw new Error('At least one photo is required');
    const body = new FormData();
    Object.entries(fields).forEach(([k, v]) => body.append(`listing[${k}]`, String(v)));
    images.forEach((img) => body.append('listing[images][]', img));

    const { res, data } = await apiFetch<ListingDetail & ApiErrorBody>('/api/v1/listings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body,
    });
    if (!res.ok) throw new Error(data.errors?.join(', ') ?? 'Failed to create listing');
    navigate(`/listings/${data.id}`);
  }

  return (
    <div className="max-w-2xl mx-auto py-10 px-6">
      <h1 className="text-2xl font-bold text-gray-900 mb-8">List your RV</h1>
      <ListingForm initialValues={{}} onSubmit={handleCreate} submitLabel="Publish listing" />
    </div>
  );
}
