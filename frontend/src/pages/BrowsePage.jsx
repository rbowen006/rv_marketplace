import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { SearchBar } from '../components/SearchBar';
import { ListingGrid } from '../components/ListingGrid';
import { SignInModal } from '../components/SignInModal';

export function BrowsePage() {
  const [allListings, setAllListings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filters, setFilters] = useState({ location: '', checkIn: '', checkOut: '', guests: '' });
  const [searched, setSearched] = useState(false);
  const [searchParams, setSearchParams] = useSearchParams();
  const [showSignIn, setShowSignIn] = useState(searchParams.get('reset') === '1');

  useEffect(() => {
    fetch('/api/v1/listings')
      .then(r => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); })
      .then(setAllListings)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  const visibleListings = searched
    ? allListings.filter(l => {
        const locationStr = [l.town, l.state, l.postcode].filter(Boolean).join(', ').toLowerCase();
        const matchesLocation = !filters.location ||
          locationStr.includes(filters.location.toLowerCase());
        const matchesGuests = !filters.guests ||
          (l.max_guests != null && l.max_guests >= parseInt(filters.guests, 10));
        return matchesLocation && matchesGuests;
      })
    : allListings;

  function closeSignIn() {
    setShowSignIn(false);
    setSearchParams({});
  }

  return (
    <div>
      <SearchBar
        filters={filters}
        onChange={setFilters}
        onSearch={() => setSearched(true)}
      />
      <main className="max-w-screen-xl mx-auto">
        <ListingGrid listings={visibleListings} loading={loading} error={error} />
      </main>
      {showSignIn && <SignInModal onClose={closeSignIn} />}
    </div>
  );
}
