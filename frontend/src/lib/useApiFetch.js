import { useAuth } from '../context/AuthContext';
import { apiFetch } from './apiFetch';

export function useApiFetch() {
  const { signOut } = useAuth();
  return async (url, options) => {
    const { res, data } = await apiFetch(url, options);
    if (res.status === 401) signOut();
    return { res, data };
  };
}
