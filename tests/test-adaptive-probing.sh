#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_dir/tests/test-helper.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-probe.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
state_dir="$test_dir/state"; fake_bin="$test_dir/bin"
mkdir -p "$state_dir" "$fake_bin"

cat > "$fake_bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then echo 'ffmpeg version probe-test'; exit 0; fi
printf '%s\n' "$@" > "$FFMPEG_SMART_TEST_FINAL_ARGS"
printf 'opening %s\n' "$*" >&2
EOF
cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then echo 'ffprobe version probe-test'; exit 0; fi
count=0
[[ ! -f "$FFMPEG_SMART_TEST_COUNT" ]] || count="$(<"$FFMPEG_SMART_TEST_COUNT")"
count=$((count + 1)); printf '%s\n' "$count" > "$FFMPEG_SMART_TEST_COUNT"
printf '%s\n' "$@" >> "$FFMPEG_SMART_TEST_PROBE_ARGS"
video='index=0|codec_name=h264|profile=High|codec_type=video|width=1280|height=720|pix_fmt=yuv420p|r_frame_rate=30000/1001|field_order=progressive|bit_rate=1000000|color_space=bt709|color_transfer=bt709|color_primaries=bt709'
good_audio='index=1|codec_name=aac|profile=HE-AACv2|codec_type=audio|sample_rate=48000|channels=2|bit_rate=96000'
bad_audio='index=1|codec_name=aac|profile=HE-AACv2|codec_type=audio|sample_rate=0|channels=0|bit_rate=N/A'
case "$FFMPEG_SMART_TEST_SCENARIO" in
    fast) printf '%s\n%s\n' "$video" "$good_audio" ;;
    expanded) [[ "$count" -eq 1 ]] && printf '%s\n%s\n' "$video" "$bad_audio" || printf '%s\n%s\n' "$video" "$good_audio" ;;
    default) [[ "$count" -lt 3 ]] && printf '%s\n%s\n' "$video" "$bad_audio" || printf '%s\n%s\n' "$video" "$good_audio" ;;
    incomplete) printf '%s\n%s\n' "$video" "$bad_audio" ;;
    transport) echo 'HTTP 503' >&2; exit 23 ;;
esac
EOF
chmod +x "$fake_bin/ffmpeg" "$fake_bin/ffprobe"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" test_write_valid_cache "$repo_dir" "$state_dir"

run_case() {
    local scenario="$1" expected="$2" dir="$test_dir/$1"
    mkdir -p "$dir"
    set +e
    PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
    FFMPEG_SMART_TEST_SCENARIO="$scenario" FFMPEG_SMART_TEST_COUNT="$dir/count" \
    FFMPEG_SMART_TEST_PROBE_ARGS="$dir/probe.args" FFMPEG_SMART_TEST_FINAL_ARGS="$dir/final.args" \
        "$repo_dir/ffmpeg-smart.sh" -i 'https://user:secret@example.invalid/live?token=also-secret' -vc h264 > "$dir/log" 2>&1
    status=$?
    set -e
    [[ "$status" -eq "$expected" ]] || { cat "$dir/log" >&2; return 1; }
    ! grep -Fq 'user:secret' "$dir/log"
    ! grep -Fq 'also-secret' "$dir/log"
    ! grep -Fq 'example.invalid/live' "$dir/log"
}

run_case fast 0
[[ "$(<"$test_dir/fast/count")" -eq 1 ]]
grep -Fq 'selected tier=fast' "$test_dir/fast/log"
grep -Fxq -- '1000000' "$test_dir/fast/final.args"

mkdir -p "$test_dir/udp"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
FFMPEG_SMART_TEST_SCENARIO=fast FFMPEG_SMART_TEST_COUNT="$test_dir/udp/count" \
FFMPEG_SMART_TEST_PROBE_ARGS="$test_dir/udp/probe.args" FFMPEG_SMART_TEST_FINAL_ARGS="$test_dir/udp/final.args" \
    "$repo_dir/ffmpeg-smart.sh" -i 'udp://127.0.0.1:19000' -vc h264 > "$test_dir/udp/log" 2>&1
! grep -Fxq -- '-reconnect' "$test_dir/udp/final.args"

run_case expanded 0
[[ "$(<"$test_dir/expanded/count")" -eq 2 ]]
grep -Fq 'retrying tier=expanded' "$test_dir/expanded/log"
grep -Fxq -- '2000000' "$test_dir/expanded/final.args"

run_case default 0
[[ "$(<"$test_dir/default/count")" -eq 3 ]]
grep -Fq 'selected tier=default' "$test_dir/default/log"
! grep -Eq '^-analyzeduration$|^-probesize$' "$test_dir/default/final.args"

run_case incomplete 1
[[ "$(<"$test_dir/incomplete/count")" -eq 3 ]]
grep -Fq 'ERROR [input-probe-default]' "$test_dir/incomplete/log"

run_case transport 1
[[ "$(<"$test_dir/transport/count")" -eq 1 ]]
grep -Fq 'probe limits were not escalated' "$test_dir/transport/log"

echo 'Adaptive metadata probing tests passed'
