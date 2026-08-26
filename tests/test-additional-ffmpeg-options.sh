#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffmpeg-smart-options.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT

sed -n '/^scan_device_overrides()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" > "$test_dir/functions.sh"
sed -n '/^parse_cli_args()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
sed -n '/^configuration_error()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
sed -n '/^validate_ffmpeg_mode()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
sed -n '/^validate_advanced_arg()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
sed -n '/^resolve_static_ffmpeg_args()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
sed -n '/^resolve_audio_ffmpeg_args()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
sed -n '/^resolve_video_tuning_args()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
sed -n '/^validate_runtime_mapping()/,/^}/p' "$repo_dir/ffmpeg-smart.sh" >> "$test_dir/functions.sh"
# shellcheck source=/dev/null
source "$test_dir/functions.sh"

assert_occurrence_count() {
    local expected="$1"
    local needle="$2"
    local actual

    actual="$(grep -Fc "$needle" "$repo_dir/ffmpeg-smart.sh")"
    if [[ "$actual" -ne "$expected" ]]; then
        echo "Expected $expected occurrences of $needle, found $actual" >&2
        exit 1
    fi
}

LOG_PREFIX="[ffmpeg-smart-test]"
DRI_DEVICE=""
VAAPI_DEVICE=""
QSV_DEVICE=""
DRI_DEVICE_WAS_SET=false
VAAPI_DEVICE_WAS_SET=false
QSV_DEVICE_WAS_SET=false

# Scoped arguments that resemble wrapper device flags must remain opaque during
# the early wrapper-device scan; later scope validation rejects ownership conflicts.
scan_device_overrides \
    -ffmpeg-input-option -device \
    -ffmpeg-map -device \
    -ffmpeg-video-option -device \
    -ffmpeg-audio-option -device \
    -ffmpeg-mux-option /dev/dri/renderD199
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
FFMPEG_INPUT_MODE="inherit"
FFMPEG_MAP_MODE="inherit"
FFMPEG_VIDEO_MODE="inherit"
FFMPEG_AUDIO_MODE="inherit"
FFMPEG_MUX_MODE="inherit"
USER_INPUT_ARGS=()
USER_MAP_SPECS=()
USER_VIDEO_ARGS=()
USER_AUDIO_ARGS=()
USER_MUX_ARGS=()

parse_cli_args \
    -i input.ts \
    -ffmpeg-input-mode replace \
    -ffmpeg-input-option -fflags \
    -ffmpeg-input-option +discardcorrupt+genpts+nobuffer \
    -ffmpeg-map-mode all \
    -ffmpeg-video-mode add \
    -ffmpeg-video-option -force_key_frames \
    -ffmpeg-video-option 'expr:gte(t,n_forced*2)' \
    -ffmpeg-audio-mode replace \
    -ffmpeg-audio-option -c:a \
    -ffmpeg-audio-option ac3 \
    -ffmpeg-mux-mode add \
    -ffmpeg-mux-option -metadata \
    -ffmpeg-mux-option "service_name=Mobile feed" \
    -ffmpeg-mux-option "; touch $test_dir/must-not-run"

[[ "$URL" == "input.ts" ]]
resolve_static_ffmpeg_args
[[ "${FFMPEG_INPUT_ARGS[*]}" == "-fflags +discardcorrupt+genpts+nobuffer" ]]
[[ "${FFMPEG_MAP_ARGS[*]}" == "-map 0" ]]
[[ "${USER_VIDEO_ARGS[*]}" == "-force_key_frames expr:gte(t,n_forced*2)" ]]
[[ "${USER_AUDIO_ARGS[*]}" == "-c:a ac3" ]]
[[ "${USER_MUX_ARGS[0]}" == "-metadata" ]]
[[ "${USER_MUX_ARGS[1]}" == "service_name=Mobile feed" ]]
[[ "${USER_MUX_ARGS[2]}" == "; touch $test_dir/must-not-run" ]]
[[ ! -e "$test_dir/must-not-run" ]]

# Audio replace and video add resolve independently from wrapper-selected defaults.
AUDIO_ARGS=(-c:a copy)
resolve_audio_ffmpeg_args
[[ "${FFMPEG_AUDIO_ARGS[*]}" == "-c:a ac3" ]]
MANAGED_VIDEO_TUNING_ARGS=(-b:v 2000000 -g 30)
resolve_video_tuning_args
[[ "${FFMPEG_VIDEO_TUNING_ARGS[*]}" == "-b:v 2000000 -g 30 -force_key_frames expr:gte(t,n_forced*2)" ]]

# The legacy boundary remains a mux/output alias and now reaches both production paths.
FFMPEG_MUX_MODE="inherit"
USER_MUX_ARGS=()
parse_cli_args -ffmpeg-option -muxdelay -ffmpeg-option 0
resolve_static_ffmpeg_args
[[ "$FFMPEG_MUX_MODE" == "add" ]]
[[ "${FFMPEG_MUX_ARGS[*]}" == *"-max_muxing_queue_size 4096 -muxdelay 0" ]]

if (USER_MUX_ARGS=(); parse_cli_args -ffmpeg-option) >/dev/null 2>&1; then
    echo "Expected a missing scoped option value to fail" >&2
    exit 1
fi

if (FFMPEG_VIDEO_MODE="add"; USER_VIDEO_ARGS=(-c:v copy); resolve_static_ffmpeg_args) >/dev/null 2>&1; then
    echo "Expected a wrapper-owned video encoder option to fail" >&2
    exit 1
fi

if (FFMPEG_MUX_MODE="add"; USER_MUX_ARGS=(-c:a ac3); resolve_static_ffmpeg_args) >/dev/null 2>&1; then
    echo "Expected an audio codec outside the audio scope to fail" >&2
    exit 1
fi

if (FFMPEG_MAP_MODE="replace"; USER_MAP_SPECS=(); resolve_static_ffmpeg_args) >/dev/null 2>&1; then
    echo "Expected empty replacement mapping to fail" >&2
    exit 1
fi

if (FFMPEG_INPUT_MODE="invalid"; resolve_static_ffmpeg_args) >/dev/null 2>&1; then
    echo "Expected an invalid scope mode to fail" >&2
    exit 1
fi

if (FFMPEG_MAP_MODE="all"; USER_MAP_SPECS=(); validate_runtime_mapping 2) >/dev/null 2>&1; then
    echo "Expected all-stream mapping with multiple videos to fail" >&2
    exit 1
fi

FFMPEG_MAP_MODE="replace"
USER_MAP_SPECS=(0:v:0 0:a:0? 0:a:1?)
validate_runtime_mapping 2

if (FFMPEG_MAP_MODE="replace"; USER_MAP_SPECS=(0:a:0); validate_runtime_mapping 1) >/dev/null 2>&1; then
    echo "Expected a mapping without video to fail" >&2
    exit 1
fi

if (FFMPEG_MAP_MODE="replace"; USER_MAP_SPECS=(0:0); validate_runtime_mapping 1) >/dev/null 2>&1; then
    echo "Expected an untyped positive mapping to fail" >&2
    exit 1
fi

if (FFMPEG_MAP_MODE="add"; USER_MAP_SPECS=(-0:v:0); validate_runtime_mapping 1) >/dev/null 2>&1; then
    echo "Expected a negative video mapping to fail" >&2
    exit 1
fi

assert_occurrence_count 3 '"${FFMPEG_INPUT_ARGS[@]}"'
assert_occurrence_count 3 '"${FFMPEG_MAP_ARGS[@]}"'
assert_occurrence_count 2 '"${FFMPEG_AUDIO_ARGS[@]}"'
assert_occurrence_count 3 '"${FFMPEG_MUX_ARGS[@]}"'
grep -Fq '"${FFMPEG_VIDEO_TUNING_ARGS[@]}"' "$repo_dir/ffmpeg-smart.sh"
assert_occurrence_count 2 '"${AUDIO_POLICY_ARGS[@]}"'
assert_occurrence_count 2 '"${MAPPED_AUXILIARY_CODEC_ARGS[@]}"'
video_tuning_line="$(grep -nF 'FFMPEG_VIDEO_TUNING_ARGS[@]+' "$repo_dir/ffmpeg-smart.sh" | tail -n 1 | cut -d: -f1)"
video_policy_line="$(grep -nF 'VIDEO_POLICY_ARGS[@]+' "$repo_dir/ffmpeg-smart.sh" | tail -n 1 | cut -d: -f1)"
[[ "$video_policy_line" -gt "$video_tuning_line" ]]

echo "Scoped FFmpeg option argument tests passed"
