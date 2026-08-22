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
| `feature/reconstruct-decisions` | feature | active | `dev` | `dev` | Reconstruct durable architectural decisions from complete available chat, work, Git, PR, and related-plugin history. |

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

### `feature/reconstruct-decisions`

- Purpose: replace the preliminary decisions file with the rationale, rejected alternatives, superseded experiments, validation evidence, and cross-project contracts established during ffmpeg-asr development.
- Base: `dev` at `a30bd9342abfff1edcca1724621a192389129a32`.
- Intended target: `dev`.
- In scope: `DECISIONS.md` and this branch record.
- Out of scope: runtime behavior, version changes, tagging, releasing, and downstream source-pin changes.
- History reviewed: ChatGPT tasks `FFMpeg-ASR`, `FFmpeg Dispatcharr Profile`, `Mobile Streaming Profile Setup`, and `Dispatcharr Xtream Output Profile`; Codex task `Add multi-GPU FFmpeg-ASR selection`; repository commits and PRs; related FFmpeg Smart plugin source-sync and release history; current code and documentation.
- Validation: pending comparison against the tagged `v1.0.0` implementation and related plugin contract.
- Last verified head: `a30bd9342abfff1edcca1724621a192389129a32`.
- Last verified at: `2026-08-22`.
