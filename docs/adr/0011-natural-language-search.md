# ADR-0011: Natural Language Search — Semantic Vector Search with Local Embeddings

## Status

Accepted

## Context

Hirers currently browse listings with no server-side search — `ListingsController#index`
returns `RvListing.all`, and the Airbnb-style `SearchBar` params (`location`,
`dateFrom`, `dateTo`, `guests`, `pets`; ADR-0006/0008) are forwarded through the
frontend URL chain but never filter on the backend. Natural Language Search is the
second AI feature on the roadmap (see `docs/ai-integrations.md`), and its explicit
purpose is to be "the main vehicle for learning embeddings and semantic search."

The design was settled in a grill session. The decisions below record the tree we
walked and why each branch was chosen — several were driven by the twin goals of
*learning the mechanics* and *not spending money on AI APIs*.

## Decision

### Approach: semantic vector search, not LLM-to-filters

Two architectures fit "natural language search": (A) embed listings and the query,
find nearest neighbours in vector space; or (B) have Claude parse the query into
structured filters and run ordinary SQL. We chose **A**. The deciding reason is the
learning objective — this feature exists to teach embeddings and vector search — and
listings carry real free-text (`title`, `description`) where semantic similarity adds
signal beyond columns. B was rejected as the pragmatic-but-off-topic choice; it would
also have required first building the structured backend search that doesn't exist.
A hybrid (semantic ranking + hard filters) is a later evolution, not v1.

### Embeddings provider: local Ollama, not a hosted API

Claude has **no embeddings API**, so a separate provider is required. Options were
Voyage AI (Anthropic's recommended partner), OpenAI (`text-embedding-3-small`, the
industry default), or a local model. We chose **local Ollama running
`nomic-embed-text` (768-dim)**, added as a service in the existing Docker Compose
stack alongside `db`/`redis`/`sidekiq`.

Rationale: the provider is incidental to *understanding* embeddings — the pipeline
(embed → store vector → nearest-neighbour → rank) is identical regardless — and the
hosted options, while only fractions of a cent per use, require a billing-enabled
third-party account. Ollama is free, offline, requires no account, and lets the whole
catalog be re-embedded arbitrarily often while experimenting. The tradeoff:
`nomic-embed-text`'s 768 dimensions are **baked into the `vector` column**; switching
models later means a migration plus a full re-embed.

### The embedded document: a composed text, price excluded

Because v1 is pure-semantic with no hard filters, embedding only the free-text
`description` would leave the vector blind to structured facts (type, location,
guests, pets). Instead each listing is embedded as a **composed document** that
renders the structured fields into natural language and concatenates the free text:

> "Caravan in Byron Bay, NSW. Sleeps 4 guests. Pet-friendly. *[title]*. *[description]*."

This is the core skill the feature teaches: **retrieval quality is mostly determined
by how the document is constructed, not by the model.** `price_per_day` is
deliberately **excluded** — "cheap"/"under $200" is a fuzzy notion better served by a
future hard filter than by semantic proximity.

### Storage: a separate `listing_embeddings` table + the `neighbor` gem

The vector lives in its own table, not a column on `rv_listings`, so the embedding
keeps a distinct lifecycle (derived, async, versioned by model):

| Column | Type | Purpose |
|---|---|---|
| `rv_listing_id` | FK, unique | one embedding per listing (v1) |
| `embedding` | `vector(768)` | `nomic-embed-text` dimensionality |
| `document` | text | the exact text embedded — the #1 debugging tool for semantic search |
| `model` | string | e.g. `"nomic-embed-text"` |
| `content_hash` | string | hash of `document`; drives idempotent re-embedding |
| timestamps | | |

The `neighbor` gem provides the canonical pgvector integration
(`has_neighbors :embedding`, `.nearest_neighbors(:embedding, vec, distance: :cosine)`),
so retrieval is idiomatic ActiveRecord over the underlying distance operators.

### Refresh: async Sidekiq, idempotent via content_hash

Embeddings are a derived artifact, regenerated when listing content changes.
`after_commit on: [:create, :update]` on `RvListing` enqueues a
`GenerateListingEmbeddingJob` (the callback stays dumb — no logic in the model). The
job builds the composed document, hashes it, and **re-embeds only if the embedding is
missing or the hash changed** — so edits to fields not in the document (e.g. `price`,
`latitude`) are no-ops, and the job is safe to re-run. Existing listings are seeded by
a **rake backfill task** that enqueues the job for every listing (which doubles as the
free "embed the whole catalog" learning loop).

Synchronous embedding (in the request) was rejected: it blocks the HTTP response on an
Ollama network hop and couples saving a listing to the embedding service being up.

**Consequence — eventual consistency:** a just-created or just-edited listing does not
appear in (or update within) semantic results until its job finishes.

The Ollama HTTP call is wrapped in a standalone `Ai::Embedder` service
(`Ai::Embedder.call(text) → [768 floats]`) so the provider detail is swappable in one
place. `Ai::Embedder` is **not** a `BaseAiService` subclass — it has no prompt file and
no output schema, so that base class is a poor fit.

### Search endpoint: POST, public, top-K, ranked listings + score

`POST /api/v1/listings/search`, body `{ "query": "..." }`. POST because a free-text
query in a JSON body is cleaner than URL-encoding and isn't cacheable anyway.
**Public** (`skip_before_action :authenticate_user!`), consistent with `index`/`show` —
browsing shouldn't require login.

Flow: `Ai::Embedder.call(query)` → `nearest_neighbors(:embedding, vec, distance: :cosine)`
→ top **K = 20** listings → render the **full listing objects in ranked order**
(same JSON shape as `index`), each with its **distance/score**. Returning IDs only (as
the roadmap phrased it) was rejected — the frontend needs listing data to render cards,
and IDs force a second round-trip. The score is returned so the ranking is visible
while learning and can later drive a threshold.

**v1 simplifications:** top-K with **no relevance threshold** (kNN always returns K rows,
so even a nonsense query yields 20 "nearest" listings — the right cutoff is empirical
and will be tuned after observing real distances) and **no hard filters**
(price/guests/availability). The endpoint is structured so filters can wrap the kNN
later.

### LLM reranking: deferred

Optional Claude reranking of the top-K was deferred. It is a paid Claude call on every
search (cost, on the hot path), it is orthogonal to the embeddings learning goal, and
a pure-vector baseline is needed before its value can be judged. Filed as a follow-up.

### Frontend: standalone NL search box, no toggle yet

The roadmap's "toggle between structured and NL search" presumes a structured backend
search that doesn't exist. v1 ships a **single natural-language input** that POSTs to
`/listings/search` and renders results through the existing `ListingGrid`/`ListingCard`
in ranked order (reuse, not rebuild). The existing `SearchBar` is left untouched; the
toggle waits until structured backend search exists. An optional dev-only score badge
on each card makes the ranking tangible. Consequence: two parallel, unshared search UIs
for now.

### Observability: embeddings logged to ai_requests

Every embedding call (query-time and listing-time) writes an `ai_requests` row
(`feature` = `"nl_search"` or `"listing_embedding"`, `model` = `"nomic-embed-text"`,
`estimated_cost_usd` = `0.0`), keeping one place to watch every AI call. The
Claude-oriented columns (`prompt_version`, token/cost fields) are null/zero for these
rows — expected, not a bug. `Ai::Embedder` writes the row in an `ensure` block,
mirroring `BaseAiService`. Consequence: the backfill writes one row per listing
(bounded by catalog size, but noisy during a bulk re-embed).

## Setup requirement

The `db` service uses `postgres:16-bookworm`, which does **not** ship the `pgvector`
extension — `enable_extension "vector"` will fail until the image is switched to
`pgvector/pgvector:pg16` (or the extension is installed into the current image).

## Alternatives Considered

**LLM query-parsing to structured filters** — rejected; off the embeddings learning
goal and requires building structured backend search first. Revisit as a hybrid.

**Hosted embeddings (Voyage AI / OpenAI)** — rejected on cost/friction; pennies per use
but require a billing-enabled third-party account. Ollama is free and offline. Voyage
(Anthropic ecosystem) or OpenAI (`text-embedding-3-small`, ubiquitous) remain the
upgrade path if hosted quality is later wanted.

**Vector column on `rv_listings`** — rejected; couples embedding lifecycle to the core
table and blocks model/versioning experiments.

**Synchronous embedding in the request** — rejected; blocks the response and couples
listing saves to Ollama availability.

**Returning listing IDs only** — rejected; forces a second frontend round-trip.

**Relevance threshold / hard filters / LLM rerank in v1** — deferred; establish the
pure-vector baseline and observe real scores first.
