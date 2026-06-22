import { Link } from 'react-router-dom';

export function Header() {
  return (
    <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
      <Link to="/" className="flex items-center gap-2 text-rose-500 font-bold text-xl no-underline">
        <span>🚐</span>
        <span>RV Marketplace</span>
      </Link>
      <nav className="flex items-center gap-4">
        <Link
          to="/listings/new"
          className="text-sm font-medium text-gray-700 hover:bg-gray-100 px-4 py-2 rounded-full transition-colors"
        >
          List your RV
        </Link>
        <button className="text-sm font-medium text-gray-700 border border-gray-300 px-4 py-2 rounded-full hover:shadow-md transition-shadow">
          Sign in
        </button>
      </nav>
    </header>
  );
}
