# ffmpeg-asr

Adaptive stream normalizer with hardware-accelerated transcoding fallback.

## What it does

Wraps ffmpeg to normalize live streams into MPEG-TS while avoiding unnecessary video re-encoding. Common IPTV video formats are stream-copied and remuxed with timestamp/reconnect handling. Hardware transcoding is used only when the source video is not already suitable, or when a video codec is explicitly forced.

On first capability probe, the script benchmarks hardware paths actually exposed to the process/container against a real compressed media sample and caches the fastest fallback transcode path.

Automatically handles:

- Video stream copy for common IPTV formats
- MPEG-TS remuxing and timestamp normalization
- Hardware encoder selection (NVENC, VAAPI, QSV, VideoToolbox, V4L2 M2M, software)
- Linux DRI render-node discovery from `/dev/dri/renderD*`
- Independent QSV and VAAPI device overrides
- Per-accelerator 10-bit decode/encode capability tracking
- HEVC Main10/P010 preservation when transcoding is required and supported
- AAC audio passthrough with predictable AAC conversion for non-AAC sources

## Usage

```bash
./ffmpeg-smart.sh -i "stream_url" -user_agent "User-Agent"
```

Outputs MPEG-TS to stdout.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `-i` | (required) | Input URL or file |
| `-user_agent` | | User agent for HTTP streams |
| `-accel` | auto | Hardware acceleration used if transcoding is required: `qsv`, `vaapi`, `nvenc`, `videotoolbox`, `v4l2m2m`, `software` |
| `-vc` | auto | Explicitly force video transcoding to `h264` or `hevc` below 4K; without `-vc`, compatible video is copied |
| `-10bit` | auto | Enable 10-bit encoding when a transcode is required and the selected accelerator supports it |
| `-hdr` | auto | Enable HDR re-encoding when a transcode is required and the selected accelerator supports 10-bit HEVC |
| `--recache` | | Force re-probe encoder capabilities |

### Examples

```bash
# Normal behavior: copy compatible video, normalize/remux the stream
./ffmpeg-smart.sh -i "http://stream.url/live.ts" -user_agent "Mozilla/5.0"

# Explicitly force HEVC transcoding below 4K
./ffmpeg-smart.sh -i "stream_url" -user_agent "UA" -vc hevc

# Explicitly force H264 transcoding
./ffmpeg-smart.sh -i "stream_url" -user_agent "UA" -vc h264

# Select the accelerator to use if a transcode is required
./ffmpeg-smart.sh -i "stream_url" -user_agent "UA" -accel vaapi
```

## Video normalization policy

The default goal is to preserve source video quality and reduce GPU/CPU work. The script remuxes compatible video rather than re-encoding it.

### Copied by default

| Source video | Default action |
|--------------|----------------|
| H264, 8-bit 4:2:0 SDR | Copy |
| HEVC, 8-bit 4:2:0 | Copy |
| HEVC Main10 / 10-bit 4:2:0 | Copy |
| HEVC HDR 4:2:0 | Copy |
| MPEG-2 video, 4:2:0 | Copy |
| Any video at 4K or higher | Copy |

The copied elementary video stream is still passed through ffmpeg and remuxed into a fresh MPEG-TS output using the script's reconnect, timestamp, corrupt-packet, PAT/PMT, and muxing settings. Video pixels are not decoded or re-encoded.

### Transcoded when needed

Video is transcoded when it is below 4K and does not match one of the normal copy-compatible formats, for example unusual codecs or pixel formats such as VP9, AV1, MPEG-4 Part 2, VC-1, H264 10-bit, or uncommon chroma formats.

When a fallback transcode is required, the cached benchmark determines the fastest working accelerator and output codec. On the tested Intel Arc system this is QSV/HEVC.

If a non-standard 10-bit or HDR source cannot be safely preserved by the selected transcode path, the script prefers video copy over a destructive conversion.

### Explicit codec override

Supplying `-vc h264` or `-vc hevc` intentionally forces a video transcode for sources below 4K, even if the source codec would normally be copied. This keeps an explicit codec request separate from the default normalizer-first behavior.

4K+ remains copy-only so this wrapper does not unexpectedly perform a high-cost 4K transcode; resolution/bitrate reduction is better handled by downstream output profiles.

## Audio policy

Audio is normalized independently from video:

- **AAC input**: Stream-copied unchanged
- **Non-AAC mono**: AAC 96 kbps
- **Non-AAC stereo**: AAC 192 kbps
- **Non-AAC 5.1**: AAC 384 kbps
- **Non-AAC 7.1**: AAC 512 kbps
- **Unknown audio layout**: Downmixed to AAC stereo at 192 kbps
- **Audio-less inputs**: Audio encoder/filter options are omitted entirely

Non-AAC audio transcodes use `aresample=async=1` to help maintain A/V sync. AAC passthrough is not filtered or re-encoded.

This means video can remain a bit-for-bit copy while problematic or incompatible audio is normalized separately.

## Linux DRI device selection

On Linux, the scripts enumerate render nodes that actually exist under `/dev/dri/renderD*`. This matters in containers/LXCs where host sysfs may contain devices that are not mapped into the container.

By default, the first exposed Intel/AMD render node is selected. You can override device selection with environment variables:

```bash
# Use one render node for both VAAPI and QSV
DRI_DEVICE=/dev/dri/renderD129 ./ffmpeg-smart.sh -i "stream_url"

# Override independently
QSV_DEVICE=/dev/dri/renderD129 \
VAAPI_DEVICE=/dev/dri/renderD130 \
./ffmpeg-smart.sh -i "stream_url"
```

`DRI_DEVICE` is the shared default. `QSV_DEVICE` and `VAAPI_DEVICE` take precedence when set explicitly.

QSV is initialized with the selected render node as its oneVPL child device. VAAPI is passed the selected render node directly.

## Transcode settings

These settings apply only when video actually needs to be re-encoded:

- **Video bitrate**: Scales quadratically with resolution (8 Mbps base at 1080p, 2 Mbps floor)
- **B-frames**: Enabled (2) for better compression unless low-power mode requires otherwise
- **GOP**: 1 second (matches source framerate)
- **10-bit HEVC**: P010/Main10 preserved when the selected accelerator proved support

## 10-bit and HDR capability handling

Capabilities are tracked per accelerator, not globally. For example:

```text
DECODE_10BIT='qsv=1;vaapi=1;'
ENCODE_10BIT='qsv=1;vaapi=1;'
```

These capabilities matter only when a video transcode is required. Compatible HEVC Main10/HDR inputs are copied by default, which preserves the original encoded video without any generation loss.

When transcoding HEVC 10-bit through a capable QSV path, the runtime keeps the video in P010 and selects HEVC Main10.

## Capability caching

The capability cache describes the best fallback transcode path; it does not mean every input is transcoded.

On a capability probe, the script:
1. Downloads a 10-bit HEVC probe sample (~4 MB from Jellyfin)
2. Tests working decode/encode pipelines using that compressed media sample
3. Benchmarks normal and low-power modes where supported
4. Tracks 10-bit decode and encode support for each accelerator
5. Caches the fastest working acceleration/codec combination

```text
.capabilities.cache   # Cached encoder test results
probe-sample.mkv      # Jellyfin 10-bit HEVC demo clip
```

Example cache from an Intel system with only `/dev/dri/renderD129` exposed:

```bash
HW_FINGERPRINT='script=render-node-v7;dri:renderD129:0x8086:0x56a6;selected:dri=/dev/dri/renderD129,vaapi=/dev/dri/renderD129,qsv=/dev/dri/renderD129;'
BEST_ACCEL='qsv'
BEST_CODEC='hevc'
BEST_LOW_POWER='0'
SUPPORTS_10BIT_DECODE='true'
SUPPORTS_10BIT_ENCODE='true'
DECODE_10BIT='qsv=1;vaapi=1;'
ENCODE_10BIT='qsv=1;vaapi=1;'
ENCODERS='h264_qsv=14.1x;hevc_qsv=17.9x;hevc_qsv_10bit=1;h264_vaapi=12.7x;hevc_vaapi=13.2x;hevc_vaapi_10bit=1;libx264=3.27x;libx265=1.13x;'
```

The `ENCODERS` field shows benchmark speeds (`17.9x` = 17.9x realtime). Low-power results appear as `encoder(lp)=speed` when available.

The cache fingerprint includes the script version, exposed DRI devices, selected device overrides, and detected GPU hardware, so capability-changing updates invalidate old cache data automatically. Use `--recache` to force a fresh probe at any time.

### Docker/LXC usage

The cache lives in the script directory, so mount the whole folder when running from Docker:

```yaml
volumes:
  - /path/to/ffmpeg-smart:/app
```

For GPU access, expose the desired render node into the container. The device does not have to be `renderD128`; `renderD129` and other render-node numbers are supported.

## Hardware candidate detection and selection

The script benchmarks fallback transcode candidates rather than assuming one acceleration API is always faster:

- macOS: VideoToolbox candidate
- `/dev/nvidia0`: NVENC candidate
- Exposed Intel render node: QSV and VAAPI candidates when compiled into FFmpeg
- Exposed AMD render node: VAAPI candidate when compiled into FFmpeg
- V4L2 M2M device: V4L2 M2M candidate
- Software encoders are always retained as fallback candidates

The real-media benchmark determines `BEST_ACCEL`, `BEST_CODEC`, and, for QSV/VAAPI, whether low-power mode is faster.

## Intel low power mode

Intel GPUs support a low-power encoding mode (VDEnc) that can be faster than the standard encoder. The script benchmarks both modes and selects the faster one when it works.

Requirements for low-power VBR/CBR may include HuC firmware and appropriate i915/xe driver support. If low-power VBR fails, normal encoding remains available.

## Benchmarking

### Quick benchmark

```bash
./benchmark-live.sh [duration] [mode]
./benchmark-live.sh 15 live
./benchmark-live.sh 15 local
./benchmark-live.sh 15 all
```

### Full encoder benchmark

```bash
./benchmark-accel.sh [duration] [runs]
./benchmark-accel.sh 30 3
```

`benchmark-accel.sh` uses the same `/dev/dri/renderD*` discovery and `DRI_DEVICE` / `QSV_DEVICE` / `VAAPI_DEVICE` overrides as `ffmpeg-smart.sh`.

The benchmark results are hardware- and driver-specific and are used only when a fallback video transcode is actually needed.
