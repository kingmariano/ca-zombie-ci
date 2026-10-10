#!/usr/bin/env bash
# CI heavy job for C2-55 non-evm-cluster (Cardano/Minswap V1 CEK proof).
# Downloads the aiken UPLC interpreter and evaluates the DEPLOYED Minswap V1
# pool validator on three reconstructed ScriptContexts (legit / no-owner /
# datum-hijack redirect). Results -> ci-out/. Read-only, no secrets, no network
# beyond the aiken release download.
set -euo pipefail
cd "$(dirname "$0")/.."     # folder root

mkdir -p ci-out
AIKEN_DIR=/tmp/aiken-ci
if [ ! -x "$AIKEN_DIR/aiken" ]; then
  mkdir -p "$AIKEN_DIR"
  curl -sL -m 120 "https://github.com/aiken-lang/aiken/releases/download/v1.1.24/aiken-x86_64-unknown-linux-musl.tar.gz" -o /tmp/aiken.tar.gz
  tar xzf /tmp/aiken.tar.gz -C /tmp
  cp /tmp/aiken-x86_64-unknown-linux-musl/aiken "$AIKEN_DIR/aiken"
fi
chmod +x "$AIKEN_DIR/aiken"
export AIKEN_BIN="$AIKEN_DIR/aiken"
"$AIKEN_BIN" --version
python3 ci/cek_cases.py
echo "== ci-out =="
ls -la ci-out/
