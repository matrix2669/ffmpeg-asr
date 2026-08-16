# ffmpeg-asr

Adaptive stream re-encoder with automatic hardware acceleration detection and real-media capability benchmarking.

## What it does

Wraps ffmpeg to transcode streams with hardware acceleration. On first run, probes the hardware paths actually exposed to the process/container, benchmarks working encoder pipelines against a real compressed media sample, and caches the fastest result. Automatically handles:

- Hardware encoder selection (NVENC, VAAPI, QSV, VideoToolbox, V4L2 M2M, software)
- Linux DRI render-node discovery from `/dev/dri/renderD*`
- Independent QSV and VAAPI device overrides
- Per-accelerator 10-bit decode/encode capability tracking
- HEVC Main10/P010 preservation when supported
- 10-bit input conversion for H264 output
- Passthrough for 4K, HDR, and unsupported formats
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
| `-accel` | auto | Hardware acceleration: `qsv`, `vaapi`, `nvenc`, `videotoolbox`, `v4l2m2m`, `software` |
| `-vc` | auto | Output codec: `h264` or `hevc`; auto uses the fastest successfully benchmarked path |
| `-10bit` | auto | Enable 10-bit encoding when the selected accelerator supports it |
| `-hdr` | auto | Enable HDR re-encoding when the selected accelerator supports 10-bit HEVC |
| `--recache` | | Force re-probe encoder capabilities |

### Examples

```bash
# Basic usage (auto-detect acceleration and output codec)
./ffmpeg-smart.sh -i "http://stream.url/live.m3u8" -user_agent "Mozilla/5.0"

# Force HEVC output
./ffmpeg-smart.sh -i "stream_url" -user_agent "UA" -vc hevc

# Enable 10-bit encoding on capable hardware
./ffmpeg-smart.sh -i "stream_url" -user_agent "UA" -vc hevc -10bit

# Force specific acceleration
./ffmpeg-smart.sh -i "stream_url" -user_agent "UA" -accel vaapi
```

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

## Encoding settings

- **Video bitrate**: Scales quadratically with resolution (8 Mbps base at 1080p, 2 Mbps floor)
- **AAC input**: Stream-copied unchanged
- **Non-AAC mono**: AAC 96 kbps
- **Non-AAC stereo**: AAC 192 kbps
- **Non-AAC 5.1**: AAC 384 kbps
- **Non-AAC 7.1**: AAC 512 kbps
- **Unknown audio layout**: Downmixed to AAC stereo at 192 kbps
- **Audio-less inputs**: Audio encoder/filter options are omitted entirely
- **B-frames**: Enabled (2) for better compression unless low-power mode requires otherwise
- **GOP**: 1 second (matches source framerate)

Non-AAC audio transcodes use `aresample=async=1` to help maintain A/V sync. AAC passthrough is not filtered or re-encoded.

## Passthrough

Video is passed through (not re-encoded) when:
- Resolution is 4K or higher
- 10-bit content requires a 10-bit encode path that the selected accelerator cannot provide
- HDR content cannot be preserved by the selected HEVC/10-bit path

## 10-bit and HDR handling

Capabilities are tracked per accelerator, not globally. For example, a machine can report both:

```text
DECODE_10BIT='qsv=1;vaapi=1;'
ENCODE_10BIT='qsv=1;vaapi=1;'
```

When QSV or VAAPI proves HEVC 10-bit support, the runtime path keeps the video in P010/10-bit instead of forcing NV12. QSV uses HEVC Main10 when preserving 10-bit content.

| Input | Output Codec | Selected Accel Support | Result |
|-------|--------------|------------------------|--------|
| 10-bit | H264 | decode supported | Convert to 8-bit |
| 10-bit | HEVC | 10-bit encode | Keep 10-bit/Main10 |
| 10-bit | HEVC | no 10-bit encode | Passthrough |
| HDR | HEVC | 10-bit encode | Re-encode with HDR color metadata preserved |
| HDR | HEVC | no 10-bit encode | Passthrough |
| HDR | H264 | any | Passthrough |

Conversion uses hardware scalers (`scale_qsv`, `scale_vaapi`, `scale_cuda`, etc.) when available.

## Capability caching

On first run, the script:
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
HW_FINGERPRINT='script=render-node-v6;dri:renderD129:0x8086:0x56a6;selected:dri=/dev/dri/renderD129,vaapi=/dev/dri/renderD129,qsv=/dev/dri/renderD129;'
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

The script first detects usable candidates, then benchmarks them. It does not assume that one acceleration API is always faster than another.

- macOS: VideoToolbox candidate
- `/dev/nvidia0`: NVENC candidate
- Exposed Intel render node: QSV and VAAPI candidates when compiled into FFmpeg
- Exposed AMD render node: VAAPI candidate when compiled into FFmpeg
- V4L2 M2M device: V4L2 M2M candidate
- Software encoders are always retained as fallback candidates

The real-media benchmark determines `BEST_ACCEL`, `BEST_CODEC`, and (for QSV/VAAPI) whether low-power mode is faster.

## Intel low power mode

Intel GPUs support a low-power encoding mode (VDEnc) that can be faster than the standard encoder. The script benchmarks both modes and selects the faster one when it works.

**Requirements for low power mode with VBR/CBR rate control may include:**
- HuC (Hardware uCode) firmware loaded
- Appropriate i915/xe firmware and driver support for the platform

If low-power VBR fails, normal mode remains available and is used when it benchmarks successfully.

To inspect HuC-related kernel messages on i915 systems:

```bash
dmesg | grep -i huc
```

## Benchmarking

### Quick benchmark (tests ffmpeg-smart.sh)

```bash
./benchmark-live.sh [duration] [mode]
./benchmark-live.sh 15 live    # Test against live streams
./benchmark-live.sh 15 local   # Test against local sample files
./benchmark-live.sh 15 all     # Both (default)
```

### Full encoder benchmark

```bash
./benchmark-accel.sh [duration] [runs]
./benchmark-accel.sh 30 3  # 30 seconds per test, 3 runs each
```

`benchmark-accel.sh` uses the same `/dev/dri/renderD*` discovery and `DRI_DEVICE` / `QSV_DEVICE` / `VAAPI_DEVICE` overrides as `ffmpeg-smart.sh`.

Downloads demo files and benchmarks all working encoder combinations. The reported results are hardware- and driver-specific; `ffmpeg-smart.sh` uses its own current real-media probe rather than relying on a fixed acceleration or codec preference.

For live streams, anything above 1x realtime is sufficient, though additional headroom is useful for multiple simultaneous streams.
