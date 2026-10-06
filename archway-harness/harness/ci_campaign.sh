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
  echo "--- E6b drift probes: trigger alone via -query (dense vs sparse, 300k iters) ---"
  for MODE in dense sparse; do
    D="$NESTED/probe_$MODE"
    if [ "$MODE" = "dense" ]; then
      python3 "$NESTED/gen_nested_contracts.py" "$D" --iters 300000 --dense > /dev/null 2>&1
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

  echo "--- vulnerable sweep (wasmvm 1.5.5, r=0..511 = all phases): crash = cross-stack hijack ---"
  CRASHES=0
  for R in $(seq 0 511); do
    OFF=$((512 - R))
    ITERS=$((65536 + R + 1))
    D="$NESTED/build_r$R"
    python3 "$NESTED/gen_nested_contracts.py" "$D" --offset "$OFF" --iters "$ITERS" > /dev/null 2>&1 || continue
    for w in holder trigger benign; do
      "$PY" -c "import wasmtime; open('$D/$w.wasm','wb').write(wasmtime.wat2wasm(open('$D/$w.wat').read()))" 2>/dev/null
    done
    if timeout 120 ./harness/harness -wasm "$D/holder.wasm" -trigger "$D/trigger.wasm" -benign "$D/benign.wasm" -warmups 4 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-vuln-r$R.json" > "ci-out/harness/nested-vuln-r$R.stdout" 2> "ci-out/harness/nested-vuln-r$R.stderr"; then
      :
    else
      echo "  r$R CRASH/exit=$?" | tee -a "$OUT/sweep.log"
      CRASHES=$((CRASHES+1))
    fi
  done
  echo "vulnerable crashes: $CRASHES / 512" | tee -a "$OUT/sweep.log"
  echo "--- fixed control (wasmvm 3.0.8, r=256) ---"
  D="$NESTED/build_r256"
  if timeout 120 ./harness-fixed/harness-fixed -wasm "$D/holder.wasm" -trigger "$D/trigger.wasm" -benign "$D/benign.wasm" -warmups 4 -exec '{}' -gas 10000000000000 -out "ci-out/harness/nested-fixed-r256.json" > "ci-out/harness/nested-fixed-r256.stdout" 2> "ci-out/harness/nested-fixed-r256.stderr"; then
    echo "  fixed r256 exit=0 (clean)" | tee -a "$OUT/sweep.log"
  else
    echo "  fixed r256 CRASH/exit=$?" | tee -a "$OUT/sweep.log"
  fi
  echo "--- nested summary ---"
  python3 - <<'PYEOF'
import glob, os, json
crashes, oks = [], []
for f in sorted(glob.glob("ci-out/harness/nested-vuln-r*.stderr"), key=lambda p: int(p.split("-r")[-1].split(".")[0])):
    r = f.split("-r")[-1].split(".")[0]
    j = f.replace(".stderr", ".json")
    if not os.path.exists(j) or os.path.getsize(j) == 0:
        crashes.append(int(r))
    else:
        oks.append(int(r))
print("vuln crashes:", len(crashes), crashes[:40])
print("vuln clean  :", len(oks), oks[:12])
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
