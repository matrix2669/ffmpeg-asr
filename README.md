# ffmpeg-asr

Adaptive stream normalizer with hardware-accelerated transcoding fallback.

This is the matrix2669 maintained fork of `FiveBoroughs/ffmpeg-asr`. It is the canonical source for the commit-pinned script embedded by Dispatcharr FFmpeg Smart.

## What it does

`ffmpeg-smart.sh` normalizes live streams into MPEG-TS while minimizing unnecessary video re-encoding. Video is stream-copied when it already satisfies the resolved output policy; otherwise the script uses the fastest working hardware/software transcode path found by its capability probe.

The policy can come from cached hardware capabilities, explicit codec/format flags, optional output-profile limits, or any combination of them.

Key features:

- Real-media capability benchmarking
- Automatic QSV, VAAPI, NVENC, VideoToolbox, V4L2 M2M, or software selection
- Linux `/dev/dri/renderD*` discovery for Docker/LXC environments
- Capacity-aware selection between the two fastest visible DRM render nodes
- Per-accelerator 10-bit decode/encode capability tracking
- HEVC Main10/P010 preservation when allowed
- Optional maximum resolution, bitrate, and audio-channel limits
- Optional HDR-to-SDR tone mapping
- Optional interlaced-to-progressive deinterlacing
- AAC passthrough and predictable AAC conversion for non-AAC/downmixed audio
- MPEG-TS remuxing, timestamp normalization, reconnect handling, and PAT/PMT refresh

## Runtime architecture

`ffmpeg-smart.sh` is a thin compatibility entry point. Independent modules under `lib/` own CLI parsing, persistent cache data, hardware discovery and benchmarking, adaptive probing, and media policy/command construction. The entry point retains the documented external options and fixed MPEG-TS stdout contract without retaining the inherited monolithic implementation structure.

The rewrite's capability cache is schema 2, a validated tab-delimited data format headed by `FFMPEG_SMART_CACHE_V2`. It is parsed as data and is never sourced as shell code. A legacy shell-assignment cache is intentionally reported as `invalid` and must be rebuilt; it is not executed or migrated in place.

## Usage

```bash
./ffmpeg-smart.sh -i "stream_url" -user_agent "User-Agent"
```

The normalized MPEG-TS stream is written to stdout.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `-i` | required | Input URL or file |
| `-user_agent` | | User agent for HTTP streams |
| `-accel` | auto | Acceleration used when transcoding is required: `qsv`, `vaapi`, `nvenc`, `videotoolbox`, `v4l2m2m`, `software` |
| `-device` | auto | Explicit shared DRM render node for QSV/VAAPI; bypasses automatic multi-GPU selection |
| `-dri-device` | auto | Alias for `-device` |
| `-qsv-device` | auto | Explicit QSV DRM render node |
| `-vaapi-device` | auto | Explicit VAAPI DRM render node |
| `-vc` | auto | Target video codec: `h264` or `hevc`; auto uses `BEST_CODEC` from the capability cache |
| `-10bit` | auto | Enable 10-bit output; auto follows the selected accelerator's proven capability |
| `-hdr` | auto | Enable HDR output; auto follows the selected HEVC/10-bit capability |
| `-maxres` | unset | Maximum vertical resolution, for example `720`; lower-resolution sources are never upscaled |
| `-maxbr` | unset | Maximum video bitrate, for example `2M`, `2000k`, or `2000000`; transcodes use constrained VBR below this ceiling |
| `-maxbitrate` | unset | Alias for `-maxbr` |
| `-maxchan` | unset | Maximum number of audio channels, for example `2`; audio is never upmixed |
| `-sdr` | unset | Require SDR output; HDR sources are tone-mapped to BT.709 SDR |
| `-deint` | unset | Require progressive output for detected interlaced video |
| `-deinterlace` | unset | Alias for `-deint` |
| `-ffmpeg-input-mode` | `inherit` | Input-default mode: `inherit`, `add`, or `replace` |
| `-ffmpeg-input-option` | unset | Add one exact input-side FFmpeg argument before `-i`; repeat for every argument |
| `-ffmpeg-map-mode` | `inherit` | Stream mapping: `inherit`, `add`, `replace`, or `all` |
| `-ffmpeg-map` | unset | Add one map specifier, such as `0:a:0?`; repeat for custom mappings |
| `-ffmpeg-video-mode` | `inherit` | Transcode-video tuning mode: `inherit`, `add`, or `replace` |
| `-ffmpeg-video-option` | unset | Add one exact transcode-video tuning argument; repeat for every argument |
| `-ffmpeg-audio-mode` | `inherit` | Audio-default mode: `inherit`, `add`, or `replace` |
| `-ffmpeg-audio-option` | unset | Add one exact audio argument; repeat for every argument |
| `-ffmpeg-mux-mode` | `inherit` | MPEG-TS/output-default mode: `inherit`, `add`, or `replace` |
| `-ffmpeg-mux-option` | unset | Add one exact MPEG-TS/output argument; repeat for every argument |
| `-ffmpeg-option` | unset | Backward-compatible alias for additive `-ffmpeg-mux-option` arguments |
| `--recache` | | Force a fresh capability probe |
| `--recache-only` | | Rebuild the capability/capacity cache and exit without requiring an input stream |
| `--cache-status` | | Check the existing cache against the current script, policy, and hardware without rebuilding it |

`-maxres`, `-maxbr`/`-maxbitrate`, `-maxchan`, `-sdr`, and `-deint` are independent optional constraints. Any one can be used by itself, or they can be combined.

## Persistent state

By default, `.capabilities.cache`, generated benchmark samples, captured probe samples, and `.benchmark.lock` remain beside `ffmpeg-smart.sh` for standalone compatibility. Integrations installed in replaceable application or plugin directories should provide a persistent writable state directory:

```bash
FFMPEG_SMART_STATE_DIR=/data/ffmpeg_smart_profiles ./ffmpeg-smart.sh -i "stream_url"
```

The directory is created when possible. Startup exits with status `73` and an `[ffmpeg-smart] ERROR [state-directory]` message if it cannot be created or written.

Integrations that coordinate benchmarking separately can also require an existing valid cache:

```bash
FFMPEG_SMART_STATE_DIR=/data/ffmpeg_smart_profiles \
FFMPEG_SMART_REQUIRE_CACHE=true \
./ffmpeg-smart.sh -i "stream_url"
```

With this mode enabled, a missing, invalid, or hardware-stale cache does not launch an implicit benchmark during stream startup. The wrapper exits with status `78` and a specific `[ffmpeg-smart] ERROR [capability-cache-*]` message instructing the operator to rebuild the hardware cache. Explicit `--recache` and `--recache-only` remain available and are not blocked by this setting.

Managed integrations that prefer basic service over a startup failure can explicitly enable degraded proxy fallback:

```bash
FFMPEG_SMART_STATE_DIR=/data/ffmpeg_smart_profiles \
FFMPEG_SMART_REQUIRE_CACHE=true \
FFMPEG_SMART_CACHE_FALLBACK=proxy \
./ffmpeg-smart.sh -i "stream_url"
```

When the required cache is missing, invalid, stale, or unavailable—or while a hardware benchmark lock is active—the wrapper skips probing, Smart policy, hardware selection, filters, and encoding. It runs a basic FFmpeg `-c copy` MPEG-TS proxy using the resolved input, mapping, and mux groups. Video/audio Smart constraints are not enforced in this mode, and an incompatible source can still fail native FFmpeg remuxing. The default `FFMPEG_SMART_CACHE_FALLBACK=none` preserves historical standalone behavior.

An integration can set `FFMPEG_SMART_FALLBACK_MARKER` to a writable file. Every degraded invocation writes a new token there before starting FFmpeg, allowing the integration to re-display an operational notice if a previous warning was dismissed. The marker is a notification signal only; `--cache-status` remains the cache-validity authority.

Managed integrations can check the same cache contract without starting a stream or benchmark:

```bash
FFMPEG_SMART_STATE_DIR=/data/ffmpeg_smart_profiles ./ffmpeg-smart.sh --cache-status
```

The command prints exactly one machine-stable `FFMPEG_SMART_CACHE_STATUS` value: `valid`, `missing`, `invalid`, `stale`, or `unavailable`. It exits successfully only for `valid`; every non-valid cache exits with status `78`. The check does not create, replace, or benchmark a cache. `--cache-status` cannot be combined with either recache option.

## Policy model

The normalizer first resolves its base video policy:

```text
target codec = -vc if supplied, otherwise BEST_CODEC
10-bit       = -10bit if supplied, otherwise selected accelerator capability
HDR          = -hdr if supplied, otherwise selected HEVC/10-bit capability
```

It then applies any optional profile limits that were supplied:

```text
-maxres      maximum source/output height
-maxbr       maximum encoded video bitrate
-maxchan     maximum audio channel count
-sdr         require SDR/BT.709 output
-deint       require progressive output when the source is interlaced
```

A video stream is copied only when it already satisfies every active video constraint. Any mismatch sends the video through the selected transcode path.

Examples with a cached HEVC/QSV target:

```text
Source HEVC SDR, no extra limits        -> video copy
Source H264 SDR                         -> H264 -> HEVC transcode
Source HEVC 1080p + -maxres 720         -> HEVC 720p transcode
Source HEVC HDR + -sdr                  -> HDR -> SDR transcode
Source interlaced + -deint              -> progressive transcode
Source progressive + -deint             -> no deinterlace work
Source HEVC <=2M + -maxbr 2M            -> video copy when bitrate is known
Source HEVC >2M + -maxbr 2M             -> bitrate-limited transcode
Source bitrate unknown + -maxbr 2M      -> transcode so the maximum can be guaranteed
```

The script does not resize, bitrate-limit, channel-limit, tone-map, or deinterlace unless the corresponding constraint is supplied or another active policy already requires a transcode.

## Dispatcharr mobile-profile example

A profile that limits video to 720p/2 Mbps, audio to stereo, converts HDR to SDR, and deinterlaces broadcast sources can call:

```bash
./ffmpeg-smart.sh \
  -i "STREAM_URL" \
  -maxres 720 \
  -maxbr 2M \
  -maxchan 2 \
  -sdr \
  -deint
```

Each limit is conditional:

- 720p or lower is not resized.
- A known video bitrate at or below 2 Mbps does not trigger a bitrate transcode.
- Mono/stereo audio is not upmixed.
- SDR video is not tone-mapped.
- Progressive video is not deinterlaced.
- AAC within the channel limit is copied unchanged.

When a transcode is required with `-maxbr 2M`, the normal 720p target is capped to 85% of the ceiling (1.7 Mbps) while `-maxrate` remains 2 Mbps, leaving headroom for constrained-VBR peaks.

If multiple constraints require a transcode, they are handled in the same video/audio pipeline rather than causing multiple generations.

## Advanced FFmpeg Smart options

Advanced arguments are grouped by where FFmpeg requires them. Every argument is preserved as an array element without evaluating a shell command.

Each group supports three modes:

- `inherit` uses FFmpeg Smart's current versioned defaults. Supplying options while leaving the mode on `inherit` behaves as `add` for backward-compatible convenience.
- `add` places the user arguments after the managed group, allowing later single-value settings to override an earlier default.
- `replace` omits the managed group and uses only the supplied arguments. An intentionally blank replacement is allowed except for stream mapping, which must still select at least one stream.

The groups have these boundaries:

- **Input** follows the dynamic HTTP user-agent/reconnect and hardware-input setup but precedes `-i`. Its inherited values are `-fflags +genpts+igndts+discardcorrupt -err_detect ignore_err`.
- **Adaptive probing** is wrapper-owned. `-analyzeduration` and `-probesize` cannot be supplied through advanced input options because Smart must use the same validated tier for FFprobe and the final FFmpeg input.
- **Mapping** follows `-i`. Its inherited value is `-map 0:v:0 -map 0:a:0?`; `all` uses `-map 0`, while `add` and `replace` accept repeated typed `-ffmpeg-map` specifiers. A job must select exactly one video stream because Smart probes, filters, schedules, and accounts for one hardware-normalized video output. Ambiguous positive mappings and negative video mappings are rejected. Mapped subtitle, data, and attachment streams are explicitly stream-copied so FFmpeg does not attempt to select an encoder, but the source codec must still be compatible with MPEG-TS; multiple auxiliary streams remain an expert compatibility choice.
- **Video tuning** is used only when Smart chooses hardware/software video transcoding. Replace removes managed bitrate, GOP, frame-rate, and encoder tuning, but retains the selected encoder, hardware filter graph, color policy, and any explicit `-maxbr` ceiling.
- **Audio** follows video processing on both the copy and transcode paths. Replace removes Smart's normal AAC/copy arguments for the mapped audio streams, while an explicit `-maxchan` remains a hard maximum.
- **MPEG-TS/output** follows audio on both paths. Its inherited group normalizes timestamps, resends PAT/PMT, flushes packets, and sets the mux queue size. The final `-f mpegts pipe:1` remains fixed.

For example, this retains hardware selection while replacing input defaults, mapping all streams, adding GOP/key-frame tuning, replacing audio with AC-3, and replacing the MPEG-TS flags:

```bash
./ffmpeg-smart.sh \
  -i "STREAM_URL" \
  -ffmpeg-input-mode replace \
  -ffmpeg-input-option -fflags \
  -ffmpeg-input-option +discardcorrupt+genpts+nobuffer \
  -ffmpeg-map-mode all \
  -ffmpeg-video-mode add \
  -ffmpeg-video-option -g \
  -ffmpeg-video-option 60 \
  -ffmpeg-video-option -force_key_frames \
  -ffmpeg-video-option 'expr:gte(t,n_forced*2)' \
  -ffmpeg-audio-mode replace \
  -ffmpeg-audio-option -c:a \
  -ffmpeg-audio-option ac3 \
  -ffmpeg-mux-mode replace \
  -ffmpeg-mux-option -mpegts_flags \
  -ffmpeg-mux-option +pat_pmt_at_frames+resend_headers+initial_discontinuity
```

FFmpeg Smart rejects structural switches that would take ownership of its input, stream-mapping syntax, hardware selection, hardware filter graph, selected video encoder, output format, or output destination. Advanced settings remain operator-controlled and may still be unsupported by the selected encoder or installed FFmpeg build.

## Maximum resolution

`-maxres` is a maximum vertical resolution:

```bash
-maxres 720
```

For a standard 1920x1080 source, the target becomes 1280x720 while preserving aspect ratio. Sources at 720p or below pass the resolution check unchanged and are never upscaled.

## Maximum video bitrate

Both forms are accepted:

```bash
-maxbr 2M
-maxbitrate 2000k
```

Accepted bitrate formats include raw bits per second and `k`, `M`, or `G` suffixes. `bps` may also be appended.

When FFprobe reports a source video bitrate, video can be copied if that bitrate is already within the limit and all other policy checks pass. Many live MPEG-TS sources do not publish a reliable video bitrate. In that case the script transcodes when a maximum bitrate is requested, because stream copy cannot guarantee the requested ceiling.

During a bitrate-limited transcode, the requested maximum becomes FFmpeg's `-maxrate`. The target `-b:v` is the lower of the normal resolution-derived target or 85% of the requested maximum, and the VBV buffer is twice the maximum. This provides constrained-VBR headroom without increasing the normal target for lower-resolution streams.

For example:

```text
-maxbr 2M  -> target up to 1.7M, maxrate 2M, bufsize 4M
-maxbr 4M  -> target up to 3.4M, maxrate 4M, bufsize 8M
```

## Maximum audio channels

`-maxchan` limits audio without forcing a video transcode:

```bash
-maxchan 2
```

AAC is copied when it is already within the channel limit. AAC above the limit is decoded and re-encoded only to perform the downmix. Non-AAC audio is still normalized to AAC.

Current AAC targets are:

| Output channels | AAC bitrate |
|-----------------|-------------|
| 1 / mono | 96 kbps |
| 2 / stereo | 192 kbps |
| 6 / 5.1 | 384 kbps |
| 8 / 7.1 | 512 kbps |
| Other | 64 kbps per channel |

Audio is never upmixed merely because `-maxchan` is higher than the source channel count.

## SDR mode

```bash
-sdr
```

SDR sources are unaffected by this constraint. HDR sources are transcoded and tone-mapped to BT.709 SDR.

QSV and VAAPI retain hardware encoding, but HDR-to-SDR conversion uses FFmpeg's software `zscale`/`tonemap` path before uploading BT.709 NV12 frames to the selected encoder. This works for correctly tagged PQ/HLG inputs even when mastering-display side data is absent, a condition that makes the native VAAPI tone-map filter reject otherwise valid HDR media. Software acceleration uses the same color conversion without the upload stage.

HDR-to-SDR output is intentionally 8-bit SDR for broad compatibility.

## Deinterlace mode

```bash
-deint
```

The script reads the video stream's `field_order` from FFprobe. If the stream is detected as interlaced, `-deint` adds a video policy mismatch and produces progressive output. Progressive sources are unaffected.

The deinterlace path keeps the source frame rate rather than doubling to field rate. For example, a 1080i29.97 source becomes 29.97p after deinterlacing.

- QSV uses `vpp_qsv` advanced motion-adaptive deinterlacing and can combine deinterlace with scaling in the same hardware VPP stage.
- VAAPI uses `deinterlace_vaapi` motion-adaptive mode at frame rate, followed by VAAPI scaling when needed.
- Other paths use `bwdif` at frame rate before scaling/encoding.

When `-deint` and `-sdr` are both required, the script combines the operations into the same transcode pipeline.

## Audio policy without `-maxchan`

When no channel limit is supplied:

- AAC input is stream-copied unchanged.
- Non-AAC mono becomes AAC 96 kbps.
- Non-AAC stereo becomes AAC 192 kbps.
- Non-AAC 5.1 becomes AAC 384 kbps.
- Non-AAC 7.1 becomes AAC 512 kbps.
- Unknown/unusual channel counts use 64 kbps per output channel.
- Audio-less inputs produce no audio encoder/filter options.

Non-AAC or downmixed audio uses `aresample=async=1` to help maintain A/V sync.

## Linux DRI device selection

On Linux, the scripts enumerate render nodes that actually exist under `/dev/dri/renderD*`. This avoids selecting host sysfs devices that are not mapped into a Docker/LXC container.

When more than one compatible render node is exposed, the capability probe measures real concurrent-stream capacity on each device independently. It first measures single-stream speed to choose a starting point, then launches that many simultaneous unthrottled transcodes. Ten-second wall-clock stress tests bracket the stable/unstable boundary, followed by 30-second confirmation at the highest stable level and the next level. Every stream must maintain at least `1.2x` speed, preserving 20% throughput headroom to reduce buffering risk.

The extended concurrency test runs only when multiple compatible GPUs are visible. A single-GPU system retains the quick five-second throughput estimate. Concurrency settings can be adjusted when needed:

```bash
CONCURRENCY_SHORT_DURATION=15 \
CONCURRENCY_CONFIRM_DURATION=45 \
CONCURRENCY_MIN_SPEED=1.25 \
CONCURRENCY_MAX_STREAMS=48 \
./ffmpeg-smart.sh --recache
```

The probe sample is looped independently for every concurrent worker, so the source file itself does not need to match the test duration. Workers run without real-time input throttling; otherwise their reported speed would be capped near `1.0x` and could not prove the configured headroom.

Before starting a hardware transcode, the script inspects visible `ffmpeg` processes under `/proc` and determines which DRM render node each process has open. Jobs launched by `ffmpeg-smart.sh` expose their input dimensions, output dimensions, and exact fractional frame rate through inherited environment markers. Each job is converted to 1080p30-equivalent load:

```text
job load = max(input pixel rate, output pixel rate) / 1080p30 pixel rate
GPU utilization = total weighted job load / verified concurrent capacity
```

Typical weights are:

| Transcode | 1080p30 units |
|-----------|---------------|
| 720p30 → 720p30 | 0.44 |
| 720p60 → 720p60 | 0.89 |
| 1080p30 → 720p30 | 1.00 |
| 1080p60 → 1080p60 | 2.00 |
| 4K30 → 1080p30 | 4.00 |
| 4K60 → 4K60 | 8.00 |

Input size accounts for decode work, while output size accounts for encode work and upscaling. The larger pixel rate is used as a conservative single load value. Fractional rates such as `60000/1001` are retained. An external FFmpeg process without the markers counts as one 1080p30 unit.

The device with lower proportional utilization is selected, and equal utilization favors the primary. Verified concurrent capacity is the denominator; single-stream speed breaks ties between devices with the same verified capacity. Only processes visible in the script's PID namespace can be counted, so a normal Docker container will not see FFmpeg jobs in unrelated containers or on the host.

Automatic selection is self-contained: it does not require shared state, lock files, or GPU monitoring services. Device selection can still be overridden:

```bash
./ffmpeg-smart.sh -device /dev/dri/renderD129 -i "stream_url"
```

or independently by accelerator:

```bash
./ffmpeg-smart.sh \
  -qsv-device /dev/dri/renderD129 \
  -vaapi-device /dev/dri/renderD130 \
  -i "stream_url"
```

Environment variables remain supported:

```bash
DRI_DEVICE=/dev/dri/renderD129 ./ffmpeg-smart.sh -i "stream_url"
```

or independently by accelerator:

```bash
QSV_DEVICE=/dev/dri/renderD129 \
VAAPI_DEVICE=/dev/dri/renderD130 \
./ffmpeg-smart.sh -i "stream_url"
```

`DRI_DEVICE` supplies the shared default. `QSV_DEVICE` and `VAAPI_DEVICE` take precedence when explicitly set.

CLI device options take precedence over environment values. When multiple CLI device options are supplied, later options override earlier ones, allowing a shared `-device` followed by an accelerator-specific exception.

Any explicit applicable override bypasses automatic multi-GPU selection. The selected device and the active/capacity values used for the decision are written to stderr.

## Capability caching

On a capability probe, the script:

1. Generates bounded H.264 and HEVC Main10 samples locally when necessary.
2. Tests real decode/encode paths.
3. Benchmarks available H264/HEVC encoders.
4. Tests normal and low-power modes where supported.
5. Tracks 10-bit decode and encode capability per accelerator.
6. Finds and confirms real concurrent-stream capacity on every compatible DRM render node.
7. Stores the fastest working fallback path and primary/secondary device capacities in `.capabilities.cache`.

Example schema-2 cache data:

```text
FFMPEG_SMART_CACHE_V2
value  schema  2
value  best_accel  vaapi
value  best_codec  h264
value  primary_device  /dev/dri/renderD129
value  secondary_device  /dev/dri/renderD128
device <hardware-signature> /dev/dri/renderD129 vaapi h264 0 true true 14 11.5
```

The real file uses tabs between fields and also carries its complete fingerprint and the remaining scalar values.

The cache describes the preferred transcode path; it does not mean every input is transcoded.

The cache fingerprint includes the script version, exposed DRI render-node mapping, GPU vendor/device/revision/subsystem IDs, and selected device overrides. A relevant script, GPU hardware, or render-node mapping change invalidates the active cache automatically. Capacity results are also stored per hardware signature, independent of render-node number, accelerator choice, codec, and low-power mode.

When the visible hardware set changes, matching per-device results are reused and only new or changed GPUs receive the concurrency benchmark. For example, moving from an A310 plus an Intel iGPU to an otherwise equivalent system exposing only the same iGPU reuses the iGPU capacity, drops the absent A310 entry, and rebuilds primary/secondary ordering without another saturation test. Moving to equivalent GPU hardware also reuses matching results even when host identity, kernel, driver version, or PCI location differs.

Render-node renumbering is handled the same way. If a reboot swaps the devices previously exposed as `renderD128` and `renderD129`, the changed node-to-hardware mapping invalidates the active selection, both hardware-keyed capacity results are reused, and primary/secondary devices are reassigned to their new render-node paths without rerunning the concurrency benchmark.

Use `--recache` to deliberately discard reusable results and retest every visible device.

For automation or plugin-triggered maintenance, use `--recache-only`. It performs the same forced rebuild but exits successfully as soon as the cache is complete, without requiring `-i`:

```bash
./ffmpeg-smart.sh --recache-only
```

While a cache-only benchmark is running, the script maintains `.benchmark.lock` in the configured state directory. New normal invocations exit with status 75 instead of competing with the benchmark unless an integration explicitly enables degraded proxy fallback, in which case they use stream copy without GPU decode, filtering, or encoding. Only the top-level recache owner may remove its lock; command substitutions and concurrent benchmark-worker subshells cannot clear it while the parent remains active. On Linux the lock records both PID and process start time, so a later container reusing PID 1 cannot inherit a stale lock. The owner removes the lock automatically on every exit path, and stale locks are discarded when their recorded process identity no longer exists (or an incomplete startup lock is older than one minute).

`-i pipe:0` and `-i -` are supported for live pipeline integrations such as Dispatcharr Output Profiles. The wrapper captures up to four seconds of the pipe for probing, then prepends that exact sample to the remaining input before starting FFmpeg so probe data is not lost.

### Adaptive input probing

Normal URL and captured-pipe inputs first use `-analyzeduration 1000000 -probesize 1000000`. A successful FFprobe exit is not enough: Smart requires a usable selected video codec, dimensions, and pixel format, plus codec, channel count, and sample rate for every selected audio stream. Incomplete selected-stream metadata retries at 2 seconds/2 MB and then with native FFmpeg defaults.

The final FFmpeg process receives the same bounded probe tier that produced complete metadata. Native defaults remain unbounded by Smart when the default tier is needed. A nonzero FFprobe result is treated as an input or transport failure and exits immediately rather than using a larger analysis window as a network retry. HTTP reconnect flags are limited to HTTP(S), not applied to UDP/SRT/RTSP inputs. Logs identify escalation and the selected tier without printing the source URL or credentials; final FFmpeg diagnostics replace complete supported network addresses with a scheme-preserving marker while media stdout and the FFmpeg exit status remain separate.

## Benchmarking

Quick wrapper benchmark:

```bash
./benchmark-live.sh [duration] [mode]
./benchmark-live.sh 15 live
./benchmark-live.sh 15 local
./benchmark-live.sh 15 all
```

Full encoder benchmark:

```bash
./benchmark-accel.sh [duration] [runs]
./benchmark-accel.sh 30 3
```

`benchmark-accel.sh` uses the same `/dev/dri/renderD*` discovery and `DRI_DEVICE` / `QSV_DEVICE` / `VAAPI_DEVICE` overrides as `ffmpeg-smart.sh`.

## Versions and source verification

Normal `vMAJOR.MINOR.PATCH` tags identify stable matrix2669 states. Downstream integrations should pin both the full Git commit and file checksum rather than following a moving branch or trusting the version label alone.

## Development and upstream contributions

Fork-owned development uses `dev` and short-lived feature or fix branches. Potential contributions to FiveBoroughs are rebuilt as focused `contrib/*` branches based directly on the current upstream `main`, keeping unrelated maintained-fork history out of upstream pull requests.

See `AGENT.md`, `DECISIONS.md`, `UPSTREAM.md`, and `RELEASE.md` for development and release policy.

## License status

The reviewed upstream repository does not currently declare a software license. This fork preserves upstream provenance and does not claim to relicense inherited code. A Git tag identifies source state but does not grant additional use or redistribution rights.
