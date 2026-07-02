export async function apiFetch(url, options = {}) {
  const { headers, ...rest } = options;
  const res = await fetch(url, {
    ...rest,
    headers: { Accept: 'application/json', ...headers },
  });
  let data = {};
  try { data = JSON.parse(await res.text()); } catch {}
  return { res, data };
}
