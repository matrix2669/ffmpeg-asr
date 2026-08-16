#!/bin/bash
if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

# Benchmark hardware video encoders
# Auto-downloads Jellyfin test files and tests all available hw encoders

RESULTS_DIR="./benchmark-results"
SAMPLES_DIR="./benchmark-samples"
DURATION="${1:-30}"
RUNS="${2:-3}"

mkdir -p "$RESULTS_DIR" "$SAMPLES_DIR"

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

    [[ -n "$fallback" ]] && { echo "$fallback"; return 0; }
    return 1
}

if [[ "$(uname -s)" == "Linux" ]]; then
    [[ -z "$DRI_DEVICE" ]] && DRI_DEVICE="$(auto_select_dri_device || true)"
    [[ -z "$VAAPI_DEVICE" ]] && VAAPI_DEVICE="$DRI_DEVICE"
    [[ -z "$QSV_DEVICE" ]] && QSV_DEVICE="$DRI_DEVICE"
fi

# Jellyfin test files - same content, different codecs
declare -A TEST_FILES=(
    ["h264_1080p"]="https://repo.jellyfin.org/archive/jellyfish/media/jellyfish-20-mbps-hd-h264.mkv"
    ["hevc_1080p"]="https://repo.jellyfin.org/archive/jellyfish/media/jellyfish-20-mbps-hd-hevc.mkv"
    ["hevc_10bit_1080p"]="https://repo.jellyfin.org/archive/jellyfish/media/jellyfish-20-mbps-hd-hevc-10bit.mkv"
    ["vp9_1080p"]="https://test-videos.co.uk/vids/bigbuckbunny/webm/vp9/1080/Big_Buck_Bunny_1080_10s_1MB.webm"
)

# Global encoder list (cached)
ENCODERS=""

# Detect available hardware based on devices actually exposed in /dev.
detect_encoders() {
    local available=()
    local vendor=""

    # NVIDIA - check for device
    if [[ -e /dev/nvidia0 ]] && echo "$ENCODERS" | grep -qw "h264_nvenc"; then
        available+=("nvenc")
    fi

    # Intel QSV on the selected, actually exposed render node.
    if [[ -n "$QSV_DEVICE" && -e "$QSV_DEVICE" ]]; then
        vendor="$(get_dri_vendor "$QSV_DEVICE" || true)"
        if [[ "$vendor" == "0x8086" ]] && echo "$ENCODERS" | grep -qw "h264_qsv"; then
            available+=("qsv")
        fi
    fi

    # Intel/AMD VAAPI on the selected, actually exposed render node.
    if [[ -n "$VAAPI_DEVICE" && -e "$VAAPI_DEVICE" ]]; then
        vendor="$(get_dri_vendor "$VAAPI_DEVICE" || true)"
        case "$vendor" in
            0x8086|0x1002)
                if echo "$ENCODERS" | grep -qw "h264_vaapi"; then
                    available+=("vaapi")
                fi
                ;;
        esac
    fi

    # VideoToolbox (macOS)
    if [[ "$(uname -s)" == "Darwin" ]] && echo "$ENCODERS" | grep -qw "h264_videotoolbox"; then
        available+=("videotoolbox")
    fi

    # V4L2 M2M (ARM) - check for codec device
    for n in /sys/class/video4linux/video*/name; do
        if [[ -r "$n" ]] && grep -qiE 'm2m|codec' "$n" 2>/dev/null; then
            if echo "$ENCODERS" | grep -qw "h264_v4l2m2m"; then
                available+=("v4l2m2m")
            fi
            break
        fi
    done

    # Software fallback
    available+=("software")

    echo "${available[@]}"
}

# Get hwaccel args for each encoder type
get_hwaccel_args() {
    local accel="$1"
    case "$accel" in
        nvenc)
            echo "-hwaccel cuda -hwaccel_output_format cuda"
            ;;
        qsv)
            [[ -n "$QSV_DEVICE" ]] || return 1
            echo "-init_hw_device qsv=qsv:hw,child_device=$QSV_DEVICE -filter_hw_device qsv -hwaccel qsv -hwaccel_device qsv -hwaccel_output_format qsv"
            ;;
        vaapi)
            [[ -n "$VAAPI_DEVICE" ]] || return 1
            echo "-hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device $VAAPI_DEVICE"
            ;;
        videotoolbox)
            echo "-hwaccel videotoolbox"
            ;;
        v4l2m2m|software)
            echo ""
            ;;
    esac
}

# Get encoder name for codec + accel type
get_encoder() {
    local codec="$1"
    local accel="$2"
    case "$accel" in
        nvenc)      echo "${codec}_nvenc" ;;
        qsv)        echo "${codec}_qsv" ;;
        vaapi)      echo "${codec}_vaapi" ;;
        videotoolbox) echo "${codec}_videotoolbox" ;;
        v4l2m2m)    echo "${codec}_v4l2m2m" ;;
        software)
            case "$codec" in
                h264) echo "libx264" ;;
                hevc) echo "libx265" ;;
                vp9)  echo "libvpx-vp9" ;;
            esac
            ;;
    esac
}

# Download test files if needed
download_samples() {
    echo "Checking test files..."
    for name in "${!TEST_FILES[@]}"; do
        local url="${TEST_FILES[$name]}"
        local ext="${url##*.}"
        local file="$SAMPLES_DIR/${name}.${ext}"
        if [[ ! -f "$file" ]] || [[ $(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null) -lt 1000000 ]]; then
            echo "  Downloading $name..."
            rm -f "$file"
            if command -v curl &>/dev/null; then
                curl -L --progress-bar -o "$file" "$url" || { echo "Failed to download $name"; return 1; }
            elif command -v wget &>/dev/null; then
                wget --show-progress -q -O "$file" "$url" || { echo "Failed to download $name"; return 1; }
            else
                echo "Neither curl nor wget available"
                return 1
            fi
            local size
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
            if [[ $size -lt 1000000 ]]; then
                echo "Download failed or file too small: $size bytes"
                rm -f "$file"
                return 1
            fi
            echo "  Downloaded: $(numfmt --to=iec $size 2>/dev/null || echo "$size bytes")"
        else
            local size
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
            echo "  $name: cached ($(numfmt --to=iec $size 2>/dev/null || echo "$size bytes"))"
        fi
    done
    echo ""
}

# Run single encode test
run_encode() {
    local input="$1"
    local encoder="$2"
    local hwaccel_args="$3"
    local encoder_opts="$4"
    local output_file="$RESULTS_DIR/test_output.ts"
    local log_file="$RESULTS_DIR/ffmpeg.log"

    local cmd=(ffmpeg -nostdin -hide_banner -y)
    if [[ -n "$hwaccel_args" ]]; then
        local -a hw_args
        read -ra hw_args <<< "$hwaccel_args"
        cmd+=("${hw_args[@]}")
    fi
    cmd+=(-i "$input" -t "$DURATION")
    cmd+=(-c:v "$encoder" -b:v 8000000 -maxrate 10000000 -bufsize 20000000 -g 30 -bf 0)
    if [[ -n "$encoder_opts" ]]; then
        local -a enc_opts
        read -ra enc_opts <<< "$encoder_opts"
        cmd+=("${enc_opts[@]}")
    fi
    cmd+=(-an -f mpegts "$output_file")

    set +e
    "${cmd[@]}" > "$log_file" 2>&1
    local rc=$?
    set -e

    if [[ $rc -eq 0 ]] && grep -q "frame=" "$log_file"; then
        local fps speed input_fps
        fps=$(sed -n 's/.*fps= *\([0-9.]*\).*/\1/p' "$log_file" 2>/dev/null | tail -1)

        if [[ -z "$fps" || "$fps" == "0" || "$fps" == "0.0" || "$fps" == "0.00" ]]; then
            speed=$(sed -n 's/.*speed= *\([0-9.]*\)x.*/\1/p' "$log_file" 2>/dev/null | tail -1)
            input_fps=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$input" 2>/dev/null | head -1)
            if [[ -n "$speed" && -n "$input_fps" && "$input_fps" =~ ^([0-9]+)/([0-9]+)$ ]]; then
                fps=$(awk "BEGIN {printf \"%.1f\", $speed * ${BASH_REMATCH[1]} / ${BASH_REMATCH[2]}}")
            fi
        fi
        echo "${fps:-0}"
    else
        echo "0"
    fi
}

# Run benchmark for all combinations
run_benchmarks() {
    local encoders=("$@")
    local results_csv="$RESULTS_DIR/results_$(date +%Y%m%d_%H%M%S).csv"

    echo "source,encoder,accel,mode,run,fps" > "$results_csv"

    echo "=============================================="
    echo "Hardware Encoder Benchmark"
    echo "Duration: ${DURATION}s per test, ${RUNS} runs each"
    echo "Encoders: ${encoders[*]}"
    echo "=============================================="
    echo ""

    for source in "${!TEST_FILES[@]}"; do
        local url="${TEST_FILES[$source]}"
        local ext="${url##*.}"
        local input="$SAMPLES_DIR/${source}.${ext}"
        [[ -f "$input" ]] || continue

        echo "=== Source: $source ==="

        for accel in "${encoders[@]}"; do
            local power_modes=("normal")
            if [[ "$accel" == "vaapi" || "$accel" == "qsv" ]]; then
                power_modes+=("low_power")
            fi

            for codec in h264 hevc vp9; do
                local encoder
                encoder=$(get_encoder "$codec" "$accel")

                if ! echo "$ENCODERS" | grep -qw "$encoder"; then
                    continue
                fi

                local hwaccel_args
                hwaccel_args=$(get_hwaccel_args "$accel")

                for power_mode in "${power_modes[@]}"; do
                    local encoder_opts=""
                    local display_name="$encoder"
                    if [[ "$power_mode" == "low_power" ]]; then
                        encoder_opts="-low_power 1"
                        display_name="${encoder}(lp)"
                    fi

                    printf "  %-24s " "$display_name"

                    local fps_sum=0
                    local fps_count=0
                    local failed=0
                    local fps

                    for run in $(seq 1 "$RUNS"); do
                        fps=$(run_encode "$input" "$encoder" "$hwaccel_args" "$encoder_opts" 2>/dev/null || echo "0")

                        if [[ -z "$fps" || "$fps" == "0" || "$fps" == "0.0" ]]; then
                            failed=1
                            break
                        fi

                        fps_sum=$(awk "BEGIN {print $fps_sum + $fps}")
                        fps_count=$((fps_count + 1))
                        echo "$source,$encoder,$accel,$power_mode,$run,$fps" >> "$results_csv"
                    done

                    if [[ $failed -eq 1 ]]; then
                        echo "FAILED"
                    else
                        local avg
                        avg=$(awk "BEGIN {printf \"%.1f\", $fps_sum / $fps_count}")
                        echo "${avg} fps"
                    fi
                done
            done
        done
        echo ""
    done

    echo "=============================================="
    echo "Results saved to: $results_csv"
    echo "=============================================="

    echo ""
    echo "=== SUMMARY (avg fps) ==="
    echo ""

    awk -F',' 'NR>1 {
        mode_suffix = ($4 == "low_power") ? "(lp)" : ""
        key = $1 "," $2 mode_suffix "," $3
        sum[key] += $6
        count[key]++
    }
    END {
        for (k in sum) {
            split(k, a, ",")
            printf "%-15s %-24s %8.1f fps\n", a[1], a[2], sum[k]/count[k]
        }
    }' "$results_csv" | sort
}

# Main
echo "=============================================="
echo "FFmpeg Hardware Encoder Benchmark"
echo "=============================================="
echo ""

# Download test files
download_samples || exit 1

# Detect available encoders
echo "Detecting hardware encoders..."
ENCODERS=$(ffmpeg -hide_banner -encoders 2>/dev/null)
read -ra AVAILABLE_ENCODERS <<< "$(detect_encoders)"
echo "Found: ${AVAILABLE_ENCODERS[*]}"
if [[ "$(uname -s)" == "Linux" ]]; then
    echo "DRI device: ${DRI_DEVICE:-none}"
    echo "QSV device: ${QSV_DEVICE:-none}"
    echo "VAAPI device: ${VAAPI_DEVICE:-none}"
fi
echo ""

# Run benchmarks
run_benchmarks "${AVAILABLE_ENCODERS[@]}"
