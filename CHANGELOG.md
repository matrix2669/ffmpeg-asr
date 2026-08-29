# Changelog

All notable matrix2669 fork changes are documented here.

## [Unreleased]

### Added

- Replace the inherited wrapper and benchmark implementations with independently organized Bash 3-compatible modules for CLI handling, cache data, hardware measurement, adaptive probing, and output policy.
- Add schema-2 tab-delimited capability data that is validated rather than sourced, reuses measurements by hardware signature across safe render-node reassignment, and invalidates the legacy executable cache format.
- Add generated local H.264 and HEVC Main10 fixtures, bounded capacity discovery with 30-second boundary confirmation, exact finite-stdin replay, and focused policy/hardware/pipe regressions.
- Add an evidence-backed provenance and overlap record plus the complete 2026-08-29 old-versus-new software, Docker/LXC, dual-GPU, live-transport, metadata, and performance report.

### Changed

- Keep QSV/VAAPI hardware encoding for HDR-to-SDR while performing mastering-metadata-independent software tone mapping and explicit BT.709 conversion before hardware upload.
- Scope reconnect controls to HTTP(S), redact complete supported network addresses from diagnostics without mixing them into MPEG-TS stdout, and retain a thin status-preserving supervisor only where redaction or captured-pipe replay requires it.
- Identify benchmark-lock owners by PID and Linux process start time, compose lock/sample cleanup, and preserve the baseline 8 Mbps-at-1080p rate formula with its 2 Mbps floor.

### Fixed

- Remove duplicated MPEG-TS program/top-level probe records, prevent P010 H.264 output selection, pass explicit VAAPI filter devices, release implicit-recache locks on every exit path, and preserve the fixed `-f mpegts pipe:1` output contract.
- Restore cache reuse, node-reassignment behavior, weighted two-GPU scheduling, representative Main10 capacity measurement, and logarithmic capacity-boundary search in the independent implementation.

### Safety

- Use the inherited runtime and benchmark files only as historical comparison evidence; no non-trivial inherited implementation block is retained in the rewritten runtime or benchmarks.
- Keep merge, relicensing, tagging, release publication, downstream plugin synchronization, deployment, upstream submission, force-push, and branch deletion behind separate review and authorization gates.

### Validation

- Pass the canonical Bash 3 suite locally and inside the production Dispatcharr image, including cache/state, advanced options, Map All, lock identity, adaptive probing, the full video/audio/HDR policy matrix, hardware command construction, representative Main10 benchmarking, and non-seekable stdin replay.
- Validate both Intel render nodes through QSV and VAAPI, explicit CLI and environment overrides, missing-DRI software fallback, weighted overlap scheduling, 16 benchmark-helper combinations, HTTP redaction, bounded UDP output, decode/metadata comparisons, and repeated startup/long-run performance measurement.

## [1.1.1-beta.1] - 2026-08-27

### Added

- Add adaptive input probing that starts at 1 second/1 MB, retries incomplete selected-stream metadata at 2 seconds/2 MB, and falls back to native FFmpeg defaults only when metadata remains incomplete.
- Validate selected video codec, dimensions, and pixel format plus codec, channels, and sample rate for every selected audio stream before launching FFmpeg.

### Safety

- Apply the successful probe tier to the final FFmpeg input, fail transport errors without increasing probe limits, and keep source URLs and credentials out of tier logs.
- Preserve direct `exec ffmpeg` lifecycle and existing URL, captured-pipe, mapping, profile, and degraded-proxy behavior.

### Validation

- Add deterministic coverage for complete fast metadata, 2-second fallback, default fallback, FFprobe exit-zero incomplete metadata, transport failure, and final-input tier propagation.

## [1.1.0] - 2026-08-26

### Added

- Add persistent state outside replaceable installations, authoritative cache-status reporting, and an integration-opt-in basic stream-copy fallback while required hardware capabilities are unavailable or being rebuilt.
- Add safely quoted phase-scoped expert FFmpeg controls for input, mapping, video tuning, audio, and MPEG-TS output while retaining Smart ownership of hardware selection, encoders, filters, input, and the final pipe.
- Add all-stream and typed custom mapping, explicit render-device selection, and repeatable additional FFmpeg arguments.

### Fixed

- Preserve compatible mapped subtitle, data, and attachment streams through explicit stream-copy codec selection.
- Retain the benchmark lock for the complete top-level recache so managed integrations remain in degraded stream-copy mode until benchmarking finishes.
- Report hardware-stale caches as unusable instead of treating file existence as cache health.

### Validation

- Promote the fully validated beta.7 tree without runtime changes. Canonical tests, two-GPU 18/15 capacity measurement, active-scan fallback, lock ownership, and live four-stream Map All with copied secondary audio and DVB subtitle pass.
- Publish only the immutable stable tag. No GitHub Release or distributable archive is created while inherited licensing remains unresolved.

## [1.1.0-beta.7] - 2026-08-26

### Fixed

- Explicitly stream-copy mapped subtitle, data, and attachment streams on normal video-copy and video-transcode paths so Map All can carry MPEG-TS-compatible auxiliary streams such as DVB subtitles without FFmpeg attempting automatic encoder selection.
- Keep `.benchmark.lock` owned by the top-level recache process so exits from command substitutions and concurrent benchmark subshells cannot expose normal Smart processing while the hardware benchmark is still running.

## [1.1.0-beta.6] - 2026-08-26

### Fixed

- Correct the scoped-command validation counts for the added degraded proxy path and make count failures explicit on shells whose `errexit` behavior did not stop the prior bare assertions.

## [1.1.0-beta.5] - 2026-08-26

### Added

- Add integration-opt-in degraded `-c copy` proxy fallback when a required capability cache is unusable or a hardware benchmark is active.
- Add an optional per-invocation marker so managed integrations can re-display dismissed degraded-mode notifications.

### Safety

- Keep standalone behavior unchanged by default and never substitute CPU transcoding for unavailable Smart hardware policy.

## [1.1.0-beta.4] - 2026-08-26

### Added

- Add a read-only `--cache-status` interface so managed consumers can distinguish valid, missing, invalid, and hardware- or policy-stale capability caches without triggering a benchmark.

## [1.1.0-beta.3] - 2026-08-25

### Added

- Add phase-scoped input, mapping, transcode-video, audio, and MPEG-TS/mux FFmpeg controls with inherited, additive, and replacement modes.
- Add all-stream and custom mapping modes without giving advanced options ownership of the input, hardware encoder, hardware filters, container, or output destination.

### Changed

- Apply audio and mux overrides consistently on both video-copy and video-transcode paths.
- Preserve `-ffmpeg-option` as a backward-compatible alias for additive MPEG-TS/output options.

### Safety

- Reject wrapper-owned structural FFmpeg switches and preserve every advanced argument as an array element without shell evaluation.

## [1.1.0-beta.2] - 2026-08-25

### Added

- Add repeatable `-ffmpeg-option` passthrough arguments for safely preserving exact advanced FFmpeg output options without shell evaluation.

## [1.1.0-beta.1] - 2026-08-22

### Added

- Add `FFMPEG_SMART_STATE_DIR` for persistent cache, probe-media, and benchmark-lock storage outside replaceable source directories.
- Add `FFMPEG_SMART_REQUIRE_CACHE` for integrations that must fail clearly instead of benchmarking during stream startup when the capability cache is missing, invalid, or stale.

### Fixed

- Identify capability-cache startup failures with explicit `[ffmpeg-smart]` error codes and configuration exit status `78`.

### Changed

- Reconstructed the architecture decision record from project conversations, implementation history, pull requests, validation evidence, and the related Dispatcharr plugin workflow.

### Validation

- Validated the tagged wrapper through the Dispatcharr beta plugin: managed directory replacement preserved persistent state, a confirmed two-GPU recache measured A310 capacity 18 and UHD 770 capacity 15, and a complete 10-second 4K30 `pipe:0` transcode selected the A310 and produced constrained 1280×720 output.

## [1.0.0] - 2026-08-22

### Added

- Conditional output constraints for resolution, bitrate, audio channels, SDR conversion, and deinterlacing.
- Per-accelerator 10-bit capability tracking and explicit render-node overrides.
- Capacity-aware multi-GPU scheduling using real concurrent-transcode measurements and weighted workload accounting.
- Cache-only hardware benchmarking, reusable hardware-keyed capacity results, and benchmark locking.
- Non-seekable standard-input support for live pipeline integrations.
- Hybrid maintained-fork guidance, semantic version metadata, upstream provenance, and automated validation.

### Changed

- Prefer stream copy whenever the input already satisfies every resolved output constraint.
- Use conditional audio normalization and constrained VBR behavior.
- Treat `ffmpeg-asr` as the canonical, commit-pinned source for the self-contained Dispatcharr FFmpeg Smart plugin.
- Replace the historical commit-hash version hook with synchronized semantic project and script versions.

### Release status

- Tagged as `v1.0.0` without a GitHub Release or attached ZIP while upstream licensing remains unresolved.

[Unreleased]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.1-beta.1...HEAD
[1.1.1-beta.1]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.0...v1.1.1-beta.1
[1.1.0-beta.7]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.0-beta.6...v1.1.0-beta.7
[1.1.0-beta.6]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.0-beta.5...v1.1.0-beta.6
[1.1.0-beta.5]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.0-beta.4...v1.1.0-beta.5
[1.1.0-beta.4]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.0-beta.3...v1.1.0-beta.4
[1.1.0-beta.3]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.0-beta.2...v1.1.0-beta.3
[1.1.0-beta.2]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.1.0-beta.1...v1.1.0-beta.2
[1.1.0-beta.1]: https://github.com/matrix2669/ffmpeg-asr/compare/v1.0.0...v1.1.0-beta.1
[1.0.0]: https://github.com/matrix2669/ffmpeg-asr/tree/v1.0.0
