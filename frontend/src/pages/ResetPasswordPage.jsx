import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

export function ResetPasswordPage() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token');
  const navigate = useNavigate();

  const [form, setForm] = useState({ password: '', password_confirmation: '' });
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const update = field => e => setForm(f => ({ ...f, [field]: e.target.value }));

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/users/password', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user: { reset_password_token: token, ...form } }),
      });
      const body = await res.json();
      if (!res.ok) {
        setError(body.errors?.join(', ') ?? 'Something went wrong.');
        return;
      }
      navigate('/?reset=1');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="max-w-md mx-auto py-16 px-4">
      <h1 className="text-2xl font-bold text-gray-900 mb-2">Choose a new password</h1>
      <p className="text-sm text-gray-500 mb-8">Enter your new password below.</p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">New password</label>
          <input
            type="password"
            required
            value={form.password}
            onChange={update('password')}
            className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
            placeholder="••••••••"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Confirm new password</label>
          <input
            type="password"
            required
            value={form.password_confirmation}
            onChange={update('password_confirmation')}
            className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
            placeholder="••••••••"
          />
        </div>

        {error && (
          <div className="text-sm text-red-600 space-y-1">
            <p>{error}</p>
            {error.toLowerCase().includes('expired') || error.toLowerCase().includes('invalid') ? (
              <a href="/" className="text-rose-500 hover:underline">Request a new reset link</a>
            ) : null}
          </div>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-rose-500 hover:bg-rose-600 disabled:opacity-60 text-white font-semibold py-3 rounded-xl transition-colors"
        >
          {loading ? 'Saving…' : 'Set new password'}
        </button>
      </form>
    </div>
  );
}
