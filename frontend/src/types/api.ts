export interface ApiResult<T = any> {
  res: Response;
  data: T;
}

export type ApiFetch = <T = any>(url: string, options?: RequestInit) => Promise<ApiResult<T>>;
