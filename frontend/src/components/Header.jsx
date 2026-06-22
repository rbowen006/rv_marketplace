import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { SignInModal } from './SignInModal';
import { UserMenu } from './UserMenu';

export function Header() {
  const { user } = useAuth();
  const [showModal, setShowModal] = useState(false);

  return (
    <>
      <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between sticky top-0 z-20">
        <Link to="/" className="flex items-center gap-2 text-rose-500 font-bold text-xl no-underline">
          <span>🚐</span>
          <span>RV Marketplace</span>
        </Link>
        <nav className="flex items-center gap-4">
          <Link
            to="/listings/new"
            className="text-sm font-medium text-gray-700 hover:bg-gray-100 px-4 py-2 rounded-full transition-colors no-underline"
          >
            List your RV
          </Link>
          {user ? (
            <UserMenu />
          ) : (
            <button
              onClick={() => setShowModal(true)}
              className="text-sm font-medium text-gray-700 border border-gray-300 px-4 py-2 rounded-full hover:shadow-md transition-shadow"
            >
              Sign in
            </button>
          )}
        </nav>
      </header>

      {showModal && <SignInModal onClose={() => setShowModal(false)} />}
    </>
  );
}
