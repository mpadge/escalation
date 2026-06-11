#!/usr/bin/env bash
set -euo pipefail

fmt_duration() {
    local secs=$1
    if   (( secs >= 3600 )); then printf "%dh %02dm %02ds" $(( secs/3600 )) $(( (secs%3600)/60 )) $(( secs%60 ))
    elif (( secs >= 60   )); then printf "%dm %02ds" $(( secs/60 )) $(( secs%60 ))
    else                         printf "%ds" "$secs"
    fi
}

cmd=$(pgrep -af 'target/release/escalation' 2>/dev/null | grep -v grep | head -1 | sed 's/^[0-9]* //' || true)
if [ -z "$cmd" ]; then
    echo "No escalation process running."
    echo ""
    make --no-print-directory status
    exit 0
fi

subcmd=$(echo "$cmd" | grep -oP '(?<=escalation )(morris|sobol|gp-train)')
design=$(echo "$cmd" | grep -oP '(?<=--design )\S+')
log_dir=$(echo "$cmd" | grep -oP '(?<=--log-dir )\S+' || echo "/tmp/escalation")

if [ ! -f "$design" ]; then
    echo "Design file '$design' not found."
    exit 1
fi

n_design=$(( $(wc -l < "$design") - 1 ))

if [ "$subcmd" = "gp-train" ]; then
    reps=$(echo "$cmd" | grep -oP '(?<=--replicates )\d+')
    expected=$(( n_design * reps ))
else
    expected=$n_design
fi

done_n=$(ls "$log_dir"/*.done 2>/dev/null | wc -l)
pct=$(( done_n * 100 / expected ))

echo "Subcommand : $subcmd"
echo "Progress   : $done_n / $expected  ($pct%)"
echo "Log dir    : $log_dir"

if (( done_n == 0 )); then
    echo "Elapsed    : (no files yet)"
    exit 0
fi

now=$(date +%s)

# Sort all .done timestamps, compute consecutive deltas, remove IQR outliers,
# use trimmed mean delta for rate and ETA.
# Outputs two values: <mean_delta_float> <elapsed_int>
# elapsed = mean_delta * done_n (pure computation estimate, no idle gap).
stats=$(
    ls -tr "$log_dir"/*.done 2>/dev/null \
        | xargs stat -c '%Y' 2>/dev/null \
        | sort -n \
        | awk -v done="$done_n" '
    NR == 1 { prev = $1 }
    NR > 1  { deltas[nd++] = $1 - prev; prev = $1 }
    END {
        if (nd == 0) { printf "1.000000 %d\n", done; exit }
        # insertion sort
        for (i = 1; i < nd; i++) {
            v = deltas[i]; j = i - 1
            while (j >= 0 && deltas[j] > v) { deltas[j+1] = deltas[j]; j-- }
            deltas[j+1] = v
        }
        q1  = deltas[int(nd * 0.25)]
        q3  = deltas[int(nd * 0.75)]
        iqr = q3 - q1
        lo  = q1 - 1.5 * iqr
        hi  = q3 + 1.5 * iqr
        sum = 0; cnt = 0
        for (i = 0; i < nd; i++)
            if (deltas[i] >= lo && deltas[i] <= hi) { sum += deltas[i]; cnt++ }
        if (cnt == 0) { sum = deltas[int(nd / 2)]; cnt = 1 }   # fallback: median
        md = sum / cnt
        if (md < 1e-6) md = 1e-6
        printf "%.6f %d\n", md, int(md * done + 0.5)
    }
    '
)
mean_delta=$(echo "$stats" | awk '{print $1}')
elapsed=$(echo "$stats" | awk '{print $2}')

echo "Elapsed    : $(fmt_duration $elapsed)"

remaining_n=$(( expected - done_n ))
if (( done_n >= 2 )); then
    eta_secs=$(awk "BEGIN { printf \"%d\", int($remaining_n * $mean_delta + 0.5) }")
    rate=$(awk "BEGIN { printf \"%.2f\", 1.0 / $mean_delta }")
    echo "Rate       : $rate pairs/s  (IQR-trimmed mean Δt)"
    eta_clock=$(date -d "@$(( now + eta_secs ))" '+%H:%M:%S')
    echo "ETA        : $(fmt_duration $eta_secs)  (done at $eta_clock)"
fi
