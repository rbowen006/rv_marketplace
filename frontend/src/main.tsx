import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { UnreadProvider } from './context/UnreadContext';
import { Header } from './components/Header';
import { BrowsePage } from './pages/BrowsePage';
import { ListingDetailPage } from './pages/ListingDetailPage';
import { BookingPage } from './pages/BookingPage';
import { BookingsPage } from './pages/BookingsPage';
import { BookingDetailPage } from './pages/BookingDetailPage';
import { ResetPasswordPage } from './pages/ResetPasswordPage';
import { ChatPage } from './pages/ChatPage';
import { InboxPage } from './pages/InboxPage';
import { ConciergePage } from './pages/ConciergePage';
import { NewListingPage } from './pages/NewListingPage';
import { EditListingPage } from './pages/EditListingPage';
import { MyListingsPage } from './pages/MyListingsPage';
import './index.css';

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <UnreadProvider>
          <div className="min-h-screen bg-white">
            <Header />
            <Routes>
              <Route path="/" element={<BrowsePage />} />
              <Route path="/listings/:id" element={<ListingDetailPage />} />
              <Route path="/listings/:id/book" element={<BookingPage />} />
              <Route path="/reset-password" element={<ResetPasswordPage />} />
              <Route path="/bookings" element={<BookingsPage />} />
              <Route path="/bookings/:id" element={<BookingDetailPage />} />
              <Route path="/concierge" element={<ConciergePage />} />
              <Route path="/chats" element={<InboxPage />} />
              <Route path="/chats/:id" element={<ChatPage />} />
              <Route path="/listings/new" element={<NewListingPage />} />
              <Route path="/listings/:id/edit" element={<EditListingPage />} />
              <Route path="/my-listings" element={<MyListingsPage />} />
            </Routes>
          </div>
        </UnreadProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}

createRoot(document.getElementById('root')!).render(<App />);
