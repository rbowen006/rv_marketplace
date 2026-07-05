import { FormEvent, useState } from 'react';
import { useAuth } from '../context/AuthContext';

interface ForgotPasswordStepProps {
  onBack: () => void;
}

function ForgotPasswordStep({ onBack }: ForgotPasswordStepProps) {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    await fetch('/users/password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user: { email } }),
    });
    setSent(true);
    setLoading(false);
  }

  if (sent) {
    return (
      <div className="text-center py-4 space-y-4">
        <p className="text-gray-700 text-sm">
          Check your email for a reset link. It expires in 6 hours.
        </p>
        <button onClick={onBack} className="text-rose-500 text-sm font-medium hover:underline">
          Back to sign in
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <p className="text-sm text-gray-600">Enter your email and we'll send you a reset link.</p>
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
          placeholder="you@example.com"
        />
      </div>
      <button
        type="submit"
        disabled={loading}
        className="w-full bg-rose-500 hover:bg-rose-600 disabled:opacity-60 text-white font-semibold py-3 rounded-xl transition-colors"
      >
        {loading ? 'Sending…' : 'Send reset link'}
      </button>
      <button
        type="button"
        onClick={onBack}
        className="w-full text-sm text-gray-500 hover:text-gray-700"
      >
        Back to sign in
      </button>
    </form>
  );
}

interface SignInModalProps {
  onClose: () => void;
  onSuccess?: () => void;
}

export function SignInModal({ onClose, onSuccess }: SignInModalProps) {
  const { signIn, signUp } = useAuth();
  const [tab, setTab] = useState<'signin' | 'register'>('signin');
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [forgotPassword, setForgotPassword] = useState(false);

  const update = (field: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [field]: e.target.value }));

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      if (tab === 'signin') {
        await signIn(form.email, form.password);
      } else {
        await signUp(form.name, form.email, form.password);
      }
      (onSuccess ?? onClose)();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  };

  const title = forgotPassword ? 'Reset password' : tab === 'signin' ? 'Sign in' : 'Create account';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="font-semibold text-lg text-gray-900">{title}</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-2xl leading-none"
          >
            ×
          </button>
        </div>

        {forgotPassword ? (
          <ForgotPasswordStep onBack={() => setForgotPassword(false)} />
        ) : (
          <>
            <div className="flex border-b border-gray-200 mb-6">
              <button
                onClick={() => setTab('signin')}
                className={`pb-3 px-4 text-sm font-medium border-b-2 transition-colors ${tab === 'signin' ? 'border-rose-500 text-rose-500' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
              >
                Sign in
              </button>
              <button
                onClick={() => setTab('register')}
                className={`pb-3 px-4 text-sm font-medium border-b-2 transition-colors ${tab === 'register' ? 'border-rose-500 text-rose-500' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
              >
                Register
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {tab === 'register' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                  <input
                    type="text"
                    required
                    value={form.name}
                    onChange={update('name')}
                    className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
                    placeholder="Your name"
                  />
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input
                  type="email"
                  required
                  value={form.email}
                  onChange={update('email')}
                  className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
                  placeholder="you@example.com"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
                <input
                  type="password"
                  required
                  value={form.password}
                  onChange={update('password')}
                  className="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-rose-400"
                  placeholder="••••••••"
                />
                {tab === 'signin' && (
                  <button
                    type="button"
                    onClick={() => setForgotPassword(true)}
                    className="mt-1 text-xs text-rose-500 hover:underline float-right"
                  >
                    Forgot password?
                  </button>
                )}
              </div>

              {error && <p className="text-red-500 text-sm">{error}</p>}

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-rose-500 hover:bg-rose-600 disabled:opacity-60 text-white font-semibold py-3 rounded-xl transition-colors"
              >
                {loading ? 'Please wait…' : tab === 'signin' ? 'Sign in' : 'Create account'}
              </button>
            </form>
          </>
        )}
      </div>
    </div>
  );
}
