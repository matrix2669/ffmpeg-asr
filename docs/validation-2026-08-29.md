# Clean-room rewrite validation — 2026-08-29

## Scope and immutable inputs

- Old baseline: `7829924588336f1de07f18d944472c429a32c5b1` (`dev` at branch creation).
- Accepted adaptive-probing dependency: `ecc64244dae2c0e80761da6f16be92d95b91d29a`.
- Rewrite remote head at validation start: `3c1b1eca23e3857a29a3b54cf6f5d7736ef133da`.
- Final rewrite: the commit containing this record on `feature/clean-room-rewrite`; the exact pushed ref is verified separately because a commit cannot contain its own hash.
- Workspace standards source: `matrix2669/workspace` `4102563425631edef07899ed1cc8fc95423e05f6`.
- Standards reconciliation revision: `sha256:6456d4a722cfca0a03e6bce3d698208c844a114953c62d0fe757789d48f1c794`, check passed.
- Test root: `/tmp/ffmpeg-asr-cleanroom-validation-20260829.3jz1oK` on `iptv`.
- Separate immutable old and prevalidation-new worktrees were used; the production checkout was not switched.

The starting rewrite ref contained branch documentation and the adaptive-probing merge, but not the claimed runtime rewrite. The implementation and validation therefore replaced the inherited runtime and both benchmark helpers on the owning feature branch before comparison.

## Host and container inventory

- Host: `Linux iptv 7.0.14-8-pve #1 SMP PREEMPT_DYNAMIC PMX 7.0.14-8 (2026-07-28T10:28Z) x86_64`.
- Container boundary: unprivileged LXC UID/GID maps `0 -> 100000 (1000)`, `1000 -> 1000 (1)`, `1001 -> 101001 (64535)`.
- Dispatcharr image: `ghcr.io/dispatcharr/dispatcharr:latest`; `/dev/dri` mapped `rwm`; relevant mounts `/opt/dispatcharr/data:/data`, `/mnt/media:/mnt/media`, `/dev/shm:/dev/shm`.
- FFmpeg/FFprobe: `8.1.2`, GCC 13, with `libvpl`, QSV, VAAPI, CUDA/NVENC, Vulkan, OpenCL, x264, x265, and the other build options recorded by `ffmpeg -version`.
- Hardware acceleration methods: `vdpau`, `cuda`, `vaapi`, `qsv`, `drm`, `opencl`, `vulkan`.
- QSV/VAAPI encoders observed: H.264, HEVC, AV1, MJPEG, MPEG-2; VAAPI also VP8/VP9, QSV also VP9. QSV decoders included AV1, H.264, HEVC, MJPEG, MPEG-2, VC-1, VP8, VP9, and VVC.
- `/dev/dri/renderD128`: PCI `0000:00:02.0`, `8086:a7a0`, revision `04`, i915, Intel Raptor Lake-P Iris Xe integrated graphics.
- `/dev/dri/renderD129`: PCI `0000:03:00.0`, `8086:56a6`, revision `05`, subsystem `172f:4019`, i915, Intel Arc A310.
- Both render nodes were character devices `226:128/129`, mode `0666`, visible as `nobody:nogroup` in the LXC.
- `intel_gpu_top` and `vainfo` were unavailable, so GPU engine-percentage telemetry could not be collected.

## Repository suites

The baseline suite passed as `Validated ffmpeg-asr 1.1.0`. The prevalidation branch suite passed as `Validated ffmpeg-asr 1.1.1-beta.1`. The final rewrite suite passed under local macOS Bash 3 and inside the Dispatcharr Linux image.

Final rewrite coverage includes:

- persistent state, schema migration, required-cache, fallback marker, and fallback/refusal exit statuses;
- phase-scoped arguments, structural-option rejection, shell safety, fixed `pipe:1`, and Map All auxiliary copy;
- benchmark owner/subshell behavior, PID-start lock identity, implicit-rebuild cleanup, and stale-lock recovery;
- adaptive fast/expanded/default probing, duplicate MPEG-TS stream suppression, transport failure, HTTP-only reconnect, and secret redaction;
- video/audio/resolution/bitrate/deinterlace/HDR policy;
- representative Main10 benchmark command construction and VAAPI filter-device construction;
- exact stdin opening-sample replay.

Both rewritten benchmark entrypoints also ran successfully in the Dispatcharr image. A one-second/one-run accelerator scan passed all 16 QSV/VAAPI H.264/HEVC normal/low-power combinations across both nodes. `benchmark-live.sh 5 local` returned status 0 with valid 1280x720 H.264/AAC MPEG-TS.

## Capability and cache comparison

| Area | Baseline | Rewrite | Result |
|---|---|---|---|
| Clean-cache recache | Passed | Passed after correction to representative HEVC Main10 fixture | Equal |
| Cache representation | Sourced shell assignments | Strict schema-2 tab-delimited data, never sourced | Rewrite better |
| `--cache-status` | Stable status contract | `valid/missing/invalid/stale/unavailable`, non-valid status 78 | Equal |
| Legacy cache | Loaded as shell | Classified invalid and rebuilt, never executed | Rewrite better |
| Signature reuse | Existing hardware-keyed behavior | Reused both measured records under CLI/environment override and simulated render-node swap | Equal |
| Explicit overrides | Supported | `DRI_DEVICE`, `QSV_DEVICE`, `VAAPI_DEVICE`, and CLI QSV/VAAPI options passed | Equal |
| Per-node acceleration | QSV/VAAPI available on both | QSV and VAAPI produced decodable HEVC on both nodes | Equal |
| 10-bit report | True decode/encode | True decode/encode on both nodes | Equal |
| Low power | Working combinations recorded | All eight per-node codec/accelerator low-power helper cases passed | Equal |
| Lock lifecycle | PID owner | PID plus process-start identity; no lock left after implicit rebuild | Rewrite better |
| Automatic software fallback | Supported | No-DRI cache selected `software/hevc`; output decoded | Equal |

Full baseline recache reported Arc primary capacity 18 and iGPU secondary 15. The corrected rewrite recache reported Arc 14 and iGPU 11, after the initially defective H.264 capacity fixture had overstated Arc as 22. These capacity numbers are not strict old/new throughput equivalents: the implementations use different generated/downloaded Main10 content and candidate command construction. The rewrite result is intentionally conservative and was confirmed at the stable level and the next rejected level for 30 seconds. A strict capacity delta remains inconclusive, not evidence that the hardware lost throughput.

Final rewrite cache:

- best path: VAAPI/H.264, low-power 0;
- Arc `renderD129`: speed 11.5x, confirmed capacity 14;
- iGPU `renderD128`: speed 10.9x, confirmed capacity 11;
- both: 10-bit decode and encode true;
- primary Arc, secondary iGPU;
- final `--cache-status`: `FFMPEG_SMART_CACHE_STATUS=valid`, exit 0.

## Media comparison

Controlled inputs covered H.264/AAC 1080p and 480p, HEVC/AAC 1080p, MPEG-2 interlaced/AC-3 5.1, verified HEVC Main10 PQ/BT.2020, and H.264 with two AAC tracks.

| Feature | Baseline | Rewrite | Classification |
|---|---|---|---|
| Compatible H.264 copy | Pass; byte-identical output | Pass; byte-identical to baseline | Equal |
| Compatible HEVC copy | Pass; byte-identical output | Pass; byte-identical to baseline | Equal |
| H.264 -> HEVC | Pass | Pass, same Main profile/geometry/rate | Equal |
| HEVC -> H.264 | Pass | Pass, same High profile/geometry/rate | Equal |
| 1080p -> 720p | 1280x720 pass | 1280x720 pass | Equal |
| No lower-resolution upscale | 854x480 copy | Byte-identical 854x480 copy | Equal |
| 1 Mbps video ceiling | Pass | Pass; constrained output and valid TS | Equal |
| AAC copy | Pass | Byte-identical copy | Equal |
| AC-3 5.1 -> AAC stereo | Pass | Pass, AAC 2-channel | Equal |
| No upmix | Mono remained mono | Byte-identical mono output | Equal |
| Interlaced -> progressive | Pass | Pass at 30000/1001 | Equal |
| Progressive plus `-deint` | Copy | Byte-identical copy | Equal |
| Main10/PQ preservation | Main10, P010, BT.2020/PQ | Same metadata and byte-identical output | Equal |
| PQ HDR -> SDR without mastering side data | Failed, status 218 | H.264 8-bit BT.709, decode pass | Rewrite better |
| Map all MPEG-TS streams | One video/two AAC pass | Byte-identical output | Equal |
| Finite stdin replay | Failed after probe consumed opening data, status 183 | Complete byte-identical 10.03-second output | Rewrite better |
| HTTP input | Not needed for baseline comparison | Pass; secret query absent from log | Rewrite better safety |
| Bounded UDP live input | Not production-tested | Wrapper/capture exit contract passed; artifact decoded but opened mid-stream without initial video parameters | Inconclusive live-join gap |
| QSV both Intel nodes | Available | Both produced decodable HEVC | Equal |
| VAAPI both Intel nodes | Available | Both produced decodable HEVC | Equal |
| Software | Available | Explicit and automatic no-DRI outputs decoded | Equal |

All final finite outputs decoded with FFmpeg status 0. Representative finite outputs had zero warning-level decode errors and zero per-stream DTS regressions; the interlaced sample emitted only FFmpeg's benign “Guessed Channel Layout: 5.1” message. Copy/no-op outputs were byte-identical between old and new. The 30-second UDP join artifact decoded with status 0 and monotonic DTS, but its file began mid-stream and FFprobe could not infer initial video geometry; this is retained as a bounded-live limitation rather than promoted to a clean finite-file result.

## Performance

Five warm repetitions inside one container isolated remux startup:

| Path | Median elapsed |
|---|---:|
| Direct FFmpeg equivalent | 23 ms |
| Baseline wrapper | 94 ms |
| Rewrite wrapper | 104 ms |

The rewrite adds about 10 ms median startup over the baseline due to stricter cache parsing, modular policy, and diagnostic handling. This is measurable but small relative to network/probe startup and did not change output correctness.

On the same looped H.264 input, automatic Arc device, HEVC target, and 18-second window after restoring the baseline 8 Mbps rate formula:

- baseline: 454 fps, reported 15.1x, 8.14 Mbps mux output, 25.16% CPU snapshot, 204.7 MiB, 39 PIDs;
- rewrite: 435 fps, reported 18.1x, 6.96 Mbps mux output, 27.48% CPU snapshot, 202.6 MiB, 39 PIDs.

The old run duplicated 1,639 frames across loop timestamp resets while the rewrite did not, making FFmpeg's `speed=x` value non-comparable; fps shows a roughly 4% rewrite cost in this single run. GPU engine utilization was unobservable. Output sizes in the finite final matrix were comparable after restoring the exact baseline resolution-scaled rate formula.

Three overlapping wrapper jobs in one PID namespace proved two-GPU scheduling:

1. first job -> Arc `renderD129`, zero load;
2. second job -> idle iGPU `renderD128`;
3. third job -> Arc with one weighted 999m workload and lower proportional utilization than the occupied iGPU.

## Managed integration

Deterministic tests proved:

- required missing/invalid/stale cache -> status 78 with specific stable error code;
- live benchmark lock without fallback -> status 75;
- opt-in proxy fallback -> native FFmpeg status, `-c copy`, marker written, no Smart transcode;
- machine status prints exactly one `FFMPEG_SMART_CACHE_STATUS=<value>` line;
- scoped arguments remain separate array elements; shell metacharacters are not evaluated;
- structural ownership and final `-f mpegts pipe:1` cannot be overridden;
- final media stdout remains separate from redacted diagnostics;
- no active FFmpeg process, validation container, or fresh-state benchmark lock remained after the final runs.

No plugin installation, managed profile change, Dispatcharr restart, production stream use, pin update, deployment, tag, release, or branch deletion occurred.

## Defects found and corrected

1. The remote branch did not contain the previously claimed rewrite; replaced the monolithic runtime and both benchmark helpers with independent modules.
2. Capacity used H.264 instead of representative HEVC Main10; corrected fixture selection and added command coverage.
3. Capacity walked the boundary linearly; replaced it with bound expansion/bisection plus 30-second stable/rejected confirmation.
4. Schema-2 cache did not yet reuse hardware records; added signature-keyed reuse and render-node reassignment coverage.
5. VAAPI runtime device initialization left filter selection ambiguous; switched to a named device and explicit filter device.
6. MPEG-TS program/top-level FFprobe records were counted twice; deduplicated by stream index/type.
7. Auto 10-bit policy could feed P010 to H.264; limited 10-bit preservation to eligible HEVC input/output and forced NV12 when required.
8. Native VAAPI tone mapping rejected PQ input without mastering-display side data; added software `zscale`/`tonemap` conversion with hardware re-upload and explicit BT.709 tags.
9. HTTP reconnect flags were applied to UDP; scoped them to HTTP(S).
10. Final FFmpeg diagnostics could reveal complete source URLs; added streaming full-address redaction for supported network schemes without mixing media stdout.
11. Implicit recache cleanup was overwritten and PID-only locks survived container PID reuse; composed cleanup and bound Linux locks to PID start time.
12. Unconstrained bitrate targets differed from baseline; restored the exact 8 Mbps 1080p pixel-scaled formula with 2 Mbps floor.

Each corrected behavior has deterministic regression coverage, hardware/media evidence, or both.

## Remaining gaps

- ShellCheck was unavailable on both local macOS and in the Dispatcharr image. The suite still ran `bash -n` over every wrapper, helper, module, and test under both Bash environments, followed by all deterministic regressions.
- GPU engine utilization was unavailable because neither `intel_gpu_top` nor `vainfo` was installed; no package was added to the production host.
- Capacity totals are conservative but not strictly comparable across the two benchmark fixture/command implementations.
- Render-node reassignment was safely simulated through signature-swapped cache records; the host was not rebooted or renumbered.
- No credentialed production Dispatcharr URL or active viewer stream was touched. Local HTTP and live UDP transports covered network behavior without exposing persistent URLs.
- A bounded UDP recording can begin mid-GOP before codec headers, although the longer artifact decoded successfully. A real receiver's join/recovery behavior remains a live-environment condition.

## Commands and evidence groups

- Standards/Git: remote fetch and `ls-remote`, branch/worktree creation, workspace `scripts/reconcile-standards --check`.
- Suites: old, prevalidation-new, final local Bash 3, and final Dispatcharr-container `scripts/validate.sh`.
- Hardware: `ffmpeg -version`, `ffprobe -version`, `-hwaccels`, encoder/decoder listings, `/dev/dri`, DRM sysfs, Dispatcharr device/mount inspection.
- Cache: clean `--recache-only`, `--cache-status`, required-cache/fallback tests, signature reuse, override states, no-DRI state, lock tests.
- Media: old/new wrapper matrix, FFprobe metadata table, full decode, warning decode, DTS monotonicity, SHA-256 copy comparisons.
- Performance: repeated direct/old/new startup, bounded long old/new runs with `docker stats`, overlapping scheduler jobs.
- Helpers: `benchmark-accel.sh 1 1`, `benchmark-live.sh 5 local`.
- Provenance: normalized exact-line overlap at 32- and 48-character thresholds, recorded in `PROVENANCE.md`.
