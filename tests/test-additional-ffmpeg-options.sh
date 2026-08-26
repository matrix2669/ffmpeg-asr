#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffmpeg-smart-options.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT

sed -n '/^scan_device_overrides()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" > "$test_dir/functions.sh"
sed -n '/^parse_cli_args()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
# shellcheck source=/dev/null
source "$test_dir/functions.sh"

LOG_PREFIX="[ffmpeg-smart-test]"
DRI_DEVICE=""
VAAPI_DEVICE=""
QSV_DEVICE=""
DRI_DEVICE_WAS_SET=false
VAAPI_DEVICE_WAS_SET=false
QSV_DEVICE_WAS_SET=false

# A passthrough argument that resembles a wrapper device flag must remain opaque.
scan_device_overrides -ffmpeg-option -device -ffmpeg-option /dev/dri/renderD199
[[ -z "$DRI_DEVICE" ]]
[[ -z "$VAAPI_DEVICE" ]]
[[ -z "$QSV_DEVICE" ]]

AGENT=""
URL=""
VCODEC_OUT=""
ALLOW_10BIT=""
ALLOW_HDR=""
MAX_RES=""
MAX_CHANNELS=""
MAX_BITRATE_INPUT=""
FORCE_SDR=false
FORCE_DEINT=false
RECACHE=false
RECACHE_ONLY=false
ACCEL="__auto__"
EXTRA_FFMPEG_ARGS=()

parse_cli_args \
    -i input.ts \
    -ffmpeg-option -metadata \
    -ffmpeg-option "service_name=Mobile feed" \
    -ffmpeg-option "; touch $test_dir/must-not-run"

[[ "$URL" == "input.ts" ]]
[[ ${#EXTRA_FFMPEG_ARGS[@]} -eq 3 ]]
[[ "${EXTRA_FFMPEG_ARGS[0]}" == "-metadata" ]]
[[ "${EXTRA_FFMPEG_ARGS[1]}" == "service_name=Mobile feed" ]]
[[ "${EXTRA_FFMPEG_ARGS[2]}" == "; touch $test_dir/must-not-run" ]]
[[ ! -e "$test_dir/must-not-run" ]]

if (EXTRA_FFMPEG_ARGS=(); parse_cli_args -ffmpeg-option) >/dev/null 2>&1; then
    echo "Expected a missing -ffmpeg-option value to fail" >&2
    exit 1
fi

grep -Fq '"${EXTRA_FFMPEG_ARGS[@]}"' "$repo_dir/ffmpeg-smart.sh"

echo "Additional FFmpeg option argument tests passed"
