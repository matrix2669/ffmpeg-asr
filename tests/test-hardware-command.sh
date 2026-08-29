#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-hardware.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT

source "$repo_dir/lib/ffsmart-common.sh"
source "$repo_dir/lib/ffsmart-cache.sh"
source "$repo_dir/lib/ffsmart-hardware.sh"
source "$repo_dir/lib/ffsmart-policy.sh"

FFSMART_H264_SAMPLE="$test_dir/h264.mkv"
FFSMART_HEVC10_SAMPLE="$test_dir/hevc10.mkv"
printf 'h264\n' > "$FFSMART_H264_SAMPLE"
printf 'hevc10\n' > "$FFSMART_HEVC10_SAMPLE"

ffsmart_build_benchmark_command /dev/dri/renderD128 vaapi h264 1 5
printf '%s\n' "${FFSMART_BENCH_CMD[@]}" | grep -Fxq -- "$FFSMART_HEVC10_SAMPLE"
printf '%s\n' "${FFSMART_BENCH_CMD[@]}" | grep -Fxq -- 'format=nv12,hwupload'

ffsmart_build_benchmark_command /dev/dri/renderD128 qsv hevc 1 5
printf '%s\n' "${FFSMART_BENCH_CMD[@]}" | grep -Fxq -- "$FFSMART_HEVC10_SAMPLE"
printf '%s\n' "${FFSMART_BENCH_CMD[@]}" | grep -Fxq -- 'format=p010le,hwupload=extra_hw_frames=64'

FFSMART_SELECTED_ACCEL=vaapi
FFSMART_SELECTED_DEVICE=/dev/dri/renderD129
FFSMART_TARGET_CODEC=h264
FFSMART_VIDEO_PIX_FMT=yuv420p10le
FFSMART_VIDEO_HEIGHT=1080
FFSMART_VIDEO_WIDTH=1920
FFSMART_OUTPUT_HEIGHT=720
FFSMART_OUTPUT_WIDTH=1280
FFSMART_DEINTERLACE=false
FFSMART_FORCE_SDR=false
FFSMART_ALLOW_10BIT=auto
FFSMART_CACHE_BEST_10BIT_ENCODE=true
FFSMART_VIDEO_COLOR_TRANSFER=smpte2084
FFSMART_VIDEO_COLOR_PRIMARIES=bt2020
ffsmart_build_hardware_args
ffsmart_build_filters
printf '%s\n' "${FFSMART_HW_INPUT_ARGS[@]}" | grep -Fxq -- 'vaapi=ffsmart:/dev/dri/renderD129'
printf '%s\n' "${FFSMART_FILTER_ARGS[@]}" | grep -Fq 'scale_vaapi=w=1280:h=720:format=nv12'

FFSMART_FORCE_SDR=true
FFSMART_OUTPUT_HEIGHT=1080
FFSMART_OUTPUT_WIDTH=1920
ffsmart_build_hardware_args
ffsmart_build_filters
! printf '%s\n' "${FFSMART_HW_INPUT_ARGS[@]}" | grep -Fxq -- '-hwaccel'
printf '%s\n' "${FFSMART_FILTER_ARGS[@]}" | grep -Fq 'zscale=t=linear'
printf '%s\n' "${FFSMART_FILTER_ARGS[@]}" | grep -Fq 'hwupload'

echo 'Representative Main10 benchmark and hardware filter command tests passed'
