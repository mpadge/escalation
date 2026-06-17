#!/usr/bin/env bash
set -euo pipefail

X="[\033[32mx\033[0m]"
O="[ ]"

step() {
    local n=$1 label=$2 cmd=$3; shift 3
    local found=0
    for f in "$@"; do
        for g in $f; do
            [ -f "$g" ] && found=1 && break 2
        done
    done
    if (( found )); then
        printf "  %b  %d. %-38s done\n" "$X" "$n" "$label"
        return 0
    else
        printf "  %b  %d. %-38s %s\n" "$O" "$n" "$label" "$cmd"
        return 1
    fi
}

running=$(pgrep -af 'target/release/escalation' 2>/dev/null | grep -v grep | head -1 \
          | sed 's/^[0-9]* //' || true)

echo "Pipeline status:"
echo ""

next=""

step 0 "binary built"              "make release"  "target/release/escalation"  \
    || next="make release"

step 1 "Morris screening"          "make screen"   "results/morris_results.csv" \
    || next=${next:-"make screen"}

step 2 "Sobol sensitivity"         "make sobol"    "results/sobol_results.csv"  \
    || next=${next:-"make sobol"}

# Adaptive exploration: show partial progress if simulations ran but GP not yet fit
if [ -f "results/gp_psi.rds" ]; then
    step 3 "Adaptive GP exploration"   "make explore"  "results/gp_psi.rds" \
           "results/adaptive_design.csv"
elif [ -f "results/gp_train_raw.csv" ]; then
    printf "  %b  3. %-38s %s\n" "$O" "Adaptive GP exploration" \
           "(sims done, GP fit pending — re-run make explore)"
    next=${next:-"make explore"}
else
    step 3 "Adaptive GP exploration"   "make explore"  "results/gp_psi.rds" \
        || next=${next:-"make explore"}
fi

step 4 "GP training (edeg + psi_sigma)" "make train" \
       "results/gp_edeg.rds" "results/gp_psi_sigma.rds" \
    || next=${next:-"make train"}

step 5 "Gini GP analysis"          "make gini"     "results/gp_gini.rds"        \
    || next=${next:-"make gini"}

if ls results/figures/*.png >/dev/null 2>&1; then
    step 6 "Figures"               "make plots"    "results/figures/psi_phase_lambda_alpha.png"
else
    step 6 "Figures"               "make plots"    "results/figures/psi_phase_lambda_alpha.png" \
        || next=${next:-"make plots"}
fi

if [ -f "docs/report.md" ]; then
    step 7 "Report"                "make doc"      "docs/report.md"
else
    step 7 "Report"                "make doc"      "docs/report.md" \
        || next=${next:-"(write docs/report.md, then make doc)"}
fi

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
