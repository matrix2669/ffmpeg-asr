#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_dir/tests/test-helper.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-map.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
state_dir="$test_dir/state"; fake_bin="$test_dir/bin"
mkdir -p "$state_dir"
test_make_fake_version_tools "$fake_bin"
cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then echo 'ffprobe version test-build'; exit 0; fi
cat <<'OUT'
index=0|codec_name=h264|profile=High|codec_type=video|width=1280|height=720|pix_fmt=yuv420p|r_frame_rate=30000/1001|field_order=progressive|bit_rate=1800000|color_space=bt709|color_transfer=bt709|color_primaries=bt709
index=1|codec_name=aac|profile=LC|codec_type=audio|sample_rate=48000|channels=2|bit_rate=192000
index=2|codec_name=aac|profile=LC|codec_type=audio|sample_rate=48000|channels=2|bit_rate=192000
index=3|codec_name=dvb_subtitle|codec_type=subtitle
index=0|codec_name=h264|profile=High|codec_type=video|width=1280|height=720|pix_fmt=yuv420p|r_frame_rate=30000/1001|field_order=progressive|bit_rate=1800000|color_space=bt709|color_transfer=bt709|color_primaries=bt709
index=1|codec_name=aac|profile=LC|codec_type=audio|sample_rate=48000|channels=2|bit_rate=192000
index=2|codec_name=aac|profile=LC|codec_type=audio|sample_rate=48000|channels=2|bit_rate=192000
index=3|codec_name=dvb_subtitle|codec_type=subtitle
OUT
EOF
chmod +x "$fake_bin/ffprobe"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" test_write_valid_cache "$repo_dir" "$state_dir"

run_case() {
    local args_file="$1"; shift
    PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
    FFMPEG_SMART_TEST_ARGS="$args_file" "$repo_dir/ffmpeg-smart.sh" -i input.ts -vc h264 -ffmpeg-map-mode all "$@" > "$test_dir/log" 2>&1
    grep -Fxq -- '-map' "$args_file"
    grep -Fxq -- '0' "$args_file"
    grep -Fxq -- '-c:s' "$args_file"
    grep -Fxq -- '-c:d' "$args_file"
    grep -Fxq -- '-c:t' "$args_file"
    grep -Fxq -- 'pipe:1' "$args_file"
}

run_case "$test_dir/copy.args"
grep -Fxq -- '-c:v' "$test_dir/copy.args"
grep -Fxq -- 'copy' "$test_dir/copy.args"

run_case "$test_dir/transcode.args" -maxres 480
grep -Fxq -- 'libx264' "$test_dir/transcode.args"
grep -Fxq -- '480' "$test_dir/transcode.args" || grep -Fq 'scale=852:480' "$test_dir/transcode.args"

echo 'Map-all auxiliary stream tests passed'
