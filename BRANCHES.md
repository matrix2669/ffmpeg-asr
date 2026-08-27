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
| `feature/degraded-proxy-fallback` | feature | merged | `dev` | `dev` | Add an opt-in stream-copy fallback for managed integrations when Smart capabilities are unavailable. |
| `fix/cache-status-reporting` | fix | merged | `dev` | `dev` | Expose a read-only authoritative cache-validity check for managed consumers. |
| `fix/beta5-validation` | fix | merged | `dev` | `dev` | Correct the beta.5 Linux validation expectation without moving the immutable tag. |
| `fix/map-all-benchmark-lock` | fix | merged | `dev` | `dev` | Copy mapped auxiliary streams explicitly and keep the benchmark lock owned by the top-level recache process. |

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
- Validation: `scripts/validate.sh` passes persistent-state, required-cache, degraded-proxy, scoped-options, shell-syntax, version-agreement, and release-metadata checks for corrective beta.6; workspace validation, exact downstream beta.8 pin/checksum, 37 plugin tests, immutable plugin archive inspection, source/plugin/registry GitHub workflows, development-registry publication, and `git diff --check` pass. Live Dispatcharr fallback validation remains pending.
- Last verified head: immutable `v1.1.0-beta.6` at `aeff09204000f58aa6fdd3a14781935f77a0823a`.
- Last verified at: `2026-08-26`

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

### `feature/degraded-proxy-fallback`

- Purpose: keep managed streams available through a basic FFmpeg stream-copy proxy when a required capability cache is missing, invalid, stale, unavailable, or being rebuilt.
- Base: `dev` at `d185a0e1d577cfeaf65106f392a64b5d9d4f5a9d` after refreshing project governance and remote state.
- Intended target: `dev` after focused fallback, cache, benchmark-lock, marker, and downstream plugin validation.
- Scope: an integration-opt-in degraded proxy mode, per-invocation notification marker, cache/lock routing, focused tests, user/developer guidance, and durable decision history.
- Exclusions: no automatic benchmark, CPU transcode substitute, hardware benchmark-policy or capacity change, native/custom FFmpeg mode, Dispatcharr core change, stable release, or upstream contribution.
- Related work: `Dispatcharr-FFmpeg-Smart-Plugin` branch `feature/degraded-proxy-fallback` enables the canonical mode and owns persistent Dispatcharr notification behavior.
- Result: finalized source commit `288f5675afa64b3876f0f3682702e77d80b962a3` merged into `dev` at `fc5b0d7`; immutable tag `v1.1.0-beta.5` resolves to `4fafc8b5af300d6e47413cfb9cf8409fef7c2201` and remains unchanged.
- Validation: fallback behavior tests passed, but beta.5 GitHub runs `33014299366` and `33014301559` exposed a stale two-path scoped-command test expectation after the third proxy path was added. Corrective beta.6 updates only version/release metadata and validation, leaving runtime fallback behavior unchanged. Live Dispatcharr validation remains pending.
- Started: `2026-08-26`.

### `fix/beta5-validation`

- Purpose: correct the stale scoped-command occurrence counts exposed by the beta.5 Linux workflow and make those assertions fail reliably across supported development shells.
- Base: `dev` at `4fafc8b5af300d6e47413cfb9cf8409fef7c2201` after the immutable beta.5 tag and development integration were published.
- Intended target: `dev`, followed by corrective immutable tag `v1.1.0-beta.6` and an exact downstream plugin repin.
- Scope: test expectations for the third degraded-proxy input/map/mux construction path, explicit count assertion failures, beta.6 metadata, changelog, and branch ledger.
- Exclusions: no runtime fallback, FFmpeg command, cache, hardware selection, capacity, notification-marker, stable release, or upstream-contribution behavior change; do not move or replace `v1.1.0-beta.5`.
- Reported evidence: GitHub workflow runs `33014299366` and `33014301559` failed after the state/fallback tests passed because the scoped-options test still expected two input/map/mux construction sites; the reviewed wrapper now has three by design.
- Result: source commit `ef7cb2d` merged into `dev` at `d217009`; immutable tag `v1.1.0-beta.6` resolves to reviewed integration commit `aeff09204000f58aa6fdd3a14781935f77a0823a`, which plugin `v0.2.0-beta.8` pins exactly and `dispatcharr-plugins:dev` advertises.
- Validation: `scripts/validate.sh` passes the persistent-state/fallback suite, scoped FFmpeg option suite with explicit three-path counts, shell syntax, version agreement, and release metadata. Workspace validation, tag GitHub run `33015471132`, exact downstream source/checksum verification, 37 plugin tests, plugin tag run `33015811503`, immutable archive inspection, registry run `33016050222`, public raw-manifest agreement, and `git diff --check` pass. Live Dispatcharr validation remains pending.
- Started: `2026-08-26`.

### `fix/map-all-benchmark-lock`

- Purpose: correct live beta.6 behavior where Map All failed on a single-video MPEG-TS source containing DVB subtitles and command-substitution or benchmark-worker subshell exits removed the shared benchmark lock while the top-level recache remained active.
- Base: `dev` at `504a67cc4e6954fa0dbd2396ec89c3a2e2cecd31` after refreshing `origin` and `upstream` and reconciling workspace standards revision `sha256:6456d4a722cfca0a03e6bce3d698208c844a114953c62d0fe757789d48f1c794`.
- Intended target: `dev`, followed by an immutable corrective beta tag and exact downstream plugin synchronization.
- Scope: explicit subtitle/data/attachment stream-copy codec selection on normal Smart output paths, top-level benchmark-lock ownership, focused regressions, version/release metadata, user guidance, and durable decision history.
- Exclusions: no change to video/audio Smart policy, hardware selection, capacity measurement, mapping's exactly-one-video requirement, degraded proxy codec policy, upstream contribution, stable release, GitHub Release, or distributable ZIP.
- Live evidence: a one-video/two-audio/DVB-subtitle source mapped with `-map 0` exited with FFmpeg status 8 because MPEG-TS had no automatic subtitle encoder; during a real two-GPU recache, PID 86932 remained active after `.benchmark.lock` disappeared and managed starts followed normal Smart/audio policy instead of degraded `-c copy` fallback.
- Result: source commit `7e7b78c` merged into `dev` at `6a735d61113646153aef5bf1a1c0a5667b1331e9`; immutable tag `v1.1.0-beta.7` resolves to that reviewed integration commit and is pinned exactly by plugin `v0.2.0-beta.11`.
- Validation: `scripts/validate.sh`, workspace reconciliation, complete-diff review, and `git diff --check` pass; dev workflow `33024572011` and tag workflow `33024640090` pass. The installed beta.11 service-user recache retained owner lock PID 117623 throughout child probes and concurrent workers, routed a live managed start through basic video/audio stream copy, kept the persistent bypass notification active, and completed with capacities 18 and 15. Map All then started stream 128120 without retry and produced one HEVC video, two copied AAC tracks, and one copied DVB subtitle in MPEG-TS. A maintenance-shell launch as root was non-authoritative because Dispatcharr's unprivileged worker could not signal that cross-UID PID; repeating through the normal `dispatch` service UID passed.
- Started: `2026-08-26`.
