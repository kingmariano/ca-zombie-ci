#!/usr/bin/env bash
# Heavy CI campaign: build both engines + contract corpus, run the differential
# fuzzer against the vulnerable (wasmvm 1.5.5 / Wasmer 4.2.2) and patched
# (wasmvm 3.0.8 / Wasmer 7.4.2) engines, and record every anomaly.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out/harness

echo "=== [1/5] toolchains ==="
go version || { echo "FATAL: no go"; exit 1; }
rustup toolchain install 1.81.0 --profile minimal 2>&1 | tail -2 || true
rustup target add wasm32-unknown-unknown --toolchain 1.81.0 2>&1 | tail -1 || true
cargo +1.81.0 --version || { echo "FATAL: no cargo 1.81"; exit 1; }

echo "=== [2/5] build vulnerable harness (wasmvm v1.5.5 / Wasmer 4.2.2) ==="
(cd harness && go build -o harness .) || { echo "FATAL: harness build failed"; exit 1; }
./harness/harness -h >/dev/null 2>&1 || true
echo "harness built"

echo "=== [3/5] build fixed harness (wasmvm v3.0.8 / Wasmer 7.4.2) ==="
(cd harness-fixed && go build -o harness-fixed .) || { echo "FATAL: harness-fixed build failed"; exit 1; }
echo "harness-fixed built"

echo "=== [4/5] build contract corpus ==="
(cd harness/contracts/minimal && cargo +1.81.0 build --release --target wasm32-unknown-unknown) || { echo "FATAL: contract build failed"; exit 1; }
WASM=harness/contracts/minimal/target/wasm32-unknown-unknown/release/minimal.wasm
ls -la "$WASM"

echo "=== [5/5] differential fuzz campaign ==="
CASES="${FUZZ_CASES:-2000}"
echo "cases=$CASES"
python3 harness/fuzz_campaign.py --wasm "$WASM" --cases "$CASES" --seed 1 --out ci-out/harness
RC=$?
echo "campaign rc=$RC"

echo "=== summary ==="
cat ci-out/harness/fuzz_summary.json 2>/dev/null | head -120
ls -la ci-out/harness/ | head -20
exit 0
