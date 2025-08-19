import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ListingList } from './components/ListingList.jsx';

function App() {
  const [token, setToken] = useState('');

  return (
    <div style={{ fontFamily: 'system-ui', margin: '2rem' }}>
      <h1>RV Marketplace Listings</h1>
      <section style={{ marginBottom: '1.5rem' }}>
        <label style={{ display: 'block', marginBottom: 4 }}>
          JWT (optional for protected endpoints):
        </label>
        <input
          style={{ width: '100%', padding: '8px' }}
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
