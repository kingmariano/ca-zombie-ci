#!/usr/bin/env bash
# LFGSwap EthereumPoW heavy job (GitHub Actions). Read-only; keyless public RPC only.
# Starts a local anvil fork (cached + retrying upstream) that the foundry tests prefer,
# runs the full-factory scan, then a cooldown so the RPC rate limiter is quiet for the
# workflow's forge-test step.
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[lfgswap] pwd=$(pwd)"
python3 --version
mkdir -p ci-out
export ETHW_RPC_URL="${ETHW_RPC_URL:-https://mainnet.ethereumpow.org}"

# --- local anvil fork (persists for the workflow's forge test step) ---
if ! curl -s -m 3 -X POST -H 'Content-Type: application/json' \
      --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' http://127.0.0.1:8545 2>/dev/null | grep -q 0x2711; then
  echo "[lfgswap] starting local anvil fork of ETHW on 127.0.0.1:8545"
  setsid nohup anvil \
    --fork-url "$ETHW_RPC_URL" \
    --fork-retry-backoff 8 \
    --host 127.0.0.1 --port 8545 \
    --no-request-size-limit \
    > ci-out/anvil.log 2>&1 &
  for i in $(seq 1 30); do
    sleep 2
    if curl -s -m 3 -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' http://127.0.0.1:8545 2>/dev/null | grep -q 0x2711; then
      echo "[lfgswap] anvil fork ready after ~$((i*2))s"
      break
    fi
  done
fi
curl -s -m 5 -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' http://127.0.0.1:8545 || echo "[lfgswap] WARN: local anvil not reachable"

# --- full-factory scan (paced to stay friendly to the public RPC) ---
echo "[lfgswap] scanning ETHW via public RPC (read-only)"
if [ -s ci-out/scan_summary.json ]; then
  echo "[lfgswap] ci-out/scan_summary.json present - skipping scan (keep artifact)"
else
  python3 ci/full_scan.py 2>&1 | tee ci-out/scan.log
fi
echo "[lfgswap] scan exit=$?"

# --- run the PoC suite here too (log evidence), then cool down before the workflow's step ---
if [ -f poc/foundry.toml ]; then
  echo "[lfgswap] forge test (via local anvil fork)"
  ( cd poc && forge test -vvv 2>&1 | tee ../ci-out/forge-test.log )
  echo "[lfgswap] forge test exit=$?"
fi

echo "[lfgswap] cooldown 90s before workflow forge step"
sleep 90
echo "[lfgswap] done"
ls -la ci-out/
