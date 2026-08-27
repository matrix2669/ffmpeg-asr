# Branches

This ledger records why every current branch exists. GitHub remains authoritative for live refs and commit state. Upstream contribution branches must be added here before substantive work and remain free of fork-only governance files so pull-request diffs stay focused.

## Maintenance rules

- Add or update a record before substantive work begins on a branch.
- Refresh observed heads and validation before using a record for review or promotion.
- Before deleting a branch, transfer user-visible results to `CHANGELOG.md` and durable rationale to `DECISIONS.md`, then remove its record.
- Base every future `contrib/*` branch on freshly reviewed `upstream/main`; never base an upstream pull request on this fork's `main` or `dev`.

## Branch index

| Branch | Type | Status | Base | Target | Purpose |
|---|---|---|---|---|---|
| `main` | long-lived | active | upstream history | stable tags | Stable canonical source for matrix2669 versions and downstream synchronization. |
| `dev` | long-lived | active | `main` | `main` | Integrate and validate the next matrix2669 version. |

## Branch records

### `main`

- Purpose: production-ready matrix2669 source and stable tags; never use this branch for an upstream contribution.
- Current stable tag: `v1.1.0` at `448837f4f6267de1c6705cb670bcdb0c6991614f`.
- Distribution state: the stable tag is published, but no GitHub Release or distributable archive is authorized until inherited licensing is resolved.
- Validation: `scripts/validate.sh` passes the persistent-state, required-cache, degraded-proxy, scoped-options, Map All auxiliary-codec, benchmark-lock, shell-syntax, version-agreement, and release-metadata gates for `1.1.0`.
- Last verified at: `2026-08-26`.

### `dev`

- Purpose: integrate fork-owned feature and fix work before stable promotion.
- Base and target: `main`.
- Current state: synchronized with `main` at stable `v1.1.0` commit `448837f4f6267de1c6705cb670bcdb0c6991614f` after the completed beta.1 through beta.7 cycle.
- Publication state: `origin/dev` and `origin/main` contain the identical stable source; beta and stable tags remain immutable.
- Last verified at: `2026-08-26`.

## Completed branch cleanup

On `2026-08-26`, all local and `origin` feature, fix, integration, safety, and release branches were deleted after their results were preserved in `CHANGELOG.md` and `DECISIONS.md` and their tips were verified as merged or tree-equivalent. Only `main` and `dev` remain; tags were retained.
