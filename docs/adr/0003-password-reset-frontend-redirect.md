# Password reset links point to the React frontend, not a Rails route

This app is Rails API-only with no server-rendered views. Devise's default
password reset flow generates a link to `/users/password/edit?reset_password_token=xxx`,
which expects a Rails view to render the "enter new password" form. That view
does not exist and cannot exist in this architecture.

## Decision

Override the Devise password mailer template so reset links point to the
React frontend at `/reset-password?token=xxx`. The frontend page reads the
token from the query string, collects the new password, and POSTs to
`PUT /users/password` (a custom `Users::PasswordsController` that returns
JSON). Devise validates the token and updates the password server-side.

## Email enumeration

The `POST /users/password` endpoint always returns a 200 with the same
response body regardless of whether the submitted email matches a registered
account. This prevents an attacker from probing which email addresses have
accounts by watching the response.

## Consequences

- The Devise mailer template (`devise/mailer/reset_password_instructions.html.erb`)
  must be maintained in this repo. If the frontend route changes, the template
  must be updated to match.
- Token expiry is Devise's default (6 hours). Tokens are single-use.
- Development email is intercepted by `letter_opener` (no real email sent).
