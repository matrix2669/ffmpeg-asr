# ffmpeg-asr

Adaptive stream normalizer with hardware-accelerated transcoding fallback.

## What it does

`ffmpeg-smart.sh` normalizes live streams into MPEG-TS while minimizing unnecessary video re-encoding.

The script first resolves an output policy from either explicit flags or cached hardware capabilities. If the source video already satisfies that resolved policy, video is stream-copied and only remuxed. If it does not satisfy the policy, the script transcodes through the selected accelerator.

On first capability probe, the script benchmarks the hardware paths actually exposed to the process/container against a real compressed media sample and caches the fastest working fallback transcode path.

## Usage

```bash
./ffmpeg-smart.sh -i "stream_url" -user_agent "User-Agent"
```

Output is MPEG-TS on stdout.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `-i` | required | Input URL or file |
| `-user_agent` | | User agent for HTTP streams |
| `-accel` | auto | Accelerator used when transcoding is required: `qsv`, `vaapi`, `nvenc`, `videotoolbox`, `v4l2m2m`, `software` |
| `-vc` | auto | Output codec policy: `h264` or `hevc`. Auto uses `BEST_CODEC` from the capability cache |
| `-10bit` | auto | Allow/preserve 10-bit video. Auto follows the selected accelerator's 10-bit capability |
| `-hdr` | auto | Allow/preserve HDR video. Auto is enabled for a capable 10-bit HEVC path |
| `--recache` | | Force a fresh capability probe |

## Video policy

The copy/transcode decision follows the **resolved output policy**.

The resolved policy is:

```text
target codec = -vc when supplied, otherwise BEST_CODEC
10-bit policy = enabled by -10bit, otherwise selected accelerator capability
HDR policy = enabled by -hdr, otherwise selected HEVC/10-bit capability
```

Video is copied only when all applicable source properties already satisfy that policy:

```text
source codec == target codec
AND (source is not 10-bit OR 10-bit policy is enabled)
AND (source is not HDR OR HDR policy is enabled)
```

If any gate fails, video is re-encoded through the selected fallback transcode path.

### Examples

If the cache contains:

```bash
BEST_ACCEL='qsv'
BEST_CODEC='hevc'
DECODE_10BIT='qsv=1;vaapi=1;'
ENCODE_10BIT='qsv=1;vaapi=1;'
```

then the default policy on that system is HEVC with 10-bit/HDR support.

Typical behavior:

| Source | Resolved policy | Action |
|--------|-----------------|--------|
| HEVC 8-bit SDR | HEVC, 10-bit/HDR allowed | Copy |
| HEVC 10-bit SDR | HEVC, 10-bit allowed | Copy |
| HEVC HDR | HEVC, HDR allowed | Copy |
| H264 8-bit SDR | HEVC | Transcode H264 -> HEVC |
| H264 10-bit | HEVC | Transcode to HEVC using the resolved 10-bit policy |
| HEVC 10-bit | HEVC with 10-bit not allowed | Transcode to 8-bit HEVC |
| HEVC HDR | HEVC with HDR not allowed | Transcode instead of copy |

Supplying `-vc h264` changes the target codec policy to H264. Supplying `-vc hevc` changes it to HEVC. A codec override does not disable the 10-bit/HDR policy; those remain resolved independently.

`BEST_ACCEL` and `BEST_CODEC` therefore describe the preferred normalization target and fallback encoder, not a requirement to re-encode every input.

## Audio policy

Audio is normalized independently from video:

- **AAC input**: Stream-copied unchanged
- **Non-AAC mono**: AAC 96 kbps
- **Non-AAC stereo**: AAC 192 kbps
- **Non-AAC 5.1**: AAC 384 kbps
- **Non-AAC 7.1**: AAC 512 kbps
- **Unknown audio layout**: Downmixed to AAC stereo at 192 kbps
- **No audio stream**: Audio options are omitted entirely

Non-AAC audio transcodes use `aresample=async=1`. AAC passthrough is not filtered or re-encoded.

This allows video to remain a bit-for-bit copy when it already matches policy while audio can still be normalized independently.

## Linux DRI device selection

On Linux, the scripts enumerate render nodes that actually exist under `/dev/dri/renderD*`. This avoids selecting host sysfs devices that are not mapped into a container/LXC.

By default, the first exposed Intel/AMD render node is selected.

Overrides:

```bash
# Shared device for QSV and VAAPI
DRI_DEVICE=/dev/dri/renderD129 ./ffmpeg-smart.sh -i "stream_url"

# Independent devices
QSV_DEVICE=/dev/dri/renderD129 \
VAAPI_DEVICE=/dev/dri/renderD130 \
./ffmpeg-smart.sh -i "stream_url"
```

`QSV_DEVICE` and `VAAPI_DEVICE` take precedence over `DRI_DEVICE`.

QSV is initialized with the selected render node as its oneVPL child device. VAAPI receives the selected render node directly.

## Capability caching

The capability probe:

1. Downloads a 10-bit HEVC Jellyfin sample if needed
2. Tests real decode/filter/encode pipelines
3. Benchmarks normal and low-power modes where supported
4. Tracks 10-bit decode and encode support per accelerator
5. Stores the fastest working accelerator/codec combination

Example:

```bash
HW_FINGERPRINT='script=render-node-v8;dri:renderD129:0x8086:0x56a6;selected:dri=/dev/dri/renderD129,vaapi=/dev/dri/renderD129,qsv=/dev/dri/renderD129;'
BEST_ACCEL='qsv'
BEST_CODEC='hevc'
BEST_LOW_POWER='0'
SUPPORTS_10BIT_DECODE='true'
SUPPORTS_10BIT_ENCODE='true'
DECODE_10BIT='qsv=1;vaapi=1;'
ENCODE_10BIT='qsv=1;vaapi=1;'
ENCODERS='h264_qsv=14.1x;hevc_qsv=17.9x;hevc_qsv_10bit=1;h264_vaapi=12.7x;hevc_vaapi=13.2x;hevc_vaapi_10bit=1;libx264=3.27x;libx265=1.13x;'
```

The fingerprint includes the script version, exposed DRI devices, selected device overrides, and detected GPU hardware, so capability-changing updates invalidate old cache data automatically.

## Transcode settings

When video must be re-encoded:

- Video bitrate scales by resolution from an 8 Mbps 1080p baseline, with a 2 Mbps floor
- Maxrate is 1.25x target bitrate
- Buffer size is 2x target bitrate
- GOP is approximately one second
- Two B-frames are used unless low-power mode requires otherwise
- HEVC 10-bit uses P010/Main10 when allowed and supported
- A 10-bit source is explicitly converted to 8-bit when the resolved 10-bit policy is disabled

## Benchmarking

Quick benchmark:

```bash
./benchmark-live.sh 15 local
```

Full accelerator benchmark:

```bash
./benchmark-accel.sh 30 3
```

`benchmark-accel.sh` uses the same `/dev/dri/renderD*` discovery and `DRI_DEVICE` / `QSV_DEVICE` / `VAAPI_DEVICE` overrides as `ffmpeg-smart.sh`.
