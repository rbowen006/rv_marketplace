import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import type { BookingDetail } from '../types/booking';
import { TripPlanPanel } from '../components/TripPlanPanel';

function formatDateRange(start: string, end: string): string {
  const opts: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric', year: 'numeric' };
  const s = new Date(start + 'T00:00:00').toLocaleDateString([], opts);
  const e = new Date(end + 'T00:00:00').toLocaleDateString([], opts);
  return `${s} – ${e}`;
}

export function BookingDetailPage() {
  const { id } = useParams();
  const { token, user } = useAuth();
  const apiFetch = useApiFetch();
  const [booking, setBooking] = useState<BookingDetail | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiFetch<BookingDetail>(`/api/v1/bookings/${id}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then(({ res, data }) => {
        if (res.ok) setBooking(data);
      })
      .finally(() => setLoading(false));
  }, [id, token]);

  if (loading) {
    return <p className="max-w-2xl mx-auto px-6 py-12 text-center text-sm text-gray-400">Loading…</p>;
  }

  if (!booking) {
    return <p className="max-w-2xl mx-auto px-6 py-12 text-center text-sm text-gray-400">Booking not found.</p>;
  }

  return (
    <div className="max-w-2xl mx-auto py-8 px-6">
      <h1 className="text-2xl font-bold text-gray-900">{booking.listing_title}</h1>
      <p className="text-sm text-gray-500 mt-1">
        {formatDateRange(booking.start_date, booking.end_date)}
      </p>
      <p className="text-sm text-gray-500 capitalize">Status: {booking.status}</p>

      {/* Trip planning is hirer-only; the owner can view the booking but not plan. */}
      {booking.trip_planning_available && booking.hirer_id === user?.id && (
        <TripPlanPanel bookingId={booking.id} />
      )}
    </div>
  );
}
