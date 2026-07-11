# Handoff: trekr_go backend rewrite
**Updated:** 2026-07-11
**For:** a fresh agent continuing the Go rewrite of the rv_marketplace Rails API.

trekr_go is a Go drop-in replacement for the rv_marketplace Rails API — same Postgres, port 3000, unchanged React frontend. Full context is in artifacts already; **read these first, don't re-derive:**

- **Plan (source of truth for PR sequence):** `~/.cursor/plans/go_backend_rewrite_06381dba.plan.md`
- **Parity checklist:** `trekr_go/api/PARITY.md` (updated each PR)
- **Auto-memory (loaded each session via MEMORY.md):** `/Users/rbowen/.claude/projects/-Users-rbowen-code-trekr-go/memory/` — read `MEMORY.md` then the linked files. Key ones: `trekr-go-rewrite-status`, `jwt-secret-source`, `code-review-every-feature-pr`, `log-followups-as-issues`.
- **Repos:** Go `/Users/rbowen/code/trekr_go` (https://github.com/rbowen006/trekr_go) · Rails `/Users/rbowen/code/rv_marketplace`

## Where things stand (2026-07-11)
- **`main` tip:** `6ab03dc` = merge of PR #10 (Active Storage read).
- **In flight:** **PR #11** (listings-read) is OPEN and green (`CLEAN`) — https://github.com/rbowen006/trekr_go/pull/11 — waiting for the user to review & merge manually. **First action next session: check if #11 is merged; if so `git checkout main && git pull`, else wait/branch off it.**
- **Open issue:** #8 — password max-length (128) parity gap, low priority — https://github.com/rbowen006/trekr_go/issues/8
- **Done this run (GitHub PRs):** #3 persistence, #4 JWT+auth-middleware, #6 email-downcase, #7 sign-out+`/api/v1` auth gate, #9 password-reset, #10 storage-read, #11 listings-read (open). This completes plan PRs #2–#6 and #8. Auth block is fully done.

## Next work (per plan)
Recommended next: **PR #7 `feat/region-resolver`** — copy `rv_marketplace/app/knowledge/regions.yml` into `trekr_go/knowledge/`, implement `Region::Resolver` equivalent as pure Go with table-driven unit tests (no HTTP). See region ADR-0013. Then PR #9 listings-write, #10 storage-write, #11 bookings, #12 chats, #13 embeddings, #14 search, #15 AI.

## How we work (follow this exactly)
1. **TDD vertical slices** — one HTTP behavior per red→green cycle; tests hit the real chi router + real test DB. Mirror the Rails request specs in `rv_marketplace/spec/requests/`.
2. **PR flow with branch protection:** branch off `main` → PR → CI (`test` check) must pass → **the user reviews and merges manually** (ruleset requires a PR + passing CI; approvals=0; **never push to `main`, never self-merge**). Use Terminal for `git push`/`gh` if needed.
3. **Run `/code-review` before handing off each feature PR** (memory: `code-review-every-feature-pr`). Fix in-scope findings on the branch; **file GitHub issues** for out-of-scope ones (memory: `log-followups-as-issues`). The diff is usually small enough to review inline without spawning agents.
4. **Verify compat against real Rails**, don't trust memory for crypto/format. Use `cd rv_marketplace && docker compose run --rm -T web bin/rails runner '...'` to generate ground-truth tokens/JSON and diff against Go. This caught several details memory would have gotten wrong.

## Dev environment
- Start deps: `cd rv_marketplace && docker compose up -d db redis ollama`. **Docker Desktop quit mid-session once (machine sleep)** — if the daemon/DB is down, `open -a Docker`, wait, then `docker compose up -d db redis`.
- trekr_go: `make test` (unit) · `make test-integration` (build tag `integration`, needs DB; uses time-seeded `UniqueID` for isolation on the shared `rv_marketplace_test` DB).
- CI runs its own Postgres and loads `trekr_go/test/schema.sql` (a `pg_dump --schema-only` of the Rails test DB) before integration tests. Refresh with `make capture-schema`. trekr_go runs **no DDL**.
- To run Go against the real dev DB for live parity checks: set `DATABASE_URL=postgres://postgres:password@localhost:5433/rv_marketplace_development`, `STORAGE_ROOT=/Users/rbowen/code/rv_marketplace/storage`, and `SECRET_KEY_BASE=<real>` (next section), then `go run ./cmd/server`. Kill stale servers with `lsof -ti tcp:3000 | xargs kill -9`.

## Compatibility facts that bit us (verify, but start here)
- **`SECRET_KEY_BASE`**: the reference (dockerized) Rails reads `secret_key_base` from **encrypted credentials**, NOT `rv_marketplace/.env`. Get the authoritative 128-char value: `docker compose run --rm -T web bin/rails runner 'print Rails.application.secret_key_base'`. Go must use this for JWT + Active Storage + reset-token parity.
- **JSON byte-parity (all endpoints):** `httpapi.writeJSON` uses `json.Marshal` (HTML-escapes `<>&`, no trailing newline) + `Content-Type: application/json; charset=utf-8`. Rails `escape_html_entities_in_json` is true. `render json:` order = struct field order; match it. Numeric/BigDecimal columns serialize as **strings** (`"150.0"`). Index endpoints use no `ORDER BY` (match `Model.all` natural order).
- **JWT (devise-jwt/warden-jwt_auth):** HS256, secret = `secret_key_base`, claims `sub`(string id), `scp`("user"), `iat`, `exp`(+3600), `jti`; revocation strategy Null. Sign-out = 204 no-op.
- **Devise reset token:** digest = `HMAC-SHA256(key, raw)` where `key = PBKDF2-HMAC-SHA1(secret_key_base, "Devise reset_password_token", 65536, 64)`. 6h validity.
- **Active Storage verifier** (`internal/storage`): secret = `PBKDF2-HMAC-SHA256(secret_key_base, "ActiveStorage", 1000, 64)` — **note: different digest/iterations than Devise**; message = `base64_std(json {"_rails":{data,[exp,]pur}}) -- hex(HMAC-SHA1(secret,payload))`. signed_id purpose `blob_id` (no expiry), disk key purpose `blob_key` (5-min). Disk layout `<root>/<k0:2>/<k2:4>/<key>`.

## Suggested skills for the next session
- **`tdd`** — for building each feature PR test-first (the established rhythm).
- **`/code-review`** (with `--fix` optional) — run on every feature PR diff before handoff, per our standing rule.
- **`review`** — optional, if the user wants a standards+spec review of a branch.
- Not `/handoff` again until the next wrap-up.

## Paste-ready resume prompt
See the message the user was given alongside this doc (a self-contained prompt that points here).
