#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_dir/lib/ffsmart-common.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-lock.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
FFSMART_LOCK_FILE="$test_dir/.benchmark.lock"
FFSMART_LOCK_OWNER_PID="$$"
FFSMART_LOCK_OWNER_START="$(ffsmart_process_start_time "$$" || true)"
write_owned_lock() {
    printf '%s%s%s\n' "$FFSMART_LOCK_OWNER_PID" "${FFSMART_LOCK_OWNER_START:+ }" "$FFSMART_LOCK_OWNER_START" > "$FFSMART_LOCK_FILE"
}
write_owned_lock

child="$(printf child)"
[[ "$child" == child ]]
[[ -f "$FFSMART_LOCK_FILE" ]]

(
    ffsmart_lock_release
)
[[ -f "$FFSMART_LOCK_FILE" ]]

printf '999999\n' > "$FFSMART_LOCK_FILE"
ffsmart_lock_release
[[ -f "$FFSMART_LOCK_FILE" ]]

write_owned_lock
ffsmart_lock_release
[[ ! -e "$FFSMART_LOCK_FILE" ]]

if [[ -n "$FFSMART_LOCK_OWNER_START" ]]; then
    printf '%s %s\n' "$$" "$((FFSMART_LOCK_OWNER_START + 1))" > "$FFSMART_LOCK_FILE"
    ! ffsmart_lock_is_live
    [[ ! -e "$FFSMART_LOCK_FILE" ]]
fi

echo 'Benchmark lock ownership tests passed'
