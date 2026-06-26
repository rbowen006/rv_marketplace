# ADR 0007 — JWT expiry and 401 handling

## Status
Accepted

## Context

`devise-jwt` issues HS256 tokens with a default expiry of 3600 seconds (1 hour), inherited from `warden-jwt_auth`. No expiry override is configured.

When a token expires, `warden-jwt_auth`'s Warden strategy rescues `JWT::DecodeError` and calls `fail!(e.message)`. With `navigational_formats = []`, Devise's `FailureApp` returns a 401. Prior to this change, frontend `fetch` calls called `res.json()` unconditionally; a non-`application/json` Accept header caused the failure body to arrive as plain text, throwing a JSON `SyntaxError` in the browser.

The industry-standard solution for SPAs is short-lived access tokens paired with a long-lived refresh token that silently re-authenticates without user interruption. `devise-jwt` supports this but requires a revocation strategy, a refresh endpoint, and client-side token rotation logic — a meaningful scope increase.

## Decision

Introduce two layers:

**`apiFetch` (utility)** — `frontend/src/lib/apiFetch.js`  
A thin wrapper around `fetch` that:
- Always sends `Accept: application/json`, ensuring Devise's `FailureApp` returns a parseable JSON body on auth failure
- Reads the response via `res.text()` then attempts `JSON.parse`, returning `{}` on failure — so a non-JSON body never throws at call sites
- Returns `{ res, data }` so callers own the `res.ok` check

**`useApiFetch` (hook)** — `frontend/src/lib/useApiFetch.js`  
A React hook that wraps `apiFetch` and calls `signOut()` automatically when any response is 401. Components import `useApiFetch` and use the returned function in place of `fetch`. This is the explicit, traceable path: the sign-out behaviour is visible at the hook import site, not hidden in an event bus or context side effect.

All auth-gated `/api/v1/` calls are migrated to `useApiFetch`. Public endpoints (`GET /api/v1/listings`, `GET /api/v1/listings/:id`) use `apiFetch` directly since they never trigger auth failures.

## Deferred: refresh tokens

Refresh token support is a deliberate future piece of work. When added it should:
- Configure a revocation strategy in `devise-jwt` (JTI matcher or denylist)
- Add a `POST /users/token/refresh` endpoint
- Replace the `signOut()` call in `useApiFetch` with a silent refresh attempt, falling back to sign-out only if the refresh also fails

The current sign-out-on-401 behaviour is intentional and acceptable for the app's current stage. Do not remove it in favour of silent refresh without also implementing the full refresh token flow.

## Consequences

- Users whose token expires mid-session are signed out cleanly rather than seeing a cryptic error or a broken UI state
- All API call sites use a consistent pattern (`useApiFetch` hook) with a single place to add future cross-cutting concerns (e.g. refresh, request logging)
- The 1-hour token expiry remains unchanged; users active for longer than 1 hour will be signed out. This is acceptable until refresh tokens are implemented

**Known limitation — sign-out with expired token returns 500**  
When `signOut()` is triggered by a 401, it calls `DELETE /users/sign_out` with the expired token. Rails returns 500 because the token is already invalid. `signOut()` swallows this with `.catch(() => {})` so client-side cleanup (localStorage cleared, React state reset) always completes. With the current Null revocation strategy there is nothing server-side to revoke, so this is harmless.  
However, if a denylist or JTI revocation strategy is added, a failed sign-out call will leave the token un-revoked on the server. Before adding revocation, fix this: when signing out due to a 401 the server already knows the token is invalid — skip the `DELETE /users/sign_out` API call and clear state locally only.
