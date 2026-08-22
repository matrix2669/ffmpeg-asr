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

missing_output="$temp_dir/missing.log"
run_wrapper "$missing_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 78 ]]
grep -Fq '[ffmpeg-smart] ERROR [capability-cache-missing]' "$missing_output"
grep -Fq 'Rebuild Hardware Cache' "$missing_output"
[[ -d "$state_dir" ]]

printf "return 1\n" >"$state_dir/.capabilities.cache"
invalid_output="$temp_dir/invalid.log"
run_wrapper "$invalid_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 78 ]]
grep -Fq '[ffmpeg-smart] ERROR [capability-cache-invalid]' "$invalid_output"

printf "HW_FINGERPRINT='definitely-stale'\n" >"$state_dir/.capabilities.cache"
stale_output="$temp_dir/stale.log"
run_wrapper "$stale_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 78 ]]
grep -Fq '[ffmpeg-smart] ERROR [capability-cache-stale]' "$stale_output"

printf '%s\n' "$$" >"$state_dir/.benchmark.lock"
lock_output="$temp_dir/lock.log"
run_wrapper "$lock_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 75 ]]
grep -Fq '[ffmpeg-smart] Hardware benchmark in progress' "$lock_output"

echo "Persistent state and required-cache error tests passed"
