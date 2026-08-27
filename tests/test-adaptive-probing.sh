#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_dir/ffmpeg-smart.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffmpeg-smart-adaptive-probe.XXXXXX")"
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
printf "HW_FINGERPRINT='%s'\nBEST_ACCEL='software'\nBEST_CODEC='h264'\nBEST_LOW_POWER='0'\nSUPPORTS_10BIT_DECODE='false'\nSUPPORTS_10BIT_ENCODE='false'\nDECODE_10BIT=''\nENCODE_10BIT=''\n" \
    "$current_fingerprint" > "$state_dir/.capabilities.cache"

cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
count=0
[[ ! -f "$FFMPEG_SMART_TEST_PROBE_COUNT" ]] || count="$(<"$FFMPEG_SMART_TEST_PROBE_COUNT")"
count=$((count + 1))
printf '%s\n' "$count" > "$FFMPEG_SMART_TEST_PROBE_COUNT"
printf '%s\n' "$*" >> "$FFMPEG_SMART_TEST_PROBE_ARGS"

complete='{"streams":[{"codec_type":"video","codec_name":"h264","r_frame_rate":"30000/1001","pix_fmt":"yuv420p","field_order":"progressive","width":1280,"height":720},{"codec_type":"audio","codec_name":"aac","profile":"HE-AACv2","channels":2,"sample_rate":"48000"}]}'
incomplete='{"streams":[{"codec_type":"video","codec_name":"h264","r_frame_rate":"30000/1001","pix_fmt":"yuv420p","field_order":"progressive","width":1280,"height":720},{"codec_type":"audio","codec_name":"aac","channels":0,"sample_rate":"0"}]}'

case "$FFMPEG_SMART_TEST_SCENARIO" in
    fast-complete) printf '%s\n' "$complete" ;;
    expanded-fallback) [[ "$count" -eq 1 ]] && printf '%s\n' "$incomplete" || printf '%s\n' "$complete" ;;
    default-fallback) [[ "$count" -lt 3 ]] && printf '%s\n' "$incomplete" || printf '%s\n' "$complete" ;;
    exit-zero-incomplete) printf '%s\n' "$incomplete" ;;
    transport-error) exit 23 ;;
    *) exit 99 ;;
esac
EOF

cat > "$fake_bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FFMPEG_SMART_TEST_FINAL_ARGS"
EOF
chmod +x "$fake_bin/ffprobe" "$fake_bin/ffmpeg"

run_case() {
    local scenario="$1" expected_status="$2"
    local case_dir="$test_dir/$scenario"
    mkdir -p "$case_dir"
    set +e
    PATH="$fake_bin:$PATH" \
    FFMPEG_SMART_STATE_DIR="$state_dir" \
    FFMPEG_SMART_REQUIRE_CACHE=true \
    FFMPEG_SMART_TEST_SCENARIO="$scenario" \
    FFMPEG_SMART_TEST_PROBE_COUNT="$case_dir/count" \
    FFMPEG_SMART_TEST_PROBE_ARGS="$case_dir/probe.args" \
    FFMPEG_SMART_TEST_FINAL_ARGS="$case_dir/final.args" \
        "$wrapper" -user_agent test-agent -i 'https://user:secret@example.invalid/live' -vc h264 \
        > "$case_dir/output.log" 2>&1
    status=$?
    set -e
    if [[ "$status" -ne "$expected_status" ]]; then
        cat "$case_dir/output.log" >&2
        echo "Scenario $scenario returned $status, expected $expected_status" >&2
        exit 1
    fi
    if grep -Fq 'user:secret' "$case_dir/output.log"; then
        echo "Scenario $scenario leaked input credentials" >&2
        exit 1
    fi
}

run_case fast-complete 0
[[ "$(<"$test_dir/fast-complete/count")" -eq 1 ]]
grep -Fq 'Input probe selected tier=fast analyzeduration=1000000 probesize=1000000' "$test_dir/fast-complete/output.log"
grep -Fxq -- '-analyzeduration' "$test_dir/fast-complete/final.args"
grep -Fxq -- '1000000' "$test_dir/fast-complete/final.args"

run_case expanded-fallback 0
[[ "$(<"$test_dir/expanded-fallback/count")" -eq 2 ]]
grep -Fq 'retrying tier=expanded' "$test_dir/expanded-fallback/output.log"
grep -Fq 'Input probe selected tier=expanded analyzeduration=2000000 probesize=2000000' "$test_dir/expanded-fallback/output.log"
grep -Fxq -- '2000000' "$test_dir/expanded-fallback/final.args"

run_case default-fallback 0
[[ "$(<"$test_dir/default-fallback/count")" -eq 3 ]]
grep -Fq 'retrying tier=default' "$test_dir/default-fallback/output.log"
grep -Fq 'Input probe selected tier=default analyzeduration=default probesize=default' "$test_dir/default-fallback/output.log"
if grep -Eq '^-analyzeduration$|^-probesize$' "$test_dir/default-fallback/final.args"; then
    echo "Default fallback unexpectedly constrained the final FFmpeg probe" >&2
    exit 1
fi

run_case exit-zero-incomplete 1
[[ "$(<"$test_dir/exit-zero-incomplete/count")" -eq 3 ]]
[[ ! -e "$test_dir/exit-zero-incomplete/final.args" ]]
grep -Fq 'ERROR [input-probe-default]: ffprobe returned incomplete selected-stream metadata' "$test_dir/exit-zero-incomplete/output.log"

run_case transport-error 1
[[ "$(<"$test_dir/transport-error/count")" -eq 1 ]]
[[ ! -e "$test_dir/transport-error/final.args" ]]
grep -Fq 'ERROR [input-probe-fast]: ffprobe failed; probe limits were not escalated' "$test_dir/transport-error/output.log"

echo "Adaptive input probing tests passed"
