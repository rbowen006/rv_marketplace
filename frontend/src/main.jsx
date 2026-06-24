import React from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { UnreadProvider } from './context/UnreadContext';
import { Header } from './components/Header';
import { BrowsePage } from './pages/BrowsePage';
import { ListingDetailPage } from './pages/ListingDetailPage';
import { BookingPage } from './pages/BookingPage';
import { BookingsPage } from './pages/BookingsPage';
import { ResetPasswordPage } from './pages/ResetPasswordPage';
import { ChatPage } from './pages/ChatPage';
import { InboxPage } from './pages/InboxPage';
import { NewListingPage } from './pages/NewListingPage';
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
              <Route path="/chats" element={<InboxPage />} />
              <Route path="/chats/:id" element={<ChatPage />} />
              <Route path="/listings/new" element={<NewListingPage />} />
            </Routes>
          </div>
        </UnreadProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}

createRoot(document.getElementById('root')).render(<App />);
