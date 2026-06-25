# ADR 0005 — Inbox uses shared chat poll from UnreadContext

**Status:** Accepted

## Context

`InboxPage` fetched `GET /api/v1/chats` once on mount and held the result in local state. This meant new messages and new chats only appeared after a manual page refresh (GitHub issue #2).

`UnreadContext` already polls the same endpoint every 30 s to maintain the unread badge count in the header. Running two parallel polls to the same endpoint is wasteful and the root cause of the staleness.

## Decision

Expose the chat list from `UnreadContext` via a second hook, `useChats()`, in the same file. `InboxPage` consumes `useChats()` instead of fetching independently.

Specifically:
- Add a `ChatsContext` (internal to `UnreadContext.jsx`) that holds `{ chats, initialized }`.
- `chats` mirrors the full `{ as_hirer, as_owner }` API response.
- `initialized` is set to `true` after the first fetch attempt, whether it succeeds or fails, so `InboxPage` can render a spinner until data is ready and avoids an infinite spinner on persistent errors.
- `InboxPage` drops its own `useEffect` fetch and `loading` state; it derives both from the context.

## Alternatives considered

- **Independent poll in `InboxPage`** — two parallel fetches to the same endpoint whenever inbox is open; rejected.
- **Rename `UnreadContext` to `ChatsContext`** — unnecessary import churn across the app for no behaviour change; rejected.
- **Separate `ChatsContext` file that `UnreadContext` consumes** — cleaner separation but extra indirection for a two-consumer system; rejected.

## Consequences

- One network request feeds both the unread badge and the inbox list.
- Inbox updates at the same 30 s cadence as the badge — acceptable; real-time is out of scope.
- Error handling: a failed fetch sets `initialized = true` and leaves `chats` as empty arrays; inbox shows "Message inbox is empty" on a transient error rather than spinning forever.
