#!/usr/bin/env bash
# CWA-2026-006 wasmer-level campaign (runs on GitHub Actions).
#  1. builds Singlepass 4.2.2 (chain-exact) + Singlepass 7.4.2 (patched) + Cranelift 7.4.2 (oracle)
#  2. R1 static-memory sentinel patterns
#  3. P1 rsp-drift probe + full variant sweep (Hexens WASMageddon shape)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"        # .../archway-wasmer-lab/wasmer-lab
ROOT="$(cd "$HERE/.." && pwd)"               # .../archway-wasmer-lab
OUT="$ROOT/ci-out"
mkdir -p "$OUT"
cd "$HERE"

echo "=== [1/4] build labs (this is the heavy step) ==="
for lab in lab-422-sp lab-742-sp lab-742-cl; do
  echo "--- build $lab"
  mkdir -p "$lab/src"
  cp common/main.rs "$lab/src/main.rs"
  (cd "$lab" && cargo build --release -j 2 2>&1 | tail -5) || { echo "BUILD FAILED: $lab"; exit 1; }
  echo "built $lab"
done

echo "=== [2/4] R1 static-memory sentinel patterns ==="
for lab in lab-422-sp lab-742-sp lab-742-cl; do
  echo "--- $lab patterns"
  (timeout 120 "./$lab/target/release/$lab" patterns 2>&1 | tee "$OUT/patterns-$lab.txt") || echo "patterns run failed/crashed ($?)" | tee -a "$OUT/patterns-$lab.txt"
done

echo "=== [3/4] P1 named patterns (regression) ==="
for lab in lab-422-sp lab-742-sp; do
  for pat in patterns/p0_control.wat patterns/p1a_else_drift.wat patterns/p1b_else_drift.wat; do
    if timeout 300 "./$lab/target/release/$lab" drift "$pat" 10000 >>"$OUT/drift-$lab.jsonl" 2>&1; then
      tail -1 "$OUT/drift-$lab.jsonl"
    else
      rc=$?
      echo "{\"pattern\":\"$pat\",\"iters\":10000,\"result\":\"CRASH/exit:$rc\"}" >>"$OUT/drift-$lab.jsonl"
    fi
  done
done

echo "=== [4/4] P1 variant sweep (96 shapes x 2 engines) ==="
python3 gen_p1_variants.py --out "$OUT/p1variants" | tee "$OUT/sweep.log"
for lab in lab-422-sp lab-742-sp; do
  : > "$OUT/drift-sweep-$lab.jsonl"
  for pat in "$OUT"/p1variants/*.wat; do
    if timeout 120 "./$lab/target/release/$lab" drift "$pat" 5000 >>"$OUT/drift-sweep-$lab.jsonl" 2>&1; then :; else
      echo "{\"pattern\":\"$pat\",\"result\":\"CRASH/exit:$?\"}" >>"$OUT/drift-sweep-$lab.jsonl"
    fi
  done
  echo "--- $lab: variants with NONZERO drift ---" | tee -a "$OUT/sweep.log"
  grep -v '"drift":0' "$OUT/drift-sweep-$lab.jsonl" | head -80 | tee -a "$OUT/sweep.log"
  echo "--- $lab: total variants ---" | tee -a "$OUT/sweep.log"
  wc -l < "$OUT/drift-sweep-$lab.jsonl" | tee -a "$OUT/sweep.log"
done

echo "=== results ==="
ls -la "$OUT"
exit 0
