#!/usr/bin/env bash
# C2-20 heavy job: global Safe-module census + family sweep + live state dump.
# Runs from the finding folder (ci/run.sh invoked by the workflow). Results -> ci-out/.
set -uo pipefail
mkdir -p ci-out

echo "[ci] state dump"
timeout 300 python3 -u analysis/state_dump.py > ci-out/state_dump.log 2>&1 || echo "state dump failed"
cp analysis/state_latest.json ci-out/ 2>/dev/null || true

echo "[ci] eth_call matrix (latest block)"
timeout 600 python3 -u analysis/matrix.py > ci-out/matrix.log 2>&1 || echo "matrix failed"
cp analysis/matrix_results.json ci-out/ 2>/dev/null || true

echo "[ci] global EnabledModule/DisabledModule census (GoldRush)"
timeout 1700 python3 -u analysis/census.py > ci-out/census.log 2>&1 || echo "census failed"
cp analysis/census_counts.json analysis/census_current_set.json ci-out/ 2>/dev/null || true

echo "[ci] family-module sweep over currently enabled modules"
timeout 900 python3 -u analysis/family_sweep.py > ci-out/family_sweep.log 2>&1 || echo "family sweep failed"
cp analysis/family_sweep_hits.json analysis/family_sweep_live.json ci-out/ 2>/dev/null || true

echo "[ci] holder intersections"
cp analysis/aethrseth_holder_intersection.json analysis/rseth_holder_intersection.json ci-out/ 2>/dev/null || true

echo "[ci] done"
