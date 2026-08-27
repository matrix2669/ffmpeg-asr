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
| `release/v1.1.0` | release | active | `main` | `main` | Promote the fully validated beta.7 state to stable `v1.1.0` without a GitHub Release or distributable archive. |

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
- Last verified head: `ed847e8` plus the branch-ledger cleanup that removed completed branch records.
- Last verified at: `2026-08-22`

### `release/v1.1.0`

- Purpose: promote the complete validated `dev` state through beta.7 to stable `v1.1.0`.
- Base: `main` at `494574688a26c347f42271540d2be7f7744b15bc` after refreshing all remote branches and tags.
- Intended target: `main`, followed by immutable tag `v1.1.0` and synchronization back to `dev`.
- Scope: merge the validated beta cycle, finalize stable version/changelog metadata, rerun the complete gate, tag, and record publication evidence.
- Exclusions: no GitHub Release, distributable ZIP, license claim, upstream submission, new runtime behavior, or unrelated dependency change.
- Approval: the user explicitly approved stable branch and tag promotion on `2026-08-26` while directing that no Release be created until licensing is resolved.
- Validation: pending stable-tree reconciliation and complete release validation.
- Started: `2026-08-26`.
