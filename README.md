# README

## Implementation Details
- Developed using GitHub Copilot with GPT-5 mini (Preview) 
- Ruby version: 3.3.8
- System dependencies (Docker)
- How to run the test suite: `bundle exec rspec`

## Development (Docker)

Start the app:
```bash
docker compose up -d --build
```

Run migrations:
```bash
# Setup databases (dev + test)
docker compose exec web bin/rails db:create db:migrate
RAILS_ENV=test docker compose exec web bin/rails db:create db:migrate
```

Run the manual smoke test:
```bash
chmod +x script/manual_test.sh
bash script/manual_test.sh
```
## View Swagger API documentation

1. Ensure the app is running (see "Start the app" above).
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
5. If the UI fails to load or 404s for the OpenAPI file, check `config/initializers/rswag_ui.rb` — ensure the `openapi_endpoint` points at the file you generated (e.g. `/api-docs/v1/swagger.json`).

Quick checks
```bash
# fetch the generated JSON to confirm it's served
curl -sS http://localhost:3000/api-docs/v1/swagger.json | jq '.info.title'  # requires jq
```

## API examples (curl)

Replace <TOKEN>, <LISTING_ID>, and <BOOKING_ID> with values returned by the API.

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
   -d '{"listing":{"title":"My RV","description":"Nice","location":"OR","price_per_day":100}}'

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
```

### Bookings
```bash
# Create a booking (hirer, not owner)
curl -i -X POST http://localhost:3000/api/v1/listings/<LISTING_ID>/bookings \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer <TOKEN>" \
   -d '{"booking":{"start_date":"2025-09-10","end_date":"2025-09-14"}}'

# Confirm a booking (owner only)
curl -i -X PATCH http://localhost:3000/api/v1/bookings/<BOOKING_ID>/confirm \
   -H "Authorization: Bearer <TOKEN>"

# Reject a booking (owner only)
curl -i -X PATCH http://localhost:3000/api/v1/bookings/<BOOKING_ID>/reject \
   -H "Authorization: Bearer <TOKEN>"

# List bookings (owner or hirer)
curl -sS -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/bookings | jq '.'
```

### Messages
```bash
# Post a message on a listing (authenticated)
curl -i -X POST http://localhost:3000/api/v1/listings/<LISTING_ID>/messages \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer <TOKEN>" \
   -d '{"message":{"content":"Is this available?"}}'

# List messages for a listing (owner or authenticated user depending on API)
curl -sS -H "Authorization: Bearer <TOKEN>" http://localhost:3000/api/v1/listings/<LISTING_ID>/messages | jq '.'
```

### Swagger / OpenAPI
```bash
# Open Swagger UI in your browser: http://localhost:3000/api-docs
# Fetch raw JSON
curl -sS http://localhost:3000/api-docs/v1/swagger.json | jq '.'
# Fetch YAML
curl -sS http://localhost:3000/api-docs/v1/swagger.yaml
```


