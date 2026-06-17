import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ListingList } from './components/ListingList.jsx';
import './index.css';

function App() {
  const [token, setToken] = useState('');

  return (
    <div className="font-sans m-8 max-w-3xl">
      <h1 className="text-2xl font-bold mb-6">RV Marketplace Listings</h1>
      <section className="mb-6">
        <label className="block mb-1 text-sm font-medium text-gray-700">
          JWT (optional for protected endpoints):
        </label>
        <input
          className="w-full p-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Paste JWT token here"
          value={token}
          onChange={e => setToken(e.target.value)}
        />
      </section>
      <ListingList token={token} />
    </div>
  );
}

createRoot(document.getElementById('root')).render(<App />);
