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
| `feature/adaptive-input-probing` | feature | active dependency | `dev` at `7829924588336f1de07f18d944472c429a32c5b1` | `dev` | Own the accepted metadata-validated adaptive probing behavior being absorbed by the clean-room rewrite. |
| `feature/clean-room-rewrite` | feature | active, validation complete | `dev` plus `feature/adaptive-input-probing` at `ecc64244dae2c0e80761da6f16be92d95b91d29a` | `dev` | Replace all remaining inherited runtime and benchmark implementation with independently structured code while preserving every accepted behavior and test contract. |
| `contrib/license-clarification` | upstream contribution | active, pending operator decision | `upstream/main` | `upstream/main` | Propose an explicit upstream MIT license without mixing fork-owned changes. |

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

### `feature/adaptive-input-probing`

- Purpose: shorten normal live-input startup while retaining complete selected-stream metadata and safe fallback for delayed audio headers.
- Base and target: `dev` at `7829924588336f1de07f18d944472c429a32c5b1`; target `dev` after validation.
- Current head: `ecc64244dae2c0e80761da6f16be92d95b91d29a` (`feat: add adaptive input probing`).
- Scope: accepted adaptive tier selection, selected-stream metadata validation, final-input tier propagation, focused tests, documentation, and ADR-022.
- Relationship: this branch is an explicit source dependency of `feature/clean-room-rewrite`. The rewrite must preserve ADR-022 and its tests; do not integrate both branches independently into `dev` after the rewrite supersedes the implementation.
- Publication state: prior beta authorization did not authorize stable promotion, a GitHub Release, or a distributable archive.
- Last reviewed: `2026-08-29`.

### `feature/clean-room-rewrite`

- Purpose: independently reimplement the adaptive FFmpeg wrapper and both benchmark tools so the maintained project no longer depends on unlicensed upstream source expression.
- Base: `dev` at `7829924588336f1de07f18d944472c429a32c5b1`, with the accepted behavior from `feature/adaptive-input-probing` at `ecc64244dae2c0e80761da6f16be92d95b91d29a` merged before implementation.
- Intended target: `dev` after complete behavioral, shell, cache, scheduling, Docker/LXC, and hardware validation.
- Scope: replace `ffmpeg-smart.sh`, `benchmark-accel.sh`, and `benchmark-live.sh`; add independently structured implementation modules and regression coverage; update architecture, provenance, user documentation, and decisions.
- Compatibility contract: preserve the documented command line, adaptive input probing, state-directory behavior, required-cache failure contract, hardware overrides, conservative workload accounting, phase-scoped advanced arguments, fixed MPEG-TS stdout destination, and Dispatcharr source-pin review boundary.
- Clean-room constraints: preserve observable behavior rather than source structure; use new organization, names, control flow, cache representation, logging, comments, and benchmark orchestration; do not copy implementation from unlicensed or copyleft donor code.
- Exclusions: no merge into `dev` or `main`, tag, release, plugin pin update, deployment, upstream submission, force-push, or branch deletion without their separate gates and approval.
- Current state: the independent runtime, benchmark tools, schema-2 cache, regression suite, provenance record, and validation report are complete. The branch is checkpointed for review and remains intentionally unintegrated pending a separate decision-bearing gate.
- Validation: `./scripts/validate.sh` passes locally under Bash 3 and in the production Dispatcharr image. Controlled dual-GPU QSV/VAAPI probes, explicit-device and environment overrides, hardware-signature cache reuse, weighted overlap scheduling, missing-DRI software fallback, adaptive URL/pipe probing, exact finite-stdin replay, HTTP credential redaction, bounded UDP output, old-versus-new media/decode metadata, and repeated startup/long-run measurements are recorded in `docs/validation-2026-08-29.md`.
- Provenance: `PROVENANCE.md` records the consulted sources, clean-room boundary, independent design choices, and file-level overlap review. ADR-023 records the durable architecture and narrowly superseded lifecycle/lock clauses.
- Publication state: only the feature-branch checkpoint is authorized. It has not been merged to `dev` or `main`; no version, tag, GitHub Release, distributable archive, downstream plugin pin, deployment, upstream submission, force-push, or branch deletion is part of this checkpoint.
- Last verified: `2026-08-29`.

### `contrib/license-clarification`

- Purpose: add an explicit upstream MIT license as isolated licensing work.
- Base: `upstream/main` at `99899d05affa501404ef2d2b926136a80bb87c75`.
- Current head: `c4b14583cec5fc0c839cab10eb517ca9b0c915ce` (`docs: add MIT license`).
- Scope: one new `LICENSE` file naming FiveBoroughs; the branch has no fork-governance or runtime changes.
- State: preserved pending the operator's decision because no upstream response or merged license grant has been recorded.

## Completed branch cleanup

On `2026-08-26`, completed feature, fix, integration, safety, and release branches were deleted after their durable results were captured. The current branches above remain active and must not be deleted while another recorded branch or composition depends on them.
