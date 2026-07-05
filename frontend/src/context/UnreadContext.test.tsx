import { renderHook, act } from '@testing-library/react';
import { ReactNode } from 'react';
import { UnreadProvider, useChats } from './UnreadContext';

vi.mock('./AuthContext', () => ({
  useAuth: () => ({ token: 'test-token', user: { id: 1 } }),
}));

vi.mock('../lib/useApiFetch', () => ({
  useApiFetch: () => mockApiFetch,
}));

let mockApiFetch: ReturnType<typeof vi.fn>;

const emptyChats = { as_hirer: [], as_owner: [] };

function wrapper({ children }: { children: ReactNode }) {
  return <UnreadProvider>{children}</UnreadProvider>;
}

describe('UnreadContext', () => {
  beforeEach(() => {
    mockApiFetch = vi.fn(() => Promise.resolve({ ok: true, data: emptyChats }));
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('useChats exposes a refreshChats function', () => {
    const { result } = renderHook(() => useChats(), { wrapper });
    expect(typeof result.current.refreshChats).toBe('function');
  });

  it('calling refreshChats triggers an immediate fetch', async () => {
    const { result } = renderHook(() => useChats(), { wrapper });

    const callsBefore = mockApiFetch.mock.calls.length;
    await act(async () => {
      await result.current.refreshChats();
    });

    expect(mockApiFetch.mock.calls.length).toBeGreaterThan(callsBefore);
    expect(mockApiFetch).toHaveBeenCalledWith('/api/v1/chats', expect.anything());
  });
});
