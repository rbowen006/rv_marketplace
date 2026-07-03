# ADR-0010: Rate-limiting the AI Description Generator

## Status

Accepted

## Context

`POST /api/v1/listings/generate_description` (`DescriptionGeneratorController#create`)
is available to any authenticated user with no rate limiting. Every call hits the
paid Claude API via `Ai::DescriptionGenerator`. A signed-in user can loop the
endpoint and run up unbounded spend / exhaust quota. This is a cost/abuse vector,
not a data leak — the endpoint requires auth and returns no other user's data
(see #12).

The design was settled in a grill session. The decisions below record the tree we
walked and, more importantly, *why* each branch was chosen, because several cut
against the "obvious" answer.

## Decision

### Key: per-user only

The limit is keyed on `current_user.id`. The endpoint is behind
`authenticate_user!`, so all traffic is already identified — there is no anonymous
traffic for a per-IP rule to catch. Per-IP was rejected here: it false-positives on
shared NAT (offices, campuses, CGNAT) and is trivially rotated. The one thing per-IP
would blunt — one person registering many accounts to multiply their budget (Sybil)
— is a *registration* problem with a different enforcement point, tracked separately
as #15, not bolted onto this endpoint.

### Dimension: request count, not cost/tokens

The limit counts requests, not accumulated dollars/tokens. The abuse in #12 is
volume; a request cap addresses it directly and is predictable for the user ("N per
hour"). A cost budget is more precise (generations vary in output length) and would
be cheap to compute from `ai_requests.estimated_cost_usd`, but it produces opaque
error messages ("you've spent $0.04 of $0.10") and the per-generation variance is
small. Revisit cost-based limiting only if pricier AI features are later placed
under the same limiter.

### Limit: 10 generations per hour, per user, fixed window

Deliberately tight. A genuine listing-crafting session is ~3–10 regenerations; 10/hr
can occasionally bite a fussy user editing one listing's copy, which is an accepted
tradeoff for a hard spend guard that is easy to loosen later. It caps a determined
abuser at 10/hr instead of thousands/day.

A **fixed count over a one-hour window** was chosen over a **spacing limit**
(e.g. "1 call / 5s"). Spacing throttles burst rate but does *not* bound volume — a
script that sleeps 5s between calls still reaches ~17k/day, exactly the unbounded
spend we are preventing. It also never bites real users, since the Claude call
itself already takes a few seconds and humans read between clicks.

### Mechanism: Rails 8 built-in `ActionController::RateLimiting`

Enforced with the framework primitive, not `rack-attack` and not a hand-rolled
counter:

```ruby
rate_limit to: 10, within: 1.hour,
  by:   -> { current_user.id },
  with: -> { render_rate_limited }
```

- `rack-attack` was rejected: it runs as middleware *before* the Rails stack, so it
  has no `current_user`; keying per-user would mean decoding the JWT in the throttle
  discriminator (duplicating auth) plus a global middleware rule for one endpoint.
  Its value is blanket/anonymous edge protection, which is not this problem.
- A hand-rolled Redis / `Rails.cache` counter was rejected: it is more code and less
  idiomatic for the sake of preserving a finer counting rule (below) that the
  frontend already makes rare. Reaching for it is the "operational cleverness over
  canonical patterns" this project explicitly avoids.

The built-in is backed by `Rails.cache`, which is **Solid Cache** in production
(already in the stack) and `:memory_store` in development — **no new dependency and
no direct Redis**, even though Redis is present for Sidekiq/ActionCable.

### Counting: every admitted request counts, including input errors

`rate_limit` is a `before_action` that increments on *admission*, before the
controller action runs. It therefore counts every admitted request — including an
`Ai::InputError` (missing required fields) that is rejected *before* Claude is ever
called.

We considered *not* charging a slot for pure input-validation failures (a call that
incurs no Claude cost). Preserving that would require abandoning the built-in for a
manual increment placed after validation. We chose instead to **accept the built-in's
increment-on-admission semantics**: the frontend already enforces the required fields
(`GENERATE_REQUIRED_FIELDS` in `ListingForm.jsx`), so a malformed request that burns a
slot is a rare edge, and taking the framework primitive is worth that cost.

### Response: 429 + JSend `fail` (top-level `message`) + `Retry-After`

On rejection, a custom `with:` handler renders:

```
HTTP/1.1 429 Too Many Requests
Retry-After: 3600
{ "status": "fail", "message": "Rate limit exceeded. Please try again later." }
```

- **JSend `fail`, not `error`.** ADR-0009 maps client-caused 4xx to `fail`; a
  throttle is the client's own doing, consistent with how `InputError` (400) renders.
- **`message` at the top level, not nested under `data`.** This is loose JSend, but
  it matches this controller's existing rescues *and* what the frontend reads
  (`data.message` in `ListingForm.jsx`). Consistency with the established house style
  beats spec purity; nesting under `data` would silently break the frontend's error
  display.
- **`Retry-After` is coarse** — the full window (3600s) rather than the key's exact
  remaining TTL, because the built-in primitive does not expose remaining TTL to the
  handler. Accepted as a minor imprecision (slightly conservative for the client).

### Frontend: no change in this work

`ListingForm.jsx` already renders `data.message` from any non-`ok` response into the
`generateError` slot under the "Generate description" button. Because the 429 body
carries a top-level `message`, the rate-limit message surfaces automatically with no
frontend change. A live `Retry-After` countdown and a disabled/cooldown button are a
nice-to-have, deferred to a separate follow-up issue.

### Testing note

The test environment uses `config.cache_store = :null_store`, where `increment` is a
no-op — the limiter would never trip. The rate-limit spec must inject a real store
(pass `store:` to `rate_limit`, or swap the cache store for that test) so the throttle
is actually exercised.

## Alternatives Considered

**`rack-attack`** — rejected; middleware runs before auth (no `current_user`), forcing
JWT decoding in the throttle plus a global rule for one endpoint.

**Hand-rolled `Rails.cache` / Redis counter** — rejected; more code and less idiomatic
than the Rails 8 primitive, only to preserve a rare "input errors don't count" rule the
frontend already prevents.

**Per-IP limiting on this endpoint** — rejected; false-positives on shared NAT, easily
rotated, and the account-multiplication threat it targets belongs at registration (#15).

**Cost/token budget instead of request count** — rejected for now; opaque error
messages and small per-generation variance. Reconsider if pricier AI features share the
limiter.

**Spacing limit (e.g. 1 call / 5s)** — rejected; bounds burst rate, not total volume, so
it fails to cap spend while rarely bothering real users.
