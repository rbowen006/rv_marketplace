# Denormalize last-message and read-at fields onto Chat for Inbox performance

At projected scale (12M+ messages), querying the Inbox by joining to the messages table to find the latest message per Chat and count unread messages per participant is not viable. We denormalize four fields onto the `chats` table — `last_message_at`, `last_message_content`, `hirer_last_read_at`, `owner_last_read_at` — so the Inbox query is a single indexed SELECT on `chats` with no join to `messages`. These fields are maintained by an `after_create_commit` callback on Message.

## Considered options

**SQL window function / lateral join** — avoids denormalization risk but requires a full scan of `messages` grouped by chat at query time. Slower as message volume grows; harder to read and maintain.

**Redis cache** — fast reads, but adds infrastructure dependency and a second consistency surface.

## Consequences

- The `chats` table has columns that look redundant with `messages` — this ADR explains why.
- If a callback fails, the denormalized fields can drift from the messages table. A re-sync rake task should exist to correct drift.
- Concurrent message creation on the same Chat can race to update `last_message_at`; the UPDATE must be conditional (only apply if the new value is more recent).
- Per-message `read_at` on `messages` is retained alongside `hirer_last_read_at` / `owner_last_read_at` on `chats`. The former supports per-message read receipts in the Chat thread; the latter supports the fast unread indicator in the Inbox. Both are updated together when a participant fetches a Chat's messages.
