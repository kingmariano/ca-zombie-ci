#!/usr/bin/env bash
# CI entry point for the Jet v1 (Solana) frozen-oracle PoC.
#
# The workflow invokes this from the finding folder (cwd = jet-v1/).
# It builds and runs the LiteSVM PoC in poc-svm/ and leaves results in ci-out/.
# Everything is local: all accounts were cloned into analysis/accounts.json and
# the deployed program ELF into analysis/jet_program.so. No RPC, no mainnet tx.
set -euo pipefail

echo "[jet-v1] pwd=$(pwd)"
mkdir -p ci-out

# ---- Rust toolchain (litesvm 0.18 needs rust >= 1.97.1) ----
if ! command -v cargo >/dev/null 2>&1; then
  echo "[jet-v1] installing rust (rustup, stable, minimal)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
fi
if command -v rustup >/dev/null 2>&1; then
  rustup toolchain install stable --profile minimal --no-self-update || true
  rustup default stable || true
fi
echo "[jet-v1] toolchain: $(rustc --version 2>/dev/null || echo 'rustc?') / $(cargo --version 2>/dev/null || echo 'cargo?')"

# Build artifacts go to /tmp (see poc-svm/.cargo/config.toml) so nothing large
# lands inside the synced folder.
cd poc-svm

echo "[jet-v1] building (release) ..."
cargo build --release

echo "[jet-v1] running PoC ..."
set +e
JET_OUT_DIR="$PWD/../ci-out" cargo run --release 2>&1 | tee ../ci-out/poc_stdout.txt
RC=${PIPESTATUS[0]}
set -e

echo "[jet-v1] cargo exit code: $RC"
echo "[jet-v1] ---- poc_results.json ----"
cat ../ci-out/poc_results.json 2>/dev/null || echo "(no results file)"
echo "[jet-v1] ---- end results ----"

exit "$RC"
