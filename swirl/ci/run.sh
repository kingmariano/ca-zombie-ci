#!/usr/bin/env bash
# Swirl (C2-45) custom CI job — READ-ONLY on-chain proofs on IOTA mainnet.
# - devInspect (dry-run simulation): never signs, never submits, never mutates state.
# - Public keyless RPC only. NO SECRETS in this file.
set -euo pipefail
cd "$(dirname "$0")/.."     # finding folder root (swirl/)
mkdir -p ci-out

echo "[swirl-ci] node: $(node --version 2>/dev/null || echo none)"
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

cd ci
if [ ! -d node_modules ]; then
  npm init -y >/dev/null 2>&1 || true
  npm install @iota/iota-sdk@1.16.0 --no-audit --no-fund
fi

cd ..
echo "[swirl-ci] running dry-run proofs..."
node ci/dryrun.mjs 2>&1 | tee ci-out/dryrun.log
echo "[swirl-ci] done. ci-out:"
ls -la ci-out/
