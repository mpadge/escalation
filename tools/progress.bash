#!/usr/bin/env bash
set -euo pipefail

fmt_duration() {
    local secs=$1
    if   (( secs >= 3600 )); then printf "%dh %02dm %02ds" $(( secs/3600 )) $(( (secs%3600)/60 )) $(( secs%60 ))
    elif (( secs >= 60   )); then printf "%dm %02ds" $(( secs/60 )) $(( secs%60 ))
    else                         printf "%ds" "$secs"
    fi
}

cmd=$(pgrep -af 'target/release/escalation' 2>/dev/null | grep -v grep | head -1 | sed 's/^[0-9]* //')
if [ -z "$cmd" ]; then
    echo "No escalation process running."
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

first_done=$(ls -tr "$log_dir"/*.done 2>/dev/null | head -1 || true)
last_done=$(ls  -t  "$log_dir"/*.done 2>/dev/null | head -1 || true)
start=$(stat -c %Y "$first_done")
last=$(stat  -c %Y "$last_done")
now=$(date +%s)
elapsed=$(( now - start ))

echo "Elapsed    : $(fmt_duration $elapsed)"

remaining_n=$(( expected - done_n ))
if (( elapsed > 0 && done_n > 0 )); then
    eta_secs=$(awk "BEGIN { printf \"%d\", ($remaining_n * $elapsed / $done_n) }")
    rate=$(awk "BEGIN { printf \"%.1f\", ($done_n / $elapsed) }")
    echo "Rate       : $rate pairs/s"
    eta_clock=$(date -d "@$(( now + eta_secs ))" '+%H:%M:%S')
    echo "ETA        : $(fmt_duration $eta_secs)  (done at $eta_clock)"
fi
