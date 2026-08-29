#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

scripts=(
    ffmpeg-smart.sh
    benchmark-accel.sh
    benchmark-live.sh
    scripts/validate.sh
    lib/*.sh
    tests/*.sh
)

for script in "${scripts[@]}"; do
    bash -n "$script"
done

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck --severity=error "${scripts[@]}"
fi

tests/test-state-dir.sh
tests/test-additional-ffmpeg-options.sh
tests/test-map-all-codecs.sh
tests/test-benchmark-lock-owner.sh
tests/test-adaptive-probing.sh
tests/test-policy-matrix.sh
tests/test-hardware-command.sh
tests/test-pipe-replay.sh

project_version="$(tr -d '[:space:]' < VERSION)"
if [[ ! "$project_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[1-9][0-9]*)?$ ]]; then
    echo "Invalid semantic version in VERSION: $project_version" >&2
    exit 1
fi

script_version="$(sed -n 's/^VERSION="\([^"]*\)"/\1/p' ffmpeg-smart.sh)"
if [[ "$script_version" != "$project_version" ]]; then
    echo "VERSION mismatch: root=$project_version script=$script_version" >&2
    exit 1
fi

if ! grep -Fq "## [$project_version]" CHANGELOG.md; then
    echo "CHANGELOG.md has no section for $project_version" >&2
    exit 1
fi

echo "Validated ffmpeg-asr $project_version"
