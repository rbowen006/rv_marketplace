import { FormEvent, useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useApiFetch } from '../lib/useApiFetch';
import { AiSparkle } from './AiSparkle';
import { ListingGrid } from './ListingGrid';
import type { ListingSummary } from '../types/listing';

// The active natural-language query lives in the URL (?q=). Both this box and the
// structured header SearchBar derive from the URL, so only one is ever populated
// and back/forward/logo navigation all behave — no cross-component coordination.
export function NlSearchBox() {
  const apiFetch = useApiFetch();
  const [searchParams, setSearchParams] = useSearchParams();
  const rawQuery = searchParams.get('q') || '';
  const query = rawQuery.trim(); // a whitespace-only ?q= is not a real search
  const [input, setInput] = useState(rawQuery);
  const [results, setResults] = useState<ListingSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Bumped to re-run the fetch when the query is resubmitted unchanged (retry).
  const [reload, setReload] = useState(0);

  // Keep the text field in step with the active query when it changes from
  // outside (back/forward navigation, Clear).
  useEffect(() => {
    setInput(rawQuery);
  }, [rawQuery]);

  // Fetch whenever the active query changes; the cleanup flag discards a response
  // whose query has since been superseded or cleared.
  useEffect(() => {
    if (!query) {
      setResults([]);
      setError(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);
    apiFetch<ListingSummary[]>('/api/v1/listings/search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query }),
    })
      .then(({ res, data }) => {
        if (cancelled) return;
        if (!res.ok || !Array.isArray(data)) throw new Error('search failed');
        setResults(data);
      })
      .catch(() => {
        if (cancelled) return;
        setError('search failed');
        setResults([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [query, reload]); // eslint-disable-line react-hooks/exhaustive-deps

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const trimmed = input.trim();
    if (!trimmed) return;
    if (trimmed === query) {
      setReload((r) => r + 1); // same query — retry (e.g. after an error)
    } else {
      setSearchParams({ q: trimmed });
    }
  }

  function handleClear() {
    setSearchParams({});
  }

  return (
    <div className="px-6 pt-8">
      <div className="max-w-2xl mx-auto text-center">
        <h2 className="text-xl font-semibold text-gray-900">Search by description</h2>
        <p className="text-gray-500 text-sm mt-1">
          Describe the trip you have in mind and we'll surface the best-matching RVs.
        </p>
        <form onSubmit={handleSubmit} className="mt-4 flex items-center gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Describe your ideal RV trip…"
            className="flex-1 border border-gray-300 rounded-full px-5 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
          />
          <button
            type="submit"
            disabled={loading}
            className="inline-flex items-center gap-2 bg-rose-500 hover:bg-rose-600 text-white rounded-full px-6 py-3 text-sm font-semibold transition-colors disabled:opacity-50"
          >
            <AiSparkle />
            {loading ? 'Searching…' : 'Search'}
          </button>
          {query && (
            <button
              type="button"
              onClick={handleClear}
              className="text-gray-500 hover:text-gray-800 text-sm font-medium px-3 py-3 transition-colors"
            >
              Clear
            </button>
          )}
        </form>
        {error && (
          <p className="text-red-500 text-sm mt-3">
            Something went wrong with your search — please try again.
          </p>
        )}
      </div>

      {query && !error && <ListingGrid listings={results} loading={loading} />}
    </div>
  );
}
