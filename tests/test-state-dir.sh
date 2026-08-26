#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_dir/ffmpeg-smart.sh"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
state_dir="$temp_dir/persistent-state"

run_wrapper() {
    local output_file="$1"
    shift
    set +e
    FFMPEG_SMART_STATE_DIR="$state_dir" \
    FFMPEG_SMART_REQUIRE_CACHE=true \
        "$wrapper" "$@" >"$output_file" 2>&1
    wrapper_status=$?
    set -e
}

run_cache_status() {
    local output_file="$1"
    shift
    set +e
    FFMPEG_SMART_STATE_DIR="$state_dir" \
        "$wrapper" --cache-status "$@" >"$output_file" 2>&1
    wrapper_status=$?
    set -e
}

missing_output="$temp_dir/missing.log"
run_wrapper "$missing_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 78 ]]
grep -Fq '[ffmpeg-smart] ERROR [capability-cache-missing]' "$missing_output"
grep -Fq 'Rebuild Hardware Cache' "$missing_output"
[[ -d "$state_dir" ]]

missing_status_output="$temp_dir/missing-status.log"
run_cache_status "$missing_status_output"
[[ "$wrapper_status" -eq 78 ]]
grep -Fxq 'FFMPEG_SMART_CACHE_STATUS=missing' "$missing_status_output"

printf "return 1\n" >"$state_dir/.capabilities.cache"
invalid_output="$temp_dir/invalid.log"
run_wrapper "$invalid_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 78 ]]
grep -Fq '[ffmpeg-smart] ERROR [capability-cache-invalid]' "$invalid_output"

invalid_status_output="$temp_dir/invalid-status.log"
run_cache_status "$invalid_status_output"
[[ "$wrapper_status" -eq 78 ]]
grep -Fxq 'FFMPEG_SMART_CACHE_STATUS=invalid' "$invalid_status_output"

printf "HW_FINGERPRINT='definitely-stale'\n" >"$state_dir/.capabilities.cache"
stale_output="$temp_dir/stale.log"
run_wrapper "$stale_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 78 ]]
grep -Fq '[ffmpeg-smart] ERROR [capability-cache-stale]' "$stale_output"

stale_status_output="$temp_dir/stale-status.log"
run_cache_status "$stale_status_output"
[[ "$wrapper_status" -eq 78 ]]
grep -Fxq 'FFMPEG_SMART_CACHE_STATUS=stale' "$stale_status_output"

fingerprint_prefix="$temp_dir/fingerprint-prefix.sh"
sed '/^ensure_probe_sample/,$d' "$wrapper" >"$fingerprint_prefix"
current_fingerprint="$({
    FFMPEG_SMART_STATE_DIR="$state_dir" \
        bash -c 'source "$1"; get_hw_fingerprint' bash "$fingerprint_prefix"
})"
printf "HW_FINGERPRINT='%s'\nBEST_ACCEL='software'\nBEST_CODEC='h264'\n" \
    "$current_fingerprint" >"$state_dir/.capabilities.cache"
valid_status_output="$temp_dir/valid-status.log"
run_cache_status "$valid_status_output"
[[ "$wrapper_status" -eq 0 ]]
grep -Fxq 'FFMPEG_SMART_CACHE_STATUS=valid' "$valid_status_output"

conflicting_status_output="$temp_dir/conflicting-status.log"
run_cache_status "$conflicting_status_output" --recache-only
[[ "$wrapper_status" -eq 64 ]]
grep -Fq -- '--cache-status cannot be combined' "$conflicting_status_output"

printf '%s\n' "$$" >"$state_dir/.benchmark.lock"
lock_output="$temp_dir/lock.log"
run_wrapper "$lock_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 75 ]]
grep -Fq '[ffmpeg-smart] Hardware benchmark in progress' "$lock_output"

echo "Persistent state and required-cache error tests passed"
