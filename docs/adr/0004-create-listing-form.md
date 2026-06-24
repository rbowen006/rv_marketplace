# ADR 0004 — Create Listing Form

## Status
Accepted

## Context

Trekr needs a page for Owners to create a new Listing. The "List your RV" link in the header exists but the route and page did not.

## Decisions

### RV Type
Add `rv_type` as a Rails enum (integer column) on `rv_listings`. Supported values for now: `caravan`, `motorhome`, `camper_trailer`. Stored as an integer; displayed as a human-readable label on the form and listing cards.

### Location fields
Drop the `location` text column. Replace with three separate columns: `town` (string), `state` (string), `postcode` (string). State is collected via a dropdown limited to Australian states and territories: NSW, VIC, QLD, SA, WA, TAS, ACT, NT. All three are required.

### Cover image
No explicit DB field. The first image in the ActiveStorage `images` attachment array is the cover — it is the one shown in listing tiles on the browse page. Owners control the cover by controlling upload order. Images can be deleted individually from the form; deleting the first image promotes the next one to cover.

### Image upload UX
Multi-file upload via a file input. Each uploaded image shows a thumbnail with a delete button. No drag-and-drop reordering in this iteration.

### Edit listing
Out of scope for this iteration.

### Auth gate
The "List your RV" link remains visible to unauthenticated users. Clicking it triggers the sign-in modal. After sign-in the user is taken to `/listings/new`.

### Post-submit redirect
After successful creation, redirect to the new listing's detail page.

## Consequences

- Migration required: add `rv_type`, `town`, `state`, `postcode`; drop `location`
- `RvListing` model: add enum, update validations (replace `location` with `town`, `state`, `postcode`)
- `ListingsController`: update permitted params; add `rv_type`
- API serializer: expose `rv_type`, `town`, `state`, `postcode`; remove `location`
- Seed data: re-seed (dev data only, no prod impact)
- Browse page listing cards: update location display from `location` to `town, state`
