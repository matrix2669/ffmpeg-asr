#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_dir/ffmpeg-smart.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffmpeg-smart-lock-owner.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT

sed -n '/^cleanup_benchmark_lock()/,/^}/p' "$wrapper" > "$test_dir/cleanup-function.sh"
# shellcheck source=/dev/null
source "$test_dir/cleanup-function.sh"

BENCHMARK_LOCK_FILE="$test_dir/.benchmark.lock"
BENCHMARK_LOCK_OWNER_PID="$$"
printf '%s\n' "$BENCHMARK_LOCK_OWNER_PID" > "$BENCHMARK_LOCK_FILE"
trap cleanup_benchmark_lock EXIT

# Command substitutions and benchmark workers inherit EXIT cleanup state. They
# must leave the top-level recache owner's lock intact when their subshell exits.
child_output="$(printf '%s' child-complete)"
[[ "$child_output" == "child-complete" ]]
[[ -f "$BENCHMARK_LOCK_FILE" ]]

(
    sleep 0.1
) &
worker_pid=$!
[[ -f "$BENCHMARK_LOCK_FILE" ]]
wait "$worker_pid"
[[ -f "$BENCHMARK_LOCK_FILE" ]]
[[ "$(<"$BENCHMARK_LOCK_FILE")" == "$BENCHMARK_LOCK_OWNER_PID" ]]

# A replaced lock belongs to another recache and must not be removed by the old
# owner's cleanup.
printf '%s\n' 999999 > "$BENCHMARK_LOCK_FILE"
cleanup_benchmark_lock
[[ -f "$BENCHMARK_LOCK_FILE" ]]

# The top-level owner removes only its own recorded lock.
printf '%s\n' "$BENCHMARK_LOCK_OWNER_PID" > "$BENCHMARK_LOCK_FILE"
cleanup_benchmark_lock
[[ ! -e "$BENCHMARK_LOCK_FILE" ]]
trap 'rm -rf -- "$test_dir"' EXIT

grep -Fq 'BENCHMARK_LOCK_OWNER_PID="$$"' "$wrapper"
grep -Fq 'trap cleanup_benchmark_lock EXIT' "$wrapper"

echo "Benchmark lock ownership tests passed"
