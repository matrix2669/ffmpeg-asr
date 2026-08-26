# Architecture Decisions

This file records the durable decisions that govern the matrix2669 `ffmpeg-asr` fork. It was reconstructed from the complete available project history on 2026-08-22: relevant ChatGPT conversations, the Codex implementation task, repository commits and pull requests, live validation results, the related Dispatcharr FFmpeg Smart plugin, and the current `v1.0.0` implementation.

Conversation proposals are not decisions by themselves. When a conversation explored multiple approaches, the accepted decision below reflects the behavior that the user approved and that survived into the current code. Superseded experiments are called out so they are not accidentally restored.

## Evidence index

- ChatGPT `FFMpeg-ASR`: `6a810a36-bf2c-83ea-bf41-b144d16ca1fb`
- ChatGPT `FFmpeg Dispatcharr Profile`: `6a78daaa-d420-83ea-ac4d-b1d50eb7a257`
- ChatGPT `Mobile Streaming Profile Setup`: `6a7ee9a4-b990-83ea-b656-d98cad0343e1`
- ChatGPT `Dispatcharr Xtream Output Profile`: `6a7ef76b-8c18-83ea-b5a3-0c59383f4563`
- ChatGPT `Simplify Plugin Versioning`: `6a898c9e-1ffc-83ea-8fcc-b44788fea3c0`
- Codex `Add multi-GPU FFmpeg-ASR selection`: `01a01a9f-e65a-7ac3-95d0-430c44a35b16`
- Codex `Update standalone release workflow`: `01a02969-01f0-7803-8031-37f7f4f2803c`
- Fork pull requests: `matrix2669/ffmpeg-asr#1` and `#2`
- Related repository: `matrix2669/Dispatcharr-FFmpeg-Smart-Plugin`

---

# ADR-001: Operate as a hybrid maintained fork

## Status

Accepted

## Date

2026-08-22

## Decision

Use the standalone `main`/`dev` lifecycle for matrix2669 development while retaining the GitHub fork relationship, the `upstream` remote, and a clean optional contribution lane.

- `main` is the stable matrix2669 line.
- `dev` integrates the next matrix2669 version.
- Fork-owned `feature/*` and `fix/*` branches start from and return to `dev`.
- Potential upstream work uses a focused `contrib/*` branch based directly on freshly reviewed `upstream/main`.
- Never submit the customized `main`, `dev`, or fork-owned feature history upstream.

## Reason

The maintained fork is the canonical source for the related Dispatcharr plugin and was already 33 commits ahead of upstream when this workflow was adopted. Upstream was not archived, but its last code update was months earlier and pending pull requests had not received maintainer review. Independent development must not depend on upstream activity, but provenance and a clean contribution path remain valuable.

## Alternatives considered

- Reset matrix2669 `main` to upstream and put maintained changes only in overlay branches. Rejected because it would change the established canonical source and complicate downstream pins.
- Detach the repository from the GitHub fork network. Rejected because it would obscure provenance and make upstream comparison harder.
- Submit upstream pull requests from the customized stable history. Rejected because unrelated fork changes would contaminate focused contributions.

## Consequences

The fork may evolve and version independently. Upstream changes are reviewed and deliberately integrated rather than assumed to flow automatically. Every upstream contribution requires a refreshed upstream review and a clean transplant.

## Provenance

- Current implementation: `AGENT.md`, `BRANCHES.md`, and `UPSTREAM.md`
- Adoption commits: `aa65455`, `ed847e8`, `a30bd93`
- Source task: Codex `Update standalone release workflow`
- Related discussion: ChatGPT `Simplify Plugin Versioning`

---

# ADR-002: Treat the wrapper as a normalizer and minimize video re-encoding

## Status

Accepted

## Date

2026-08-15

## Decision

Resolve an explicit output policy first, then stream-copy video whenever the input already satisfies every active requirement. Re-encode only when at least one mismatch exists.

The base target comes from explicit flags when supplied and otherwise from the selected hardware capabilities:

- target codec: `-vc`, otherwise `BEST_CODEC`;
- 10-bit allowance: `-10bit`, otherwise the selected accelerator's proven encode capability;
- HDR allowance: `-hdr`, otherwise HEVC plus the selected accelerator's proven 10-bit encode capability.

A codec, bit-depth, HDR, resolution, bitrate, or deinterlace mismatch triggers one video transcode that satisfies all active requirements together. The diagnostic log must state why the transcode occurred. Compatible HEVC, H.264, 10-bit, and HDR inputs are not transcoded merely because they are high quality or because a hardware encoder is available.

## Reason

The primary user goal was to normalize inconsistent IPTV sources while minimizing generational loss, startup cost, latency, and GPU work. Earlier behavior transcoded compatible streams too aggressively and treated passthrough as a special case rather than the default result of policy satisfaction.

## Alternatives considered

- Always transcode through the fastest detected encoder. Rejected because it needlessly reduces quality and consumes GPU capacity.
- Passthrough based only on resolution or HDR exceptions. Rejected because it ignores the resolved codec and profile policy.
- Let each optional constraint build a separate transcode stage. Rejected because all required transformations can be composed into one pipeline.

## Consequences

Any new policy flag must participate in the same mismatch evaluation. A change that makes compatible inputs transcode needs explicit justification and regression validation. Audio policy remains independent and may transcode while video is copied.

## Provenance

- ChatGPT `FFMpeg-ASR`: user direction to normalize output and minimize video re-encoding
- Commits: `1a9d42d`, `17b1283`, `510695a`, `ea6041e`
- Current implementation: `VIDEO_TRANSCODE_REASON` and `VIDEO_COPY_REASON` in `ffmpeg-smart.sh`

---

# ADR-003: Make output constraints optional, composable, and non-upscaling

## Status

Accepted

## Date

2026-08-15

## Decision

Support `-maxres`, `-maxbr`/`-maxbitrate`, `-maxchan`, `-sdr`, and `-deint`/`-deinterlace` as independent optional constraints. Any subset may be supplied. Omitted constraints must not silently change the stream.

- `-maxres` is a maximum vertical resolution; lower-resolution sources are never upscaled.
- `-maxbr` is a guaranteed maximum. A known bitrate at or below the limit can pass; an unknown bitrate must transcode because stream copy cannot guarantee the ceiling.
- A bitrate-limited transcode uses the requested limit as `-maxrate`, caps the target at 85 percent of that limit, and uses a buffer twice the limit.
- `-maxchan` only downmixes when the source exceeds the limit; it never upmixes merely to reach the configured maximum.
- `-sdr` tone-maps only HDR input to BT.709 SDR.
- `-deint` deinterlaces only input reported as interlaced. Progressive input is unaffected.
- When several constraints require work, apply them in one audio/video pipeline.

The maintained defaults belong to the consumer profile, not the wrapper: the Dispatcharr mobile Output Profile enables `-maxres 720 -maxbr 2M -maxchan 2 -sdr -deint`. The wrapper does not globally force that mobile policy.

## Reason

Different Dispatcharr profiles need different compatibility and bandwidth policies. The user explicitly required that every limit be individually usable or omittable. Separating wrapper capability from profile defaults keeps the source reusable while allowing a strict mobile profile.

## Alternatives considered

- Bundle all mobile constraints into a fixed mode. Rejected because profiles need independent control.
- Upscale smaller sources to the configured resolution. Rejected because a maximum is not a target and upscaling adds cost without source detail.
- Set `-b:v` equal to the maximum. Rejected because VBR peaks need headroom below the ceiling.
- Enable deinterlacing unconditionally for every invocation. Rejected in the surviving implementation because incorrect field flags, latency, and high-quality client deinterlacers make it a profile-level choice. The mobile profile enables it explicitly.

## Consequences

Unknown source bitrate is intentionally conservative. Hardware filters should combine scale, tone-map, and deinterlace operations where supported. The mobile default may evolve independently in the plugin without changing wrapper defaults.

## Provenance

- ChatGPT `Mobile Streaming Profile Setup` and `FFMpeg-ASR`
- Commits: `b58f72e`, `80b2794`, `97486d5`, `b3221ce`, `cbd6df1`, `bea2b61`
- Live validation: 1080i MPEG-2 to 720p progressive HEVC with sampled frames reporting `interlaced_frame=0`

---

# ADR-004: Normalize audio independently and preserve compatible AAC

## Status

Accepted

## Date

2026-08-15

## Decision

Treat audio independently from the video copy/transcode decision.

- Copy AAC when it already satisfies the optional channel limit.
- Re-encode non-AAC audio to AAC.
- Downmix AAC or non-AAC audio only when it exceeds `-maxchan`.
- Never upmix.
- Use 96 kbps mono, 192 kbps stereo, 384 kbps 5.1, 512 kbps 7.1, and 64 kbps per channel for other layouts.
- Use asynchronous resampling for transcoded audio to improve live A/V synchronization.
- If no audio stream exists, generate no unused audio options.

## Reason

The original objective was AAC normalization up to 5.1, but always re-encoding AAC would be wasteful. Audio-only normalization must not force a video transcode, and a video copy must not prevent necessary audio conversion.

## Alternatives considered

- Always encode stereo AAC. Rejected because it destroys surround audio when no profile limit requests a downmix.
- Always copy AAC regardless of channel count. Rejected because mobile profiles require enforceable channel limits.
- Force a default two-channel output when the source has no audio. Rejected after testing exposed unused/invalid audio arguments.

## Consequences

Video and audio paths can independently be copy or transcode. New audio constraints must preserve the no-upmix rule and must not force video work.

## Provenance

- ChatGPT `FFmpeg Dispatcharr Profile` and `FFMpeg-ASR`
- Commits: `1267bb5`, `0ed8630`, `6ac32a5`
- Current implementation: `AUDIO_ARGS` and `AUDIO_INFO` construction in `ffmpeg-smart.sh`

---

# ADR-005: Discover and bind actual exposed render nodes

## Status

Accepted

## Date

2026-08-15

## Decision

On Linux, discover DRM devices from render nodes that actually exist under `/dev/dri/renderD*`. Do not gate hardware detection on `renderD128` or infer usable container devices only from host sysfs entries.

Bind QSV and VAAPI explicitly to the selected render node throughout probing, benchmarking, capability tests, and runtime transcoding. Preserve shared and accelerator-specific environment overrides, and provide matching CLI overrides:

- `DRI_DEVICE` / `-device` / `-dri-device`;
- `QSV_DEVICE` / `-qsv-device`;
- `VAAPI_DEVICE` / `-vaapi-device`.

CLI values take precedence over environment values. An applicable explicit override bypasses automatic multi-GPU selection.

## Reason

The original script skipped Intel probing when a container exposed only `renderD129`, even though QSV and VAAPI worked on that device. Sysfs could show devices that were not mapped into the container. Explicit binding is also necessary on hosts with both an Intel iGPU and Arc GPU because automatic library selection is ambiguous.

## Alternatives considered

- Assume `renderD128` exists. Rejected by the live LXC/Docker deployment.
- Use the first sysfs Intel device. Rejected because it may not have a corresponding container device node.
- Rely on oneVPL/FFmpeg to pick an Intel device. Rejected because multi-GPU selection must be deterministic.
- Support environment overrides only. Rejected because Dispatcharr profile commands need invocation-level control.

## Consequences

Every probe and runtime path must use the same resolved device. Missing override values must fail clearly. Automatic selection remains the default only when the caller did not pin the applicable device.

## Provenance

- ChatGPT `FFMpeg-ASR`: initial `renderD129` diagnosis and live QSV/VAAPI commands
- Commits: `b5baa21`, `64dfa9a`, `93f1e06`, `a5cdf9e`
- Pull request: `matrix2669/ffmpeg-asr#2`

---

# ADR-006: Benchmark representative production paths and track capabilities per accelerator

## Status

Accepted

## Date

2026-08-15

## Decision

Benchmark real decode/filter/encode paths with the downloaded HEVC Main10 sample when available. Use synthetic input only as a fallback when the sample cannot be obtained. Match production rate control, pixel conversion, encoder preset, and low-power constraints closely enough that rankings predict runtime behavior.

Track 10-bit decode and encode capability per accelerator rather than as one global machine flag. Derive runtime 10-bit and HDR policy from the selected accelerator's proven capability. Preserve HEVC Main10 when allowed and supported.

Benchmark commands must use `-nostdin`, an explicit duration, bounded timeouts, and useful per-encoder diagnostics.

## Reason

Synthetic input initially made software appear faster than hardware and produced misleading rankings. Early capability state could also claim 10-bit support proven by VAAPI while QSV had been selected. The hardware path must be validated as an end-to-end pipeline, not inferred from encoder presence.

## Alternatives considered

- Prefer hardware through an arbitrary ranking bonus. Rejected because representative measurements are more defensible than policy bias.
- Use only `testsrc`/`testsrc2`. Rejected because synthetic generation, format conversion, and lack of compressed decode distorted results.
- Maintain one global `SUPPORTS_10BIT` flag. Rejected because capabilities vary by accelerator and selected path.
- Allow benchmark commands to run until input EOF. Rejected after a probe took nearly five minutes because termination was unreliable.

## Consequences

Capability results are path-specific. A selected accelerator must never inherit another accelerator's proof. Synthetic fallback results are less authoritative and should be logged as such.

## Provenance

- ChatGPT `FFMpeg-ASR`: manual QSV, VAAPI, and software comparisons
- Commits: `1491300`, `2c32e46`, `08cae69`, `64dfa9a`, `93f1e06`
- Live result: representative sample changed the winner from synthetic software to QSV/HEVC on the tested Arc system

---

# ADR-007: Keep multi-GPU scheduling self-contained and proportional to verified capacity

## Status

Accepted

## Date

2026-08-19

## Decision

For multiple compatible DRM GPUs, benchmark each physical render node independently, identify primary and secondary devices from verified capacity, and route each automatic invocation to the device with the lower proportional load:

```text
device utilization = visible weighted FFmpeg load / verified capacity
```

Ties favor the primary. If only one valid device remains, use it. Poll visible `ffmpeg` processes, deduplicate a process after finding the target render node, and read wrapper workload markers from `/proc/<pid>/environ`.

Keep the scheduler inside `ffmpeg-smart.sh`. Do not require a daemon, database, reservation directory, GPU-monitoring service, Dispatcharr core change, or host-wide coordinator. The visibility boundary is the wrapper's PID namespace and permissions; other containers and invisible host processes are outside the model. Visible external FFmpeg processes still count conservatively.

## Reason

Single-device selection wasted usable capacity on systems with an iGPU and Arc GPU. Filling the nominally fastest GPU first would also leave no headroom for other applications. Proportional routing naturally shares work according to each device's proven capacity without adding an operational service.

## Alternatives considered

- Maintain PID reservation files under a shared state directory. Rejected because stale state, locking, cleanup, and simultaneous startup handling made the design less self-contained.
- Depend on cross-container engine-utilization monitoring. Rejected because an unprivileged container cannot reliably observe every host or sibling-container process.
- Fill the primary before using the secondary. Rejected because it concentrates heat and removes incidental headroom.
- Choose by single-stream speed only. Rejected because similar single-stream throughput can hide materially different concurrent capacity.

## Consequences

Scheduling is best-effort within the visible process namespace, not a host-global resource manager. Explicit device overrides remain the escape hatch. The scheduler must tolerate unreadable process metadata and disappearing processes without persistent state.

## Provenance

- ChatGPT `FFMpeg-ASR`: explicit rejection of excessive complexity and preference for self-contained primary/secondary proportional selection
- Commit: `7c1afcf`
- Pull request: `matrix2669/ffmpeg-asr#1`
- Measured cached-start overhead: approximately 5 ms idle and 110 ms with ten visible FFmpeg jobs in the tested container

---

# ADR-008: Define capacity with real concurrent 1080p workloads and 1.2x headroom

## Status

Accepted; supersedes throughput-only and `0.95x` experiments

## Date

2026-08-19

## Decision

Use single-stream throughput only to choose an initial search point. Define stored capacity by running real simultaneous, unthrottled 1080p transcodes on each physical GPU:

1. Use 10-second tests to bracket the stable/unstable boundary.
2. Confirm the highest stable level for 30 seconds.
3. Test the next level for 30 seconds to confirm instability.
4. Require every worker to sustain at least `1.2x`; one slower or failed worker rejects the level.

Run the extended capacity comparison when multiple compatible GPUs are visible. A single-GPU system retains the shorter capability probe. The duration, maximum streams, and minimum-speed threshold may be explicitly overridden for investigation, but `1.2x` is the production default.

## Reason

`floor(single_stream_speed)` did not prove simultaneous session stability. An interim `0.95x` threshold allowed streams close enough to real time that normal variance could cause buffering. The user explicitly required real concurrency testing, short boundary discovery, longer confirmation, and 20 percent throughput headroom.

Normal expected workloads are 720p and 1080p, so a 4K smoke test must not define the production capacity denominator.

## Alternatives considered

- Treat one transcode running at `Nx` as proof of `N` concurrent slots. Rejected by direct concurrent testing.
- Use a long sequential benchmark per device. Rejected because it still does not exercise simultaneous decode/filter/encode sessions.
- Require only `0.95x`. Superseded because it risks buffering.
- Base capacity on a 4K sample. Rejected because it underrepresents the normal 720p/1080p workload and conflates validation with scheduling units.
- Real-time throttle benchmark workers. Rejected because it caps reported speed near `1.0x` and cannot prove headroom.

## Consequences

Full recaching is intentionally heavy and can take minutes. Capacity is deployment-specific and must be re-measured on materially different hardware or policy. Historical measured values are evidence, not defaults: the final PR validation measured Arc A310 capacity 18 and UHD 770 capacity 15 at the `1.2x` threshold.

## Provenance

- Codex `Add multi-GPU FFmpeg-ASR selection`
- Commits: `23fe80f`, `976bedb`, `618c1c0`
- Pull request: `matrix2669/ffmpeg-asr#1`

---

# ADR-009: Express active load in 1080p30-equivalent weighted units

## Status

Accepted; supersedes equal process counting

## Date

2026-08-19

## Decision

Normalize active workload to 1080p30-equivalent milli-units using the larger of input and output pixel rate:

```text
job load = max(input width × input height × fps,
               output width × output height × fps)
           / (1920 × 1080 × 30)
```

Carry exact fractional frame rates such as `60000/1001`. The wrapper exports input/output dimensions and FPS in environment variables inherited by FFmpeg; another invocation reads them from `/proc/<pid>/environ`. If the markers are missing or unreadable, count the visible FFmpeg process as one 1080p30 unit.

Expected approximate weights include:

- 720p30: 0.44 units;
- 720p60: 0.89 units;
- 1080p30: 1.00 unit;
- 1080p60: 2.00 units;
- 4K30: 4.00 units;
- 4K60: 8.00 units.

## Reason

Counting every process as one slot treats a 720p30 job like 4K60 and cannot account for the user's common 1080p60 workloads. Input pixels represent decode cost, output pixels represent encode cost, and the maximum provides a conservative single load without building separate engine models.

## Alternatives considered

- Count active processes equally. Rejected because workload sizes differ too much.
- Use output size only. Rejected because 4K-to-1080p still decodes 4K input.
- Use input size only. Rejected because output encoding and possible future upscaling also matter.
- Add codec and bit-depth multipliers immediately. Deferred because measured pixel rate is the simplest strong baseline; add multipliers only if live evidence shows better routing.

## Consequences

Wrapper-launched jobs provide precise metadata without a shared state service. Unknown external jobs remain visible but conservative. Any future scheduler metric must continue to account for 1080p60 and retain fractional FPS.

## Provenance

- ChatGPT `FFMpeg-ASR`: user requirement to account for 1080p60 and normal 720p/1080p workloads
- Commit: `f63af2d`
- Live validation: 1080p60 recorded as 2000 milli-units and routed away from the more-loaded device

---

# ADR-010: Cache capacity by physical hardware identity and reuse matching results

## Status

Accepted

## Date

2026-08-19

## Decision

Separate current render-node mapping from reusable device benchmark results. Key reusable capacity by physical hardware identity and benchmark-relevant policy, including vendor, device, revision, subsystem, accelerator, codec, low-power choice, and capacity benchmark version.

On cache load:

- reuse known GPU results when render-node numbers swap;
- reuse a matching iGPU if a previously present external GPU disappears;
- reuse equivalent hardware after a host move;
- benchmark only a new or materially changed GPU;
- discard absent devices from current primary/secondary selection;
- make `--recache` the explicit instruction to discard reusable results and test everything.

The script version and visible hardware mapping remain part of active cache validity so policy changes rebuild the active selection.

## Reason

LXC migration, reboot-driven `renderD128`/`renderD129` swaps, and partial hardware changes should not trigger several minutes of unnecessary saturation testing when the same physical GPU was already measured. Conversely, a new GPU must not inherit a capacity merely because it occupies an old node number.

## Alternatives considered

- Key capacity only by render-node path. Rejected because paths are not stable across reboot or host migration.
- Invalidate and rerun every GPU on any fingerprint change. Rejected because it wastes time and disrupts service.
- Reuse by vendor/model alone. Rejected because revision, subsystem, encoder path, and benchmark policy can change capacity.

## Consequences

Benchmark policy changes must increment the capacity benchmark version. Cache migrations must preserve partial reuse without retaining absent devices. Simulated render-node swaps are a required regression case.

## Provenance

- Codex `Add multi-GPU FFmpeg-ASR selection`
- Commits: `0c9ebb5`, `d8fd120`
- Pull request: `matrix2669/ffmpeg-asr#1`
- Validation: simulated node swap reused both capacities without rerunning saturation tests

---

# ADR-011: Provide a coordinated cache-only maintenance mode

## Status

Accepted

## Date

2026-08-19

## Decision

Provide `--recache-only` for automation and plugin-triggered maintenance. It must force a cache rebuild, require no media input URL, and exit immediately after the cache is complete.

While cache-only benchmarking runs, maintain `.benchmark.lock` beside the script. New normal wrapper invocations must refuse to start with exit status 75 and a clear message. Remove the lock on normal exit or interruption, and recover stale or incomplete locks conservatively.

The related Dispatcharr plugin owns service coordination:

- warn users that benchmarking is disruptive;
- stop active Dispatcharr transcodes and wait for teardown;
- leave proxy-only streams running;
- prevent new FFmpeg Smart transcodes through the wrapper lock;
- start `--recache-only` in the background and report progress.

## Reason

Real concurrent benchmarking saturates the GPUs and produces invalid results if production transcodes compete with it. The wrapper needs a self-contained refusal mechanism, while Dispatcharr-specific stream shutdown belongs in the plugin rather than in this generic script.

## Alternatives considered

- Run `--recache` without an input and tolerate the final “No stream URL” error. Rejected because automation needs a successful maintenance command.
- Kill arbitrary FFmpeg processes from the wrapper. Rejected because the script cannot distinguish service ownership safely.
- Stop proxy/remux viewers. Rejected because they do not consume the benchmarked transcode capacity.
- Give the plugin Docker-socket access so it can restart Dispatcharr. Rejected because it grants host-level Docker control.

## Consequences

Exit status 75 is an intentional temporary-unavailability signal during maintenance. Direct `--recache` remains an expert command; coordinated service maintenance should use `--recache-only`. Lock lifecycle changes require interruption and stale-PID tests.

## Provenance

- Codex `Add multi-GPU FFmpeg-ASR selection`
- Commits: `9afb064`, `fbb80be`
- Related plugin commits: `fbdffa3`, `ee4b933`
- Installed-container validation confirmed active transcodes stop, new smart transcodes refuse, proxy streams continue, and stale locks recover

---

# ADR-012: Preserve non-seekable pipe input during probing

## Status

Accepted

## Date

2026-08-19

## Decision

Support `-i pipe:0` and `-i -` for Dispatcharr Output Profiles. Capture a bounded initial MPEG-TS sample from stdin, use that file for FFprobe, then prepend the exact captured bytes to the continuing input when launching the final FFmpeg pipeline.

Do not probe stdin once and then start FFmpeg from the already-consumed pipe. Clean up the temporary sample on every exit path and return the final FFmpeg status.

## Reason

Dispatcharr Output Profiles receive media through non-seekable stdin. The wrapper must inspect stream properties before resolving policy, but probing consumes bytes. Losing those packets truncates startup content or prevents tuning.

## Alternatives considered

- Use bare native FFmpeg commands for Output Profiles. Rejected because they bypass smart policy and GPU selection.
- Probe `pipe:0` and then reuse it directly. Rejected because the probe has already consumed opening packets.
- Require a seekable file or URL. Rejected because it would exclude Dispatcharr's native Output Profile contract.

## Consequences

Pipe support necessarily introduces a short bounded sampling phase and a temporary file. Changes must be tested with a real generated MPEG-TS stream and confirm exact output duration/no missing opening content.

## Provenance

- Codex `Add multi-GPU FFmpeg-ASR selection`
- Commit: `1422797`
- Live validation: 10-second 4K MPEG-TS stdin produced the complete 10-second 720p output through the bundled wrapper

---

# ADR-013: Keep ffmpeg-asr canonical and the Dispatcharr plugin self-contained

## Status

Accepted

## Date

2026-08-19

## Decision

Treat `matrix2669/ffmpeg-asr` as the single source of truth for `ffmpeg-smart.sh`. Keep a vendored executable copy inside `Dispatcharr-FFmpeg-Smart-Plugin` so installed plugins and immutable releases remain self-contained.

The plugin must record:

- source repository and path;
- full 40-character source commit;
- SHA-256 of the exact bundled bytes.

CI verifies the local checksum and, when online, byte-for-byte equality with the pinned source. Synchronization resolves an explicit branch, tag, or commit, validates shell syntax, updates the copy and metadata idempotently, and opens a reviewable plugin pull request when bytes change. It must not silently modify an existing release.

## Reason

Duplicated unmanaged scripts drift, but runtime fetching or a submodule would make plugin installation dependent on external state and would not reliably populate GitHub release archives. A pinned vendored copy provides both operational independence and traceability.

## Alternatives considered

- Maintain separate script implementations. Rejected because fixes and policy would diverge.
- Download `ffmpeg-smart.sh` at plugin runtime. Rejected because installation and execution must be deterministic and offline-capable.
- Use a Git submodule. Rejected because normal GitHub release archives do not include submodule contents.
- Automatically commit or publish synchronized bytes directly to a release branch. Rejected because source changes require review and immutable releases must not mutate.

## Consequences

Changing canonical `ffmpeg-smart.sh` can trigger a downstream synchronization PR, but it does not change the installed or released plugin until reviewed and published. A release gate must reject a bundled copy that disagrees with its pin.

## Provenance

- Codex `Add multi-GPU FFmpeg-ASR selection`
- Plugin commits: `d371587`, `e823c47`
- Metadata: `ffmpeg-smart-profiles/FFMPEG_SMART_SOURCE.json`
- Validation: offline checksum, remote byte comparison, idempotent no-change sync, and successful manual GitHub workflow

---

# ADR-014: Use semantic project versions without weakening commit-level source pins

## Status

Accepted

## Date

2026-08-22

## Decision

Use root `VERSION` as the canonical semantic version and keep the embedded `ffmpeg-smart.sh` version synchronized.

- Stable tags use `vMAJOR.MINOR.PATCH` on `main`.
- Beta tags use `vMAJOR.MINOR.PATCH-beta.N` on tested `dev` commits.
- Tags are immutable.
- Downstream integrations continue to pin the full Git commit and SHA-256; a human-facing semantic version does not replace exact source verification.

Remove the historical tracked post-commit hook that rewrote the script version to an abbreviated commit because it conflicts with semantic release metadata.

## Reason

Users need comprehensible project versions, while the downstream plugin needs stronger provenance than a short embedded commit string. Maintaining both semantic identity and exact immutable pins satisfies both needs.

## Alternatives considered

- Keep commit-derived versions only. Rejected because they do not communicate compatibility or release intent.
- Use semantic tags without changing the embedded script version. Rejected because logs and cache fingerprints would disagree with the tagged project.
- Let downstream consumers follow `main`. Rejected because moving branches are not immutable source identities.

## Consequences

Version changes deliberately invalidate active capability cache state through the script fingerprint. `VERSION`, embedded version, changelog, and tag must agree. Downstream sync remains a separate reviewable operation.

## Provenance

- Commits: `ed847e8`, `a30bd93`
- Tag: `v1.0.0`
- Source task: Codex `Update standalone release workflow`
- Related discussion: ChatGPT `Simplify Plugin Versioning`

---

# ADR-015: Do not infer a license or publish distributable releases for inherited code

## Status

Accepted

## Date

2026-08-22

## Decision

Preserve upstream provenance and do not add a repository-wide license, publish a GitHub Release, or attach a distributable project ZIP until the upstream copyright holder explicitly licenses the inherited code.

A normal Git tag may identify an immutable project state but does not claim or grant redistribution rights. Do not copy an unmerged license proposal into the fork as though it were authorization.

## Reason

At the full upstream review, `FiveBoroughs/ffmpeg-asr` contained no license. Upstream pull request #2 proposes MIT but remains unmerged. The fork owner can license independently authored additions, but cannot unilaterally relicense the inherited implementation.

## Alternatives considered

- Add the standard MIT text to the fork immediately. Rejected because it would misrepresent authority over upstream code.
- Treat the open MIT pull request as permission. Rejected because a contributor's proposal is not acceptance by the copyright holder.
- Publish a ZIP with only an attribution notice. Rejected because attribution alone does not grant redistribution rights.

## Consequences

`v1.0.0` exists as a tag without a GitHub Release or attached ZIP. Release packaging remains blocked until explicit licensing is verified and recorded. The fork commented on upstream PR #2 to explain the downstream licensing need.

The separate Dispatcharr plugin `v0.1.0` had already been published with a pinned copy before this licensing review. That historical publication does not authorize a new `ffmpeg-asr` Release; the plugin's licensing posture must be reviewed separately.

## Provenance

- `UPSTREAM.md`
- Upstream pull request: `FiveBoroughs/ffmpeg-asr#2`
- Fork tag: `v1.0.0`
- Source task: Codex `Update standalone release workflow`

---

# ADR-016: Separate persistent runtime state from replaceable installations

## Status

Accepted

## Date

2026-08-22

## Decision

Keep the standalone default of storing `.capabilities.cache`, `probe-sample.mkv`, and `.benchmark.lock` beside `ffmpeg-smart.sh`, but allow consumers to set `FFMPEG_SMART_STATE_DIR` to a persistent writable directory. All three files move together so capability reuse and benchmark coordination share one state boundary.

Provide `FFMPEG_SMART_REQUIRE_CACHE` for managed integrations that coordinate maintenance separately. When enabled for a normal stream invocation, a missing, invalid, or hardware-stale cache must:

- avoid an implicit capability/concurrency benchmark during stream startup;
- write one clear `[ffmpeg-smart] ERROR [capability-cache-*]` diagnostic to stderr;
- identify the cache path and recovery action;
- exit with configuration status `78` before probing media.

Explicit `--recache` and `--recache-only` bypass the required-cache refusal so maintenance can create or replace the cache. Failure to create or write the configured state directory exits with status `73` and an identified state-directory error.

## Reason

Application and plugin managers may replace their installation directory during updates. Runtime cache and lock files stored beside the executable are then deleted, which loses expensive capacity measurements and can make production streams fail while the wrapper attempts disruptive implicit probing. A consumer-owned state path survives code replacement, while an explicit required-cache mode gives operators a deterministic recovery message.

## Alternatives considered

- Store persistent data permanently in `/data` inside the generic wrapper. Rejected because standalone deployments may not have or want that layout; the consumer owns the location.
- Keep cache files beside the script and copy them during plugin update. Rejected because the old plugin directory may be removed before new code can migrate it.
- Automatically benchmark whenever a managed integration loses its cache. Rejected because real capacity testing is disruptive and must remain operator-coordinated.
- Manufacture an invalid FFmpeg command so the error looks like an FFmpeg parser failure. Rejected because a direct wrapper-identified stderr diagnostic and non-zero configuration exit are clearer and do not misrepresent the cause.

## Consequences

Consumers must configure the same state directory for normal streams, recache maintenance, status reads, and benchmark locking. State-path and required-cache changes require missing/invalid/stale cache tests plus downstream integration validation. Existing standalone users retain the historical beside-script behavior.

## Provenance

- User-reported Dispatcharr plugin update deleting runtime files
- Related plugin fix branch: `fix/persistent-state-errors`

---

# ADR-017: Pass advanced FFmpeg output arguments without shell evaluation

## Status

Accepted

## Date

2026-08-25

## Decision

Support repeatable `-ffmpeg-option <argument>` wrapper arguments. Each occurrence appends exactly one argument to an array and passes that array to the final FFmpeg process after the wrapper-managed video, audio, timing, and MPEG-TS settings but before the fixed `-f mpegts pipe:1` output contract.

Do not parse a shell command string, use `eval`, or invoke an intermediate shell. A consumer that starts from a free-form options field must split the field with a shell-compatible argument parser and emit one safely quoted `-ffmpeg-option` pair for every resulting token.

The later placement means an advanced option may intentionally override an earlier managed FFmpeg setting. It cannot replace the wrapper's fixed MPEG-TS container or standard-output destination. The wrapper preserves argument boundaries but does not attempt to validate encoder- or filter-specific compatibility.

## Reason

Profiles occasionally need FFmpeg features that are outside the normalizer's maintained policy surface. Treating every advanced encoder or muxer switch as a new wrapper policy flag would keep expanding the core interface, while evaluating an arbitrary string would create quoting ambiguity and command-injection risk.

## Alternatives considered

- Accept one raw shell fragment. Rejected because correct quote handling would require shell evaluation or an incomplete parser.
- Add a dedicated wrapper flag for every FFmpeg option. Rejected because hardware encoders and deployment-specific FFmpeg builds expose a large, evolving option surface.
- Allow additional output URLs or replace `-f mpegts pipe:1`. Rejected because live integrations rely on the wrapper's single MPEG-TS standard-output contract.

## Consequences

Manual callers repeat `-ffmpeg-option` for each FFmpeg argument. Integrations may present one friendlier text field, but must preserve the parsed token boundaries when generating the wrapper command. Validation must cover values containing spaces and shell metacharacters, repeat ordering, missing values, and the device-pre-scan boundary.

## Provenance

- Operator requirement review: 2026-08-25
- Related plugin branch: `feature/additional-ffmpeg-options`
