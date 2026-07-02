import { Link, useSearchParams } from 'react-router-dom';

export function ListingCard({ listing }) {
  const [searchParams] = useSearchParams();
  const primaryImage = listing.images?.[0]?.url;
  const qs = searchParams.toString();

  return (
    <Link to={`/listings/${listing.id}${qs ? '?' + qs : ''}`} className="block group no-underline text-inherit">
      <div className="rounded-xl overflow-hidden">
        <div className="aspect-square bg-gray-200 overflow-hidden">
          {primaryImage ? (
            <img
              src={primaryImage}
              alt={listing.title}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-gray-400 text-4xl">🚐</div>
          )}
        </div>
      </div>

      <div className="mt-2 px-1">
        <div className="flex justify-between items-start">
          <h3 className="font-semibold text-gray-900 text-sm truncate flex-1">{listing.title}</h3>
          {listing.pet_friendly && (
            <span title="Pet friendly" className="ml-2 text-base">🐾</span>
          )}
        </div>

        <p className="text-gray-500 text-sm mt-0.5">
          {[listing.town, listing.state].filter(Boolean).join(', ')}
        </p>

        <div className="flex items-center gap-1.5 mt-1">
          {listing.owner?.avatar_url ? (
            <img
              src={listing.owner.avatar_url}
              alt={listing.owner.name}
              className="w-5 h-5 rounded-full object-cover"
            />
          ) : (
            <div className="w-5 h-5 rounded-full bg-rose-100 flex items-center justify-center text-rose-500 text-xs font-bold">
              {listing.owner?.name?.[0]?.toUpperCase() ?? '?'}
            </div>
          )}
          <span className="text-gray-500 text-sm">{listing.owner?.name}</span>
          <span className="text-gray-400 text-sm">·</span>
          <span className="text-gray-500 text-sm">👥 {listing.max_guests}</span>
        </div>

        <p className="mt-1 text-sm text-gray-900">
          <span className="font-semibold">${listing.price_per_day}</span>
          <span className="text-gray-500"> / day</span>
        </p>
      </div>
    </Link>
  );
}
