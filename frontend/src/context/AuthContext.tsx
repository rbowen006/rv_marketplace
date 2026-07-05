import { createContext, useContext, useState, useCallback, ReactNode } from 'react';
import type { AuthContextValue, AuthUser } from '../types/auth';

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem('rv_token'));
  const [user, setUser] = useState<AuthUser | null>(() => {
    const saved = localStorage.getItem('rv_user');
    return saved ? JSON.parse(saved) : null;
  });

  const signIn = useCallback(async (email: string, password: string) => {
    const res = await fetch('/users/sign_in', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user: { email, password } }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error ?? 'Invalid email or password');
    }
    const jwt = res.headers.get('Authorization')?.split(' ').pop() ?? null;
    const body = await res.json();
    const userData: AuthUser = { id: body.user?.id, name: body.user?.name ?? email, email };
    setToken(jwt);
    setUser(userData);
    localStorage.setItem('rv_token', jwt);
    localStorage.setItem('rv_user', JSON.stringify(userData));
    return userData;
  }, []);

  const signUp = useCallback(async (name: string, email: string, password: string) => {
    const res = await fetch('/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user: { name, email, password, password_confirmation: password } }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.errors?.[0] ?? 'Registration failed');
    }
    const jwt = res.headers.get('Authorization')?.split(' ').pop() ?? null;
    const userData: AuthUser = { id: undefined, name, email };
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
  return useContext(AuthContext) as AuthContextValue;
}
