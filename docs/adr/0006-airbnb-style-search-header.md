# ADR 0006 — Airbnb-style collapsible search header

**Status:** Accepted

## Context

The existing `SearchBar` is a sticky strip that only appears on `BrowsePage`, with four plain `<input>` fields (Where, Check in, Check out, Guests). It does not match the Airbnb-style design the product is aiming for, and it has no pets filter despite `pet_friendly` being a filterable listing attribute.

## Decision

Replace the existing `SearchBar` with an Airbnb-style collapsible search bar embedded in the `Header` (visible on every page).

### Behaviour

- **Collapsed state**: a single pill showing a summary ("Anywhere · Any week · Add guests"). Clicking any section opens the corresponding panel.
- **Panels** (one open at a time, tracked by `activePanel: null | 'where' | 'when' | 'who'`):
  - **Where** — styled dropdown containing a free-text input; filters listings client-side by `town`, `state`, `postcode` concatenation.
  - **When** — a custom two-month inline calendar range picker. User clicks a start date then an end date. Range is highlighted on hover. Dates are UI state only — no availability filtering against bookings.
  - **Who** — a guests stepper (+ / −) and a pets toggle. `pet_friendly` is applied as a real client-side filter; guest count filters against `max_guests`.
- Clicking outside any open panel collapses it.
- The search button encodes all filters as URL query params and navigates to `/` (BrowsePage). `BrowsePage` reads params from `useSearchParams` and applies filters — no page-level filter state needed.

### What changes

- `Header.jsx` — imports and renders the new `SearchBar`.
- `SearchBar.jsx` — completely rewritten as the collapsible Airbnb-style component.
- `BrowsePage.jsx` — removes the `SearchBar` render and the local `filters`/`searched` state; derives all filters from URL params. Adds pets filter (`l.pet_friendly === true`).

## Alternatives considered

- **Flexible / "Any week" date tab** (Airbnb's second tab) — deferred; adds significant complexity for little gain at this stage.
- **Location autocomplete suggestions** — deferred; requires listing data in the header context.
- **Availability date filtering** — out of scope (no booking data in `GET /api/v1/listings`); dates pass through to the booking flow only.
- **React context for filter state** — rejected in favour of URL params (shareable, bookmarkable, reload-safe).

## Consequences

- Pets is now a searchable dimension — the first concrete use of the `pet_friendly` column in browse.
- The old sticky `SearchBar` on `BrowsePage` is removed entirely.
- Dates entered in the search bar are available as URL params and can be pre-populated in `BookingPage` in a future iteration.
