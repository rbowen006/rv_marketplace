export interface ApiResult<T = any> {
  res: Response;
  data: T;
}

export type ApiFetch = <T = any>(url: string, options?: RequestInit) => Promise<ApiResult<T>>;

/**
 * Error fields Rails renders on a non-2xx response. Callers only read these
 * after checking `res.ok === false`, so they're modelled as optional and
 * intersected onto the success payload type at the call site
 * (e.g. `apiFetch<ListingDetail & ApiErrorBody>`).
 */
export interface ApiErrorBody {
  error?: string;
  errors?: string[];
  message?: string;
}
