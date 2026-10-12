#!/usr/bin/env bash
# Lenfi (Cardano) — CI job: refresh live state (keyless Koios) + run chain-native CEK proofs (aiken).
# Writes results to ci-out/ (uploaded as artifacts). No secrets, no transactions.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "[lenfi-ci] start $(date -u +%FT%TZ)"

python3 -m pip install --quiet --user "uplc==1.3.3" "cbor2==5.6.5" "pycardano==0.19.2" 2>/dev/null || pip install --quiet "uplc==1.3.3" "cbor2==5.6.5" "pycardano==0.19.2" 2>/dev/null || true
python3 -c "import uplc, cbor2, pycardano; print('[lenfi-ci] python deps ok')" || echo "[lenfi-ci] python deps missing (proofs may fail)"

if ! command -v aiken >/dev/null 2>&1; then
  mkdir -p /tmp/opencode/aiken
  curl -sL -o /tmp/opencode/aiken.tgz \
    https://github.com/aiken-lang/aiken/releases/download/v1.1.24/aiken-x86_64-unknown-linux-musl.tar.gz
  tar xzf /tmp/opencode/aiken.tgz -C /tmp/opencode/aiken --strip-components=1
  export AIKEN_BIN=/tmp/opencode/aiken/aiken
else
  export AIKEN_BIN="$(command -v aiken)"
fi
echo "[lenfi-ci] aiken $($AIKEN_BIN --version 2>/dev/null || echo MISSING)"

echo "[lenfi-ci] === refresh live state (Koios, keyless) ==="
python3 analysis/fetch_live.py        || echo "[lenfi-ci] fetch_live failed; using committed snapshot"
python3 analysis/enrich_live.py       || echo "[lenfi-ci] enrich failed"
python3 analysis/decode_datums2.py    || echo "[lenfi-ci] datum decode failed"
python3 analysis/valuation2.py        || echo "[lenfi-ci] valuation failed"
python3 analysis/v2/v2_stats.py       || echo "[lenfi-ci] v2 stats failed"

echo "[lenfi-ci] === CEK proofs: claim gates (aiken) ==="
python3 analysis/cek_proofs_aiken.py    || echo "[lenfi-ci] gate proofs had failures"
echo "[lenfi-ci] === CEK proofs: debt_request window semantics ==="
python3 analysis/cek_window_proofs.py   || echo "[lenfi-ci] window proofs had failures"

echo "[lenfi-ci] === summary ==="
python3 analysis/make_summary.py || echo "[lenfi-ci] summary failed"
ls -la ci-out
echo "[lenfi-ci] done $(date -u +%FT%TZ)"
