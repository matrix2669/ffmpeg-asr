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

rm -f -- "$state_dir/.benchmark.lock" "$state_dir/.capabilities.cache"
fake_bin="$temp_dir/fake-bin"
mkdir -p "$fake_bin"
fake_ffmpeg="$fake_bin/ffmpeg"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf '\''%s\n'\'' "$@" > "$FFMPEG_SMART_TEST_ARGS"' \
    'printf '\''degraded-proxy-output\n'\''' \
    'exit "${FFMPEG_SMART_TEST_EXIT:-0}"' \
    >"$fake_ffmpeg"
chmod +x "$fake_ffmpeg"

run_proxy_fallback() {
    local output_file="$1"
    shift
    set +e
    PATH="$fake_bin:$PATH" \
    FFMPEG_SMART_STATE_DIR="$state_dir" \
    FFMPEG_SMART_REQUIRE_CACHE=true \
    FFMPEG_SMART_CACHE_FALLBACK=proxy \
    FFMPEG_SMART_FALLBACK_MARKER="$state_dir/runtime/fallback-invocation" \
    FFMPEG_SMART_TEST_ARGS="$temp_dir/ffmpeg-args" \
        "$wrapper" "$@" >"$output_file" 2>&1
    wrapper_status=$?
    set -e
}

proxy_output="$temp_dir/proxy-missing.log"
run_proxy_fallback "$proxy_output" \
    -user_agent "test agent" \
    -i "https://example.invalid/live" \
    -ffmpeg-input-mode replace \
    -ffmpeg-input-option -nostdin \
    -ffmpeg-map-mode all \
    -ffmpeg-mux-mode replace \
    -ffmpeg-mux-option -flush_packets \
    -ffmpeg-mux-option 1
[[ "$wrapper_status" -eq 0 ]]
grep -Fq '[ffmpeg-smart] WARNING [degraded-proxy]: Hardware capability cache is missing' "$proxy_output"
grep -Fq 'degraded-proxy-output' "$proxy_output"
grep -Fxq -- '-user_agent' "$temp_dir/ffmpeg-args"
grep -Fxq -- 'test agent' "$temp_dir/ffmpeg-args"
grep -Fxq -- '-nostdin' "$temp_dir/ffmpeg-args"
grep -Fxq -- '-map' "$temp_dir/ffmpeg-args"
grep -Fxq -- '0' "$temp_dir/ffmpeg-args"
grep -Fxq -- '-c' "$temp_dir/ffmpeg-args"
grep -Fxq -- 'copy' "$temp_dir/ffmpeg-args"
grep -Fxq -- '-flush_packets' "$temp_dir/ffmpeg-args"
grep -Fxq -- 'mpegts' "$temp_dir/ffmpeg-args"
grep -Fxq -- 'pipe:1' "$temp_dir/ffmpeg-args"
marker="$state_dir/runtime/fallback-invocation"
[[ -s "$marker" ]]
first_marker="$(<"$marker")"

printf "return 1\n" >"$state_dir/.capabilities.cache"
invalid_proxy_output="$temp_dir/proxy-invalid.log"
run_proxy_fallback "$invalid_proxy_output" -i pipe:0
[[ "$wrapper_status" -eq 0 ]]
grep -Fq 'Hardware capability cache is invalid or unreadable' "$invalid_proxy_output"
grep -Fxq -- 'pipe:0' "$temp_dir/ffmpeg-args"
second_marker="$(<"$marker")"
[[ "$second_marker" != "$first_marker" ]]

printf "HW_FINGERPRINT='definitely-stale'\n" >"$state_dir/.capabilities.cache"
stale_proxy_output="$temp_dir/proxy-stale.log"
run_proxy_fallback "$stale_proxy_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 0 ]]
grep -Fq 'Hardware capability cache does not match the current hardware or policy' "$stale_proxy_output"

printf '%s\n' "$$" >"$state_dir/.benchmark.lock"
lock_proxy_output="$temp_dir/proxy-lock.log"
run_proxy_fallback "$lock_proxy_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 0 ]]
grep -Fq '[ffmpeg-smart] WARNING [degraded-proxy]: Hardware benchmark is in progress' "$lock_proxy_output"
grep -Fq 'degraded-proxy-output' "$lock_proxy_output"

rm -f -- "$state_dir/.benchmark.lock" "$state_dir/.capabilities.cache"
native_failure_output="$temp_dir/proxy-native-failure.log"
FFMPEG_SMART_TEST_EXIT=23 run_proxy_fallback "$native_failure_output" -i unavailable-test-input
[[ "$wrapper_status" -eq 23 ]]
grep -Fq 'degraded-proxy-output' "$native_failure_output"

invalid_mode_output="$temp_dir/proxy-invalid-mode.log"
set +e
FFMPEG_SMART_STATE_DIR="$state_dir" \
FFMPEG_SMART_CACHE_FALLBACK=transcode \
    "$wrapper" -i unavailable-test-input >"$invalid_mode_output" 2>&1
wrapper_status=$?
set -e
[[ "$wrapper_status" -eq 64 ]]
grep -Fq 'FFMPEG_SMART_CACHE_FALLBACK must be none or proxy' "$invalid_mode_output"

echo "Persistent state and required-cache error tests passed"
