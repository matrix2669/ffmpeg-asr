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
| `feature/clean-room-rewrite` | feature | active, WIP | `dev` at `7829924588336f1de07f18d944472c429a32c5b1` | `dev` | Replace all remaining inherited runtime and benchmark implementation with independently structured code while preserving documented behavior and tests. |
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

### `feature/clean-room-rewrite`

- Purpose: independently reimplement the adaptive FFmpeg wrapper and both benchmark tools so the maintained project no longer depends on unlicensed upstream source expression.
- Base: `dev` at `7829924588336f1de07f18d944472c429a32c5b1`.
- Intended target: `dev` after complete behavioral, shell, cache, scheduling, Docker/LXC, and hardware validation.
- Scope: replace `ffmpeg-smart.sh`, `benchmark-accel.sh`, and `benchmark-live.sh`; add independently structured implementation modules and regression coverage; update architecture, provenance, user documentation, and decisions.
- Compatibility contract: preserve the documented command line, state-directory behavior, required-cache failure contract, hardware overrides, conservative workload accounting, phase-scoped advanced arguments, fixed MPEG-TS stdout destination, and Dispatcharr source-pin review boundary.
- Clean-room constraints: preserve observable behavior rather than source structure; use new organization, names, control flow, cache representation, logging, comments, and benchmark orchestration; do not copy implementation from unlicensed or copyleft donor code.
- Exclusions: no merge into `dev` or `main`, tag, release, plugin pin update, deployment, upstream submission, force-push, or branch deletion without their separate gates and approval.
- Current state: branch created and recorded; implementation and validation are in progress.
- Validation plan: run `./scripts/validate.sh`, new unit/regression tests, software fallback tests, controlled hardware-probe tests, benchmark lock tests, required-cache tests, and deployment-hardware capacity validation before integration.
- Last verified: `2026-08-29`.

### `contrib/license-clarification`

- Purpose: add an explicit upstream MIT license as isolated licensing work.
- Base: `upstream/main` at `99899d05affa501404ef2d2b926136a80bb87c75`.
- Current head: `c4b14583cec5fc0c839cab10eb517ca9b0c915ce` (`docs: add MIT license`).
- Scope: one new `LICENSE` file naming FiveBoroughs; the branch has no fork-governance or runtime changes.
- State: this unmerged remote branch appeared after the requested branch cleanup completed. It is preserved pending the operator's decision because deleting it would erase concurrent work aimed at the active license blocker; no pull request currently exists.

## Completed branch cleanup

On `2026-08-26`, all feature, fix, integration, safety, and release branches that existed during cleanup were deleted locally and from `origin` after their results were preserved in `CHANGELOG.md` and `DECISIONS.md` and their tips were verified as merged or tree-equivalent. Tags were retained. The later concurrent `contrib/license-clarification` branch is the only additional remote ref and is explicitly recorded above pending operator direction.
