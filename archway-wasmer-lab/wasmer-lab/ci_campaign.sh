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

echo "=== [5/5] high-iteration overflow probes (rsp probe is blind: host calls run on_host_stack) ==="
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

echo "=== [6/6] E1 write-stream detector (push_used_gpr writes at drifted rsp) ==="
python3 gen_writestream.py patterns/ws_drift.wat | tee -a "$OUT/sweep.log"
for lab in lab-422-sp lab-742-sp; do
  # stride 8192: scan at i = 0, 8192, ... ; drift 16 B/iter -> ~128 KiB per scan step
  if timeout 300 "./$lab/target/release/$lab" writestream patterns/ws_drift.wat 70000 8192 >"$OUT/writestream-$lab.json" 2>&1; then
    echo "--- $lab writestream scan summary ---" | tee -a "$OUT/sweep.log"
    python3 - "$OUT/writestream-$lab.json" <<'PYEOF' | tee -a "$OUT/sweep.log"
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("parse error:", e)
    print(open(sys.argv[1]).read()[:2000])
    sys.exit(0)
print("pattern:", d.get("pattern"), "| result:", d.get("result"), "| calls:", d.get("calls"))
scans = d.get("scans", [])
print(f"scans: {len(scans)}")
prev = None
for s in scans:
    step = ""
    if prev is not None and s.get("max") not in ("0x0", None):
        try:
            step = f" dMax={int(s['max'],16)-int(prev,16)}"
        except Exception:
            pass
    print(f"  i={s.get('i'):<7} hits={s.get('hits'):<6} min={s.get('min')} max={s.get('max')} k0={s.get('k0')} cand={s.get('candidates')}{step}")
    if s.get("max") not in ("0x0", None):
        prev = s["max"]
PYEOF
  else
    rc=$?
    echo "writestream $lab failed/exit=$rc" | tee -a "$OUT/sweep.log"
    tail -3 "$OUT/writestream-$lab.json" 2>/dev/null | tee -a "$OUT/sweep.log"
  fi
done

echo "=== results ==="
ls -la "$OUT"
exit 0
