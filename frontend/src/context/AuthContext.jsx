import { createContext, useContext, useState, useCallback } from 'react';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem('rv_token'));
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('rv_user');
    return saved ? JSON.parse(saved) : null;
  });

  const signIn = useCallback(async (email, password) => {
    const res = await fetch('/users/sign_in', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user: { email, password } }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error ?? 'Invalid email or password');
    }
    const jwt = res.headers.get('Authorization')?.split(' ').at(-1);
    const body = await res.json();
    const userData = { name: body.data?.name ?? email, email };
    setToken(jwt);
    setUser(userData);
    localStorage.setItem('rv_token', jwt);
    localStorage.setItem('rv_user', JSON.stringify(userData));
    return userData;
  }, []);

  const signUp = useCallback(async (name, email, password) => {
    const res = await fetch('/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user: { name, email, password, password_confirmation: password } }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.errors?.[0] ?? 'Registration failed');
    }
    const jwt = res.headers.get('Authorization')?.split(' ').at(-1);
    const userData = { name, email };
    setToken(jwt);
    setUser(userData);
    localStorage.setItem('rv_token', jwt);
    localStorage.setItem('rv_user', JSON.stringify(userData));
    return userData;
  }, []);

  const signOut = useCallback(async () => {
    await fetch('/users/sign_out', {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    }).catch(() => {});
    setToken(null);
    setUser(null);
    localStorage.removeItem('rv_token');
    localStorage.removeItem('rv_user');
  }, [token]);

  return (
    <AuthContext.Provider value={{ token, user, signIn, signUp, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
