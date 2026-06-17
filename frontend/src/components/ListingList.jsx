import { useEffect, useState } from 'react';

export function ListingList({ token }) {
  const [listings, setListings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState(null);

  useEffect(() => {
    const load = async () => {
      try {
        const res = await fetch(`/api/v1/listings`, {
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {})
          }
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        setListings(data);
      } catch (e) {
        setErr(e.message);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [token]);

  if (loading) return <p className="text-gray-500">Loading listings...</p>;
  if (err) return <p className="text-red-600">Error: {err}</p>;

  if (!Array.isArray(listings)) {
    return <pre className="bg-gray-100 p-4 rounded text-sm overflow-auto">{JSON.stringify(listings, null, 2)}</pre>;
  }

  return (
    <ul className="list-none p-0 space-y-3">
      {listings.map(l => (
        <li key={l.id} className="border border-gray-300 rounded p-3">
          <strong className="text-lg">{l.title}</strong>
          <p className="mt-1 text-gray-700">{l.description}</p>
          <p className="mt-1 text-gray-500 italic">{l.location}</p>
          {l.price_per_day != null && (
            <p className="mt-1 font-medium text-green-700">{`$${l.price_per_day} / day`}</p>
          )}
        </li>
      ))}
    </ul>
  );
}
