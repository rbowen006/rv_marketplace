# ADR 0008 — Search param forwarding and booking terminology

## Status
Accepted

## Context

After implementing the Airbnb-style search header (ADR 0006), search params (`checkIn`, `checkOut`, `location`, `guests`, `pets`) were set in the URL by `SearchBar` but were dropped when navigating to a listing detail page (`/listings/:id`). This meant dates entered in search were lost by the time the user reached `BookingPage`.

Additionally, the terms `checkIn`/`checkOut` carry hotel connotations that are wrong for an RV hire marketplace. A Hirer picks up a caravan — they don't check in. Similarly, the "Reserve" button on `ListingDetailPage` and the "Check-in"/"Check-out" labels on `BookingPage` used hotel language.

A grill session identified all affected touch-points and locked the design before any code was written.

## Decisions

### 1. Terminology

| Old | New |
|-----|-----|
| URL param `checkIn` | `dateFrom` |
| URL param `checkOut` | `dateTo` |
| `SearchBar` internal state `checkIn`/`checkOut` | `dateFrom`/`dateTo` |
| `WhenPanel` props `checkIn`/`checkOut` | `dateFrom`/`dateTo` |
| `CalendarMonth` props `checkIn`/`checkOut` | `dateFrom`/`dateTo` |
| `whenLabel` params `checkIn`/`checkOut` | `dateFrom`/`dateTo` |
| `BookingPage` labels "Check-in" / "Check-out" | "Date From" / "Date To" |
| `ListingDetailPage` button "Reserve" | "Book" |

The Rails API's `start_date`/`end_date` field names are unchanged — these are internal persistence names, not user-facing terms.

### 2. Search params forward through the full navigation chain

All search params carry forward at every navigation step:

```
/?location=...&dateFrom=...&dateTo=...&guests=...&pets=1
  → /listings/:id?location=...&dateFrom=...&dateTo=...&guests=...&pets=1   (ListingCard link)
    → /listings/:id/book?location=...&dateFrom=...&dateTo=...&guests=...&pets=1  (Book button)
      ← /listings/:id?...   (BookingPage back link)
        ← /?...             (ListingDetailPage back link)
```

`ListingCard` reads `useSearchParams()` directly and appends the full query string to its link. This avoids prop-drilling through `ListingGrid`.

### 3. SearchBar seeds from URL on mount

`SearchBar` calls `useSearchParams()` and seeds `location`, `dateFrom`, `dateTo`, `guests`, and `pets` from the current URL when it mounts. This means navigating back to `/` with params in the URL restores the search state visibly in the pill.

### 4. BookingPage pre-populates date inputs

`BookingPage` reads `dateFrom` and `dateTo` from `useSearchParams()` and uses them as initial values for the date inputs. If `dateFrom` is in the past, both params are silently discarded and the inputs start empty — pre-populating stale/past dates would confuse the Hirer.

## Consequences

- Every link to a listing and every "Book" / back-link navigation must include the current search query string. Forgetting to forward params on a future navigation point will silently break the chain.
- `SearchBar` now depends on a router context (`useSearchParams`). All `SearchBar` tests must be wrapped in `MemoryRouter`.
- The `checkIn`/`checkOut` URL param names are gone. Any bookmarks or external links using the old names will silently drop the date filter — acceptable given this is a development-stage app with no public links.
