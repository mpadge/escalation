#!/usr/bin/env bash
set -euo pipefail

X="[\033[32mx\033[0m]"
O="[ ]"

# Print one pipeline step.
# step <n> <label> <cmd> <note> <sentinel_file> [<sentinel_file2> ...]
# Always shows <cmd>; appends <note> when incomplete and note is non-empty.
step() {
    local n=$1 label=$2 cmd=$3 note=$4; shift 4
    local found=0
    for f in "$@"; do
        for g in $f; do
            [ -f "$g" ] && found=1 && break 2
        done
    done
    if (( found )); then
        printf "  %b  %d. %-38s %s\n" "$X" "$n" "$label" "$cmd"
        return 0
    else
        local suffix=""
        [ -n "$note" ] && suffix="  ($note)"
        printf "  %b  %d. %-38s %s%s\n" "$O" "$n" "$label" "$cmd" "$suffix"
        return 1
    fi
}

running=$(pgrep -af 'target/release/escalation' 2>/dev/null | grep -v grep | head -1 \
          | sed 's/^[0-9]* //' || true)

echo "Pipeline status:"
echo ""

next=""

step 0 "binary built"           "make release" "" \
       "target/release/escalation" \
    || next="make release"

step 1 "Morris screening"       "make screen"  "" \
       "results/morris_results.csv" \
    || next=${next:-"make screen"}

step 2 "Sobol sensitivity"      "make sobol"   "" \
       "results/sobol_results.csv" \
    || next=${next:-"make sobol"}

explore_note=""
[ -f "results/gp_train_raw.csv" ] && [ ! -f "results/gp_psi.rds" ] \
    && explore_note="sims done, GP fit pending"
step 3 "Adaptive GP exploration" "make explore" "$explore_note" \
       "results/gp_psi.rds" "results/adaptive_design.csv" \
    || next=${next:-"make explore"}

step 4 "GP training"            "make train"   "" \
       "results/gp_edeg.rds" "results/gp_psi_sigma.rds" \
    || next=${next:-"make train"}

step 5 "Gini GP analysis"       "make gini"    "" \
       "results/gp_gini.rds" \
    || next=${next:-"make gini"}

step 6 "Figures"                "make plots"   "" \
       "results/figures/psi_phase_lambda_alpha.png" \
    || next=${next:-"make plots"}

step 7 "Report"                 "make doc"     "write docs/report.md first" \
       "docs/report.md" \
    || next=${next:-"make doc"}

echo ""
if [ -n "$running" ]; then
    subcmd=$(echo "$running" \
             | grep -oP '(?<=escalation )(morris|sobol|gp-train)' \
             || echo "unknown")
    echo "  Running : $subcmd  —  use 'make progress' for details"
elif [ -n "$next" ]; then
    echo "  Next    : $next"
else
    echo "  All steps complete."
fi
