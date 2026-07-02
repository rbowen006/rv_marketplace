import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ListingGrid } from '../components/ListingGrid';
import { SignInModal } from '../components/SignInModal';

export function BrowsePage() {
  const [allListings, setAllListings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchParams, setSearchParams] = useSearchParams();
  const [showSignIn, setShowSignIn] = useState(searchParams.get('reset') === '1');

  const location = searchParams.get('location') || '';
  const guests   = searchParams.get('guests')   || '';
  const pets     = searchParams.get('pets') === '1';

  useEffect(() => {
    fetch('/api/v1/listings')
      .then(r => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); })
      .then(setAllListings)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  const visibleListings = allListings.filter(l => {
    const loc = [l.town, l.state, l.postcode].filter(Boolean).join(', ').toLowerCase();
    const matchesLocation = !location || loc.includes(location.toLowerCase());
    const matchesGuests   = !guests   || (l.max_guests != null && l.max_guests >= parseInt(guests, 10));
    const matchesPets     = !pets     || l.pet_friendly === true;
    return matchesLocation && matchesGuests && matchesPets;
  });

  function closeSignIn() {
    setShowSignIn(false);
    setSearchParams({});
  }

  return (
    <div>
      <main className="max-w-screen-xl mx-auto">
        <ListingGrid listings={visibleListings} loading={loading} error={error} />
      </main>
      {showSignIn && <SignInModal onClose={closeSignIn} />}
    </div>
  );
}
