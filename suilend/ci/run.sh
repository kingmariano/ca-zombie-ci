#!/usr/bin/env bash
# C2-11 Suilend CI heavy job — read-only. Writes artifacts to ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "== C2-11 Suilend CI job =="
date -u
python3 --version; node --version || true

# 1) heavy pulls: version chain, module hashes, market state, dynamic fields, all markets, events+differential
python3 ci/fetch_all.py 2>&1 | tee ci-out/fetch_all.log

# 2) obligation sample (stored health; bounded)
SCAN_N=1000 python3 ci/scan_obligations.py 2>&1 | tee ci-out/scan.log || true

# 3) live devInspect probes (callability, decisive-path tests, freshness cadence)
mkdir -p ci/js
if [ -f ci/js/package.json ]; then
  (cd ci/js && npm install --no-audit --no-fund --silent 2>&1 | tail -2)
  (cd ci/js && node probe.mjs 2>&1 | tee ../ci-out/probe.log)
fi

# 4) optional: fetch Sui CLI + disassemble key modules for the record (best effort, bounded)
if [ ! -x /tmp/sui-cli/sui ]; then
  mkdir -p /tmp/sui-cli
  if curl -sL --max-time 420 -o /tmp/sui-cli/sui.tgz \
      "https://github.com/MystenLabs/sui/releases/download/mainnet-v1.81.1/sui-mainnet-v1.81.1-ubuntu-x86_64.tgz"; then
    tar xzf /tmp/sui-cli/sui.tgz -C /tmp/sui-cli sui 2>/dev/null || true
  fi
fi
if [ -x /tmp/sui-cli/sui ]; then
  mkdir -p ci-out/disasm
  for v in 10 18 20 22 23 24 25; do
    for m in lending_market obligation reserve oracles reserve_config; do
      /tmp/sui-cli/sui move disassemble ci-out/modules/v$v/$m.mv > ci-out/disasm/v$v-$m.dis 2>/dev/null || true
    done
  done
  echo "disassembly done: $(ls ci-out/disasm | wc -l) files"
else
  echo "sui CLI unavailable in CI; disassembly artifacts remain in analysis/disasm (local)"
fi

echo "== artifacts =="
find ci-out -maxdepth 2 -type f | sort | head -40
echo "== done =="
