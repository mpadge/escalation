#!/usr/bin/env bash
set -euo pipefail

X="[x]"
O="[ ]"

file_status() {
    local label=$1; shift
    local found=0
    for f in "$@"; do
        # support globs passed as strings
        for g in $f; do
            [ -f "$g" ] && found=1 && break 2
        done
    done
    if (( found )); then
        echo "  $X $label"
        return 0
    else
        echo "  $O $label"
        return 1
    fi
}

running=$(pgrep -af 'target/release/escalation' 2>/dev/null | grep -v grep | head -1 | sed 's/^[0-9]* //' || true)

echo "Pipeline status:"
echo ""

next=""

file_status "binary built"        "target/release/escalation"           || { next="make release";       }
file_status "morris screening"    "results/morris_results.csv"          || { next=${next:-"make morris"}; }
file_status "sobol analysis"      "results/sobol_results.csv"           || { next=${next:-"make sobol"};  }

# gp_train and gp_phase are both launched by 'make gp'; distinguish partial completion
if [ -f "results/gp_psi.rds" ] && [ -f "results/gp_validation.csv" ]; then
    echo "  $X gp emulation (training + validation)"
else
    if [ -f "results/gp_train_raw.csv" ] && [ ! -f "results/gp_psi.rds" ]; then
        echo "  $O gp emulation  (simulations done, GP fitting incomplete — re-run make gp)"
    else
        echo "  $O gp emulation"
    fi
    next=${next:-"make gp"}
fi

if [ -f "results/sobol_gp.csv" ] && ls results/gp_phase/phase_*.csv >/dev/null 2>&1; then
    echo "  $X phase diagrams + emulator Sobol"
else
    if [ -f "results/gp_psi.rds" ]; then
        echo "  $O phase diagrams + emulator Sobol  (GP ready — run make gp)"
        next=${next:-"make gp"}
    else
        echo "  $O phase diagrams + emulator Sobol"
    fi
fi

if ls results/plots/*.png >/dev/null 2>&1; then
    echo "  $X plots"
else
    echo "  $O plots"
    if [ -f "results/sobol_gp.csv" ]; then
        next=${next:-"make plots"}
    fi
fi

echo ""
if [ -n "$running" ]; then
    subcmd=$(echo "$running" | grep -oP '(?<=escalation )(morris|sobol|gp-train)' || echo "unknown")
    echo "  Running : $subcmd  —  use 'make progress' for details"
elif [ -n "$next" ]; then
    echo "  Next    : $next"
else
    echo "  All steps complete."
fi
