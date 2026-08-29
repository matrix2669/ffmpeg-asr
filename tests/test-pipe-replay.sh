#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_dir/tests/test-helper.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-pipe.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
state_dir="$test_dir/state"; fake_bin="$test_dir/bin"
mkdir -p "$state_dir" "$fake_bin"

cat > "$fake_bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then echo 'ffmpeg version pipe-test'; exit 0; fi
printf '%s\n' "$@" > "$FFMPEG_SMART_TEST_ARGS"
cat
EOF
cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then echo 'ffprobe version pipe-test'; exit 0; fi
cat <<'OUT'
index=0|codec_name=h264|profile=High|codec_type=video|width=1280|height=720|pix_fmt=yuv420p|r_frame_rate=30000/1001|field_order=progressive|bit_rate=1000000|color_space=bt709|color_transfer=bt709|color_primaries=bt709
index=1|codec_name=aac|profile=LC|codec_type=audio|sample_rate=48000|channels=2|bit_rate=128000
OUT
EOF
chmod +x "$fake_bin/ffmpeg" "$fake_bin/ffprobe"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" test_write_valid_cache "$repo_dir" "$state_dir"

for n in $(seq 1 2000); do printf 'packet-%04d:%s\n' "$n" 'opening-media-must-survive'; done > "$test_dir/input"

PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
FFMPEG_SMART_TEST_ARGS="$test_dir/args" \
    "$repo_dir/ffmpeg-smart.sh" -i pipe:0 -vc h264 < "$test_dir/input" > "$test_dir/output" 2> "$test_dir/log"

cmp "$test_dir/input" "$test_dir/output"
grep -Fxq -- 'pipe:0' "$test_dir/args"
echo 'Non-seekable stdin opening-sample replay test passed'
