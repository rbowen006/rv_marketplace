import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const STATUS_STYLES = {
  pending:   'bg-yellow-100 text-yellow-800',
  confirmed: 'bg-green-100 text-green-800',
  rejected:  'bg-gray-100 text-gray-500',
  cancelled: 'bg-gray-100 text-gray-500',
};

function formatDateRange(start, end) {
  const opts = { month: 'short', day: 'numeric' };
  const s = new Date(start + 'T00:00:00').toLocaleDateString([], opts);
  const e = new Date(end + 'T00:00:00').toLocaleDateString([], opts);
  return `${s} – ${e}`;
}

function StatusBadge({ status }) {
  return (
    <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-full capitalize ${STATUS_STYLES[status] ?? 'bg-gray-100 text-gray-500'}`}>
      {status}
    </span>
  );
}

function BookingRow({ booking, role, onAction }) {
  const isOwner = role === 'owner';
  const other = isOwner ? booking.hirer : booking.owner;
  const [acting, setActing] = useState(false);

  async function handleAction(action) {
    setActing(true);
    await onAction(booking.id, action);
    setActing(false);
  }

  return (
    <div className="px-6 py-5 border-b border-gray-100 flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex-1 min-w-0">
        <p className="font-semibold text-gray-900 truncate">{booking.listing_title}</p>
        <p className="text-sm text-gray-500 mt-0.5">{formatDateRange(booking.start_date, booking.end_date)}</p>
        <p className="text-sm text-gray-500">
          {isOwner ? 'From' : 'Owner'}: {other?.name ?? '—'}
        </p>
      </div>

      <div className="flex items-center gap-3 flex-shrink-0">
        <StatusBadge status={booking.status} />

        {isOwner && booking.status === 'pending' && (
          <>
            <button
              disabled={acting}
              onClick={() => handleAction('confirm')}
              className="text-sm px-3 py-1.5 rounded-lg bg-rose-500 text-white font-medium hover:bg-rose-600 disabled:opacity-50 transition-colors"
            >
              Confirm
            </button>
            <button
              disabled={acting}
              onClick={() => handleAction('reject')}
              className="text-sm px-3 py-1.5 rounded-lg border border-gray-300 text-gray-700 font-medium hover:bg-gray-50 disabled:opacity-50 transition-colors"
            >
              Reject
            </button>
          </>
        )}
      </div>
    </div>
  );
}

export function BookingsPage() {
  const { user, token } = useAuth();
  const navigate = useNavigate();
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('hirer');

  useEffect(() => {
    if (!user) { navigate('/'); return; }
    fetch('/api/v1/bookings', { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.json())
      .then(setBookings)
      .finally(() => setLoading(false));
  }, [user, token, navigate]);

  async function handleAction(bookingId, action) {
    const res = await fetch(`/api/v1/bookings/${bookingId}/${action}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return;
    const updated = await res.json();
    setBookings(prev => prev.map(b => b.id === updated.id ? { ...b, status: updated.status } : b));
  }

  const trips    = bookings.filter(b => b.hirer_id === user?.id);
  const listings = bookings.filter(b => b.owner?.id === user?.id);

  const tabs = [
    { key: 'hirer', label: 'My trips',    items: trips,    role: 'hirer' },
    { key: 'owner', label: 'My listings', items: listings, role: 'owner' },
  ];

  const active = tabs.find(t => t.key === activeTab);

  return (
    <div className="max-w-2xl mx-auto py-8">
      <h1 className="text-2xl font-bold text-gray-900 px-6 mb-6">Bookings</h1>

      <div className="flex border-b border-gray-200 px-6 mb-0">
        {tabs.map(tab => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`pb-3 px-4 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab.key
                ? 'border-rose-500 text-rose-500'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {loading ? (
        <p className="px-6 py-12 text-center text-sm text-gray-400">Loading…</p>
      ) : active.items.length === 0 ? (
        <p className="px-6 py-12 text-center text-sm text-gray-400">No bookings yet</p>
      ) : (
        <div>
          {active.items.map(booking => (
            <BookingRow
              key={booking.id}
              booking={booking}
              role={active.role}
              onAction={handleAction}
            />
          ))}
        </div>
      )}
    </div>
  );
}
