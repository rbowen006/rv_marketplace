export function SearchBar({ filters, onChange, onSearch }) {
  return (
    <div className="sticky top-[73px] z-10 bg-white border-b border-gray-200 px-6 py-3 shadow-sm">
      <div className="max-w-4xl mx-auto flex items-center rounded-full border border-gray-300 shadow-sm divide-x divide-gray-300 bg-white">
        <div className="flex-1 px-5 py-3">
          <label className="block text-xs font-semibold text-gray-700">Where</label>
          <input
            className="w-full text-sm text-gray-800 placeholder-gray-400 outline-none bg-transparent"
            placeholder="Search destinations"
            value={filters.location}
            onChange={e => onChange({ ...filters, location: e.target.value })}
          />
        </div>
        <div className="px-5 py-3">
          <label className="block text-xs font-semibold text-gray-700">Check in</label>
          <input
            type="date"
            className="text-sm text-gray-800 outline-none bg-transparent"
            value={filters.checkIn}
            onChange={e => onChange({ ...filters, checkIn: e.target.value })}
          />
        </div>
        <div className="px-5 py-3">
          <label className="block text-xs font-semibold text-gray-700">Check out</label>
          <input
            type="date"
            className="text-sm text-gray-800 outline-none bg-transparent"
            value={filters.checkOut}
            onChange={e => onChange({ ...filters, checkOut: e.target.value })}
          />
        </div>
        <div className="px-5 py-3">
          <label className="block text-xs font-semibold text-gray-700">Guests</label>
          <input
            type="number"
            min="1"
            className="w-16 text-sm text-gray-800 outline-none bg-transparent"
            placeholder="Add guests"
            value={filters.guests}
            onChange={e => onChange({ ...filters, guests: e.target.value })}
          />
        </div>
        <button
          onClick={onSearch}
          className="m-1.5 bg-rose-500 hover:bg-rose-600 text-white rounded-full px-5 py-3 text-sm font-semibold transition-colors flex items-center gap-2"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          Search
        </button>
      </div>
    </div>
  );
}
