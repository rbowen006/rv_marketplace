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

  if (loading) return <p>Loading listings...</p>;
  if (err) return <p style={{ color: 'red' }}>Error: {err}</p>;

  if (!Array.isArray(listings)) {
    return <pre>{JSON.stringify(listings, null, 2)}</pre>;
  }

  return (
    <ul style={{ listStyle: 'none', padding: 0 }}>
      {listings.map(l => (
        <li key={l.id} style={{ border: '1px solid #ccc', margin: '0 0 12px', padding: '8px' }}>
          <strong>{l.title}</strong><br />
          {l.description}<br />
          <em>{l.location}</em><br />
          ${'{'}l.price_per_day{'}'} / day
        </li>
      ))}
    </ul>
  );
}
