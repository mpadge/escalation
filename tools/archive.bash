#!/usr/bin/env bash
set -euo pipefail

phase=$(ls -d specs/[0-9]* 2>/dev/null | sort -V | tail -1)
if [ -z "$phase" ]; then
    echo "No numbered specs phase found under specs/."
    exit 1
fi
phase=$(basename "$phase")

dest="results/$phase"
mkdir -p "$dest"

for f in results/*.csv results/*.rds; do
    [ -e "$f" ] && mv "$f" "$dest/"
done
for d in results/gp_phase results/plots; do
    [ -d "$d" ] && mv "$d" "$dest/"
done
for d in results/gp_phase2 results/plots; do
    [ -d "$d" ] && mv "$d" "$dest/"
done
for d in results/gp_phase3 results/plots; do
    [ -d "$d" ] && mv "$d" "$dest/"
done

# tar -czf "${dest}.tar.gz" -C results "$phase"
# rm -rf "$dest"
# echo "Archived to ${dest}.tar.gz"
