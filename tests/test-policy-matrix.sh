#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_dir/tests/test-helper.sh"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ffsmart-policy.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
state_dir="$test_dir/state"; fake_bin="$test_dir/bin"
mkdir -p "$state_dir"
test_make_fake_version_tools "$fake_bin"
cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -version ]]; then echo 'ffprobe version test-build'; exit 0; fi
codec=h264; width=1920; height=1080; pix=yuv420p; field=progressive; bitrate=4000000; transfer=bt709; primaries=bt709; audio=aac; channels=2
case "$FFMPEG_SMART_TEST_MEDIA" in
  hevc) codec=hevc ;;
  low) width=640; height=360; bitrate=700000 ;;
  highbitrate) bitrate=9000000 ;;
  unknownbitrate) bitrate=N/A ;;
  interlaced) field=tt ;;
  hdr10) codec=hevc; pix=yuv420p10le; transfer=smpte2084; primaries=bt2020 ;;
  surround) channels=6 ;;
  ac3) audio=ac3; channels=6 ;;
esac
printf 'index=0|codec_name=%s|profile=Main|codec_type=video|width=%s|height=%s|pix_fmt=%s|r_frame_rate=30000/1001|field_order=%s|bit_rate=%s|color_space=bt709|color_transfer=%s|color_primaries=%s\n' "$codec" "$width" "$height" "$pix" "$field" "$bitrate" "$transfer" "$primaries"
printf 'index=1|codec_name=%s|profile=LC|codec_type=audio|sample_rate=48000|channels=%s|bit_rate=192000\n' "$audio" "$channels"
EOF
chmod +x "$fake_bin/ffprobe"
PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" test_write_valid_cache "$repo_dir" "$state_dir"

run_case() {
    local name="$1" media="$2"; shift 2
    PATH="$fake_bin:$PATH" FFMPEG_SMART_STATE_DIR="$state_dir" FFMPEG_SMART_REQUIRE_CACHE=true \
    FFMPEG_SMART_TEST_MEDIA="$media" FFMPEG_SMART_TEST_ARGS="$test_dir/$name.args" \
        "$repo_dir/ffmpeg-smart.sh" -i input.ts "$@" > "$test_dir/$name.log" 2>&1
}

run_case h264-copy h264 -vc h264
grep -Fq 'Video copy' "$test_dir/h264-copy.log"
grep -Fxq -- 'copy' "$test_dir/h264-copy.args"

run_case hevc-copy hevc -vc hevc
grep -Fq 'Video copy' "$test_dir/hevc-copy.log"

run_case h264-to-hevc h264 -vc hevc
grep -Fq 'codec h264 -> hevc' "$test_dir/h264-to-hevc.log"
grep -Fxq -- 'libx265' "$test_dir/h264-to-hevc.args"
grep -Fxq -- '8000000' "$test_dir/h264-to-hevc.args"

run_case hevc-to-h264 hevc -vc h264
grep -Fq 'codec hevc -> h264' "$test_dir/hevc-to-h264.log"
grep -Fxq -- 'libx264' "$test_dir/hevc-to-h264.args"

run_case downscale h264 -vc h264 -maxres 720
grep -Fq 'height 1080 > 720' "$test_dir/downscale.log"
grep -Fq 'scale=1280:720' "$test_dir/downscale.args"

run_case no-upscale low -vc h264 -maxres 720
grep -Fq 'Video copy' "$test_dir/no-upscale.log"
! grep -Fq 'scale=' "$test_dir/no-upscale.args"

run_case bitrate highbitrate -vc h264 -maxbr 2M
grep -Fq 'bitrate 9000000 > 2000000' "$test_dir/bitrate.log"
grep -Fxq -- '2000000' "$test_dir/bitrate.args"
grep -Fxq -- '4000000' "$test_dir/bitrate.args"

run_case progressive h264 -vc h264 -deint
grep -Fq 'Video copy' "$test_dir/progressive.log"

run_case interlaced interlaced -vc h264 -deint
grep -Fq 'interlaced -> progressive' "$test_dir/interlaced.log"
grep -Fq 'bwdif=' "$test_dir/interlaced.args"

run_case downmix surround -vc h264 -maxchan 2
grep -Fxq -- 'aac' "$test_dir/downmix.args"
grep -Fxq -- '-ac' "$test_dir/downmix.args"
grep -Fxq -- '2' "$test_dir/downmix.args"

run_case no-upmix h264 -vc h264 -maxchan 6
grep -Fxq -- '-c:a' "$test_dir/no-upmix.args"
grep -Fxq -- 'copy' "$test_dir/no-upmix.args"
! grep -Fxq -- '-ac' "$test_dir/no-upmix.args"

run_case normalize-audio ac3 -vc h264
grep -Fxq -- 'aac' "$test_dir/normalize-audio.args"
grep -Fxq -- '384k' "$test_dir/normalize-audio.args"

run_case hdr-sdr hdr10 -vc hevc -sdr
grep -Fq 'HDR -> SDR' "$test_dir/hdr-sdr.log"
grep -Fq 'tonemap=' "$test_dir/hdr-sdr.args"
grep -Fxq -- '-color_trc' "$test_dir/hdr-sdr.args"
grep -Fxq -- 'bt709' "$test_dir/hdr-sdr.args"

echo 'Video, audio, scaling, bitrate, deinterlace, and HDR policy tests passed'
