import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import { ListingCard } from '../components/ListingCard';

export function MyListingsPage() {
  const { user, token } = useAuth();
  const apiFetch = useApiFetch();
  const navigate = useNavigate();
  const [listings, setListings] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) { navigate('/'); return; }
    apiFetch('/api/v1/listings/mine', { headers: { Authorization: `Bearer ${token}` } })
      .then(({ res, data }) => setListings(res.ok && Array.isArray(data) ? data : []))
      .finally(() => setLoading(false));
  }, [user, token, navigate]);

  return (
    <div className="max-w-screen-xl mx-auto py-8">
      <h1 className="text-2xl font-bold text-gray-900 px-6 mb-6">My listings</h1>

      {loading ? (
        <p className="px-6 py-12 text-center text-sm text-gray-400">Loading…</p>
      ) : listings.length === 0 ? (
        <div className="text-center py-20 px-6">
          <p className="text-5xl mb-4">🚐</p>
          <p className="text-gray-900 text-lg font-semibold">You haven't listed any RVs yet</p>
          <p className="text-gray-500 mt-1 mb-6">List your RV and start earning.</p>
          <Link
            to="/listings/new"
            className="inline-block px-5 py-2.5 rounded-lg bg-rose-500 text-white text-sm font-medium hover:bg-rose-600 no-underline transition-colors"
          >
            List your RV
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 p-6">
          {listings.map(listing => (
            <div key={listing.id}>
              <ListingCard listing={listing} />
              <Link
                to={`/listings/${listing.id}/edit`}
                className="mt-2 inline-block text-sm font-medium text-rose-500 hover:text-rose-600 no-underline px-1"
              >
                Edit listing
              </Link>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
