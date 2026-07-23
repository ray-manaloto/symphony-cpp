# Tracker adapter profiles

These profiles define the compact defaults and validation surface implemented by the fixture-only
tracker contract. They do not enable network access or tracker mutation. Future provider DTOs use
Glaze, and live HTTP remains gated by the Glaze HTTP client decision in
[`dependency-decisions.md`](dependency-decisions.md).

## Linear

- Kind: `linear`
- Provider key: `project_slug` (required, non-empty string)
- Secret environment name: `LINEAR_API_KEY`
- Active-state defaults: `Todo`, `In Progress`
- Terminal-state defaults: `Done`, `Cancelled`
- Missing or empty project/secret values are configuration errors.

## GitHub Issues

- Kind: `github`
- Provider keys: `owner`, `repository` (required, non-empty strings)
- Secret environment name: `GITHUB_TOKEN`
- Active-state default: `open`
- Terminal-state default: `closed`
- Missing or empty owner/repository/secret values are configuration errors.

## Shared behavior

- Adapter kinds are matched after trimming and ASCII lowercasing.
- Labels are trimmed, lowercased, deduplicated, and blank labels are discarded.
- Missing `id`, `identifier`, `title`, `state`, or adapter-derived `dispatchable` fails the complete
  fetch as `malformed_response`; partial pages are never dispatched.
- Pagination preserves provider page and record order. Blank/repeated cursors and the 1,000-page
  safety limit fail as `malformed_response`.
- Portable errors distinguish configuration, authentication, permission, not-found, rate-limit,
  unavailable, and malformed-response failures. Only rate limits and service unavailability are
  retryable by default.
- Secret values and issue contents are never included in portable error messages.
- Host-side tracker secret variables must not be inherited by the Codex child process.

The GitHub and Linear concrete classes remain non-networking stubs until the transport gate passes.
Their mutation mode remains disabled; this document grants no live tracker authority.
