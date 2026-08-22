#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

for script in ffmpeg-smart.sh benchmark-accel.sh benchmark-live.sh scripts/validate.sh; do
    bash -n "$script"
done

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
