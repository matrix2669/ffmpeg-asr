# Changelog

All notable matrix2669 fork changes are documented here.

## [Unreleased]

### Added

- Add `FFMPEG_SMART_STATE_DIR` for persistent cache, probe-media, and benchmark-lock storage outside replaceable source directories.
- Add `FFMPEG_SMART_REQUIRE_CACHE` for integrations that must fail clearly instead of benchmarking during stream startup when the capability cache is missing, invalid, or stale.

### Fixed

- Identify capability-cache startup failures with explicit `[ffmpeg-smart]` error codes and configuration exit status `78`.

### Changed

- Reconstructed the architecture decision record from project conversations, implementation history, pull requests, validation evidence, and the related Dispatcharr plugin workflow.

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

[1.0.0]: https://github.com/matrix2669/ffmpeg-asr/tree/v1.0.0
