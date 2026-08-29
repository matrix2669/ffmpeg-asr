#!/usr/bin/env bash
set -eo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
duration="${1:-15}"
mode="${2:-all}"
input="${FFMPEG_SMART_BENCHMARK_INPUT:-}"

[[ "$duration" =~ ^[1-9][0-9]*$ ]] || { echo "Duration must be a positive integer" >&2; exit 64; }
case "$mode" in live|local|all) ;; *) echo "Mode must be live, local, or all" >&2; exit 64 ;; esac

state_dir="${FFMPEG_SMART_STATE_DIR:-$root}"
mkdir -p -- "$state_dir"
sample="$state_dir/benchmark-live-input.ts"

if [[ "$mode" == local || "$mode" == all ]]; then
    ffmpeg -hide_banner -loglevel error -nostdin \
        -f lavfi -i 'testsrc2=size=1920x1080:rate=30000/1001' \
        -f lavfi -i 'sine=frequency=1000:sample_rate=48000' \
        -t "$duration" -c:v libx264 -preset veryfast -c:a aac -f mpegts -y "$sample"
    input="$sample"
fi

if [[ "$mode" == live && -z "$input" ]]; then
    echo "Set FFMPEG_SMART_BENCHMARK_INPUT for live mode" >&2
    exit 64
fi

output="$state_dir/benchmark-live-output.ts"
log="$state_dir/benchmark-live.log"
start_ns="$(date +%s%N 2>/dev/null || printf '0')"
set +e
FFMPEG_SMART_STATE_DIR="$state_dir" "$root/ffmpeg-smart.sh" -i "$input" -maxres 720 > "$output" 2> "$log"
status=$?
set -e
end_ns="$(date +%s%N 2>/dev/null || printf '0')"

ffprobe -v error -show_entries stream=index,codec_type,codec_name,profile,pix_fmt,width,height,r_frame_rate,field_order,channels,bit_rate -show_entries format=duration,size,bit_rate -of json "$output"
if [[ "$start_ns" =~ ^[0-9]+$ && "$end_ns" =~ ^[0-9]+$ && "$start_ns" -gt 0 ]]; then
    awk -v s="$start_ns" -v e="$end_ns" 'BEGIN { printf "elapsed_seconds=%.3f\n", (e-s)/1000000000 }'
fi
printf 'wrapper_status=%s\noutput=%s\nlog=%s\n' "$status" "$output" "$log"
exit "$status"
