# Trekr RV Marketplace

Trekr is a full-stack RV/caravan marketplace with a Rails API, React/TypeScript/Vite frontend, PostgreSQL persistence, Redis-backed Sidekiq jobs, and a Docker Compose development stack.

<p align="center">
  <img src="docs/assets/trekr-icon.png" alt="Trekr app icon" width="180">
</p>

<p align="center">
  <img src="docs/assets/trekr-home.png" alt="Trekr marketplace home page" width="900">
</p>

## 🤖 AI

Trekr is AI-native in two senses:

**Built with AI** — developed with [Claude Code](https://claude.com/claude-code) driving a test-first workflow (grill → TDD → code-review → verify) via a set of agent skills for design, review, and QA.

**AI-powered features** — Trekr ships real LLM features on a reusable, production-style service layer (`Ai::BaseAiService`) with:

- **Prompt versioning** — prompts are versioned files in `app/prompts/`, never hardcoded
- **Observability & cost tracking** — every Claude call logs tokens, latency, and estimated cost to an `ai_requests` table
- **Guardrails** — input/output validation with graceful failures
- **Human-in-the-loop** — AI drafts; the user edits and accepts (nothing auto-saves)

| Feature | Status |
|---|---|
| ✨ **Listing Description Generator** — drafts a listing description from RV attributes | ✅ Shipped |
| 🔎 Natural-language search | 🗺️ Planned |
| 💬 Smart chat replies for owners | 🗺️ Planned |
| 💲 Pricing suggestions | 🗺️ Planned |
| 🧭 Trip-planning assistant (RAG) | 🗺️ Planned |
| 🤖 AI concierge (agentic + tool use) | 🗺️ Planned |
| 🔌 MCP server | 🗺️ Planned |

See [docs/ai-integrations.md](docs/ai-integrations.md) for the full design brief.

## Implementation Details
- Rails 8.0.5 · Ruby 3.3.11 in Docker
- PostgreSQL 16 · Redis 7 · Sidekiq 8
- Devise + devise-jwt for token authentication
- Active Storage for listing image uploads
- Rswag for OpenAPI/Swagger spec generation
- React 18 + TypeScript + Vite 8 frontend in `frontend/` (strict mode; ESLint + Prettier)
- Tailwind CSS 4 for styling

## Contents
- [Development With Docker](#development-with-docker)
- [Local Production-Like Run](#local-production-like-run)
- [Useful Docker Commands](#useful-docker-commands)
- [Background Jobs](#background-jobs)
- [Swagger API Documentation](#swagger-api-documentation)
- [API Examples](#api-examples-curl)
- [Frontend](#frontend)
- [Further Reading](#further-reading)

## Development With Docker

Build and start the Rails development stack:

```bash
docker compose up --build        # attach (logs stream to terminal)
docker compose up --build -d     # detached (runs in background)
```

This starts:

- `web`: Rails/Puma API on http://localhost:3000
- `db`: PostgreSQL, available to other containers as `db`
- `redis`: Redis, available to other containers as `redis`
- `sidekiq`: background worker using Redis

The development Compose file builds the `development` Dockerfile target, sets `RAILS_ENV=development`, and bind-mounts the local repo into `/app`, so Rails sees code changes from your editor.

Prepare the database:

```bash
docker compose exec web bin/rails db:prepare
```

Optionally load sample listings with Australian data and images:

```bash
docker compose exec web bin/rails db:seed
```

Run the test suite:

```bash
docker compose exec web bundle exec rspec
```

Stop the development stack:

```bash
docker compose down
```

## Local Production-Like Run

Use this when you want to test the Rails backend the way it will run from the production Docker image.

Create a local env file. This file is ignored by git:

```bash
cat > .env.local <<'EOF'
export POSTGRES_USER="postgres"
export POSTGRES_PASSWORD="local_production_password"
export SECRET_KEY_BASE="replace-with-a-stable-local-secret"
EOF
```

Only `POSTGRES_PASSWORD` is required — `build.sh` auto-generates a random `SECRET_KEY_BASE` if you omit it, but a new random value is used on every run, which invalidates any existing sessions. Set a stable value if you're testing repeatedly.

For a stable local `SECRET_KEY_BASE`, generate one with:

```bash
openssl rand -hex 64
```

Start the local production-like stack:

```bash
source .env.local
./build.sh
```

This builds the `production` Dockerfile target, sets `RAILS_ENV=production`, prepares the production database, and starts Rails plus Sidekiq. Rails is available at http://localhost:3000.

Health check:

```bash
curl http://localhost:3000/up
```

Stop the production-like stack:

```bash
docker compose -f docker-compose.prod.yml down
```

Delete the local production database and storage volumes:

```bash
docker compose -f docker-compose.prod.yml down -v
```

Development vs production-like Docker:

- Development uses `docker-compose.yml`, `RAILS_ENV=development`, and a bind mount from the repo into `/app`.
- Production-like uses `docker-compose.prod.yml`, `RAILS_ENV=production`, named volumes, and app code baked into the Docker image.

## Useful Docker Commands

```bash
docker compose ps
docker compose logs -f web
docker compose logs -f sidekiq
docker compose exec web bin/rails console
docker compose exec web bin/rails runner 'puts ActiveRecord::Base.connection.adapter_name'
docker compose exec redis redis-cli ping
docker compose exec db psql -U postgres -l
docker compose down
```

Reset local Docker database state:

```bash
docker compose down -v
docker compose up --build
docker compose exec web bin/rails db:prepare
```

`docker compose down -v` deletes Compose-managed volumes, including the local PostgreSQL data volume.

Production-like stack equivalents:

```bash
source .env.local
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f web
docker compose -f docker-compose.prod.yml logs -f sidekiq
docker compose -f docker-compose.prod.yml exec web bin/rails console
docker compose -f docker-compose.prod.yml down
```

## Background Jobs

Active Job is configured to use Sidekiq. Sidekiq stores jobs in Redis and runs them in the separate `sidekiq` container.

Smoke test the worker:

```bash
docker compose exec web bin/rails runner 'DockerSmokeJob.perform_later("sidekiq is working")'
docker compose logs -f sidekiq
```

You should see `DockerSmokeJob` run in the Sidekiq logs.

## Swagger API Documentation

1. Ensure the Docker stack is running.
2. Open the Swagger UI in your browser:
   - Default: http://localhost:3000/api-docs
   - If you mapped a different host port, replace `3000` with that port.
3. Raw OpenAPI artifact (if you need it):
   - JSON: http://localhost:3000/api-docs/v1/swagger.json
   - YAML: http://localhost:3000/api-docs/v1/swagger.yaml
4. Regenerate the OpenAPI doc from rswag specs (run inside container or on host):
```bash
# from host (with docker running)
docker compose exec web bundle exec rake rswag:specs:swaggerize

# or on host machine without docker
bundle exec rake rswag:specs:swaggerize
```
5. If the UI fails to load or 404s for the OpenAPI file, check `config/initializers/rswag_ui.rb` and ensure the `openapi_endpoint` points at the file you generated (e.g. `/api-docs/v1/swagger.json`).

Quick checks
```bash
# fetch the generated JSON to confirm it's served
curl -sS http://localhost:3000/api-docs/v1/swagger.json | jq '.info.title'  # requires jq
```

## API Examples (curl)

Replace `<TOKEN>`, `<LISTING_ID>`, `<BOOKING_ID>`, and `<CHAT_ID>` with values returned by the API.

### Auth / Users
```bash
# Register
curl -i -X POST http://localhost:3000/users \
   -H "Content-Type: application/json" \
   -d '{"user":{"email":"alice@example.com","password":"password","password_confirmation":"password","name":"Alice"}}'

# Sign in (returns Authorization: Bearer <token> header)
curl -i -X POST http://localhost:3000/users/sign_in \
   -H "Content-Type: application/json" \
   -d '{"user":{"email":"alice@example.com","password":"password"}}'

# Note: extracting the JWT token from the sign-in response
# The sign-in endpoint returns the JWT in the response headers as
# `Authorization: Bearer <token>`. When using curl with `-i` (or
# `--include`) the response headers are printed. You can capture the
# token into a shell variable like this (POSIX / zsh / bash):

# store the raw Authorization header value, then strip the leading "Bearer "
TOKEN=$(curl -i -s -X POST http://localhost:3000/users/sign_in \
   -H "Content-Type: application/json" \
   -d '{"user":{"email":"alice@example.com","password":"password"}}' \
   | awk -F": " '/[Aa]uthorization/ {print $2}' \
   | tr -d '\r' \
   | sed 's/^Bearer //')

# Now use the token in subsequent requests:
# -H "Authorization: Bearer $TOKEN"

# Sign out
curl -i -X DELETE http://localhost:3000/users/sign_out \
    -H "Authorization: Bearer <TOKEN>"
```

### Listings
```bash
# List public listings
curl -sS http://localhost:3000/api/v1/listings | jq '.'

# Create listing (authenticated user)
curl -i -X POST http://localhost:3000/api/v1/listings \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer <TOKEN>" \
   -d '{"listing":{"title":"My RV","description":"Nice caravan","rv_type":"caravan","town":"Portland","state":"OR","postcode":"97201","price_per_day":100,"max_guests":2}}'

# Show a listing
curl -sS http://localhost:3000/api/v1/listings/<LISTING_ID> | jq '.'

# Update a listing (owner only)
curl -i -X PUT http://localhost:3000/api/v1/listings/<LISTING_ID> \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer <TOKEN>" \
   -d '{"listing":{"title":"Updated title"}}'

# Delete a listing (owner only)
curl -i -X DELETE http://localhost:3000/api/v1/listings/<LISTING_ID> \
   -H "Authorization: Bearer <TOKEN>"

# Upload images to a listing (owner only, multipart)
curl -i -X POST http://localhost:3000/api/v1/listings/<LISTING_ID>/images \
   -H "Authorization: Bearer <TOKEN>" \
   -F "images[]=@/path/to/photo1.jpg" \
   -F "images[]=@/path/to/photo2.jpg"

# Delete an image from a listing (owner only)
curl -i -X DELETE http://localhost:3000/api/v1/listings/<LISTING_ID>/images/<IMAGE_ID> \
   -H "Authorization: Bearer <TOKEN>"
```

### Bookings
```bash
# Create a booking (hirer, not owner)
# Note: start_date must be today or in the future — past dates will return 422.
curl -i -X POST http://localhost:3000/api/v1/listings/<LISTING_ID>/bookings \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer <TOKEN>" \
   -d '{"booking":{"start_date":"2026-09-10","end_date":"2026-09-14"}}'

# Confirm a booking (owner only)
curl -i -X PATCH http://localhost:3000/api/v1/bookings/<BOOKING_ID>/confirm \
   -H "Authorization: Bearer <TOKEN>"

# Reject a booking (owner only)
curl -i -X PATCH http://localhost:3000/api/v1/bookings/<BOOKING_ID>/reject \
   -H "Authorization: Bearer <TOKEN>"

# List bookings (owner or hirer)
curl -sS -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/bookings | jq '.'
```

### Chats & Messages
```bash
# Start or resume a chat about a listing (creates the chat and sends the first message)
curl -i -X POST http://localhost:3000/api/v1/listings/<LISTING_ID>/chats \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer <TOKEN>" \
   -d '{"message":{"content":"Is this available?"}}'
# Returns 201 if a new chat is created, 200 if an existing chat is resumed.
# The response includes the chat object with its id (use <CHAT_ID> below).

# List all chats for the current user (as hirer and as owner)
curl -sS -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/chats | jq '.'

# Show a chat with all messages
curl -sS -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/chats/<CHAT_ID> | jq '.'

# List messages in a chat
curl -sS -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/chats/<CHAT_ID>/messages | jq '.'

# Send a message in an existing chat
curl -i -X POST http://localhost:3000/api/v1/chats/<CHAT_ID>/messages \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer <TOKEN>" \
   -d '{"message":{"content":"Yes, it is available!"}}'
```

## Frontend

Vite + React + TypeScript SPA in `frontend/`; Rails runs in Docker and serves the API behind `/api`. Source is `.ts`/`.tsx` under `frontend/src/` with API response types in `frontend/src/types/`.

### Setup And Run

```bash
cd frontend
npm install
npm run dev  # http://localhost:5173
```

The dev server proxies `/api`, `/users`, and `/rails` to `http://localhost:3000` (see `frontend/vite.config.ts`). This covers both the API routes and the Devise auth endpoints. Ensure the Rails container is running.

Run frontend checks:

```bash
cd frontend
npm run typecheck   # tsc --noEmit
npm run lint        # ESLint
npm run format:check
npm test            # Vitest
```

### CORS

Configured via `config/initializers/cors.rb`. The default allowed origin is `http://localhost:5173`, so no extra configuration is needed for local development. Override it for other environments:

```bash
ALLOWED_ORIGINS=https://yourapp.example.com docker compose up -d
```

### Active Storage (Image Uploads)

Listing image uploads use Rails Active Storage. In development and the local production-like stack, files are stored on disk (`local` service). The production Rails config defaults to Amazon S3 (`amazon`). To use S3 in production, set:

```bash
ACTIVE_STORAGE_SERVICE=amazon
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=...
AWS_BUCKET=...
```

See `config/storage.yml` for service definitions.

### Build Production Bundle

```bash
cd frontend
npm run build
# Output: frontend/dist
```

The production Docker image (`docker-compose.prod.yml`) contains only the Rails API — the frontend is not bundled into it. You must build and serve `frontend/dist` separately, for example via Nginx, a CDN, or by copying it into Rails `public/` before building the image.

## Further Reading

- [`CONTEXT.md`](CONTEXT.md) — ubiquitous language and domain glossary (Listing, Booking, Hirer, Owner, etc.)
- [`docs/adr/`](docs/adr/) — Architecture Decision Records covering key design choices (chat model, JWT expiry, search UX, and more)