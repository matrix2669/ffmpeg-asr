#!/bin/bash
if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

LOG_PREFIX="[ffmpeg-smart]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="render-node-v8"
CACHE_FILE="$SCRIPT_DIR/.capabilities.cache"
PROBE_SAMPLE="$SCRIPT_DIR/probe-sample.mkv"
PROBE_SAMPLE_URL="https://repo.jellyfin.org/archive/jellyfish/media/jellyfish-3-mbps-hd-hevc-10bit.mkv"

# DRI device selection. DRI_DEVICE can override both VAAPI and QSV;
# VAAPI_DEVICE and QSV_DEVICE can override them independently.
DRI_DEVICE="${DRI_DEVICE:-}"
VAAPI_DEVICE="${VAAPI_DEVICE:-}"
QSV_DEVICE="${QSV_DEVICE:-}"

get_dri_vendor() {
    local dev="$1"
    local node="${dev##*/}"
    local vendor_file="/sys/class/drm/$node/device/vendor"

    [[ -r "$vendor_file" ]] || return 1
    cat "$vendor_file" 2>/dev/null
}

# Select an actually exposed /dev/dri/renderD* node. This intentionally checks
# /dev first so host sysfs entries that are not mapped into a container are ignored.
auto_select_dri_device() {
    local dev vendor
    local fallback=""

    for dev in /dev/dri/renderD*; do
        [[ -e "$dev" ]] || continue
        [[ -z "$fallback" ]] && fallback="$dev"

        vendor="$(get_dri_vendor "$dev" || true)"
        case "$vendor" in
            0x8086|0x1002)
                echo "$dev"
                return 0
                ;;
        esac
    done

    if [[ -n "$fallback" ]]; then
        echo "$fallback"
        return 0
    fi

    return 1
}

if [[ "$(uname -s)" == "Linux" ]]; then
    if [[ -z "$DRI_DEVICE" ]]; then
        DRI_DEVICE="$(auto_select_dri_device || true)"
    fi
    [[ -z "$VAAPI_DEVICE" ]] && VAAPI_DEVICE="$DRI_DEVICE"
    [[ -z "$QSV_DEVICE" ]] && QSV_DEVICE="$DRI_DEVICE"
fi

# Cache fingerprint includes the script version, exposed DRI nodes, selected
# device overrides, and other detected GPU hardware.
get_hw_fingerprint() {
    local fp="script=$VERSION;"
    local dev node vendor device

    for dev in /dev/dri/renderD*; do
        [[ -e "$dev" ]] || continue
        node="${dev##*/}"
        vendor="$(cat "/sys/class/drm/$node/device/vendor" 2>/dev/null || true)"
        device="$(cat "/sys/class/drm/$node/device/device" 2>/dev/null || true)"
        fp+="dri:${node}:${vendor:-unknown}:${device:-unknown};"
    done

    if [[ "$(uname -s)" == "Linux" ]]; then
        fp+="selected:dri=${DRI_DEVICE:-none},vaapi=${VAAPI_DEVICE:-none},qsv=${QSV_DEVICE:-none};"
    fi

    [[ -e /dev/nvidia0 ]] && fp+="nvidia:$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -1 | tr ' ' '_');"
    [[ "$(uname -s)" == "Darwin" ]] && fp+="darwin:$(system_profiler SPDisplaysDataType 2>/dev/null | grep 'Chip' | head -1 | tr ' ' '_');"
    echo "$fp"
}

ensure_probe_sample() {
    [[ -f "$PROBE_SAMPLE" ]] && return 0
    echo "$LOG_PREFIX Downloading probe sample (~4MB)..." >&2
    curl -fsSL -o "$PROBE_SAMPLE" "$PROBE_SAMPLE_URL" 2>/dev/null || {
        echo "$LOG_PREFIX WARNING: Failed to download probe sample, using synthetic test" >&2
        return 1
    }
}

parse_bench_speed() {
    local output="$1"
    grep -oP 'speed=\s*\K[0-9.]+(?=x)' <<<"$output" | tail -1 || true
}

log_bench_failure() {
    local label="$1"
    local output="$2"
    echo "$LOG_PREFIX WARNING: $label benchmark produced no speed result" >&2
    tail -n 8 <<<"$output" | sed "s/^/$LOG_PREFIX   /" >&2
}

# Quick encoder benchmark - returns "speed:lp_speed".
# Uses a real compressed HEVC 10-bit sample when available.
bench_encoder() {
    local encoder="$1"
    local pix_fmt="nv12"
    local size="1920x1080"
    local sample_duration="5"
    local synthetic_duration="2"
    local output speed
    local lp_speed=""
    local use_sample="false"

    [[ -f "$PROBE_SAMPLE" ]] && use_sample="true"

    local prod_opts="-b:v 8M -maxrate 10M -bufsize 16M -g 30 -bf 2"
    local lp_prod_opts="-b:v 8M -maxrate 10M -bufsize 16M -g 30 -bf 0 -look_ahead 0"

    case "$encoder" in
        *_qsv)
            [[ -n "$QSV_DEVICE" && -e "$QSV_DEVICE" ]] || { echo "0:"; return; }
            if [[ "$use_sample" == "true" ]]; then
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE" \
                    -filter_hw_device qsv \
                    -hwaccel qsv -hwaccel_device qsv -hwaccel_output_format qsv \
                    -i "$PROBE_SAMPLE" -t "$sample_duration" \
                    -vf "scale_qsv=format=$pix_fmt" -an \
                    -c:v "$encoder" -preset faster $prod_opts -f null - 2>&1 || true)
            else
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE" \
                    -filter_hw_device qsv \
                    -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                    -vf "format=$pix_fmt,hwupload=extra_hw_frames=16" \
                    -c:v "$encoder" -preset faster $prod_opts -f null - 2>&1 || true)
            fi
            speed=$(parse_bench_speed "$output")
            [[ -n "$speed" ]] || log_bench_failure "$encoder" "$output"

            if [[ "$use_sample" == "true" ]]; then
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE" \
                    -filter_hw_device qsv \
                    -hwaccel qsv -hwaccel_device qsv -hwaccel_output_format qsv \
                    -i "$PROBE_SAMPLE" -t "$sample_duration" \
                    -vf "scale_qsv=format=$pix_fmt" -an \
                    -c:v "$encoder" -low_power true $lp_prod_opts -f null - 2>&1 || true)
            else
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE" \
                    -filter_hw_device qsv \
                    -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                    -vf "format=$pix_fmt,hwupload=extra_hw_frames=16" \
                    -c:v "$encoder" -low_power true $lp_prod_opts -f null - 2>&1 || true)
            fi
            lp_speed=$(parse_bench_speed "$output")
            ;;
        *_vaapi)
            [[ -n "$VAAPI_DEVICE" && -e "$VAAPI_DEVICE" ]] || { echo "0:"; return; }
            if [[ "$use_sample" == "true" ]]; then
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device "$VAAPI_DEVICE" \
                    -i "$PROBE_SAMPLE" -t "$sample_duration" \
                    -vf "scale_vaapi=format=$pix_fmt" -an \
                    -c:v "$encoder" -rc_mode VBR $prod_opts -f null - 2>&1 || true)
            else
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -vaapi_device "$VAAPI_DEVICE" \
                    -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                    -vf "format=$pix_fmt,hwupload,scale_vaapi=format=$pix_fmt" \
                    -c:v "$encoder" -rc_mode VBR $prod_opts -f null - 2>&1 || true)
            fi
            speed=$(parse_bench_speed "$output")
            [[ -n "$speed" ]] || log_bench_failure "$encoder" "$output"

            if [[ "$use_sample" == "true" ]]; then
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device "$VAAPI_DEVICE" \
                    -i "$PROBE_SAMPLE" -t "$sample_duration" \
                    -vf "scale_vaapi=format=$pix_fmt" -an \
                    -c:v "$encoder" -rc_mode VBR -low_power 1 $lp_prod_opts -f null - 2>&1 || true)
            else
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -vaapi_device "$VAAPI_DEVICE" \
                    -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                    -vf "format=$pix_fmt,hwupload,scale_vaapi=format=$pix_fmt" \
                    -c:v "$encoder" -rc_mode VBR -low_power 1 $lp_prod_opts -f null - 2>&1 || true)
            fi
            lp_speed=$(parse_bench_speed "$output")
            ;;
        *_nvenc)
            output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                -init_hw_device cuda=cuda -filter_hw_device cuda \
                -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                -vf "format=$pix_fmt,hwupload_cuda" \
                -c:v "$encoder" -f null - 2>&1 || true)
            speed=$(parse_bench_speed "$output")
            [[ -n "$speed" ]] || log_bench_failure "$encoder" "$output"
            ;;
        *_videotoolbox)
            output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                -c:v "$encoder" -f null - 2>&1 || true)
            speed=$(parse_bench_speed "$output")
            [[ -n "$speed" ]] || log_bench_failure "$encoder" "$output"
            ;;
        *_v4l2m2m)
            output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                -c:v "$encoder" -f null - 2>&1 || true)
            speed=$(parse_bench_speed "$output")
            [[ -n "$speed" ]] || log_bench_failure "$encoder" "$output"
            ;;
        *)
            if [[ "$use_sample" == "true" ]]; then
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -i "$PROBE_SAMPLE" -t "$sample_duration" \
                    -vf "format=yuv420p" -an \
                    -c:v "$encoder" -preset faster $prod_opts -f null - 2>&1 || true)
            else
                output=$(timeout 15s ffmpeg -nostdin -hide_banner -benchmark \
                    -f lavfi -i "testsrc2=size=$size:rate=30" -t "$synthetic_duration" \
                    -c:v "$encoder" -preset faster $prod_opts -f null - 2>&1 || true)
            fi
            speed=$(parse_bench_speed "$output")
            [[ -n "$speed" ]] || log_bench_failure "$encoder" "$output"
            ;;
    esac

    echo "${speed:-0}:${lp_speed}"
}

test_encoder() {
    local encoder="$1"
    local test_10bit="${2:-false}"
    local pix_fmt="nv12"
    [[ "$test_10bit" == "true" ]] && pix_fmt="p010le"
    local size="256x256"

    case "$encoder" in
        *_qsv)
            [[ -n "$QSV_DEVICE" && -e "$QSV_DEVICE" ]] || return 1
            if [[ "$test_10bit" == "true" && -f "$PROBE_SAMPLE" ]]; then
                timeout 10s ffmpeg -nostdin -hide_banner -v error \
                    -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE" \
                    -filter_hw_device qsv \
                    -hwaccel qsv -hwaccel_device qsv -hwaccel_output_format qsv \
                    -i "$PROBE_SAMPLE" -t 0.5 \
                    -vf "scale_qsv=format=p010le" \
                    -c:v "$encoder" -profile:v main10 -f null - 2>/dev/null
            else
                local qsv_profile=()
                [[ "$test_10bit" == "true" ]] && qsv_profile=(-profile:v main10)
                timeout 10s ffmpeg -nostdin -hide_banner -v error \
                    -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE" \
                    -filter_hw_device qsv \
                    -f lavfi -i "color=black:size=$size:rate=30,format=$pix_fmt" \
                    -t 0.2 \
                    -vf "hwupload=extra_hw_frames=16" \
                    -c:v "$encoder" "${qsv_profile[@]}" -f null - 2>/dev/null
            fi
            ;;
        *_vaapi)
            [[ -n "$VAAPI_DEVICE" && -e "$VAAPI_DEVICE" ]] || return 1
            if [[ "$test_10bit" == "true" && -f "$PROBE_SAMPLE" ]]; then
                timeout 10s ffmpeg -nostdin -hide_banner -v error \
                    -hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device "$VAAPI_DEVICE" \
                    -i "$PROBE_SAMPLE" -t 0.5 \
                    -vf "scale_vaapi=format=p010le" \
                    -c:v "$encoder" -f null - 2>/dev/null
            else
                timeout 10s ffmpeg -nostdin -hide_banner -v error \
                    -vaapi_device "$VAAPI_DEVICE" \
                    -f lavfi -i "color=black:size=$size:rate=30,format=$pix_fmt" \
                    -t 0.2 \
                    -vf "hwupload,scale_vaapi=format=$pix_fmt" \
                    -c:v "$encoder" -f null - 2>/dev/null
            fi
            ;;
        *_nvenc)
            timeout 10s ffmpeg -nostdin -hide_banner -v error \
                -init_hw_device cuda=cuda -filter_hw_device cuda \
                -f lavfi -i "color=black:size=$size:rate=30,format=$pix_fmt,hwupload_cuda" \
                -t 0.2 -c:v "$encoder" -f null - 2>/dev/null
            ;;
        *_videotoolbox|*_v4l2m2m)
            timeout 10s ffmpeg -nostdin -hide_banner -v error \
                -f lavfi -i "color=black:size=$size:rate=30,format=$pix_fmt" \
                -t 0.2 -c:v "$encoder" -f null - 2>/dev/null
            ;;
        *)
            timeout 10s ffmpeg -nostdin -hide_banner -v error \
                -f lavfi -i "color=black:size=$size:rate=30" \
                -t 0.2 -c:v "$encoder" -f null - 2>/dev/null
            ;;
    esac
}

test_10bit_decode() {
    local accel="$1"
    local hwaccel_args=()

    [[ ! -f "$PROBE_SAMPLE" ]] && return 1

    case "$accel" in
        qsv)
            [[ -n "$QSV_DEVICE" && -e "$QSV_DEVICE" ]] || return 1
            hwaccel_args=(
                -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE"
                -filter_hw_device qsv
                -hwaccel qsv
                -hwaccel_device qsv
                -hwaccel_output_format qsv
            )
            ;;
        vaapi)
            [[ -n "$VAAPI_DEVICE" && -e "$VAAPI_DEVICE" ]] || return 1
            hwaccel_args=(-hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device "$VAAPI_DEVICE")
            ;;
        nvenc) hwaccel_args=(-hwaccel cuda -hwaccel_output_format cuda) ;;
        videotoolbox) hwaccel_args=(-hwaccel videotoolbox) ;;
        *) return 1 ;;
    esac

    timeout 5s ffmpeg -nostdin -hide_banner -v error \
        "${hwaccel_args[@]}" -i "$PROBE_SAMPLE" -t 0.2 \
        -f null - 2>/dev/null
}

probe_capabilities() {
    local results=""
    local encoders_list
    encoders_list=$(ffmpeg -hide_banner -encoders 2>/dev/null || true)

    ensure_probe_sample || true
    if [[ -f "$PROBE_SAMPLE" ]]; then
        echo "$LOG_PREFIX Benchmark source: $(basename "$PROBE_SAMPLE") (real decode/transcode)" >&2
    else
        echo "$LOG_PREFIX Benchmark source: synthetic lavfi fallback" >&2
    fi

    local accels_to_test=()
    local can_decode_10bit=""
    local can_encode_10bit=""
    local vendor=""

    if [[ "$(uname -s)" == "Darwin" ]]; then
        accels_to_test+=("videotoolbox")
    else
        [[ -e /dev/nvidia0 ]] && accels_to_test+=("nvenc")

        if [[ -n "$QSV_DEVICE" && -e "$QSV_DEVICE" ]]; then
            vendor="$(get_dri_vendor "$QSV_DEVICE" || true)"
            [[ "$vendor" == "0x8086" ]] && accels_to_test+=("qsv")
        fi

        if [[ -n "$VAAPI_DEVICE" && -e "$VAAPI_DEVICE" ]]; then
            vendor="$(get_dri_vendor "$VAAPI_DEVICE" || true)"
            case "$vendor" in
                0x8086|0x1002) accels_to_test+=("vaapi") ;;
            esac
        fi

        for n in /sys/class/video4linux/video*/name; do
            if [[ -r "$n" ]] && grep -qiE 'm2m|codec' "$n" 2>/dev/null; then
                accels_to_test+=("v4l2m2m")
                break
            fi
        done
    fi
    accels_to_test+=("software")

    local best_accel="software"
    local best_codec="h264"
    local best_speed="0"
    local best_low_power="0"

    for accel in "${accels_to_test[@]}"; do
        if [[ "$accel" != "software" ]] && test_10bit_decode "$accel"; then
            can_decode_10bit+="${accel}=1;"
        fi

        for codec in h264 hevc; do
            local encoder
            if [[ "$accel" == "software" ]]; then
                [[ "$codec" == "h264" ]] && encoder="libx264" || encoder="libx265"
            else
                encoder="${codec}_${accel}"
            fi

            grep -qw "$encoder" <<<"$encoders_list" || continue
            echo "$LOG_PREFIX Probing $encoder..." >&2

            local bench_result speed lp_speed best_of_two use_lp
            bench_result=$(bench_encoder "$encoder")
            speed="${bench_result%%:*}"
            lp_speed="${bench_result##*:}"

            if [[ -n "$speed" && "$speed" != "0" ]]; then
                results+="${encoder}=${speed}x;"
                if [[ -n "$lp_speed" && "$lp_speed" != "0" ]]; then
                    results+="${encoder}(lp)=${lp_speed}x;"
                fi

                if [[ -n "$lp_speed" ]] && awk "BEGIN {exit !($lp_speed > $speed)}"; then
                    best_of_two="$lp_speed"
                    use_lp="1"
                else
                    best_of_two="$speed"
                    use_lp="0"
                fi

                if awk "BEGIN {exit !($best_of_two > $best_speed)}"; then
                    best_speed="$best_of_two"
                    best_accel="$accel"
                    best_codec="$codec"
                    best_low_power="$use_lp"
                fi

                if [[ "$codec" == "hevc" && "$accel" != "software" ]]; then
                    if test_encoder "$encoder" "true"; then
                        results+="${encoder}_10bit=1;"
                        can_encode_10bit+="${accel}=1;"
                    fi
                fi
            else
                results+="${encoder}=0;"
            fi
        done
    done

    local supports_10bit_decode="false"
    local supports_10bit_encode="false"
    [[ "$can_decode_10bit" == *"${best_accel}=1;"* ]] && supports_10bit_decode="true"
    [[ "$can_encode_10bit" == *"${best_accel}=1;"* ]] && supports_10bit_encode="true"

    echo "BEST_ACCEL='$best_accel'"
    echo "BEST_CODEC='$best_codec'"
    echo "BEST_LOW_POWER='$best_low_power'"
    echo "SUPPORTS_10BIT_DECODE='$supports_10bit_decode'"
    echo "SUPPORTS_10BIT_ENCODE='$supports_10bit_encode'"
    echo "DECODE_10BIT='$can_decode_10bit'"
    echo "ENCODE_10BIT='$can_encode_10bit'"
    echo "ENCODERS='$results'"
}

load_cache() {
    [[ -f "$CACHE_FILE" ]] || return 1
    source "$CACHE_FILE" || return 1

    local current_fp
    current_fp=$(get_hw_fingerprint)
    [[ "$HW_FINGERPRINT" == "$current_fp" ]] || return 1
    return 0
}

save_cache() {
    {
        echo "# ffmpeg-smart capability cache"
        echo "# Generated: $(date -Iseconds)"
        echo "HW_FINGERPRINT='$(get_hw_fingerprint)'"
        probe_capabilities
    } > "$CACHE_FILE"
    source "$CACHE_FILE"
}

accel_has_capability() {
    local caps="$1"
    local accel="$2"
    [[ "$caps" == *"${accel}=1;"* ]]
}

AGENT=""
URL=""
VCODEC_OUT=""
VCODEC_FORCED=false
ALLOW_10BIT=""
ALLOW_HDR=""
RECACHE=false
ACCEL="__auto__"

detect_accel() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "videotoolbox"; return
    fi
    if [[ -e /dev/nvidia0 ]]; then
        echo "nvenc"; return
    fi

    local vendor=""
    if [[ -n "$VAAPI_DEVICE" && -e "$VAAPI_DEVICE" ]]; then
        vendor="$(get_dri_vendor "$VAAPI_DEVICE" || true)"
        case "$vendor" in
            0x8086|0x1002) echo "vaapi"; return ;;
        esac
    fi
    if [[ -n "$QSV_DEVICE" && -e "$QSV_DEVICE" ]]; then
        vendor="$(get_dri_vendor "$QSV_DEVICE" || true)"
        [[ "$vendor" == "0x8086" ]] && { echo "qsv"; return; }
    fi

    for n in /sys/class/video4linux/video*/name; do
        [[ -r "$n" ]] && grep -qiE 'm2m|codec' "$n" && echo "v4l2m2m" && return
    done

    if [[ -n "$VAAPI_DEVICE" && -e "$VAAPI_DEVICE" ]]; then
        echo "vaapi"
    else
        echo "software"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -user_agent) AGENT="$2"; shift 2 ;;
        -i) URL="$2"; shift 2 ;;
        -accel) ACCEL="$2"; shift 2 ;;
        -vc) VCODEC_OUT="$2"; VCODEC_FORCED=true; shift 2 ;;
        -10bit) ALLOW_10BIT=true; shift ;;
        -hdr) ALLOW_HDR=true; shift ;;
        --recache) RECACHE=true; shift ;;
        *) shift ;;
    esac
done

if [[ "$RECACHE" == "true" ]] || ! load_cache 2>/dev/null; then
    save_cache
    echo "$LOG_PREFIX v$VERSION | Probed: accel=$BEST_ACCEL codec=$BEST_CODEC 10bit=$SUPPORTS_10BIT_ENCODE hdr=$SUPPORTS_10BIT_ENCODE" >&2
else
    echo "$LOG_PREFIX v$VERSION | Cached: accel=$BEST_ACCEL codec=$BEST_CODEC 10bit=$SUPPORTS_10BIT_ENCODE hdr=$SUPPORTS_10BIT_ENCODE" >&2
fi

[[ -z "$VCODEC_OUT" ]] && VCODEC_OUT="${BEST_CODEC:-h264}"
if [[ "$ACCEL" == "__auto__" ]]; then
    ACCEL="${BEST_ACCEL:-}"
    [[ -z "$ACCEL" ]] && ACCEL=$(detect_accel)
fi

SELECTED_SUPPORTS_10BIT_DECODE=false
SELECTED_SUPPORTS_10BIT_ENCODE=false
accel_has_capability "${DECODE_10BIT:-}" "$ACCEL" && SELECTED_SUPPORTS_10BIT_DECODE=true
accel_has_capability "${ENCODE_10BIT:-}" "$ACCEL" && SELECTED_SUPPORTS_10BIT_ENCODE=true

[[ -z "$ALLOW_10BIT" ]] && ALLOW_10BIT="$SELECTED_SUPPORTS_10BIT_ENCODE"
if [[ -z "$ALLOW_HDR" ]]; then
    if [[ "$VCODEC_OUT" == "hevc" && "$SELECTED_SUPPORTS_10BIT_ENCODE" == "true" ]]; then
        ALLOW_HDR=true
    else
        ALLOW_HDR=false
    fi
fi

if [[ -z "$URL" ]]; then
    echo "$LOG_PREFIX ERROR: No stream URL provided" >&2
    exit 1
fi

case "$ACCEL" in
    qsv|vaapi|nvenc|v4l2m2m|videotoolbox|software) ;;
    *)
        echo "$LOG_PREFIX ERROR: Unknown accel type: $ACCEL (use: qsv, vaapi, nvenc, v4l2m2m, videotoolbox, software)" >&2
        exit 1
        ;;
esac

case "$VCODEC_OUT" in
    h264|hevc) ;;
    *)
        echo "$LOG_PREFIX ERROR: Unknown video codec: $VCODEC_OUT (use: h264, hevc)" >&2
        exit 1
        ;;
esac

# Build network-specific args only for HTTP/HTTPS inputs.
if [[ "$URL" =~ ^https?:// ]]; then
    [[ -n "$AGENT" ]] && UA_ARGS=(-user_agent "$AGENT") || UA_ARGS=()
    NET_ARGS=(-reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 30 -rw_timeout 15000000)
else
    UA_ARGS=()
    NET_ARGS=()
fi

PROBE=$(ffprobe "${UA_ARGS[@]}" -v quiet -print_format json -show_streams "$URL" 2>&1) || {
    echo "$LOG_PREFIX ERROR: ffprobe failed - cannot access stream" >&2
    exit 1
}

VCODEC=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="video") | .codec_name' | head -n1)
FPS_FRAC=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="video") | .r_frame_rate' | head -n1)
PIX_FMT=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="video") | .pix_fmt // empty' | head -n1)
COLOR_TRANSFER=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="video") | .color_transfer // empty' | head -n1)
WIDTH=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="video") | .width // 0' | head -n1)
HEIGHT=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="video") | .height // 0' | head -n1)
ACODEC=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="audio") | .codec_name // empty' | head -n1)
ACHANNELS=$(echo "$PROBE" | jq -r '.streams[] | select(.codec_type=="audio") | .channels // empty' | head -n1)
AUDIO_STREAM_COUNT=$(echo "$PROBE" | jq '[.streams[] | select(.codec_type=="audio")] | length')
HAS_AUDIO=false
[[ "$AUDIO_STREAM_COUNT" -gt 0 ]] && HAS_AUDIO=true

if [[ -z "$VCODEC" || "$VCODEC" == "null" ]]; then
    echo "$LOG_PREFIX ERROR: No video stream found" >&2
    exit 1
fi

SOURCE_10BIT=false
[[ "$PIX_FMT" == *"10"* ]] && SOURCE_10BIT=true
IS_HDR=false
[[ "$COLOR_TRANSFER" == "smpte2084" || "$COLOR_TRANSFER" == "arib-std-b67" ]] && IS_HDR=true

# Normalizer-first policy: stream-copy video only when the source already
# satisfies the resolved output policy. The policy comes from explicit flags
# when supplied, otherwise from the selected cached hardware capabilities.
VIDEO_COPY_REASON=""
VIDEO_TRANSCODE_REASON=""
if [[ "$VCODEC" != "$VCODEC_OUT" ]]; then
    VIDEO_TRANSCODE_REASON="codec ${VCODEC}->${VCODEC_OUT}"
elif [[ "$SOURCE_10BIT" == "true" && "$ALLOW_10BIT" != "true" ]]; then
    VIDEO_TRANSCODE_REASON="10-bit not allowed"
elif [[ "$IS_HDR" == "true" && "$ALLOW_HDR" != "true" ]]; then
    VIDEO_TRANSCODE_REASON="HDR not allowed"
else
    VIDEO_COPY_REASON="matches policy codec=${VCODEC_OUT} 10bit=${ALLOW_10BIT} hdr=${ALLOW_HDR}"
fi

# Audio policy:
# - AAC input is stream-copied unchanged.
# - Non-AAC input is converted to AAC at predictable channel-based bitrates.
# - Unknown channel layouts are downmixed to stereo.
AUDIO_ARGS=()
AUDIO_INFO="none"
if [[ "$HAS_AUDIO" == "true" ]]; then
    if [[ "$ACODEC" == "aac" ]]; then
        AUDIO_ARGS=(-c:a copy)
        AUDIO_INFO="aac copy ${ACHANNELS:-unknown}ch"
    else
        CHANNEL_LAYOUT_ARGS=()
        AUDIO_CHANNELS_DISPLAY="${ACHANNELS:-unknown}"
        case "$ACHANNELS" in
            1)
                ABITRATE=96000
                CHANNEL_LAYOUT_ARGS=(-ch_layout mono)
                ;;
            2)
                ABITRATE=192000
                CHANNEL_LAYOUT_ARGS=(-ch_layout stereo)
                ;;
            6)
                ABITRATE=384000
                CHANNEL_LAYOUT_ARGS=(-ch_layout 5.1)
                ;;
            8)
                ABITRATE=512000
                CHANNEL_LAYOUT_ARGS=(-ch_layout 7.1)
                ;;
            *)
                ABITRATE=192000
                CHANNEL_LAYOUT_ARGS=(-ac 2 -ch_layout stereo)
                AUDIO_CHANNELS_DISPLAY="${ACHANNELS:-unknown} -> 2 (forced)"
                ;;
        esac

        AUDIO_ARGS=(
            -c:a aac
            -b:a "$ABITRATE"
            "${CHANNEL_LAYOUT_ARGS[@]}"
            -af "aresample=async=1"
        )
        AUDIO_INFO="${ACODEC:-unknown}->aac ${ABITRATE}bps ${AUDIO_CHANNELS_DISPLAY}ch"
    fi
fi

if [[ -n "$VIDEO_COPY_REASON" ]]; then
    echo "$LOG_PREFIX Detected ${WIDTH}x${HEIGHT} $VCODEC/$PIX_FMT @ $FPS_FRAC -> copy (${VIDEO_COPY_REASON}) audio=${AUDIO_INFO}" >&2
    exec ffmpeg \
        "${UA_ARGS[@]}" \
        "${NET_ARGS[@]}" \
        -fflags +genpts+igndts+discardcorrupt \
        -err_detect ignore_err \
        -i "$URL" \
        -map 0:v:0 \
        -map 0:a:0? \
        -c:v copy \
        "${AUDIO_ARGS[@]}" \
        -avoid_negative_ts make_zero \
        -start_at_zero \
        -mpegts_copyts 0 \
        -mpegts_flags +pat_pmt_at_frames+resend_headers \
        -flush_packets 1 \
        -max_muxing_queue_size 4096 \
        -f mpegts \
        pipe:1
fi

# Everything below this point is the policy-mismatch transcode path.
case "$ACCEL" in
    qsv)
        if [[ -z "$QSV_DEVICE" || ! -e "$QSV_DEVICE" ]]; then
            echo "$LOG_PREFIX ERROR: QSV render device not available: ${QSV_DEVICE:-none}" >&2
            exit 1
        fi
        ;;
    vaapi)
        if [[ -z "$VAAPI_DEVICE" || ! -e "$VAAPI_DEVICE" ]]; then
            echo "$LOG_PREFIX ERROR: VAAPI render device not available: ${VAAPI_DEVICE:-none}" >&2
            exit 1
        fi
        ;;
esac

ENCODERS="$(ffmpeg -hide_banner -encoders 2>/dev/null || true)"

if [[ "$ACCEL" == "software" ]]; then
    if [[ "$VCODEC_OUT" == "hevc" ]]; then
        ENCODER="libx265"
        TAG_ARGS="-tag:v hvc1"
    else
        ENCODER="libx264"
        TAG_ARGS=""
    fi
else
    ENCODER="${VCODEC_OUT}_${ACCEL}"
    if ! grep -qw "$ENCODER" <<<"$ENCODERS"; then
        echo "$LOG_PREFIX ERROR: Encoder $ENCODER not available" >&2
        exit 1
    fi
    [[ "$VCODEC_OUT" == "hevc" ]] && TAG_ARGS="-tag:v hvc1" || TAG_ARGS=""
fi

set_hwaccel_args() {
    case "$ACCEL" in
        qsv)
            HWACCEL_ARGS=(
                -init_hw_device "qsv=qsv:hw,child_device=$QSV_DEVICE"
                -filter_hw_device qsv
                -hwaccel qsv
                -hwaccel_device qsv
                -hwaccel_output_format qsv
            )
            ;;
        vaapi) HWACCEL_ARGS=(-hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device "$VAAPI_DEVICE") ;;
        nvenc) HWACCEL_ARGS=(-hwaccel cuda -hwaccel_output_format cuda) ;;
        videotoolbox) HWACCEL_ARGS=(-hwaccel videotoolbox) ;;
        *) HWACCEL_ARGS=() ;;
    esac
}

set_encoder_opts() {
    BF_ARGS="-bf 2"
    case "$ACCEL" in
        qsv)
            if [[ "${BEST_LOW_POWER:-0}" == "1" ]]; then
                ACCEL_OPTS="-low_power true -look_ahead 0"
                BF_ARGS="-bf 0"
            else
                ACCEL_OPTS="-preset faster"
            fi
            ;;
        vaapi)
            ACCEL_OPTS="-rc_mode VBR"
            if [[ "${BEST_LOW_POWER:-0}" == "1" ]]; then
                ACCEL_OPTS+=" -low_power 1"
                BF_ARGS="-bf 0"
            fi
            ;;
        nvenc) ACCEL_OPTS="-preset p4 -rc vbr" ;;
        videotoolbox) ACCEL_OPTS="-realtime false" ;;
        software) ACCEL_OPTS="-preset faster" ;;
        *) ACCEL_OPTS="" ;;
    esac
}

set_hwaccel_args
set_encoder_opts

VF_ARGS=""
PROFILE_ARGS=""
if [[ "$SOURCE_10BIT" == "true" && "$ALLOW_10BIT" != "true" ]]; then
    # Policy requires an 8-bit output from a 10-bit source.
    case "$ACCEL" in
        nvenc) VF_ARGS="-vf scale_cuda=format=nv12" ;;
        vaapi) VF_ARGS="-vf scale_vaapi=format=nv12" ;;
        qsv) VF_ARGS="-vf scale_qsv=format=nv12" ;;
        *) VF_ARGS="-pix_fmt yuv420p" ;;
    esac
elif [[ "$SOURCE_10BIT" == "true" && "$VCODEC_OUT" == "h264" ]]; then
    # This script's H264 output path is 8-bit.
    case "$ACCEL" in
        nvenc) VF_ARGS="-vf scale_cuda=format=nv12" ;;
        vaapi) VF_ARGS="-vf scale_vaapi=format=nv12" ;;
        qsv) VF_ARGS="-vf scale_qsv=format=nv12" ;;
        *) VF_ARGS="-pix_fmt yuv420p" ;;
    esac
elif [[ "$SOURCE_10BIT" == "true" && "$VCODEC_OUT" == "hevc" && "$ALLOW_10BIT" == "true" ]]; then
    case "$ACCEL" in
        vaapi) VF_ARGS="-vf scale_vaapi=format=p010le" ;;
        qsv)
            VF_ARGS="-vf scale_qsv=format=p010le"
            PROFILE_ARGS="-profile:v main10"
            ;;
        *) VF_ARGS="-pix_fmt yuv420p10le" ;;
    esac
elif [[ "$ACCEL" == "vaapi" || "$ACCEL" == "qsv" ]]; then
    case "$ACCEL" in
        vaapi) VF_ARGS="-vf format=nv12|vaapi,hwupload,scale_vaapi=format=nv12" ;;
        qsv) VF_ARGS="-vf scale_qsv=format=nv12" ;;
    esac
fi

HDR_ARGS=""
if [[ "$IS_HDR" == "true" && "$VCODEC_OUT" == "hevc" && "$ALLOW_HDR" == "true" ]]; then
    HDR_ARGS="-color_primaries bt2020 -color_trc $COLOR_TRANSFER -colorspace bt2020nc"
fi

BASE_VBITRATE=8000000
VBITRATE=$((BASE_VBITRATE * WIDTH * HEIGHT / 1920 / 1080))
[[ $VBITRATE -lt 2000000 ]] && VBITRATE=2000000
MAXRATE=$((VBITRATE * 125 / 100))
BUFSIZE=$((VBITRATE * 2))

if [[ "$FPS_FRAC" =~ ^([0-9]+)/([0-9]+)$ ]]; then
    NUM=${BASH_REMATCH[1]}
    DEN=${BASH_REMATCH[2]}
    if [[ $DEN -gt 0 ]]; then
        GOP=$(( (NUM + DEN/2) / DEN ))
        FPS_OUT="$FPS_FRAC"
        GOP_WARN=""
    else
        GOP=50
        FPS_OUT="25/1"
        GOP_WARN=" (invalid fps denominator)"
    fi
else
    GOP=50
    FPS_OUT="25/1"
    GOP_WARN=" (fps parse failed)"
fi

DEVICE_INFO=""
case "$ACCEL" in
    qsv) DEVICE_INFO=" device=$QSV_DEVICE" ;;
    vaapi) DEVICE_INFO=" device=$VAAPI_DEVICE" ;;
esac

echo "$LOG_PREFIX Detected ${WIDTH}x${HEIGHT} $VCODEC/$PIX_FMT @ $FPS_FRAC -> $ENCODER reason=${VIDEO_TRANSCODE_REASON} GOP=$GOP${GOP_WARN} audio=${AUDIO_INFO} accel=${ACCEL}${DEVICE_INFO} 10bit=${ALLOW_10BIT} hdr=${ALLOW_HDR}" >&2

exec ffmpeg \
    "${UA_ARGS[@]}" \
    "${NET_ARGS[@]}" \
    "${HWACCEL_ARGS[@]}" \
    -reinit_filter 0 \
    -fflags +genpts+igndts+discardcorrupt \
    -err_detect ignore_err \
    -i "$URL" \
    -map 0:v:0 \
    -map 0:a:0? \
    -c:v "$ENCODER" \
    $VF_ARGS \
    $PROFILE_ARGS \
    $HDR_ARGS \
    -b:v "$VBITRATE" \
    -maxrate "$MAXRATE" \
    -bufsize "$BUFSIZE" \
    -g "$GOP" \
    $BF_ARGS \
    ${ACCEL_OPTS} \
    -fps_mode cfr \
    -r "$FPS_OUT" \
    $TAG_ARGS \
    "${AUDIO_ARGS[@]}" \
    -avoid_negative_ts make_zero \
    -start_at_zero \
    -mpegts_copyts 0 \
    -mpegts_flags +pat_pmt_at_frames+resend_headers \
    -flush_packets 1 \
    -max_muxing_queue_size 4096 \
    -f mpegts \
    pipe:1
