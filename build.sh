#!/usr/bin/env bash
set -euo pipefail

# Local-only production settings. Do not store real secrets in this file.
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(openssl rand -hex 64)}"
export POSTGRES_USER="${POSTGRES_USER:-postgres}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD before running this script.}"

# These make the production environment usable on localhost.
export ACTIVE_STORAGE_SERVICE="local"
export RAILS_FORCE_SSL="false"
export RAILS_ASSUME_SSL="false"

COMPOSE_FILE="docker-compose.prod.yml"

docker compose -f "${COMPOSE_FILE}" build
docker compose -f "${COMPOSE_FILE}" up -d db redis
docker compose -f "${COMPOSE_FILE}" run --rm web bin/rails db:prepare
docker compose -f "${COMPOSE_FILE}" up web sidekiq
