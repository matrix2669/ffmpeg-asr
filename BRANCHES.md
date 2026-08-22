# Branches

This ledger records why every current branch exists. GitHub remains authoritative for live refs and commit state. Upstream contribution branches are documented here but remain free of fork-only governance files so their pull-request diffs stay focused.

## Maintenance rules

- Add or update a record before substantive work begins on a branch.
- Refresh observed heads and validation before using a record for review or promotion.
- Before deleting a branch, transfer user-visible results to `CHANGELOG.md` and durable rationale to `DECISIONS.md`, then remove its record.
- Base every `contrib/*` branch on the freshly reviewed `upstream/main`; never base an upstream pull request on this fork's `main` or `dev`.

## Branch index

| Branch | Type | Status | Base | Target | Purpose |
|---|---|---|---|---|---|
| `main` | long-lived | active | upstream history | stable releases | Stable canonical source for matrix2669 releases and downstream synchronization. |
| `dev` | long-lived | active | `main` | `main` | Integrate and validate the next matrix2669 version. |

## Branch records

### `main`

- Purpose: production-ready matrix2669 source, stable tags, and GitHub Releases.
- Upstream relationship: retains shared history with `FiveBoroughs/ffmpeg-asr`; it is intentionally allowed to diverge.
- Contribution rule: never submit this branch upstream.
- Last verified head: `1422797653e82034b4726e331fd971969534913c`
- Last verified at: `2026-08-22T15:25:16Z`

### `dev`

- Purpose: integrate fork-owned feature and fix work before stable promotion.
- Base: `main` at `1422797653e82034b4726e331fd971969534913c`
- Intended target: `main`
- Validation: `scripts/validate.sh`, standalone persistent-state/cache failure tests, downstream plugin tests, and installed-container missing/stale-cache behavior pass for `v1.1.0-beta.1`.
- Last verified head: the tested `v1.1.0-beta.1` source state including persistent-state and required-cache handling.
- Last verified at: `2026-08-22`
