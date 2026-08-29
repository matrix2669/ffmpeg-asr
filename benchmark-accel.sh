#!/usr/bin/env bash
set -eo pipefail

VERSION="1.1.1-beta.1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFSMART_ENTRYPOINT="$root/ffmpeg-smart.sh"
source "$root/lib/ffsmart-common.sh"
source "$root/lib/ffsmart-cli.sh"
source "$root/lib/ffsmart-cache.sh"
source "$root/lib/ffsmart-hardware.sh"

duration="${1:-30}"
runs="${2:-3}"
ffsmart_positive_integer "$duration" || { echo "Duration must be a positive integer" >&2; exit 64; }
ffsmart_positive_integer "$runs" || { echo "Runs must be a positive integer" >&2; exit 64; }

ffsmart_cli_defaults
ffsmart_init_state
ffsmart_lock_acquire
ffsmart_ensure_benchmark_samples
ffsmart_refresh_hardware_inventory

result_file="$FFSMART_STATE_DIR/benchmark-accel-results.tsv"
printf 'node\thardware_signature\taccelerator\tcodec\tlow_power\trun\tspeed\tstatus\n' > "$result_file"

nodes=("${FFSMART_RENDER_NODES[@]}")
if ((${#nodes[@]} == 0)); then nodes=(-); fi
for node in "${nodes[@]}"; do
    if [[ "$node" == - ]]; then accelerators=(software); else accelerators=(qsv vaapi); fi
    for accel in "${accelerators[@]}"; do
        for codec in h264 hevc; do
            if [[ "$accel" == software ]]; then
                encoder="libx264"; [[ "$codec" == hevc ]] && encoder="libx265"
            else
                encoder="${codec}_${accel}"
            fi
            ffsmart_encoder_available "$encoder" || continue
            for low_power in 0 1; do
                [[ "$accel" == software && "$low_power" == 1 ]] && continue
                for ((run=1; run<=runs; run++)); do
                    if speed="$(ffsmart_benchmark_candidate "$node" "$accel" "$codec" "$low_power" "$duration")"; then
                        status=pass
                    else
                        speed=0; status=fail
                    fi
                    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                        "$node" "$(ffsmart_device_get signature "$node" 2>/dev/null || printf software)" "$accel" "$codec" "$low_power" "$run" "$speed" "$status" | tee -a "$result_file"
                done
            done
        done
    done
done

ffsmart_log "Benchmark results: $result_file"
