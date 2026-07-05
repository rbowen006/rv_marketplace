import type { ApiResult } from '../types/api';

export async function apiFetch<T = any>(url: string, options: RequestInit = {}): Promise<ApiResult<T>> {
  const { headers, ...rest } = options;
  const res = await fetch(url, {
    ...rest,
    headers: { Accept: 'application/json', ...headers },
  });
  let data = {} as T;
  try { data = JSON.parse(await res.text()); } catch {}
  return { res, data };
}
