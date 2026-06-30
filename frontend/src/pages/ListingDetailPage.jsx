import { useEffect, useState } from 'react';
import { useParams, Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { SignInModal } from '../components/SignInModal';
import { ContactOwnerModal } from '../components/ContactOwnerModal';

export function ListingDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [searchParams] = useSearchParams();
  const qs = searchParams.toString();

  const [listing, setListing] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeImage, setActiveImage] = useState(0);
  const [showSignIn, setShowSignIn] = useState(false);
  const [showContact, setShowContact] = useState(false);
  // Tracks which action to trigger after successful sign-in
  const [pendingAction, setPendingAction] = useState(null);

  useEffect(() => {
    fetch(`/api/v1/listings/${id}`)
      .then(r => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); })
      .then(setListing)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false));
  }, [id]);

  function requireAuth(action) {
    if (user) {
      triggerAction(action);
    } else {
      setPendingAction(action);
      setShowSignIn(true);
    }
  }

  function triggerAction(action) {
    if (action === 'book') {
      navigate(`/listings/${id}/book${qs ? '?' + qs : ''}`);
    } else if (action === 'contact') {
      setShowContact(true);
    }
  }

  function onSignInSuccess() {
    setShowSignIn(false);
    if (pendingAction) {
      triggerAction(pendingAction);
      setPendingAction(null);
    }
  }

  if (loading) return <div className="p-8 text-gray-500">Loading...</div>;
  if (error) return <div className="p-8 text-red-500">Error: {error}</div>;
  if (!listing) return null;

  const images = listing.images ?? [];
  const isOwner = user?.id === listing.owner?.id;

  return (
    <>
      {showSignIn && (
        <SignInModal onClose={() => setShowSignIn(false)} onSuccess={onSignInSuccess} />
      )}
      {showContact && (
        <ContactOwnerModal
          listingId={id}
          listingTitle={listing.title}
          onClose={() => setShowContact(false)}
        />
      )}

      <div className="max-w-5xl mx-auto px-6 py-8">
        <Link to={`/${qs ? '?' + qs : ''}`} className="text-sm text-gray-500 hover:text-gray-800 flex items-center gap-1 mb-4">
          ← Back to listings
        </Link>

        <h1 className="text-2xl font-bold text-gray-900 mb-2">{listing.title}</h1>
        <p className="text-gray-500 text-sm mb-6">{[listing.town, listing.state, listing.postcode].filter(Boolean).join(', ')}</p>

        {/* Image gallery */}
        <div className="mb-8">
          <div className="aspect-video rounded-xl overflow-hidden bg-gray-200 mb-2">
            {images[activeImage] ? (
              <img
                src={images[activeImage].url}
                alt={listing.title}
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-gray-400 text-6xl">🚐</div>
            )}
          </div>
          {images.length > 1 && (
            <div className="flex gap-2 overflow-x-auto">
              {images.map((img, i) => (
                <button
                  key={img.id}
                  onClick={() => setActiveImage(i)}
                  className={`flex-shrink-0 w-20 h-20 rounded-lg overflow-hidden border-2 transition-colors ${i === activeImage ? 'border-rose-500' : 'border-transparent'}`}
                >
                  <img src={img.url} alt="" className="w-full h-full object-cover" />
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          <div className="md:col-span-2">
            {/* Owner info */}
            <div className="flex items-center gap-3 mb-6 pb-6 border-b border-gray-200">
              <div className="w-12 h-12 rounded-full bg-rose-100 flex items-center justify-center text-rose-500 text-xl font-bold">
                {listing.owner?.name?.[0]?.toUpperCase() ?? '?'}
              </div>
              <div>
                <p className="text-sm text-gray-500">Owned by</p>
                <p className="font-semibold text-gray-900">{listing.owner?.name ?? 'Owner'}</p>
              </div>
            </div>

            {/* Details */}
            <div className="flex gap-6 mb-6 text-sm text-gray-700">
              <span>👥 Up to {listing.max_guests} guests</span>
              {listing.pet_friendly && <span>🐾 Pet friendly</span>}
            </div>

            <p className="text-gray-700 leading-relaxed">{listing.description}</p>
          </div>

          {/* Booking widget */}
          <div className="bg-white border border-gray-200 rounded-2xl shadow-lg p-6 h-fit sticky top-24">
            <p className="text-xl font-bold text-gray-900 mb-1">
              ${listing.price_per_day}
              <span className="text-base font-normal text-gray-500"> / day</span>
            </p>

            {isOwner ? (
              <p className="mt-4 text-sm text-center text-gray-400">This is your listing.</p>
            ) : (
              <div className="mt-4 space-y-3">
                <button
                  onClick={() => requireAuth('book')}
                  className="w-full bg-rose-500 hover:bg-rose-600 text-white font-semibold py-3 rounded-xl transition-colors"
                >
                  Book
                </button>
                <button
                  onClick={() => requireAuth('contact')}
                  className="w-full border border-gray-300 hover:border-gray-400 text-gray-800 font-semibold py-3 rounded-xl transition-colors"
                >
                  Contact owner
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
