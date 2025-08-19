#!/usr/bin/env bash
# One-shot manual test script for RV Marketplace API
# Requires: bash, curl, jq
# Usage: bash scripts/manual_test.sh

set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3000}"
CURL_OPTS="-sS"

fail=0
assert_status() {
  local want=$1; shift
  local got=$1; shift
  local msg=${1:-}
  if [ "$want" -ne "$got" ]; then
    echo "FAIL: $msg (want $want, got $got)"
    fail=1
  else
    echo "OK: $msg (status $got)"
  fi
}

extract_auth() {
  # read HTTP response headers from stdin and return the Authorization header value
  # case-insensitive and trims CR/LF
  grep -iE '^authorization:' | sed -E 's/^[Aa]uthorization:[[:space:]]*//' | tr -d '\r\n'
}

req_post_json() {
  local url=$1; local data=$2; shift 2
  # returns body then status on separate lines
  local tmp
  tmp=$(mktemp)
  http_code=$(curl $CURL_OPTS -w "%{http_code}" -o "$tmp" -X POST "$url" -H "Content-Type: application/json" -d "$data" "$@")
  body=$(cat "$tmp")
  rm -f "$tmp"
  printf '%s\n%s' "$body" "$http_code"
}

req_patch() {
  local url=$1; shift
  local tmp
  tmp=$(mktemp)
  http_code=$(curl $CURL_OPTS -w "%{http_code}" -o "$tmp" -X PATCH "$url" "$@")
  body=$(cat "$tmp")
  rm -f "$tmp"
  printf '%s\n%s' "$body" "$http_code"
}

req_get() {
  local url=$1; shift
  local tmp
  tmp=$(mktemp)
  http_code=$(curl $CURL_OPTS -w "%{http_code}" -o "$tmp" -X GET "$url" "$@")
  body=$(cat "$tmp")
  rm -f "$tmp"
  printf '%s\n%s' "$body" "$http_code"
}

req_delete() {
  local url=$1; shift
  local tmp
  tmp=$(mktemp)
  http_code=$(curl $CURL_OPTS -w "%{http_code}" -o "$tmp" -X DELETE "$url" "$@")
  body=$(cat "$tmp")
  rm -f "$tmp"
  printf '%s\n%s' "$body" "$http_code"
}

echo "Starting manual API test against $BASE_URL"
echo

# 1) Register owner and hirer (idempotent if already exist may return 422; ignore)
owner_email="owner+manual@example.com"
hirer_email="hirer+manual@example.com"
password="password"

echo "Registering users (if they already exist it's fine)..."
curl $CURL_OPTS -X POST "$BASE_URL/users" -H "Content-Type: application/json" -d "{\"user\":{\"email\":\"$owner_email\",\"password\":\"$password\",\"password_confirmation\":\"$password\",\"name\":\"Owner\"}}" || true
curl $CURL_OPTS -X POST "$BASE_URL/users" -H "Content-Type: application/json" -d "{\"user\":{\"email\":\"$hirer_email\",\"password\":\"$password\",\"password_confirmation\":\"$password\",\"name\":\"Hirer\"}}" || true

# 2) Sign in -> capture Authorization header
echo "Signing in owner..."
owner_auth=$(curl -i $CURL_OPTS -X POST "$BASE_URL/users/sign_in" -H "Content-Type: application/json" -d "{\"user\":{\"email\":\"$owner_email\",\"password\":\"$password\"}}" | extract_auth)
if [ -z "$owner_auth" ]; then
  echo "ERROR: owner sign-in failed (no Authorization header). Last raw response:"
  curl -i $CURL_OPTS -X POST "$BASE_URL/users/sign_in" -H "Content-Type: application/json" -d "{\"user\":{\"email\":\"$owner_email\",\"password\":\"$password\"}}"
  exit 2
fi
echo "Owner token captured."

echo "Signing in hirer..."
hirer_auth=$(curl -i $CURL_OPTS -X POST "$BASE_URL/users/sign_in" -H "Content-Type: application/json" -d "{\"user\":{\"email\":\"$hirer_email\",\"password\":\"$password\"}}" | extract_auth)
if [ -z "$hirer_auth" ]; then
  echo "ERROR: hirer sign-in failed (no Authorization header). Last raw response:"
  curl -i $CURL_OPTS -X POST "$BASE_URL/users/sign_in" -H "Content-Type: application/json" -d "{\"user\":{\"email\":\"$hirer_email\",\"password\":\"$password\"}}"
  exit 2
fi
echo "Hirer token captured."

# 3) Owner creates a listing
echo
echo "Owner creates a listing..."
create_listing_response=$(req_post_json "$BASE_URL/api/v1/listings" '{"listing":{"title":"Manual Test RV","description":"Test created by script","location":"Local","price_per_day":123.45}}' -H "Authorization: $owner_auth")
listing_body=$(echo "$create_listing_response" | sed -n '1p')
listing_code=$(echo "$create_listing_response" | sed -n '2p')
assert_status 201 "$listing_code" "Create listing"
listing_id=$(echo "$listing_body" | jq -r '.id // empty')
if [ -z "$listing_id" ]; then
  echo "ERROR: could not parse listing id from response:"
  echo "$listing_body"
  fail=1
else
  echo "Listing id: $listing_id"
fi

# 3a) Non-owner attempts to update listing (should be 403)
echo
echo "Non-owner attempts to update listing title (should be 403)..."
non_owner_update_resp=$(req_patch "$BASE_URL/api/v1/listings/$listing_id" -H "Authorization: $hirer_auth" -H "Content-Type: application/json" -d '{"listing":{"title":"Hacker Edit"}}')
non_owner_update_code=$(echo "$non_owner_update_resp" | sed -n '2p')
assert_status 403 "$non_owner_update_code" "Non-owner listing update forbidden"

# 3b) Owner updates listing (should be 200)
echo
echo "Owner updates listing title (should be 200)..."
owner_update_resp=$(req_patch "$BASE_URL/api/v1/listings/$listing_id" -H "Authorization: $owner_auth" -H "Content-Type: application/json" -d '{"listing":{"title":"Manual Test RV (Updated)"}}')
owner_update_body=$(echo "$owner_update_resp" | sed -n '1p')
owner_update_code=$(echo "$owner_update_resp" | sed -n '2p')
assert_status 200 "$owner_update_code" "Owner listing update"
updated_title=$(echo "$owner_update_body" | jq -r '.title // empty')
if [ "$updated_title" != "Manual Test RV (Updated)" ]; then
  echo "WARN: listing title not updated as expected (got '$updated_title')"
fi

# 3c) Owner creates a temporary listing for destroy tests
echo
echo "Owner creates temp listing for destroy tests..."
temp_listing_resp=$(req_post_json "$BASE_URL/api/v1/listings" '{"listing":{"title":"Temp Destroy","description":"Temp","location":"X","price_per_day":10}}' -H "Authorization: $owner_auth")
temp_listing_body=$(echo "$temp_listing_resp" | sed -n '1p')
temp_listing_code=$(echo "$temp_listing_resp" | sed -n '2p')
assert_status 201 "$temp_listing_code" "Create temp listing"
temp_listing_id=$(echo "$temp_listing_body" | jq -r '.id // empty')

# 3d) Non-owner attempts to destroy temp listing (403)
echo
echo "Non-owner attempts to destroy temp listing (should be 403)..."
if [ -n "$temp_listing_id" ]; then
  non_owner_destroy_resp=$(req_delete "$BASE_URL/api/v1/listings/$temp_listing_id" -H "Authorization: $hirer_auth")
  non_owner_destroy_code=$(echo "$non_owner_destroy_resp" | sed -n '2p')
  assert_status 403 "$non_owner_destroy_code" "Non-owner destroy forbidden"
else
  echo "Skipping non-owner destroy test (no temp listing id)"
fi

# 3e) Owner destroys temp listing (204)
echo
echo "Owner destroys temp listing (should be 204)..."
if [ -n "$temp_listing_id" ]; then
  owner_destroy_resp=$(req_delete "$BASE_URL/api/v1/listings/$temp_listing_id" -H "Authorization: $owner_auth")
  owner_destroy_code=$(echo "$owner_destroy_resp" | sed -n '2p')
  assert_status 204 "$owner_destroy_code" "Owner destroy listing"
fi

# 4) Hirer creates booking (happy)
echo
echo "Hirer creates booking (happy path)..."
create_booking_response=$(req_post_json "$BASE_URL/api/v1/listings/$listing_id/bookings" '{"booking":{"start_date":"2025-09-10","end_date":"2025-09-14"}}' -H "Authorization: $hirer_auth")
booking_body=$(echo "$create_booking_response" | sed -n '1p')
booking_code=$(echo "$create_booking_response" | sed -n '2p')
assert_status 201 "$booking_code" "Hirer booking create"
booking_id=$(echo "$booking_body" | jq -r '.id // empty')
if [ -z "$booking_id" ]; then
  echo "WARN: booking id not returned in body"
else
  echo "Booking id: $booking_id"
fi

# 5) Owner attempts to create booking (should be forbidden 403)
echo
echo "Owner attempts to book own listing (should be 403)..."
owner_book_response=$(req_post_json "$BASE_URL/api/v1/listings/$listing_id/bookings" '{"booking":{"start_date":"2025-09-20","end_date":"2025-09-25"}}' -H "Authorization: $owner_auth")
owner_book_code=$(echo "$owner_book_response" | sed -n '2p')
assert_status 403 "$owner_book_code" "Owner booking own listing forbidden"

# 6) Unauthenticated booking attempt (should be 401)
echo
echo "Unauthenticated booking attempt (should be 401)..."
unauth_book_response=$(req_post_json "$BASE_URL/api/v1/listings/$listing_id/bookings" '{"booking":{"start_date":"2025-10-01","end_date":"2025-10-05"}}')
unauth_book_code=$(echo "$unauth_book_response" | sed -n '2p')
assert_status 401 "$unauth_book_code" "Unauthenticated booking forbidden"

# 7) Non-owner tries to confirm booking (should be forbidden 403)
echo
echo "Non-owner (hirer) attempts to confirm booking (should be 403)..."
if [ -z "$booking_id" ]; then
  echo "Skipping confirm test because booking id is missing"
  fail=1
else
  confirm_non_owner_response=$(req_patch "$BASE_URL/api/v1/bookings/$booking_id/confirm" -H "Authorization: $hirer_auth")
  confirm_non_owner_code=$(echo "$confirm_non_owner_response" | sed -n '2p')
  assert_status 403 "$confirm_non_owner_code" "Non-owner confirm forbidden"
fi

# 8) Owner confirms booking (should be 200 and status confirmed)
echo
echo "Owner confirms booking (should be 200)..."
if [ -z "$booking_id" ]; then
  echo "Skipping owner confirm test because booking id is missing"
  fail=1
else
  confirm_owner_response=$(req_patch "$BASE_URL/api/v1/bookings/$booking_id/confirm" -H "Authorization: $owner_auth")
  confirm_owner_body=$(echo "$confirm_owner_response" | sed -n '1p')
  confirm_owner_code=$(echo "$confirm_owner_response" | sed -n '2p')
  assert_status 200 "$confirm_owner_code" "Owner confirm booking"
  # try to read status
  confirmed_status=$(echo "$confirm_owner_body" | jq -r '.status // empty')
  if [ "$confirmed_status" = "confirmed" ]; then
    echo "Booking status confirmed."
  else
    echo "Booking status after confirm: '$confirmed_status' (expected 'confirmed')"
  fi
fi

# 9) Hirer posts a message (happy)
echo
echo "Hirer posts a message..."
post_msg_resp=$(req_post_json "$BASE_URL/api/v1/listings/$listing_id/messages" '{"message":{"content":"Is this available for our dates?"}}' -H "Authorization: $hirer_auth")
post_msg_code=$(echo "$post_msg_resp" | sed -n '2p')
assert_status 201 "$post_msg_code" "Hirer posts message"

# 10) Owner lists messages (should include the message)
echo
echo "Owner lists messages..."
list_messages_resp=$(req_get "$BASE_URL/api/v1/listings/$listing_id/messages" -H "Authorization: $owner_auth")
list_messages_body=$(echo "$list_messages_resp" | sed -n '1p')
list_messages_code=$(echo "$list_messages_resp" | sed -n '2p')
assert_status 200 "$list_messages_code" "Owner lists messages"
echo "Messages (first 300 chars):"
echo "$list_messages_body" | jq '.' | sed -n '1,20p'

# 11) Invalid message (empty content) -> expect 422
echo
echo "Hirer posts an invalid (empty) message -> expect 422..."
invalid_msg_resp=$(req_post_json "$BASE_URL/api/v1/listings/$listing_id/messages" '{"message":{"content":""}}' -H "Authorization: $hirer_auth")
invalid_msg_code=$(echo "$invalid_msg_resp" | sed -n '2p')
assert_status 422 "$invalid_msg_code" "Invalid message rejected (unprocessable)"

echo
# ensure final exit uses numeric status
if [ "$fail" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED"
  exit 2
fi