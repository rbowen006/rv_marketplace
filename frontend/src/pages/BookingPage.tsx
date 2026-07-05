import { FormEvent, useEffect, useState } from 'react';
import { useParams, Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import type { BookingConfirmation } from '../types/booking';
import type { ListingDetail } from '../types/listing';
import type { ApiErrorBody } from '../types/api';

function daysBetween(start: string, end: string): number {
  if (!start || !end) return 0;
  const ms = new Date(end).getTime() - new Date(start).getTime();
  return Math.max(0, Math.round(ms / 86400000));
}

export function BookingPage() {
  const { id } = useParams();
  const { token } = useAuth();
  const apiFetch = useApiFetch();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const today = new Date().toISOString().split('T')[0];

  function validFutureDate(str: string | null): string {
    return str && str >= today ? str : '';
  }

  const [listing, setListing] = useState<ListingDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const initialDateFrom = validFutureDate(searchParams.get('dateFrom'));
  const [startDate, setStartDate] = useState(initialDateFrom);
  const [endDate, setEndDate] = useState(initialDateFrom ? validFutureDate(searchParams.get('dateTo')) : '');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmed, setConfirmed] = useState<BookingConfirmation | null>(null);

  useEffect(() => {
    apiFetch<ListingDetail>(`/api/v1/listings/${id}`)
      .then(({ res, data }) => { if (!res.ok) throw new Error(`HTTP ${res.status}`); setListing(data); })
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  }, [id]);

  const nights = daysBetween(startDate, endDate);
  const total = listing ? nights * listing.price_per_day : 0;

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const { res, data } = await apiFetch<BookingConfirmation & ApiErrorBody>(`/api/v1/listings/${id}/bookings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ booking: { start_date: startDate, end_date: endDate } }),
      });
      if (!res.ok) throw new Error((data.errors || [data.error]).flat().join(', '));
      setConfirmed(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) return <div className="p-8 text-gray-500">Loading...</div>;
  if (!listing) return <div className="p-8 text-red-500">Listing not found.</div>;

  if (confirmed) {
    return (
      <div className="max-w-lg mx-auto px-6 py-16 text-center">
        <div className="text-5xl mb-4">🎉</div>
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Booking requested!</h1>
        <p className="text-gray-500 mb-1">{listing.title}</p>
        <p className="text-gray-700 mb-6">
          {confirmed.start_date} → {confirmed.end_date} · {nights} night{nights !== 1 ? 's' : ''}
        </p>
        <p className="text-sm text-gray-400 mb-8">The owner will confirm your booking soon.</p>
        <Link to="/" className="inline-block bg-rose-500 hover:bg-rose-600 text-white font-semibold py-3 px-6 rounded-xl transition-colors">
          Back to listings
        </Link>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto px-6 py-8">
      <Link to={`/listings/${id}${searchParams.toString() ? '?' + searchParams.toString() : ''}`} className="text-sm text-gray-500 hover:text-gray-800 flex items-center gap-1 mb-6">
        ← Back to listing
      </Link>

      <h1 className="text-2xl font-bold text-gray-900 mb-1">Book {listing.title}</h1>
      <p className="text-gray-500 text-sm mb-8">${listing.price_per_day} / night</p>

      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label htmlFor="date-from" className="block text-sm font-medium text-gray-700 mb-1">Date From</label>
            <input
              id="date-from"
              type="date"
              required
              min={today}
              value={startDate}
              onChange={e => { setStartDate(e.target.value); if (endDate && e.target.value >= endDate) setEndDate(''); }}
              className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
            />
          </div>
          <div>
            <label htmlFor="date-to" className="block text-sm font-medium text-gray-700 mb-1">Date To</label>
            <input
              id="date-to"
              type="date"
              required
              min={startDate || today}
              value={endDate}
              onChange={e => setEndDate(e.target.value)}
              className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
            />
          </div>
        </div>

        {nights > 0 && (
          <div className="bg-gray-50 rounded-xl p-4 text-sm space-y-2">
            <div className="flex justify-between text-gray-600">
              <span>${listing.price_per_day} × {nights} night{nights !== 1 ? 's' : ''}</span>
              <span>${total}</span>
            </div>
            <div className="flex justify-between font-semibold text-gray-900 border-t border-gray-200 pt-2 mt-2">
              <span>Total</span>
              <span>${total}</span>
            </div>
          </div>
        )}

        {error && <p className="text-sm text-red-500">{error}</p>}

        <button
          type="submit"
          disabled={submitting || nights === 0}
          className="w-full bg-rose-500 hover:bg-rose-600 disabled:bg-rose-300 text-white font-semibold py-3 rounded-xl transition-colors"
        >
          {submitting ? 'Requesting…' : 'Request to book'}
        </button>
      </form>
    </div>
  );
}
