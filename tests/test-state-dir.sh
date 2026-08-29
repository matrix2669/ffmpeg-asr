#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_dir/tests/test-helper.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-state.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
state_dir="$test_dir/state"
fake_bin="$test_dir/bin"
mkdir -p "$state_dir"
test_make_fake_version_tools "$fake_bin"
wrapper="$repo_dir/ffmpeg-smart.sh"

run_managed() {
    local output="$1"; shift
    set +e
    PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
        "$wrapper" "$@" > "$output" 2>&1
    TEST_WRAPPER_STATUS=$?
    set -e
}

run_managed "$test_dir/missing" -i input.ts
[[ "$TEST_WRAPPER_STATUS" -eq 78 ]]
grep -Fq 'ERROR [capability-cache-missing]' "$test_dir/missing"

set +e
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" "$wrapper" --cache-status > "$test_dir/status" 2>&1
status=$?
set -e
[[ "$status" -eq 78 ]]
grep -Fxq 'FFMPEG_SMART_CACHE_STATUS=missing' "$test_dir/status"

printf "HW_FINGERPRINT='old-shell-cache'\n" > "$state_dir/.capabilities.cache"
run_managed "$test_dir/invalid" -i input.ts
[[ "$TEST_WRAPPER_STATUS" -eq 78 ]]
grep -Fq 'ERROR [capability-cache-invalid]' "$test_dir/invalid"

PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" test_write_valid_cache "$repo_dir" "$state_dir"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" "$wrapper" --cache-status > "$test_dir/valid-status"
grep -Fxq 'FFMPEG_SMART_CACHE_STATUS=valid' "$test_dir/valid-status"

(
    set +u
    source "$repo_dir/lib/ffsmart-common.sh"
    source "$repo_dir/lib/ffsmart-cache.sh"
    FFSMART_CACHE_FILE="$test_dir/reassignment.cache"
    cat > "$FFSMART_CACHE_FILE" <<'EOF'
FFMPEG_SMART_CACHE_V2
value	schema	2
value	fingerprint	fixture
value	best_accel	vaapi
value	best_codec	h264
value	best_low_power	0
value	best_10bit_decode	true
value	best_10bit_encode	true
value	primary_device	/dev/dri/renderD129
value	secondary_device	/dev/dri/renderD128
device	gpu-a	/dev/dri/renderD128	vaapi	h264	1	true	true	11	10.9
device	gpu-b	/dev/dri/renderD129	vaapi	h264	0	true	true	14	11.5
EOF
    ffsmart_cache_snapshot_reusable_devices
    ffsmart_cache_reset
    ffsmart_device_set signature /dev/dri/renderD128 gpu-b
    ffsmart_device_set signature /dev/dri/renderD129 gpu-a
    ffsmart_cache_reuse_device /dev/dri/renderD128 gpu-b
    ffsmart_cache_reuse_device /dev/dri/renderD129 gpu-a
    [[ "$(ffsmart_device_get capacity /dev/dri/renderD128)" == 14 ]]
    [[ "$(ffsmart_device_get capacity /dev/dri/renderD129)" == 11 ]]
    [[ "$(ffsmart_device_get low_power /dev/dri/renderD128)" == 0 ]]
    [[ "$(ffsmart_device_get low_power /dev/dri/renderD129)" == 1 ]]
)

sed -i.bak 's/value\tfingerprint\t.*/value\tfingerprint\tstale/' "$state_dir/.capabilities.cache"
rm -f -- "$state_dir/.capabilities.cache.bak"
run_managed "$test_dir/stale" -i input.ts
[[ "$TEST_WRAPPER_STATUS" -eq 78 ]]
grep -Fq 'ERROR [capability-cache-stale]' "$test_dir/stale"

rm -f -- "$state_dir/.capabilities.cache"
printf 'fixture\n' > "$state_dir/benchmark-h264.mkv"
printf 'fixture\n' > "$state_dir/benchmark-hevc10.mkv"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_TEST_ARGS="$test_dir/implicit.args" \
    "$wrapper" -i input.ts -vc h264 > "$test_dir/implicit" 2>&1
[[ ! -e "$state_dir/.benchmark.lock" ]]
grep -Fq 'Capability cache is missing; rebuilding' "$test_dir/implicit"

rm -f -- "$state_dir/.capabilities.cache"
set +e
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
FFMPEG_SMART_CACHE_FALLBACK=proxy FFMPEG_SMART_FALLBACK_MARKER="$state_dir/marker" \
FFMPEG_SMART_TEST_ARGS="$test_dir/proxy.args" FFMPEG_SMART_TEST_OUTPUT=proxy-output \
    "$wrapper" -i input.ts -ffmpeg-map-mode all > "$test_dir/proxy" 2>&1
status=$?
set -e
[[ "$status" -eq 0 ]] || { cat "$test_dir/proxy" >&2; exit 1; }
grep -Fq 'WARNING [degraded-proxy]' "$test_dir/proxy"
grep -Fxq -- '-c' "$test_dir/proxy.args"
grep -Fxq -- 'copy' "$test_dir/proxy.args"
grep -Fxq -- 'pipe:1' "$test_dir/proxy.args"
[[ -s "$state_dir/marker" ]]

printf '%s\n' "$$" > "$state_dir/.benchmark.lock"
set +e
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
    "$wrapper" -i input.ts > "$test_dir/locked" 2>&1
status=$?
set -e
[[ "$status" -eq 75 ]]
grep -Fq 'Hardware benchmark in progress' "$test_dir/locked"

echo 'Persistent state, cache migration, fallback, and lock tests passed'
