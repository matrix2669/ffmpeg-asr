#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_dir/tests/test-helper.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-options.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
state_dir="$test_dir/state"; fake_bin="$test_dir/bin"
mkdir -p "$state_dir"
test_make_fake_version_tools "$fake_bin"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" test_write_valid_cache "$repo_dir" "$state_dir"

marker="$test_dir/must-not-run"
set +e
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
FFMPEG_SMART_TEST_ARGS="$test_dir/args" \
    "$repo_dir/ffmpeg-smart.sh" -i input.ts -vc h264 -maxres 480 \
    -ffmpeg-input-mode replace -ffmpeg-input-option -nostdin \
    -ffmpeg-map-mode replace -ffmpeg-map 0:v:0 -ffmpeg-map '0:a:0?' \
    -ffmpeg-video-mode add -ffmpeg-video-option -force_key_frames -ffmpeg-video-option 'expr:gte(t,n_forced*2)' \
    -ffmpeg-audio-mode replace -ffmpeg-audio-option -c:a -ffmpeg-audio-option ac3 \
    -ffmpeg-mux-mode add -ffmpeg-mux-option -metadata -ffmpeg-mux-option 'service_name=Mobile feed' \
    -ffmpeg-mux-option "; touch $marker" > "$test_dir/log" 2>&1
status=$?
set -e
[[ "$status" -eq 0 ]] || { cat "$test_dir/log" >&2; exit 1; }

grep -Fxq -- '-nostdin' "$test_dir/args"
grep -Fxq -- 'expr:gte(t,n_forced*2)' "$test_dir/args"
grep -Fxq -- 'service_name=Mobile feed' "$test_dir/args"
grep -Fxq -- "; touch $marker" "$test_dir/args"
[[ ! -e "$marker" ]]
grep -Fxq -- 'pipe:1' "$test_dir/args"

set +e
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" "$repo_dir/ffmpeg-smart.sh" -i input.ts -ffmpeg-input-option -analyzeduration > "$test_dir/reject" 2>&1
status=$?
set -e
[[ "$status" -eq 64 ]]
grep -Fq 'owned by FFmpeg Smart' "$test_dir/reject"

set +e
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" "$repo_dir/ffmpeg-smart.sh" -i input.ts -ffmpeg-map-mode replace -ffmpeg-map 0:a:0 > "$test_dir/map-reject" 2>&1
status=$?
set -e
[[ "$status" -eq 64 ]]
grep -Fq 'exactly one video' "$test_dir/map-reject"

echo 'Scoped FFmpeg argument and shell-safety tests passed'
