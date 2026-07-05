import { ListingCard } from './ListingCard';
import type { ListingSummary } from '../types/listing';

interface ListingGridProps {
  listings: ListingSummary[];
  loading: boolean;
  error?: string | null;
}

export function ListingGrid({ listings, loading, error }: ListingGridProps) {
  if (loading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 p-6">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="animate-pulse">
            <div className="aspect-square bg-gray-200 rounded-xl" />
            <div className="mt-2 space-y-2 px-1">
              <div className="h-4 bg-gray-200 rounded w-3/4" />
              <div className="h-3 bg-gray-200 rounded w-1/2" />
              <div className="h-3 bg-gray-200 rounded w-1/3" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (error) {
    return <p className="text-center text-red-500 py-12">Failed to load listings: {error}</p>;
  }

  if (listings.length === 0) {
    return (
      <div className="text-center py-20">
        <p className="text-5xl mb-4">🚐</p>
        <p className="text-gray-500 text-lg">No RVs found. Try adjusting your search.</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 p-6">
      {listings.map((listing) => (
        <ListingCard key={listing.id} listing={listing} />
      ))}
    </div>
  );
}
