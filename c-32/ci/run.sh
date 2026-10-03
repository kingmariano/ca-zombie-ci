#!/usr/bin/env bash
# C-32 heavy scan job (runs on GitHub Actions). Read-only RPC + indexer reads.
# Results land in c-32/ci-out/ and are uploaded as CI artifacts.
set -uo pipefail
cd "$(dirname "$0")/.."          # c-32/
mkdir -p ci-out
export SCAN_OUTDIR="$PWD/ci-out"

probe() { # probe <url> <fallback> -> echoes a working url (eth_chainId + latest block)
  local u="${1:-}" fb="$2"
  if [ -n "$u" ]; then
    if curl -s -m 12 -X POST -H 'Content-Type: application/json' \
         --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest",false]}' "$u" 2>/dev/null | grep -q '"result"'; then
      echo "$u"; return
    fi
  fi
  echo "$fb"
}

probe_eth() { # stronger probe: eth_call getAllMarkets() on the Ethereum comptroller
  local u="${1:-}" fb="$2"
  if [ -n "$u" ]; then
    if curl -s -m 15 -X POST -H 'Content-Type: application/json' \
         --data '{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0xdec80bB934397575594E91970b37baf65f5b21bE","data":"0xb0772d0b"},"latest"]}' "$u" 2>/dev/null | grep -q '"result"'; then
      echo "$u"; return
    fi
  fi
  echo "$fb"
}

export RPC_URL=$(probe_eth "${RPC_URL:-}" "https://ethereum-rpc.publicnode.com")
export BASE_RPC_URL=$(probe "${BASE_RPC_URL:-}" "https://base-rpc.publicnode.com")
export OP_RPC_URL=$(probe "${OP_RPC_URL:-}" "https://optimism-rpc.publicnode.com")
export MOONRIVER_RPC_URL=$(probe "${MOONRIVER_RPC_URL:-}" "https://moonriver.api.onfinality.io/public")
export MOONBEAM_RPC_URL=$(probe "${MOONBEAM_RPC_URL:-}" "https://moonbeam.api.onfinality.io/public")
echo "rpcs: eth=$RPC_URL base=$BASE_RPC_URL op=$OP_RPC_URL movr=$MOONRIVER_RPC_URL glmr=$MOONBEAM_RPC_URL"

# make the probed endpoints available to later workflow steps (forge tests)
if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "C32_ETH_RPC=$RPC_URL"
    echo "C32_BASE_RPC=$BASE_RPC_URL"
    echo "C32_OP_RPC=$OP_RPC_URL"
    echo "C32_MOONRIVER_RPC=$MOONRIVER_RPC_URL"
    echo "C32_MOONBEAM_RPC=$MOONBEAM_RPC_URL"
  } >> "$GITHUB_ENV"
fi

echo "== c-32 scan start $(date -u +%FT%TZ)"

# live chains: full market/oracle/cap snapshot
python3 analysis/scan.py base optimism ethereum 2>&1 | tee ci-out/scan_live.txt || true

# frozen Polkadot chains
python3 analysis/scan.py moonbeam moonriver 2>&1 | tee ci-out/scan_frozen.txt || true

# Full borrower enumeration via GoldRush (may be unavailable in CI; tolerate failure),
# then CI-fresh RPC verification of the committed enumeration artifacts.
python3 analysis/enumerate_positions.py moonbeam 2>&1 | tee ci-out/moonbeam_enum.txt || true
if [ -f ci-out/moonbeam_positions.json ]; then
  python3 analysis/fix_balances.py moonbeam 2>&1 | tee -a ci-out/moonbeam_enum.txt || true
  python3 analysis/quantify.py moonbeam ci-out/moonbeam_positions_fixed.json ci-out/moonbeam.json \
      2>&1 | tee ci-out/moonbeam_liquidation_estimate.txt || true
else
  echo "[skip] GoldRush enumeration unavailable; using committed artifacts" | tee ci-out/moonbeam_enum.txt
fi
python3 analysis/verify_accounts.py 2>&1 | tee ci-out/verify_accounts.txt || true
cp analysis/committed/*.json ci-out/ 2>/dev/null || true

echo "== c-32 scan done; outputs:"
ls -la ci-out
