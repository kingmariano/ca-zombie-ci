#!/usr/bin/env bash
# CWA-2026-006 wasmer-level campaign (runs on GitHub Actions).
#  1. builds Singlepass 4.2.2 (chain-exact) + Singlepass 7.4.2 (patched) + Cranelift 7.4.2 (oracle)
#  2. R1 static-memory sentinel patterns
#  3. P1 rsp-drift probe (Hexens WASMageddon shape: result-bearing if/else in a loop)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"        # .../archway-wasmer-lab/wasmer-lab
ROOT="$(cd "$HERE/.." && pwd)"               # .../archway-wasmer-lab
OUT="$ROOT/ci-out"
mkdir -p "$OUT"
cd "$HERE"

echo "=== [1/3] build labs (this is the heavy step) ==="
for lab in lab-422-sp lab-742-sp lab-742-cl; do
  echo "--- build $lab"
  mkdir -p "$lab/src"
  cp common/main.rs "$lab/src/main.rs"
  (cd "$lab" && cargo build --release -j 2 2>&1 | tail -5) || { echo "BUILD FAILED: $lab"; exit 1; }
  echo "built $lab"
done

echo "=== [2/3] R1 static-memory sentinel patterns ==="
for lab in lab-422-sp lab-742-sp lab-742-cl; do
  echo "--- $lab patterns"
  (timeout 120 "./$lab/target/release/$lab" patterns 2>&1 | tee "$OUT/patterns-$lab.txt") || echo "patterns run failed/crashed ($?)" | tee -a "$OUT/patterns-$lab.txt"
done

echo "=== [3/3] P1 rsp-drift probe ==="
for lab in lab-422-sp lab-742-sp; do
  for pat in patterns/p1a_else_drift.wat patterns/p1b_else_drift.wat; do
    for iters in 1000 10000; do
      echo "--- $lab $pat iters=$iters"
      if timeout 300 "./$lab/target/release/$lab" drift "$pat" "$iters" >>"$OUT/drift-$lab.jsonl" 2>&1; then
        tail -1 "$OUT/drift-$lab.jsonl"
      else
        rc=$?
        echo "{\"pattern\":\"$pat\",\"iters\":$iters,\"result\":\"CRASH/exit:$rc\"}" | tee -a "$OUT/drift-$lab.jsonl"
      fi
    done
  done
done

echo "=== results ==="
ls -la "$OUT"
echo "--- drift summary ---"
cat "$OUT"/drift-*.jsonl 2>/dev/null || true
exit 0
