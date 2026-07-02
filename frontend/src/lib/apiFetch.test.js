import { apiFetch } from './apiFetch';

describe('apiFetch', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('sends Accept: application/json on every request', async () => {
    global.fetch = vi.fn(() =>
      Promise.resolve({ ok: true, text: () => Promise.resolve('{}') })
    );

    await apiFetch('/api/v1/chats');

    expect(global.fetch).toHaveBeenCalledWith(
      '/api/v1/chats',
      expect.objectContaining({
        headers: expect.objectContaining({ Accept: 'application/json' }),
      })
    );
  });

  it('returns the parsed JSON body as data', async () => {
    global.fetch = vi.fn(() =>
      Promise.resolve({ ok: true, text: () => Promise.resolve('{"id":7}') })
    );

    const { data } = await apiFetch('/api/v1/chats');

    expect(data).toEqual({ id: 7 });
  });

  it('returns empty object as data when body is not valid JSON', async () => {
    global.fetch = vi.fn(() =>
      Promise.resolve({ ok: false, text: () => Promise.resolve('Signature has expired') })
    );

    const { res, data } = await apiFetch('/api/v1/chats');

    expect(res.ok).toBe(false);
    expect(data).toEqual({});
  });

  it('merges caller-provided headers without overwriting Accept', async () => {
    global.fetch = vi.fn(() =>
      Promise.resolve({ ok: true, text: () => Promise.resolve('{}') })
    );

    await apiFetch('/api/v1/chats', {
      headers: { Authorization: 'Bearer tok', 'Content-Type': 'application/json' },
    });

    expect(global.fetch).toHaveBeenCalledWith(
      '/api/v1/chats',
      expect.objectContaining({
        headers: expect.objectContaining({
          Accept: 'application/json',
          Authorization: 'Bearer tok',
          'Content-Type': 'application/json',
        }),
      })
    );
  });
});
