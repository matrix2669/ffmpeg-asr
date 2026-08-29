#!/usr/bin/env bash

test_write_valid_cache() {
    local repo_dir="$1" state_dir="$2" accel="${3:-software}" codec="${4:-h264}"
    local fingerprint
    fingerprint="$({
        set +u
        FFSMART_ENTRYPOINT="$repo_dir/ffmpeg-smart.sh"
        VERSION="$(tr -d '[:space:]' < "$repo_dir/VERSION")"
        source "$repo_dir/lib/ffsmart-common.sh"
        source "$repo_dir/lib/ffsmart-cli.sh"
        source "$repo_dir/lib/ffsmart-cache.sh"
        ffsmart_cli_defaults
        ffsmart_init_state
        ffsmart_current_fingerprint
    })"
    {
        printf 'FFMPEG_SMART_CACHE_V2\n'
        printf 'value\tschema\t2\n'
        printf 'value\tfingerprint\t%s\n' "$fingerprint"
        printf 'value\tbest_accel\t%s\n' "$accel"
        printf 'value\tbest_codec\t%s\n' "$codec"
        printf 'value\tbest_low_power\t0\n'
        printf 'value\tbest_10bit_decode\tfalse\n'
        printf 'value\tbest_10bit_encode\tfalse\n'
        printf 'value\tprimary_device\t-\n'
        printf 'value\tsecondary_device\t-\n'
    } > "$state_dir/.capabilities.cache"
}

test_make_fake_version_tools() {
    local fake_bin="$1"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then
    echo 'ffmpeg version test-build'
    exit 0
fi
if [[ " $* " == *' -encoders '* ]]; then
    echo ' V..... libx264'
    echo ' V..... libx265'
    exit 0
fi
printf '%s\n' "$@" > "${FFMPEG_SMART_TEST_ARGS:-/dev/null}"
printf '%s' "${FFMPEG_SMART_TEST_OUTPUT:-}"
exit "${FFMPEG_SMART_TEST_EXIT:-0}"
EOF
    cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then
    echo 'ffprobe version test-build'
    exit 0
fi
cat <<'OUT'
index=0|codec_name=h264|profile=High|codec_type=video|width=1280|height=720|pix_fmt=yuv420p|r_frame_rate=30000/1001|field_order=progressive|bit_rate=1800000|color_space=bt709|color_transfer=bt709|color_primaries=bt709
index=1|codec_name=aac|profile=LC|codec_type=audio|sample_rate=48000|channels=2|bit_rate=192000
OUT
EOF
    chmod +x "$fake_bin/ffmpeg" "$fake_bin/ffprobe"
}

test_run_wrapper() {
    local wrapper="$1" state_dir="$2" output="$3"
    shift 3
    set +e
    FFMPEG_SMART_STATE_DIR="$state_dir" "$wrapper" "$@" > "$output" 2>&1
    TEST_WRAPPER_STATUS=$?
    set -e
}
