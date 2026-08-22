# Agent Guidance

## Purpose

`ffmpeg-asr` is the canonical matrix2669 source for `ffmpeg-smart.sh`, an adaptive live-stream normalizer with hardware-accelerated fallback. The related `Dispatcharr-FFmpeg-Smart-Plugin` embeds a reviewed, commit-pinned copy; changes here never silently mutate a published plugin release.

This repository is a hybrid maintained fork of `FiveBoroughs/ffmpeg-asr`. It follows a standalone `main`/`dev` lifecycle for matrix2669 development while preserving clean, optional upstream contributions.

## Architecture

- `ffmpeg-smart.sh` resolves stream-copy versus transcode policy, probes hardware, caches capabilities and concurrent capacity, and launches FFmpeg.
- `benchmark-accel.sh` downloads samples and benchmarks available encoders.
- `benchmark-live.sh` exercises the production wrapper against local or live media.
- `.capabilities.cache`, probe media, benchmark samples, benchmark results, and `.benchmark.lock` are runtime state and must not be committed or packaged as source. Consumers installed under replaceable directories set `FFMPEG_SMART_STATE_DIR` to a persistent writable location; standalone use defaults to the script directory.
- The Dispatcharr plugin pins this repository, path, commit, and checksum in `ffmpeg-smart-profiles/FFMPEG_SMART_SOURCE.json`. Synchronization must remain reviewable through its check/sync workflows.

## Non-negotiable behavior

- Preserve explicit `DRI_DEVICE`, `QSV_DEVICE`, and `VAAPI_DEVICE` overrides.
- Read wrapper workload markers from `/proc/<pid>/environ`; count unknown external FFmpeg work conservatively.
- Capacity changes require simultaneous real-time workload validation: short boundary bracketing followed by longer confirmation. Account for 1080p60 and other workloads by weighted pixel rate.
- Keep automatic scheduling self-contained; do not introduce required shared services or mutable cross-process state without an accepted decision.
- Do not silently update the Dispatcharr plugin or an existing release. Source synchronization must produce a reviewable change pinned to an immutable commit.
- Preserve the explicit required-cache failure contract for managed integrations: missing, invalid, or stale required caches identify `ffmpeg-smart` on stderr and exit before media probing.

## Branch workflow

- `main` is the stable matrix2669 line and source for normal tags and Releases.
- `dev` integrates the next matrix2669 version.
- Fork-owned `feature/*` and `fix/*` branches start from and return to `dev`.
- Potential upstream work uses `contrib/*` branches based strictly on freshly fetched `upstream/main`.
- Never open an upstream pull request from this fork's `main`, `dev`, or fork-owned feature history. Transplant only the focused upstream-suitable change onto `contrib/*`.
- Record all current branches in `BRANCHES.md`. Remove deleted-branch entries after their durable results are captured in `CHANGELOG.md` and `DECISIONS.md`.

Before beginning or submitting an upstream contribution, refresh and re-review the upstream tree, instructions, contribution policy, license, CI, relevant issues, and overlapping pull requests. Update `UPSTREAM.md` when anything changes.

## Version and release requirements

- `VERSION` is the canonical semantic version without a `v` prefix.
- The `VERSION` embedded in `ffmpeg-smart.sh`, a normal tag, changelog heading, and published Release must agree.
- Beta tags may be created from tested `dev` commits as `vMAJOR.MINOR.PATCH-beta.N`.
- Stable tags use `vMAJOR.MINOR.PATCH` on `main`.
- Follow `RELEASE.md`. Never move a published tag or replace a published artifact.
- Do not publish a GitHub Release or distributable project ZIP while inherited upstream licensing remains unresolved. A Git tag alone is not a license grant.

## Validation

Run at minimum:

```bash
./scripts/validate.sh
```

Behavioral changes also require applicable software fallback, hardware-path, Docker/LXC, live stream, cache migration, and real concurrency tests. Re-measure capacity on the deployment hardware; recorded capacities are not portable defaults.

## Future-agent checklist

- Read `DECISIONS.md`, `UPSTREAM.md`, `BRANCHES.md`, and the relevant history.
- Confirm the branch base and intended delivery path before editing.
- Keep user documentation, agent guidance, decisions, and history in their designated files.
- Test proportionately to behavioral and hardware risk.
- Verify downstream source pins when promoting canonical script changes.
