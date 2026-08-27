#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_dir/ffmpeg-smart.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffmpeg-smart-map-all.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
state_dir="$test_dir/state"
fake_bin="$test_dir/fake-bin"
mkdir -p "$state_dir" "$fake_bin"

fingerprint_prefix="$test_dir/fingerprint-prefix.sh"
sed '/^ensure_probe_sample/,$d' "$wrapper" > "$fingerprint_prefix"
current_fingerprint="$({
    FFMPEG_SMART_STATE_DIR="$state_dir" \
        bash -c 'source "$1"; get_hw_fingerprint' bash "$fingerprint_prefix"
})"
printf "HW_FINGERPRINT='%s'\nBEST_ACCEL='videotoolbox'\nBEST_CODEC='h264'\nBEST_LOW_POWER='0'\nSUPPORTS_10BIT_DECODE='false'\nSUPPORTS_10BIT_ENCODE='false'\nDECODE_10BIT=''\nENCODE_10BIT=''\n" \
    "$current_fingerprint" > "$state_dir/.capabilities.cache"

cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"streams":[
  {"codec_type":"video","codec_name":"h264","r_frame_rate":"30000/1001","pix_fmt":"yuv420p","field_order":"progressive","width":1280,"height":720},
  {"codec_type":"audio","codec_name":"aac","channels":2,"sample_rate":"48000"},
  {"codec_type":"audio","codec_name":"aac","channels":2,"sample_rate":"48000"},
  {"codec_type":"subtitle","codec_name":"dvb_subtitle"}
]}
JSON
EOF

cat > "$fake_bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" -encoders "* ]]; then
    printf '%s\n' ' V..... h264_videotoolbox'
    exit 0
fi
printf '%s\n' "$@" > "$FFMPEG_SMART_TEST_ARGS"
EOF
chmod +x "$fake_bin/ffprobe" "$fake_bin/ffmpeg"

run_case() {
    local output_file="$1"
    shift
    if ! PATH="$fake_bin:$PATH" \
        FFMPEG_SMART_STATE_DIR="$state_dir" \
        FFMPEG_SMART_REQUIRE_CACHE=true \
        FFMPEG_SMART_TEST_ARGS="$output_file" \
            "$wrapper" -user_agent test-agent -i https://example.invalid/live -vc h264 -ffmpeg-map-mode all "$@" \
            > "$test_dir/wrapper.log" 2>&1; then
        cat "$test_dir/wrapper.log" >&2
        return 1
    fi
}

assert_auxiliary_copy_sequence() {
    local output_file="$1" joined="" arg
    while IFS= read -r arg; do
        joined+="<$arg>"
    done < "$output_file"
    [[ "$joined" == *"<-map><0>"* ]]
    [[ "$joined" == *"<-c:s><copy><-c:d><copy><-c:t><copy>"* ]]
    [[ "$joined" == *"<-f><mpegts><pipe:1>"* ]]
}

copy_args="$test_dir/copy.args"
run_case "$copy_args"
assert_auxiliary_copy_sequence "$copy_args"
grep -Fxq -- '-c:v' "$copy_args"
grep -Fxq -- 'copy' "$copy_args"

transcode_args="$test_dir/transcode.args"
run_case "$transcode_args" -maxres 480
assert_auxiliary_copy_sequence "$transcode_args"
grep -Fxq -- 'h264_videotoolbox' "$transcode_args"

echo "Map-all auxiliary stream codec tests passed"
