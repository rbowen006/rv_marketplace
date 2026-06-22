# ADR-0001: Introduce Chat model; Message belongs to Chat, not RvListing

## Status

Accepted

## Context

The original `Message` model has `belongs_to :rv_listing`. This bakes in the wrong assumption: that a conversation is about a single, fixed Listing. In reality, a pre-booking conversation between a Hirer and an Owner can shift across Listings ("RV #1 isn't available, but RV #2 is"), and the Owner's identity — not the Listing — is the stable anchor of the thread.

## Decision

Introduce a `Chat` model as the container for the hirer-owner conversation. `Message` belongs to `Chat`, not to `RvListing`.

### Chat columns

| Column | Type | Notes |
|---|---|---|
| `hirer_id` | FK → User | The Hirer who initiated contact |
| `owner_id` | FK → User | The Owner being contacted |
| `rv_listing_id` | FK → RvListing, nullable | The current subject RV; updatable pre-booking |
| `booking_id` | FK → Booking, nullable | Set when a Booking results from this Chat |
| `created_at` / `updated_at` | timestamps | Standard Rails |

### Message columns

| Column | Type | Notes |
|---|---|---|
| `chat_id` | FK → Chat | Replaces `rv_listing_id` |
| `user_id` | FK → User | The sender (Hirer or Owner) |
| `content` | text | Message body |
| `read_at` | datetime, nullable | Null = unread; set when recipient reads it |
| `created_at` / `updated_at` | timestamps | Standard Rails |

### Constraints

- At most one **unbooked** Chat per hirer-owner pair (enforced at the application layer on creation).
- When a Hirer clicks "Contact Owner" on a Listing and an unbooked Chat with that Owner already exists, redirect to the existing Chat and update its `rv_listing_id` (subject) to the new Listing.
- When a Booking is made, stamp `booking_id` on the Chat. The Chat is now considered closed; new contact — even for the same Listing with the same Owner — creates a new Chat.
- No status column on Chat. State is derived: `booking_id.nil?` = open, `booking_id` present = booked.

## Alternatives considered

**Keep Message on RvListing** — rejected because a conversation is owner-scoped, not listing-scoped. Tying each message to a single Listing prevents the natural flow of a conversation across an Owner's inventory.

**One Chat per hirer-owner-listing combination** — rejected because it would create duplicate parallel threads between the same two people, which is confusing and splits conversation history.
