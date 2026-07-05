import { renderHook } from '@testing-library/react';
import { useApiFetch } from './useApiFetch';

vi.mock('../context/AuthContext', () => ({
  useAuth: () => ({ signOut: mockSignOut }),
}));

let mockSignOut: ReturnType<typeof vi.fn>;

describe('useApiFetch', () => {
  beforeEach(() => {
    mockSignOut = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns a function that makes the underlying fetch call', async () => {
    globalThis.fetch = vi.fn(() =>
      Promise.resolve({ ok: true, text: () => Promise.resolve('{"id":1}') })
    ) as unknown as typeof fetch;

    const { result } = renderHook(() => useApiFetch());
    await result.current('/api/v1/chats');

    expect(globalThis.fetch).toHaveBeenCalledWith(
      '/api/v1/chats',
      expect.objectContaining({ headers: expect.objectContaining({ Accept: 'application/json' }) })
    );
  });

  it('calls signOut when response status is 401', async () => {
    globalThis.fetch = vi.fn(() =>
      Promise.resolve({ ok: false, status: 401, text: () => Promise.resolve('{"error":"Signature has expired"}') })
    ) as unknown as typeof fetch;

    const { result } = renderHook(() => useApiFetch());
    await result.current('/api/v1/chats');

    expect(mockSignOut).toHaveBeenCalledOnce();
  });

  it('does not call signOut for other error statuses', async () => {
    globalThis.fetch = vi.fn(() =>
      Promise.resolve({ ok: false, status: 422, text: () => Promise.resolve('{"errors":["invalid"]}') })
    ) as unknown as typeof fetch;

    const { result } = renderHook(() => useApiFetch());
    await result.current('/api/v1/chats');

    expect(mockSignOut).not.toHaveBeenCalled();
  });
});
