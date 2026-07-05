import { useState, useEffect, useRef } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MONTH_FULL = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const DAYS = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

type SearchPanel = 'where' | 'when' | 'who';

function monthAbbr(date: Date): string {
  return MONTHS[date.getMonth()];
}

function whoLabel(guests: number, pets: boolean): string {
  if (!guests && !pets) return 'Add guests';
  const parts: string[] = [];
  if (guests) parts.push(`${guests} guest${guests !== 1 ? 's' : ''}`);
  if (pets) parts.push('Pets');
  return parts.join(' · ');
}

function whenLabel(dateFrom: Date | null, dateTo: Date | null): string {
  if (!dateFrom) return 'Any week';
  if (!dateTo) return `${monthAbbr(dateFrom)} ${dateFrom.getDate()}`;
  return `${monthAbbr(dateFrom)} ${dateFrom.getDate()} – ${monthAbbr(dateTo)} ${dateTo.getDate()}`;
}

function isSameDay(a: Date | null, b: Date | null): boolean {
  if (!a || !b) return false;
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function inRange(date: Date, start: Date | null, end: Date | null): boolean {
  if (!start || !end) return false;
  return date > start && date < end;
}

interface CalendarMonthProps {
  year: number;
  month: number;
  dateFrom: Date | null;
  dateTo: Date | null;
  hoverDate: Date | null;
  onDayClick: (date: Date) => void;
  onDayHover: (date: Date) => void;
}

function CalendarMonth({
  year,
  month,
  dateFrom,
  dateTo,
  hoverDate,
  onDayClick,
  onDayHover,
}: CalendarMonthProps) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const rangeEnd = dateTo || hoverDate;

  const cells: (Date | null)[] = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month, d));

  return (
    <div className="w-64">
      <p className="text-center font-semibold text-gray-800 mb-3">
        {MONTH_FULL[month]} {year}
      </p>
      <div className="grid grid-cols-7 mb-1">
        {DAYS.map((d) => (
          <div key={d} className="text-center text-xs font-medium text-gray-400 pb-1">
            {d}
          </div>
        ))}
      </div>
      <div className="grid grid-cols-7">
        {cells.map((date, i) => {
          if (!date) return <div key={`empty-${i}`} />;

          const isPast = date < today;
          const isStart = isSameDay(date, dateFrom);
          const isEnd = isSameDay(date, dateTo);
          const isMid = !isPast && dateFrom && inRange(date, dateFrom, rangeEnd);

          let cls =
            'w-full aspect-square flex items-center justify-center text-sm cursor-pointer select-none ';
          if (isPast) {
            cls += 'text-gray-300 cursor-default pointer-events-none';
          } else if (isStart) {
            cls += 'bg-rose-500 text-white rounded-l-full';
          } else if (isEnd) {
            cls += 'bg-rose-500 text-white rounded-r-full';
          } else if (isMid) {
            cls += 'bg-rose-100 text-gray-800';
          } else {
            cls += 'text-gray-800 hover:bg-gray-100 rounded-full';
          }

          return (
            <div
              key={date.toISOString()}
              className={cls}
              onClick={() => !isPast && onDayClick(date)}
              onMouseEnter={() => !isPast && onDayHover(date)}
            >
              {date.getDate()}
            </div>
          );
        })}
      </div>
    </div>
  );
}

interface WhenPanelProps {
  dateFrom: Date | null;
  dateTo: Date | null;
  onDateFrom: (date: Date | null) => void;
  onDateTo: (date: Date | null) => void;
  onClose: () => void;
}

function WhenPanel({ dateFrom, dateTo, onDateFrom, onDateTo, onClose }: WhenPanelProps) {
  const today = new Date();
  const [viewYear, setViewYear] = useState(today.getFullYear());
  const [viewMonth, setViewMonth] = useState(today.getMonth());
  const [hoverDate, setHoverDate] = useState<Date | null>(null);

  const rightMonth = viewMonth === 11 ? 0 : viewMonth + 1;
  const rightYear = viewMonth === 11 ? viewYear + 1 : viewYear;

  function handleDayClick(date: Date) {
    if (!dateFrom || (dateFrom && dateTo)) {
      onDateFrom(date);
      onDateTo(null);
    } else if (date > dateFrom) {
      onDateTo(date);
      onClose();
    } else {
      onDateFrom(date);
    }
  }

  function prevMonth() {
    if (viewMonth === 0) {
      setViewMonth(11);
      setViewYear((y) => y - 1);
    } else setViewMonth((m) => m - 1);
  }

  function nextMonth() {
    if (viewMonth === 11) {
      setViewMonth(0);
      setViewYear((y) => y + 1);
    } else setViewMonth((m) => m + 1);
  }

  return (
    <div className="absolute top-full mt-2 left-1/2 -translate-x-1/2 bg-white rounded-3xl shadow-2xl border border-gray-200 p-6 z-50">
      <div className="flex items-center justify-between mb-4">
        <button
          onClick={prevMonth}
          aria-label="Previous month"
          className="p-2 rounded-full hover:bg-gray-100 text-gray-600"
        >
          ‹
        </button>
        <div className="flex gap-8">
          <CalendarMonth
            year={viewYear}
            month={viewMonth}
            dateFrom={dateFrom}
            dateTo={dateTo}
            hoverDate={!dateFrom || dateTo ? null : hoverDate}
            onDayClick={handleDayClick}
            onDayHover={setHoverDate}
          />
          <CalendarMonth
            year={rightYear}
            month={rightMonth}
            dateFrom={dateFrom}
            dateTo={dateTo}
            hoverDate={!dateFrom || dateTo ? null : hoverDate}
            onDayClick={handleDayClick}
            onDayHover={setHoverDate}
          />
        </div>
        <button
          onClick={nextMonth}
          aria-label="Next month"
          className="p-2 rounded-full hover:bg-gray-100 text-gray-600"
        >
          ›
        </button>
      </div>
    </div>
  );
}

function parseDate(str: string | null): Date | null {
  if (!str) return null;
  const d = new Date(str + 'T00:00:00');
  return isNaN(d.getTime()) ? null : d;
}

function formatLocalDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// The structured search fields decoded from the URL. Single source for both the
// initial seed and the URL-mirror below, so they can't drift.
function fieldsFromParams(searchString: string) {
  const p = new URLSearchParams(searchString);
  return {
    location: p.get('location') || '',
    dateFrom: parseDate(p.get('dateFrom')),
    dateTo: parseDate(p.get('dateTo')),
    guests: parseInt(p.get('guests') || '0', 10),
    pets: p.get('pets') === '1',
  };
}

export function SearchBar() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const searchString = searchParams.toString();
  const [activePanel, setActivePanel] = useState<SearchPanel | null>(null);
  const [location, setLocation] = useState(() => fieldsFromParams(searchString).location);
  const [dateFrom, setDateFrom] = useState<Date | null>(
    () => fieldsFromParams(searchString).dateFrom,
  );
  const [dateTo, setDateTo] = useState<Date | null>(() => fieldsFromParams(searchString).dateTo);
  const [guests, setGuests] = useState(() => fieldsFromParams(searchString).guests);
  const [pets, setPets] = useState(() => fieldsFromParams(searchString).pets);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setActivePanel(null);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Mirror the URL: the pill reflects the applied structured search. A natural-
  // language search (?q=) carries no structured params, so this clears the fields
  // — keeping only one search UI populated without any cross-component wiring.
  useEffect(() => {
    const f = fieldsFromParams(searchString);
    setLocation(f.location);
    setDateFrom(f.dateFrom);
    setDateTo(f.dateTo);
    setGuests(f.guests);
    setPets(f.pets);
  }, [searchString]);

  function handleSearch() {
    const params = new URLSearchParams();
    if (location) params.set('location', location);
    if (dateFrom) params.set('dateFrom', formatLocalDate(dateFrom));
    if (dateTo) params.set('dateTo', formatLocalDate(dateTo));
    if (guests > 0) params.set('guests', String(guests));
    if (pets) params.set('pets', '1');
    // A structured search carries no ?q=, so navigating here drops any NL search.
    navigate('/' + (params.toString() ? '?' + params.toString() : ''));
    setActivePanel(null);
  }

  const whereLabel = location || 'Anywhere';
  const isActive = (panel: SearchPanel) => activePanel === panel;

  return (
    <div ref={containerRef} className="relative w-full">
      {/* Collapsed pill */}
      <div className="flex items-center rounded-full border border-gray-300 shadow-sm bg-white divide-x divide-gray-200 text-sm w-full">
        <button
          onClick={() => setActivePanel(isActive('where') ? null : 'where')}
          className={`flex-1 min-w-0 px-6 py-3 rounded-l-full text-left hover:bg-gray-50 transition-colors ${isActive('where') ? 'bg-gray-50' : ''}`}
        >
          <span className="block text-xs font-semibold text-gray-700">Where</span>
          <span className="block text-gray-500 truncate">{whereLabel}</span>
        </button>

        <button
          onClick={() => setActivePanel(isActive('when') ? null : 'when')}
          className={`w-48 px-6 py-3 text-left hover:bg-gray-50 transition-colors ${isActive('when') ? 'bg-gray-50' : ''}`}
        >
          <span className="block text-xs font-semibold text-gray-700">When</span>
          <span className="block text-gray-500 truncate">{whenLabel(dateFrom, dateTo)}</span>
        </button>

        <button
          onClick={() => setActivePanel(isActive('who') ? null : 'who')}
          className={`w-40 px-6 py-3 text-left hover:bg-gray-50 transition-colors ${isActive('who') ? 'bg-gray-50' : ''}`}
        >
          <span className="block text-xs font-semibold text-gray-700">Who</span>
          <span className="block text-gray-500 truncate">{whoLabel(guests, pets)}</span>
        </button>

        <button
          onClick={handleSearch}
          className="m-1.5 bg-rose-500 hover:bg-rose-600 text-white rounded-full px-5 py-3 font-semibold transition-colors flex items-center gap-2"
          aria-label="Search"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
          Search
        </button>
      </div>

      {/* Where panel */}
      {isActive('where') && (
        <div className="absolute top-full mt-2 left-0 bg-white rounded-3xl shadow-2xl border border-gray-200 p-6 z-50 w-80">
          <p className="text-xs font-semibold text-gray-700 mb-2">Where to?</p>
          <input
            autoFocus
            className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
            placeholder="Search destinations"
            value={location}
            onChange={(e) => setLocation(e.target.value)}
          />
        </div>
      )}

      {/* When panel */}
      {isActive('when') && (
        <WhenPanel
          dateFrom={dateFrom}
          dateTo={dateTo}
          onDateFrom={setDateFrom}
          onDateTo={setDateTo}
          onClose={() => setActivePanel(null)}
        />
      )}

      {/* Who panel */}
      {isActive('who') && (
        <div className="absolute top-full mt-2 right-0 bg-white rounded-3xl shadow-2xl border border-gray-200 p-6 z-50 w-72">
          <div className="flex items-center justify-between py-3 border-b border-gray-100">
            <div>
              <p className="text-sm font-medium text-gray-800">Guests</p>
              <p className="text-xs text-gray-400">Max guests for the RV</p>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={() => setGuests((g) => Math.max(0, g - 1))}
                className="w-8 h-8 rounded-full border border-gray-300 text-gray-600 hover:border-gray-800 transition-colors flex items-center justify-center disabled:opacity-30"
                disabled={guests === 0}
                aria-label="Remove guest"
              >
                −
              </button>
              <span className="w-6 text-center text-sm font-medium">{guests}</span>
              <button
                onClick={() => setGuests((g) => g + 1)}
                className="w-8 h-8 rounded-full border border-gray-300 text-gray-600 hover:border-gray-800 transition-colors flex items-center justify-center"
                aria-label="Add guest"
              >
                +
              </button>
            </div>
          </div>

          <div className="flex items-center justify-between py-3">
            <div>
              <p className="text-sm font-medium text-gray-800">Pets</p>
              <p className="text-xs text-gray-400">Pet-friendly RVs only</p>
            </div>
            <button
              onClick={() => setPets((p) => !p)}
              aria-label={pets ? 'Disable pets filter' : 'Enable pets filter'}
              className={`relative w-12 h-6 rounded-full transition-colors ${pets ? 'bg-rose-500' : 'bg-gray-200'}`}
            >
              <span
                className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${pets ? 'translate-x-6' : 'translate-x-0.5'}`}
              />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
