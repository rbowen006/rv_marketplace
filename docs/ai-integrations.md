# AI Integrations — Design Brief

## Goal

Build a production-style AI-enabled Rails application that demonstrates modern AI engineering practices. The objective is not simply to call an LLM — it is to gain practical experience with:

- LLM integrations & prompt engineering
- Semantic search (embeddings + vector search)
- Retrieval-Augmented Generation (RAG)
- Agentic workflows & tool use
- Model Context Protocol (MCP)
- AI observability & cost tracking
- Evaluation frameworks
- Guardrails & safety

---

## Cross-Cutting Requirements

These apply to **every** AI feature, not just one.

### 1. Prompt Versioning

- Prompts live as files under `app/prompts/` — never hardcoded in service objects.
- File naming: `app/prompts/<feature>/<version>.txt` (e.g. `app/prompts/description_generator/v1.txt`).
- Service objects load prompts by name + version; switching versions is a one-line change.
- Enables prompt iteration without code changes.

### 2. AI Observability

Every AI call records a row in an `ai_requests` table (or equivalent log store):

| Column | Type | Notes |
|---|---|---|
| `feature` | string | e.g. `"description_generator"` |
| `model` | string | e.g. `"claude-sonnet-4-6"` |
| `prompt_version` | string | e.g. `"v1"` |
| `input_tokens` | integer | |
| `output_tokens` | integer | |
| `latency_ms` | integer | |
| `estimated_cost_usd` | decimal | calculated from token counts + model pricing |
| `success` | boolean | |
| `error_message` | string | nullable |
| `created_at` | datetime | |

Enables cost tracking, reliability monitoring, and evaluation over time.

### 3. Structured Outputs

- Use JSON responses with a defined schema wherever possible, rather than free-form text.
- Validate the response against the schema before using it in the application.
- Return a graceful error if the response fails validation.

### 4. Evaluation Framework

An eval suite that allows prompts and models to be regression-tested:

- Fixtures: a set of representative inputs with expected outputs (or quality criteria).
- Runner: executes the suite against a prompt version + model, records results to `ai_requests`.
- Metrics: correctness, latency, token usage, estimated cost.
- Goal: prove a new prompt version is better (or no worse) before deploying it.

### 5. Human-in-the-Loop

AI assists — it never makes irreversible decisions. Every AI-generated result follows:

**Generate → Review → Edit → Accept**

AI output is always placed into an editable field. Nothing is auto-saved or auto-committed.

### 6. Background Jobs (Sidekiq)

Long-running AI operations (trip planner, concierge, RAG pipeline) run asynchronously via Sidekiq. The frontend polls for status or receives a push update. Short operations (description generator, chat reply) may run inline if latency is acceptable.

### 7. Guardrails

Applied across all AI features:

- Input validation before sending to Claude (length limits, content sanity checks).
- Output validation (schema check for structured outputs, length/content check for free text).
- Prompt injection protection (sanitise user-provided text before interpolating into prompts).
- Permission checks (auth required; owner-only vs hirer-only enforced at controller level).
- Never allow AI to take booking or payment actions directly — tool calls are read-only or require explicit user confirmation.

---

## AI Concepts Map

| Concept | Feature(s) that demonstrate it |
|---|---|
| Prompt engineering | All features |
| Context window management | Concierge, Trip Planner |
| Structured outputs / function calling | All features |
| Tool use | Concierge, MCP Server |
| MCP (Model Context Protocol) | MCP Server |
| Embeddings | Natural Language Search, Concierge |
| Retrieval-Augmented Generation (RAG) | Trip Planner, Concierge |
| Agent loops | Concierge |
| Evaluation | Evaluation Framework (cross-cutting) |
| Guardrails | Cross-cutting |
| Observability | ai_requests table (cross-cutting) |

---

## Features

### 1. Listing Description Generator
**Status:** Shipped (ADR-0009, ADR-0010) | **Teaches:** Prompt engineering, structured outputs, human-in-the-loop

Owners struggle to write compelling listing descriptions. When creating (or editing) a listing, a "Generate description" button passes the structured fields (RV type, location, guests, pet-friendly, price) to Claude and returns a draft the owner reviews and edits before saving.

- **Backend:** `POST /api/v1/listings/generate_description` (auth required)
- **Service:** `app/services/ai/description_generator.rb`
- **Prompt:** `app/prompts/description_generator/v1.txt`
- **Output:** Structured JSON `{ description: "..." }` — validated before returning
- **Frontend:** "Generate description" button below textarea in `NewListingPage`; disabled until RV type, town, state, max guests are filled; replaces field content (confirm if non-empty); spinner during call
- **Why first:** Zero new data needed. Establishes the shared pattern (service object, prompt file, observability logging, structured output) every other feature reuses.

---

### 2. Natural Language Search
**Status:** Shipped (PR #24, ADR-0011) | **Teaches:** Embeddings, vector search, semantic search

Instead of keyword-only filtering, allow hirers to type free-form queries. Pipeline:

**Query → Embedding → Vector Search → Relevant Listings → Optional LLM Ranking**

- Store listing embeddings in a `listing_embeddings` table (pgvector extension).
- On search: embed the query, find nearest-neighbour listings, optionally re-rank with Claude.
- **Backend:** `POST /api/v1/listings/search` — accepts `{ query: "..." }`, returns ranked listing IDs.
- **Frontend:** Toggle between structured (existing SearchBar panels) and natural language mode.
- **Why:** Biggest UX leap. Also the main vehicle for learning embeddings and semantic search.

---

### 3. Smart Chat Replies for Owners
**Status:** Shipped (PR #38, ADR-0012) | **Teaches:** Prompt engineering, context window management

Owners receive the same questions repeatedly. A "Suggest reply" button in `ChatPage` reads the last few messages plus the listing description and drafts a reply the owner can send or edit.

- **Backend:** `POST /api/v1/chats/:id/suggest_reply` (owner only)
- **Service:** `app/services/ai/chat_reply_suggester.rb`
- **Output:** Structured JSON `{ reply: "..." }`
- **Frontend:** "Suggest reply" button below message input in `ChatPage` (owner-only); inserts into compose field for editing before sending.

---

### 4. Trip Planning Assistant
**Status:** Shipped (PR #39, ADR-0013) | **Teaches:** RAG, background jobs, context management

After a booking is confirmed, a "Plan my trip" panel lets the hirer enter their interests. Claude generates a day-by-day itinerary, grounded by retrieved context (local attractions, campground FAQs, RV manuals, area policies).

**Pipeline:** Interests + Location + Dates → Retrieve relevant docs → RAG prompt → Itinerary

- **Backend:** `POST /api/v1/bookings/:id/trip_plan` — enqueues a Sidekiq job; frontend polls for result.
- **RAG corpus:** Markdown files in `app/knowledge/` (campgrounds, attractions by region), embedded at deploy time.
- **Service:** `app/services/ai/trip_planner.rb`
- **Frontend:** Collapsible panel on booking detail page; interests input → loading state → rendered itinerary.

---

### 5. Pricing Suggestions for Owners
**Status:** Not started | **Teaches:** Prompt engineering, structured outputs

When creating/editing a listing, show a recommended price range from comparable listings (same state, RV type, similar capacity). Claude narrates the reasoning.

- **Backend:** Query comparables, pass aggregate stats to Claude for a narrative.
- **Service:** `app/services/ai/pricing_suggester.rb`
- **Output:** Structured JSON `{ min: 150, max: 220, narrative: "..." }`
- **Frontend:** Hint card near `price_per_day` field in `NewListingPage`.

---

### 6. AI Concierge (new)
**Status:** Not started | **Teaches:** Agent loops, tool use, embeddings, context management, RAG

A conversational assistant that guides hirers toward a booking:

1. Understands travel requirements via multi-turn conversation.
2. Asks follow-up questions to clarify needs.
3. Searches listings using tool calls (embeddings + structured filters).
4. Ranks and explains recommendations.
5. Can hand off to the booking flow.

**Tools available to the agent:**
- `search_listings(query, filters)` — semantic search over listings
- `get_listing_detail(id)` — full listing data
- `check_availability(listing_id, start_date, end_date)` — booking overlap check
- `calculate_price(listing_id, start_date, end_date)` — total cost estimate

All tools are **read-only**. No bookings are created without explicit user action.

- **Backend:** `POST /api/v1/concierge/message` — stateful conversation via session or chat record.
- **Frontend:** Chat-style UI (new page or modal); streaming responses.

---

### 7. MCP Server
**Status:** Not started | **Teaches:** Model Context Protocol, AI tool integration

Expose Trekr as an MCP server so external AI agents (Claude Desktop, etc.) can interact with the marketplace.

**Example tools:**
- `search_listings` — semantic search
- `create_booking` — (with explicit confirmation step)
- `calculate_price`
- `get_owner_statistics`
- `find_available_rvs`

- **Implementation:** Rails engine or standalone Rack app exposing the MCP protocol.
- **Auth:** API key or OAuth for external agent access.

---

## Shared Integration Pattern

All AI features follow the same shape:

```
app/
  services/
    ai/
      base_ai_service.rb        # shared: logging to ai_requests, error handling
      description_generator.rb
      chat_reply_suggester.rb
      trip_planner.rb
      pricing_suggester.rb
      concierge.rb
  prompts/
    description_generator/
      v1.txt
    chat_reply/
      v1.txt
    trip_planner/
      v1.txt
    pricing_suggester/
      v1.txt
    concierge/
      v1.txt
```

- **Model:** `claude-sonnet-4-6` default; overridable per feature.
- **API key:** Rails encrypted credentials (`rails credentials:edit` → `anthropic_api_key`).
- **Observability:** `BaseAiService` wraps every call — records to `ai_requests`, measures latency, calculates cost.
- **Error handling:** Rescue `Anthropic::Error`; return structured error JSON; log failure to `ai_requests`.

---

## Build Order

1. **Cross-cutting infrastructure first** — `ai_requests` table, `BaseAiService`, prompt loading, guardrails skeleton.
2. **Feature 1: Description Generator** — validates the full pattern end-to-end.
3. **Feature 5: Pricing Suggestions** — reuses the pattern; no new infrastructure.
4. **Feature 3: Smart Chat Replies** — reuses the pattern; no new infrastructure.
5. **Cross-cutting: Embeddings + pgvector** — installs the vector search layer.
6. **Feature 2: Natural Language Search** — first feature using embeddings.
7. **Cross-cutting: RAG corpus + retrieval** — builds the knowledge base + retrieval service.
8. **Feature 4: Trip Planner** — first RAG + background job feature.
9. **Feature 6: AI Concierge** — agent loop, tool use, multi-turn.
10. **Feature 7: MCP Server** — exposes everything as MCP tools.
11. **Evaluation Framework** — regression suite across all features.

---

## Process

Each feature follows the standard workflow:
1. `/grilling` interview + write ADR in `docs/adr/`
2. `/tdd` for implementation
3. `/verify` in the running app
4. Commit + update tracking issue
