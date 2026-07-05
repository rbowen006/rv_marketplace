---
name: implement
description: "Implement a piece of work based on a PRD or set of issues."
disable-model-invocation: true
---

Implement the work described by the user in the PRD or issues.

Use /tdd where possible, at pre-agreed seams.

Run the project's automated checks as you go. For frontend work under `frontend/`:

- `npm run typecheck` regularly
- `npm run lint` (and `npm run format:check` before finishing)
- single test files regularly; full `npm test` once at the end

For backend work: `bin/rubocop` on touched files and the relevant test suite (`docker compose exec -e RAILS_ENV=test web bundle exec rspec` for this repo).

Once done, use /review to review the work.

Commit your work to the current branch.
