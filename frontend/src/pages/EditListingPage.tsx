import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import { ListingForm } from '../components/ListingForm';
import type { ListingDetail } from '../types/listing';
import type { ListingFormFields } from '../types/listing-form';

export function EditListingPage() {
  const { id } = useParams();
  const { user, token } = useAuth();
  const navigate = useNavigate();
  const apiFetch = useApiFetch();

  const [listing, setListing] = useState<ListingDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) {
      navigate('/');
      return;
    }

    apiFetch(`/api/v1/listings/${id}`)
      .then(({ res, data }) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const listingData = data as ListingDetail;
        if (listingData.owner?.id !== user.id) {
          navigate(`/listings/${id}`);
          return;
        }
        setListing(listingData);
      })
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  }, [id, user, navigate]);

  async function handleSave(fields: ListingFormFields) {
    const body = new FormData();
    Object.entries(fields).forEach(([k, v]) => body.append(`listing[${k}]`, String(v)));

    const { res, data } = await apiFetch(`/api/v1/listings/${id}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}` },
      body,
    });
    if (!res.ok) throw new Error(data.errors?.join(', ') ?? 'Failed to save listing');
    navigate(`/listings/${id}`);
  }

  if (!user || loading) return <div className="p-8 text-gray-500">Loading…</div>;
  if (error) return <div className="p-8 text-red-500">Error: {error}</div>;
  if (!listing) return null;

  return (
    <div className="max-w-2xl mx-auto py-10 px-6">
      <h1 className="text-2xl font-bold text-gray-900 mb-8">Edit listing</h1>
      <ListingForm
        listingId={Number(id)}
        initialValues={listing}
        onSubmit={handleSave}
        submitLabel="Save changes"
      />
    </div>
  );
}
