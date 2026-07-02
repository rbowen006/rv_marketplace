---
name: run
description: How to launch and drive Trekr (rv_marketplace) locally — backend (Rails API via Docker Compose) and frontend (Vite dev server) — for /verify sessions.
---

# Running Trekr locally

Two independent processes: the Rails API backend (Docker Compose) and the Vite/React frontend (plain `npm`, no Docker). The frontend needs the backend running — its dev server proxies `/api`, `/users`, `/rails` to `http://localhost:3000`.

## Backend (Rails API, Docker Compose)

```sh
docker compose up -d
```

Starts `web` (Rails, :3000), `db` (Postgres), `redis`, `sidekiq`.

**Prerequisite:** `ANTHROPIC_API_KEY` must be in a `.env` file at the repo root — **not** `.env.local`. `docker-compose.yml` only auto-loads `.env` for its `ANTHROPIC_API_KEY:` passthrough syntax; a differently-named file is silently ignored (no error, key just isn't set).

**Common startup failures and fixes:**

| Symptom | Cause | Fix |
|---|---|---|
| `sidekiq` crash-loops with `Bundler::GemNotFound` | `Gemfile`/`Gemfile.lock` changed since the image was last built — `sidekiq` is a separate image from `web` and doesn't share the bundle | `docker compose build sidekiq && docker compose up -d sidekiq` |
| `web` fails with "A server is already running (pid: 1, file: /app/tmp/pids/server.pid)" | Container was killed uncleanly, stale PID file survived on the mounted volume | `docker compose run --rm web rm -f tmp/pids/server.pid` then `docker compose up -d` |

Rails code is volume-mounted — edits are picked up live (Zeitwerk autoloading in dev/test) without restarting the container.

### Auth (get a JWT)

```sh
curl -s -i -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"owner1782195679@test.com","password":"password123"}}'
```

Token is in the `Authorization` response header (`Bearer <jwt>`). **Expires after 1 hour** — always fetch fresh rather than reusing across sessions.

Seeded test users (dev DB):

| Role | Email | Password |
|---|---|---|
| Owner | `owner1782195679@test.com` | `password123` |
| Hirer | `hirer1782195679@test.com` | `password123` |

### Backend tests

```sh
docker compose exec -e RAILS_ENV=test web bundle exec rspec
```

Always pass `-e RAILS_ENV=test` explicitly.

## Frontend (Vite/React)

```sh
npm run dev --prefix frontend
```

Starts Vite on `:5173`. No Docker — plain Node process. Requires the backend containers already running (see above) for any API call to work.

Poll for readiness rather than a fixed sleep:

```sh
for i in $(seq 1 30); do curl -sf http://localhost:5173 >/dev/null && echo UP && break; sleep 1; done
```

### Frontend tests

```sh
npm test --prefix frontend
```

(Vitest.)

### Live browser verification (not just unit tests)

Playwright is available via `npx playwright` — Chromium is cached locally (`~/Library/Caches/ms-playwright/`), so no download needed on repeat runs. There is no `@playwright/test` devDependency in `frontend/package.json`; install it ad hoc in a scratch dir (`npm install playwright --no-save`) if a fresh script needs `import { chromium } from 'playwright'`.

**Auth for browser sessions:** don't drive the login UI for feature verification unrelated to auth itself — seed `localStorage` the same way `AuthContext.signIn()` does (`frontend/src/context/AuthContext.jsx`):

```js
await page.goto('http://localhost:5173/');
await page.evaluate((jwt) => {
  localStorage.setItem('rv_token', jwt);
  localStorage.setItem('rv_user', JSON.stringify({ id: 11, name: 'Miss Eleven', email: 'owner1782195679@test.com' }));
}, token);
await page.goto('http://localhost:5173/listings/new'); // or wherever
```

Get `token` via the curl sign-in call above first.

## Shutting down

```sh
docker compose down          # backend
kill $(cat /tmp/vite-dev.pid) # frontend, if launched with `nohup ... & echo $! > /tmp/vite-dev.pid`
```
