import { FormEvent, useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useApiFetch } from '../lib/useApiFetch';
import type { Itinerary, TripPlan } from '../types/booking';

interface TripPlanPanelProps {
  bookingId: number;
  pollIntervalMs?: number;
}

interface TripPlanEnvelope {
  status: string;
  data: TripPlan;
  message?: string;
}

const GENERATING = ['pending', 'processing'];

export function TripPlanPanel({ bookingId, pollIntervalMs = 2500 }: TripPlanPanelProps) {
  const { token } = useAuth();
  const apiFetch = useApiFetch();
  const [plan, setPlan] = useState<TripPlan | null>(null);
  const [interests, setInterests] = useState('');
  const [error, setError] = useState<string | null>(null);

  const url = `/api/v1/bookings/${bookingId}/trip_plan`;
  const authHeaders = { Authorization: `Bearer ${token}` };

  // Load any existing plan on mount, prefilling the last interests used.
  useEffect(() => {
    apiFetch<TripPlanEnvelope>(url, { headers: authHeaders }).then(({ res, data }) => {
      if (!res.ok) return;
      setPlan(data.data);
      if (data.data.interests) setInterests(data.data.interests);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bookingId, token]);

  // Poll while the itinerary is being generated; stop once it settles.
  const status = plan?.status;
  useEffect(() => {
    if (!status || !GENERATING.includes(status)) return;
    const timer = setInterval(() => {
      apiFetch<TripPlanEnvelope>(url, { headers: authHeaders }).then(({ res, data }) => {
        if (res.ok) setPlan(data.data);
      });
    }, pollIntervalMs);
    return () => clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, bookingId, token, pollIntervalMs]);

  async function generate(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const { res, data } = await apiFetch<TripPlanEnvelope>(url, {
      method: 'POST',
      headers: { ...authHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ interests }),
    });
    if (res.ok) {
      setPlan(data.data);
    } else {
      setError(data.message ?? "Sorry, we couldn't start planning. Please try again.");
    }
  }

  const generating = status !== undefined && GENERATING.includes(status);
  const failed = status === 'failed';
  const completed = status === 'completed';

  const buttonLabel = failed ? 'Try again' : completed ? 'Regenerate' : 'Generate itinerary';

  return (
    <section className="mt-8 border-t border-gray-100 pt-6">
      <h2 className="text-lg font-semibold text-gray-900">Plan my trip</h2>
      <p className="text-sm text-gray-500 mt-1">
        Tell us what you enjoy and we'll draft a day-by-day itinerary grounded in local guides.
      </p>

      {!generating && (
        <form onSubmit={generate} className="mt-4">
          <label htmlFor="trip-interests" className="block text-sm font-medium text-gray-700">
            Your interests (optional)
          </label>
          <textarea
            id="trip-interests"
            value={interests}
            onChange={(e) => setInterests(e.target.value)}
            rows={2}
            placeholder="e.g. quiet beaches, koalas, a rainforest walk"
            className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-rose-500"
          />
          <button
            type="submit"
            className="mt-2 text-sm px-4 py-2 rounded-lg bg-rose-500 text-white font-medium hover:bg-rose-600 transition-colors"
          >
            {buttonLabel}
          </button>
        </form>
      )}

      {generating && (
        <p className="mt-4 text-sm text-gray-500" role="status">
          Generating your itinerary… this can take a moment.
        </p>
      )}

      {failed && (
        <p className="mt-4 text-sm text-red-600">
          Sorry, we couldn't generate your itinerary{plan?.error ? `: ${plan.error}` : '.'}
        </p>
      )}

      {error && <p className="mt-4 text-sm text-red-600">{error}</p>}

      {completed && plan?.itinerary && <ItineraryView itinerary={plan.itinerary} />}
    </section>
  );
}

function ItineraryView({ itinerary }: { itinerary: Itinerary }) {
  return (
    <div className="mt-6">
      <p className="text-gray-800">{itinerary.summary}</p>

      <ol className="mt-4 space-y-4">
        {itinerary.days.map((day) => (
          <li key={day.date} className="rounded-lg border border-gray-100 p-4">
            <p className="text-xs font-medium uppercase tracking-wide text-gray-400">{day.date}</p>
            <p className="font-semibold text-gray-900">{day.title}</p>
            <ul className="mt-2 space-y-1">
              {day.segments.map((segment, i) => (
                <li key={i} className="text-sm text-gray-700">
                  <span className="font-medium capitalize">{segment.part_of_day}:</span>{' '}
                  {segment.activity}
                  {segment.detail ? ` — ${segment.detail}` : ''}
                </li>
              ))}
            </ul>
          </li>
        ))}
      </ol>

      <p className="mt-4 text-xs text-gray-400">{itinerary.disclaimer}</p>
    </div>
  );
}
