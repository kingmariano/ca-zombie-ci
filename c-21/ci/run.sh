#!/usr/bin/env bash
# C-21 heavy job — independent ERC-20 approval re-enumeration for the four
# vulnerable Ekubo HuffRouter deployments (Ethereum + Arbitrum), then live
# allowance/balance reads and USD pricing for anything still extractable.
#
# Also probes archive RPCs for the 2026-05-05 historical control forks and
# exports them (ARCHIVE_RPC_URL / ARB_ARCHIVE_RPC_URL) for the Foundry step.
#
# Read-only: only eth_getLogs / eth_call / eth_getBalance. Outputs land in
# ci-out/ (artifact).
set -uo pipefail
cd "$(dirname "$0")/.."

mkdir -p ci-out
echo "[c-21] start $(date -u +%FT%TZ)"

probe_archive() {
  local url="$1" block="$2"
  [ -z "$url" ] && return 1
  local r
  r=$(curl -s -m 20 -X POST -H 'Content-Type: application/json' \
        --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBalance\",\"params\":[\"0x0000000000000000000000000000000000000000\",\"$block\"]}" \
        "$url" 2>/dev/null)
  case "$r" in *result*) return 0 ;; esac
  return 1
}

if [ -n "${GITHUB_ENV:-}" ]; then
  # Ethereum archive (2026-05-05 control block 25,030,408 = 0x17def08)
  i=0
  for u in "https://rpc.ankr.com/eth/${ANKR_API_KEY:-}" \
           "${NODEREAL_ETH_RPC_URL:-}" \
           "https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY:-}" \
           "${RPC_URL:-}" \
           "https://eth.drpc.org" \
           "https://rpc.payload.de"; do
    i=$((i+1))
    if probe_archive "$u" 0x17def08; then
      echo "ARCHIVE_RPC_URL=$u" >> "$GITHUB_ENV"
      echo "[c-21] archive ETH RPC found (candidate $i)"
      break
    else
      echo "[c-21] archive ETH candidate $i unavailable"
    fi
  done
  # Arbitrum archive (2026-05-05 control block 459,854,115 = 0x1b68d123)
  i=0
  for u in "https://rpc.ankr.com/arbitrum/${ANKR_API_KEY:-}" \
           "https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY:-}" \
           "https://1rpc.io/arb" \
           "${ARB_RPC_URL:-}" \
           "https://arb1.arbitrum.io/rpc"; do
    i=$((i+1))
    if probe_archive "$u" 0x1b68d123; then
      echo "ARB_ARCHIVE_RPC_URL=$u" >> "$GITHUB_ENV"
      echo "[c-21] archive ARB RPC found (candidate $i)"
      break
    else
      echo "[c-21] archive ARB candidate $i unavailable"
    fi
  done
fi

python3 analysis/scan_approvals.py --out ci-out --chain all
rc=$?
echo "[c-21] scan exit code: $rc"
ls -la ci-out
exit $rc
