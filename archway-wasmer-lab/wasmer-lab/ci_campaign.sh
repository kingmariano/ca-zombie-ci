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

echo "=== [1/7] build labs (this is the heavy step) ==="
for lab in lab-422-sp lab-742-sp lab-742-cl; do
  echo "--- build $lab"
  mkdir -p "$lab/src"
  cp common/main.rs "$lab/src/main.rs"
  (cd "$lab" && cargo build --release -j 2 2>&1 | tail -5) || { echo "BUILD FAILED: $lab"; exit 1; }
  echo "built $lab"
done

echo "=== [2/7] R1 static-memory sentinel patterns ==="
for lab in lab-422-sp lab-742-sp lab-742-cl; do
  echo "--- $lab patterns"
  (timeout 120 "./$lab/target/release/$lab" patterns 2>&1 | tee "$OUT/patterns-$lab.txt") || echo "patterns run failed/crashed ($?)" | tee -a "$OUT/patterns-$lab.txt"
done

echo "=== [3/7] P1 named patterns (regression) ==="
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

echo "=== [4/7] P1 variant sweep (96 shapes x 2 engines) ==="
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

echo "=== [5/7] high-iteration overflow probes (rsp probe is blind: host calls run on_host_stack) ==="
SEL="v_l6_extend_add_r1 v_l8_extend_add_r1 v_l12_extend_add_r1 v_l16_extend_add_r1 v_l24_extend_add_r1 v_l6_load_add_r1 v_l12_load_add_r1 v_l6_extend_extend_r1 v_l12_extend_extend_r1 v_l16_extend_extend_r1"
for lab in lab-422-sp lab-742-sp; do
  : > "$OUT/overflow-$lab.jsonl"
  for v in $SEL; do
    pat="$OUT/p1variants/$v.wat"
    [ -f "$pat" ] || continue
    for iters in 300000 2000000; do
      if timeout 300 "./$lab/target/release/$lab" drift "$pat" "$iters" >>"$OUT/overflow-$lab.jsonl" 2>&1; then
        tail -1 "$OUT/overflow-$lab.jsonl"
      else
        rc=$?
        echo "{\"pattern\":\"$v\",\"iters\":$iters,\"result\":\"CRASH/exit:$rc\"}" >>"$OUT/overflow-$lab.jsonl"
      fi
    done
  done
  echo "--- $lab: overflow outcomes (non-ok only) ---" | tee -a "$OUT/sweep.log"
  grep -v '"result":"ok"' "$OUT/overflow-$lab.jsonl" | head -40 | tee -a "$OUT/sweep.log"
done

echo "=== [6/7] E1 write-stream (dense) + E3 guard-jump (sparse) ==="
run_writestream() {
  local lab="$1" pat="$2" iters="$3" stride="$4" tag="$5"
  if timeout 900 "./$lab/target/release/$lab" writestream "$pat" "$iters" "$stride" >"$OUT/writestream-$lab-$tag.json" 2>&1; then
    echo "--- $lab $tag scan summary ---" | tee -a "$OUT/sweep.log"
    python3 - "$OUT/writestream-$lab-$tag.json" <<'PYEOF' | tee -a "$OUT/sweep.log"
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("parse error:", e)
    print(open(sys.argv[1]).read()[:2000])
    sys.exit(0)
print("result:", d.get("result"), "| calls:", d.get("calls"))
scans = d.get("scans", [])
print(f"scans: {len(scans)}")
idx = sorted(set(list(range(min(3, len(scans)))) + list(range(max(0, len(scans) - 4), len(scans)))))
for n in idx:
    s = scans[n]
    print(f"  i={s.get('i'):<8} hits={s.get('hits'):<6} k0={s.get('k0')} map_hits={s.get('map_hits')}")
PYEOF
  else
    rc=$?
    echo "writestream $lab $tag failed/exit=$rc" | tee -a "$OUT/sweep.log"
    tail -3 "$OUT/writestream-$lab-$tag.json" 2>/dev/null | tee -a "$OUT/sweep.log"
  fi
}

# E1: dense stream (call every iteration) - regression on the confirmed result
python3 gen_writestream.py patterns/ws_drift.wat 1 | tee -a "$OUT/sweep.log"
run_writestream lab-422-sp patterns/ws_drift.wat 70000 8192 dense
run_writestream lab-742-sp patterns/ws_drift.wat 70000 8192 dense

# E3: sparse streams - write batches jump 16*K bytes per call; K >= 512 can skip the 4 KiB guard
for K in 512 1024 2048 4096 8192; do
  python3 gen_writestream.py "patterns/ws_sparse_$K.wat" "$K" | tee -a "$OUT/sweep.log"
  run_writestream lab-422-sp "patterns/ws_sparse_$K.wat" 400000 1 "sparse$K"
done
run_writestream lab-742-sp patterns/ws_sparse_1024.wat 400000 1 "sparse1024"

echo "=== results ==="
ls -la "$OUT"
exit 0
