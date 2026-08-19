# ffmpeg-asr

Adaptive stream normalizer with hardware-accelerated transcoding fallback.

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
| `--recache` | | Force a fresh capability probe |

`-maxres`, `-maxbr`/`-maxbitrate`, `-maxchan`, `-sdr`, and `-deint` are independent optional constraints. Any one can be used by itself, or they can be combined.

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

On QSV, the script uses QSV VPP tone mapping. On VAAPI, it uses `tonemap_vaapi`. Other accelerators use a software tone-map filter path before hardware encoding where possible.

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

When more than one compatible render node is exposed, the capability probe benchmarks each device independently. It runs three 60-second passes per device, uses the median raw speed to rank them, and rounds that speed down to a sustainable concurrent-stream capacity. The two fastest devices become the primary and secondary devices. Ranking by raw speed means a `4.8x` device is preferred over a `4.1x` device even though both have a rounded capacity of four streams.

The extended comparison runs only when multiple compatible GPUs are visible. A single-GPU system retains the quick five-second probe. The multi-GPU duration and run count can be adjusted when needed:

```bash
MULTI_GPU_BENCH_DURATION=90 \
MULTI_GPU_BENCH_RUNS=5 \
./ffmpeg-smart.sh --recache
```

The probe sample is looped for the requested duration, so the source file itself does not need to be 60 seconds long.

Before starting a hardware transcode, the script inspects visible `ffmpeg` processes under `/proc` and determines which DRM render node each process has open. It selects the device with the lower proportional load:

```text
load = active ffmpeg jobs / benchmarked device capacity
```

For example, a primary device with 3 active jobs and capacity 8 (37.5%) is preferred over a secondary with 3 active jobs and capacity 6 (50%). Equal loads favor the primary device. Only processes visible in the script's PID namespace can be counted, so a normal Docker container will not see FFmpeg jobs in unrelated containers or on the host.

Automatic selection is self-contained: it does not require shared state, lock files, or GPU monitoring services. Device selection can still be overridden:

```bash
DRI_DEVICE=/dev/dri/renderD129 ./ffmpeg-smart.sh -i "stream_url"
```

or independently:

```bash
QSV_DEVICE=/dev/dri/renderD129 \
VAAPI_DEVICE=/dev/dri/renderD130 \
./ffmpeg-smart.sh -i "stream_url"
```

`DRI_DEVICE` supplies the shared default. `QSV_DEVICE` and `VAAPI_DEVICE` take precedence when explicitly set.

Any explicit applicable override bypasses automatic multi-GPU selection. The selected device and the active/capacity values used for the decision are written to stderr.

## Capability caching

On a capability probe, the script:

1. Downloads a small HEVC Main10 sample when necessary.
2. Tests real decode/encode paths.
3. Benchmarks available H264/HEVC encoders.
4. Tests normal and low-power modes where supported.
5. Tracks 10-bit decode and encode capability per accelerator.
6. Benchmarks the selected QSV/VAAPI path on every compatible DRM render node.
7. Stores the fastest working fallback path and primary/secondary device capacities in `.capabilities.cache`.

Example:

```bash
BEST_ACCEL='qsv'
BEST_CODEC='hevc'
BEST_LOW_POWER='0'
SUPPORTS_10BIT_DECODE='true'
SUPPORTS_10BIT_ENCODE='true'
DECODE_10BIT='qsv=1;vaapi=1;'
ENCODE_10BIT='qsv=1;vaapi=1;'
PRIMARY_DEVICE='/dev/dri/renderD129'
PRIMARY_SPEED='8.62'
PRIMARY_CAPACITY='8'
SECONDARY_DEVICE='/dev/dri/renderD128'
SECONDARY_SPEED='6.35'
SECONDARY_CAPACITY='6'
```

The cache describes the preferred transcode path; it does not mean every input is transcoded.

The cache fingerprint includes the script version, exposed DRI devices, selected device overrides, and detected GPU hardware. Capability-changing script updates therefore invalidate an older cache automatically. Use `--recache` to force a fresh probe manually.

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
