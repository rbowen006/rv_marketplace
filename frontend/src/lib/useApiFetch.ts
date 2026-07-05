import { useAuth } from '../context/AuthContext';
import { apiFetch } from './apiFetch';
import type { ApiFetch } from '../types/api';

export function useApiFetch(): ApiFetch {
  const { signOut } = useAuth();
  return async (url, options) => {
    const { res, data } = await apiFetch(url, options);
    if (res.status === 401) signOut();
    return { res, data };
  };
}
