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
| `feature/hybrid-standalone-release` | feature | active | `dev` | `dev`, then `main` | Bootstrap hybrid governance and publish `v1.0.0`. |
| `agent/capacity-aware-multi-gpu-scheduling` | legacy feature | merged | historical `main` | delete | Retained remote branch for work already present in `main`. |
| `agent/recache-only` | legacy feature | merged | historical `main` | delete | Retained remote branch whose head already equals `main`. |

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
- Validation: shell syntax, release metadata, packaging, and hardware/live validation proportionate to behavioral changes.
- Last verified head: `1422797653e82034b4726e331fd971969534913c`
- Last verified at: `2026-08-22T15:25:16Z`

### `feature/hybrid-standalone-release`

- Purpose: add repository-owned guidance, decisions, release history, semantic versioning, reproducible ZIP packaging, and upstream provenance while preserving a clean contribution lane.
- Base: `dev` at `1422797653e82034b4726e331fd971969534913c`
- Intended target: `dev`, followed by promotion of the validated release state to `main`.
- In scope: documentation structure, semantic version metadata, packaging, release validation, `v1.0.0`, and cleanup of contained legacy branches.
- Out of scope: new transcoding behavior and an upstream pull request.
- Validation: pending.
- Last verified head: `1422797653e82034b4726e331fd971969534913c`
- Last verified at: `2026-08-22T15:25:16Z`

### `agent/capacity-aware-multi-gpu-scheduling`

- Outcome: its work is contained in `main` through merge commits `7f89823` and `0c93727`.
- Disposition: delete after the `v1.0.0` history records its delivered functionality.
- Last verified head: `a5cdf9e`
- Last verified at: `2026-08-22T15:25:16Z`

### `agent/recache-only`

- Outcome: its head equals the pre-release `main` head; the cache-only and pipe-input work is fully contained.
- Disposition: delete after the `v1.0.0` history records its delivered functionality.
- Last verified head: `1422797653e82034b4726e331fd971969534913c`
- Last verified at: `2026-08-22T15:25:16Z`
