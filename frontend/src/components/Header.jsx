import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useUnreadCount } from '../context/UnreadContext';
import { SignInModal } from './SignInModal';
import { UserMenu } from './UserMenu';
import { SearchBar } from './SearchBar';

export function Header() {
  const { user } = useAuth();
  const unreadCount = useUnreadCount();
  const navigate = useNavigate();
  const [showModal, setShowModal] = useState(false);

  return (
    <>
      <header className="bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between sticky top-0 z-20">
        <Link to="/" className="flex items-center gap-2 no-underline shrink-0">
          <img src="/trekr.png" alt="Trekr" className="h-10 w-10" />
          <span className="text-rose-500 font-bold text-xl">Trekr</span>
        </Link>
        <div className="flex-1 flex justify-center px-6">
          <SearchBar />
        </div>
        <nav className="flex items-center gap-4 shrink-0">
          <button
            onClick={() => user ? navigate('/listings/new') : setShowModal(true)}
            className="text-sm font-medium text-gray-700 hover:bg-gray-100 px-4 py-2 rounded-full transition-colors"
          >
            List your RV
          </button>
          {user && (
            <Link to="/chats" className="relative text-gray-500 hover:text-gray-800 p-1">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                  d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              {unreadCount > 0 && (
                <span className="absolute -top-0.5 -right-0.5 bg-rose-500 text-white text-[10px] font-bold rounded-full min-w-[16px] h-4 px-0.5 flex items-center justify-center leading-none">
                  {unreadCount > 9 ? '9+' : unreadCount}
                </span>
              )}
            </Link>
          )}
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
