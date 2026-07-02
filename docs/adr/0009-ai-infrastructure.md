# ADR-0009: AI Infrastructure — BaseAiService, ai_requests, and Prompt Loading

## Status

Accepted

## Context

All seven planned AI features (description generator, natural language search, smart chat replies, trip planner, pricing suggestions, concierge, MCP server) share the same cross-cutting concerns: calling an LLM, logging every call for observability, loading versioned prompts, validating structured outputs, and handling errors consistently. Rather than re-implementing these in each feature, a shared infrastructure layer is introduced first.

## Decision

### Client

Use the `anthropic` gem (official Anthropic Ruby SDK). Direct to Anthropic's API — not via AWS Bedrock. API key stored in `ENV['ANTHROPIC_API_KEY']`, not in Rails encrypted credentials.

The key is set in a `.env` file at the project root (already covered by `.gitignore`'s `/.env*` rule). `docker-compose.yml` passes it into both the `web` and `sidekiq` containers via the `x-app` environment anchor using Docker Compose's pass-through syntax (`ANTHROPIC_API_KEY:` with no value).

### BaseAiService

All AI services inherit from `Ai::BaseAiService`. The base class implements the algorithm skeleton via the **template method pattern**; subclasses fill in feature-specific steps.

**Call interface:** `Service.call(...)` delegates to `new(...).call` — ergonomic at the call site, testable at the instance level.

**Algorithm skeleton (in `call`):**
1. `validate_input!` — subclass raises `Ai::InputError` if required fields are missing or invalid
2. Load system prompt from `app/prompts/<PROMPT_FEATURE>/<PROMPT_VERSION>.txt`
3. `build_user_message` — subclass returns a structured hash (listing fields, chat history, etc.)
4. Call Claude — system prompt as the system turn, user message as the sole user turn (see JSON Output Reliability — assistant-turn prefill was removed as of the Claude 4.6 model generation and is no longer used)
5. Parse the JSON response
6. Validate against `output_schema` using the `json-schema` gem
7. Return the validated data hash
8. `ensure` — always write a row to `ai_requests`, success or failure

**Required subclass interface:**

| Method / Constant | Purpose |
|---|---|
| `PROMPT_FEATURE` | Directory name under `app/prompts/` |
| `PROMPT_VERSION` | File name, e.g. `"v1"` |
| `validate_input!` | Raise `Ai::InputError` if inputs are invalid |
| `build_user_message` | Return a hash passed as the user turn |
| `output_schema` | JSON Schema hash for validating Claude's response |
| `MODEL` (optional) | Override the default model per feature |

Default model: `claude-sonnet-4-6`. Subclasses may override with `MODEL = "claude-haiku-4-5"` for cheaper/faster features.

### Prompt Files

Prompts live in `app/prompts/<feature>/<version>.txt` — never hardcoded in service objects. Files contain static instructions only; no ERB or string interpolation. Variable data is passed as a structured JSON hash in the user message turn. Switching prompt versions is a one-line constant change on the subclass.

### JSON Output Reliability

Originally two techniques combined: a system prompt instruction plus an assistant-turn prefill (`{role: "assistant", content: "{"}`) so Claude would continue from an open brace, guaranteeing JSON-only output at the API level.

**Revised 2026-07-02:** assistant-turn prefill is rejected outright (HTTP 400: "This model does not support assistant message prefill") on `claude-sonnet-4-6` and every model since the Claude 4.6 generation — confirmed via a live `/verify` call against the real API; all 155 WebMock-backed unit tests still passed beforehand because the stubbed responses never exercised the real request shape. The prefill message and the corresponding `"{" + response.text` reassembly were removed from `BaseAiService#invoke_claude`.

Current mechanism — one technique, not two:
1. System prompt explicitly instructs Claude to respond with valid JSON only, no prose, no markdown.
2. The `json-schema` gem validates the parsed response against the subclass-defined schema before the data is used. If validation fails, `Ai::OutputError` is raised.

**Known limitation:** this is a *weaker* guarantee than the original design — nothing at the request level forces JSON-shaped output anymore; malformed output is only caught after the round trip, via schema validation. Anthropic's documented replacement for prefill is API-enforced structured output (`output_config.format` with a JSON schema) or forced `tool_choice` — both would restore a hard guarantee, and both could reuse the `output_schema` each subclass already defines. Deliberately deferred in favor of the smaller fix above; revisit before adding features that depend on tighter reliability than "validated after the fact." Filed as a known limitation rather than a bug, since the schema-validation safety net already existed and continues to catch the failure mode, just later than before.

**Also known:** when Claude's response is truncated (`stop_reason: "max_tokens"`), the resulting parse failure is reported as a generic `Ai::OutputError, "Claude returned invalid JSON"` with no indication the real cause was hitting the token cap. Minor debuggability gap, predates this revision, not addressed here.

### Error Handling

Three exception types, all inheriting from `Ai::Error`:

| Exception | Raised when | HTTP status |
|---|---|---|
| `Ai::InputError` | Invalid input before calling Claude | 400 (JSend `fail`) |
| `Ai::ApiError` | Claude API failure — network, timeout, rate limit | 503 (JSend `error`) |
| `Ai::OutputError` | Claude responded but output is malformed or fails schema | 500 (JSend `error`) |

Controllers rescue these and render JSend-shaped responses, mirroring the exception-driven pattern established in the contact-api `JSendProcessor`. Services raise; controllers map to HTTP.

### ai_requests Table

Every AI call — success or failure — writes a row to `ai_requests`. Written in the `ensure` block of `BaseAiService#call`; intermediate values (`@input_tokens`, `@output_tokens`, `@latency_ms`, `@error`) accumulate on `self` during the call.

| Column | Type | Notes |
|---|---|---|
| `feature` | string | e.g. `"description_generator"` |
| `model` | string | e.g. `"claude-sonnet-4-6"` |
| `prompt_version` | string | e.g. `"v1"` |
| `input_tokens` | integer | |
| `output_tokens` | integer | |
| `latency_ms` | integer | |
| `estimated_cost_usd` | decimal(10,6) | Calculated from `Ai::Pricing` constants |
| `success` | boolean | |
| `error_message` | string | nullable |
| `request_payload` | text | nullable; the full prompt sent |
| `response_payload` | text | nullable; the raw Claude response |
| `user_id` | FK → User, nullable | nullable; nil for background jobs |
| `created_at` | datetime | |

### Pricing

`Ai::Pricing::RATES` is a constants module keyed by model name. Each entry has `:input` and `:output` cost per token. `BaseAiService` uses this to calculate `estimated_cost_usd` after each call.

### Testing

WebMock stubs Anthropic's HTTP endpoints. Tests never hit the real API. Both success and error response shapes are stubbed to exercise all code paths.

### Listing Description Generator — Endpoint Shape

`POST /api/v1/listings/generate_description` (auth required). Accepts raw listing fields as a JSON body — no listing ID. Stateless: the controller passes fields directly to the service and returns the generated description. Works for both the create and edit flows because no persisted listing is required.

## Alternatives Considered

**AWS Bedrock (`aws-sdk-bedrockruntime`)** — rejected; adds AWS credential complexity for no learning benefit on a project aimed at AI engineering fluency.

**ERB or string interpolation in prompt files** — rejected; static system prompt + structured user message is the idiomatic Claude API pattern and keeps prompt files versionable without a templating engine.

**Result object instead of exceptions** — rejected in favour of the exception-driven pattern from contact-api's `JSendProcessor`. Services raise typed exceptions; the HTTP boundary maps them to JSend responses.

**VCR cassettes for tests** — rejected; WebMock is sufficient and avoids cassette management.

**Two exception types (input vs service)** — rejected; three types (`InputError`, `ApiError`, `OutputError`) carry meaningful semantic differences. `ApiError` means "retry may help"; `OutputError` means "the prompt is broken."
