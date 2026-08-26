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
| `feature/additional-ffmpeg-options` | feature | merged | `dev` | `dev` | Add safely quoted, output-scoped passthrough arguments for the final FFmpeg command. |
| `feature/scoped-ffmpeg-options` | feature | merged | `dev` | `dev` | Add Smart-owned, phase-scoped FFmpeg defaults and expert overrides without surrendering hardware selection. |
| `fix/cache-status-reporting` | fix | merged | `dev` | `dev` | Expose a read-only authoritative cache-validity check for managed consumers. |

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
- Validation: `scripts/validate.sh`, standalone persistent-state/cache failure tests, downstream plugin tests, a managed plugin-directory replacement, confirmed A310/UHD 770 recache, full Dispatcharr restart, and complete 10-second 4K30 `pipe:0` transcode pass for `v1.1.0-beta.1`.
- Last verified head: the tested `v1.1.0-beta.1` source state including persistent-state and required-cache handling.
- Last verified at: `2026-08-22`

### `feature/additional-ffmpeg-options`

- Purpose: add a repeatable canonical wrapper argument for exact additional FFmpeg output arguments and document its placement and safety boundary.
- Base: current `dev` at `5f12499`.
- Intended target: `dev` after focused wrapper validation and downstream plugin synchronization.
- Result: source commit `babd056` merged into `dev` at `f53f824`; annotated tag `v1.1.0-beta.2` resolves to reviewed integration commit `6659e1b`.
- Scope: `ffmpeg-smart.sh`, wrapper documentation, tests, and the durable decision record.
- Exclusions: no changes to automatic GPU scheduling, managed codec/filter defaults, capacity benchmarking, releases, tags, or upstream contribution history.
- Related work: `Dispatcharr-FFmpeg-Smart-Plugin` branch `feature/additional-ffmpeg-options` will expose the field and pin the reviewed canonical wrapper commit.
- Validation: `scripts/validate.sh`, persistent-state and required-cache regression tests, focused argument-boundary checks for spaces and shell metacharacters, missing-value rejection, device-pre-scan isolation, shell syntax, version agreement, and `git diff --check` pass for `v1.1.0-beta.2`; the published `dev` workflow completed successfully.
- Last verified at: `2026-08-25`.

### `feature/scoped-ffmpeg-options`

- Purpose: replace the single output-tail passthrough boundary with explicit input, mapping, video-tuning, audio, and MPEG-TS/mux argument groups while retaining FFmpeg Smart's hardware, encoder, filter, input, and final-output ownership.
- Base: `dev` at `0f14a05`.
- Intended target: `dev` after focused wrapper validation and downstream plugin synchronization.
- Result: source commit `f95bca0` merged into `dev` at `2f48909`; annotated tag `v1.1.0-beta.3` resolves to reviewed integration commit `4addad2`.
- Scope: canonical wrapper arguments and placement, inherited/add/replace behavior, structural-option validation, backward compatibility for `-ffmpeg-option`, tests, user/developer documentation, and decision history.
- Exclusions: no custom/native FFmpeg mode, no arbitrary input or output destination, no replacement of the hardware-selected video encoder or hardware filter graph, no scheduler/capacity changes, no upstream contribution, and no stable release.
- Related work: `Dispatcharr-FFmpeg-Smart-Plugin` branch `feature/scoped-ffmpeg-options` will expose the scoped Smart controls and pin the reviewed canonical commit.
- Validation: `scripts/validate.sh`, persistent-state and required-cache regressions, focused copy/transcode command construction, all scoped modes, exact argument boundaries, legacy alias compatibility, structural-option rejection, exactly-one-video mapping enforcement, shell syntax, version agreement, and `git diff --check` pass for `v1.1.0-beta.3`; the published tag resolves correctly and the `dev` workflow completed successfully.
- Last verified at: `2026-08-25`.

### `fix/cache-status-reporting`

- Purpose: let managed consumers distinguish a cache that merely exists from one that is valid for the current script, policy, and hardware fingerprint.
- Base: `dev` at `99536f5` after refreshing `origin` and `upstream` and confirming workspace standards revision `sha256:6456d4a722cfca0a03e6bce3d698208c844a114953c62d0fe757789d48f1c794`.
- Intended target: `dev`, followed by approved immutable tag `v1.1.0-beta.4` and downstream plugin synchronization.
- Result: source commit `59306a1` merged into `dev` at `6afa184`; annotated tag `v1.1.0-beta.4` resolves to reviewed integration commit `fb990e9`.
- Scope: a read-only machine-stable cache-status interface, required-cache contract reuse, focused tests, user/developer guidance, and `v1.1.0-beta.4` metadata.
- Exclusions: no benchmark or cache rebuild side effect, no hardware-selection or capacity change, no upstream contribution, no downstream plugin publication, and no stable tag, Release, or distributable ZIP.
- Related work: `Dispatcharr-FFmpeg-Smart-Plugin v0.2.0-beta.6` pins commit `fb990e9`, consumes the status interface, repairs direct-launch executable modes, and is advertised through `dispatcharr-plugins:dev`.
- Validation: `scripts/validate.sh` passes valid, missing, invalid, stale, conflicting-mode, required-cache, scoped-options, shell-syntax, and version-agreement checks for `v1.1.0-beta.4`; workspace reconciliation and `git diff --check` pass, and the published tag resolves correctly. The downstream beta.6 pin, source checksum, tests, tag archive, and registry publication pass; installed-plugin validation remains pending.
- Started: `2026-08-26`.
