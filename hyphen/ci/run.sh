#!/usr/bin/env bash
# Hyphen live-state snapshot for CI. Read-only. Uses CI-provided RPC env vars when
# present (never printed), falls back to keyless public RPCs. No secrets written.
set -u
cd "$(dirname "$0")/.."
OUT=ci-out
mkdir -p "$OUT"

rpc_for() { # $1 = env var name, $2 = public fallback
  local v="${!1:-}"
  if [ -n "$v" ]; then echo "$v"; else echo "$2"; fi
}

ETH=$(rpc_for FORK_RPC_URL "$(rpc_for RPC_URL https://ethereum-rpc.publicnode.com)")
POL=$(rpc_for POLYGON_RPC_URL https://polygon-bor-rpc.publicnode.com)
BSC=$(rpc_for BSC_RPC_URL https://bsc-rpc.publicnode.com)
OP=$(rpc_for OP_RPC_URL https://optimism-rpc.publicnode.com)
ARB=$(rpc_for ARB_RPC_URL https://arbitrum-one-rpc.publicnode.com)
AVAX=https://api.avax.network/ext/bc/C/rpc

snapshot() { # name rpc pool providers token...
  local name="$1" rpc="$2" pool="$3" prov="$4"; shift 4
  {
    echo "### $name"
    echo "block=$(cast block-number --rpc-url "$rpc")"
    echo "pool=$pool providers=$prov"
    echo "pool_owner=$(cast call "$pool" 'owner()(address)' --rpc-url "$rpc")"
    echo "pool_paused=$(cast call "$pool" 'paused()(bool)' --rpc-url "$rpc")"
    echo "prov_owner=$(cast call "$prov" 'owner()(address)' --rpc-url "$rpc")"
    echo "prov_paused=$(cast call "$prov" 'paused()(bool)' --rpc-url "$rpc")"
    echo "pool_native_wei=$(cast balance "$pool" --rpc-url "$rpc")"
    echo "prov_native_wei=$(cast balance "$prov" --rpc-url "$rpc")"
    for t in "$@"; do
      echo "token $t pool_balance=$(cast call "$t" 'balanceOf(address)(uint256)' "$pool" --rpc-url "$rpc" 2>/dev/null | awk '{print $1}') totalReserve=$(cast call "$prov" 'totalReserve(address)(uint256)' "$t" --rpc-url "$rpc" 2>/dev/null | awk '{print $1}')"
    done
  } >> "$OUT/live-state.txt"
}

: > "$OUT/live-state.txt"
snapshot ethereum "$ETH" 0x2a5c2568b10A0E826BfA892Cf21BA7218310180b 0xebaB24F13de55789eC1F3fFe99A285754e15F7b9 \
  0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0xdAC17F958D2ee523a2206206994597C13D831ec7 0xF17e65822b568B3903685a7c9F496CF7656C2C2 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0
snapshot polygon "$POL" 0x2a5c2568b10A0E826BfA892Cf21BA7218310180b 0xebaB24F13de55789eC1F3fFe99A285754e15F7b9 \
  0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
snapshot bsc "$BSC" 0x94d3e62151b12A12a4976F60eDC18459538fAf08 0x279ac60785A2FCb85550EB243B9A42A543171Cc7 \
  0x55d398326f99059fF775485246999027B3197955 0x2170Ed0880ac9A755fd29B2688956BD959F933F8 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
snapshot optimism "$OP" 0x856Cb5C3cBBe9e2e21293A644Aa1F9363CEE11E8 0xb4778f5aefeb4605ED96e893417271d4a55e32Ee \
  0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
snapshot arbitrum "$ARB" 0x856Cb5C3cBBe9e2e21293A644Aa1F9363CEE11E8 0xb4778f5aefeb4605ED96e893417271d4a55e32Ee \
  0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9 0xa68EC98D7ca870cF1dD0b00ebbb7c4bF60a8e74d
snapshot avalanche "$AVAX" 0x2a5c2568b10A0E826BfA892Cf21BA7218310180b 0xebaB24F13de55789eC1F3fFe99A285754e15F7b9 \
  0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664 0xc7198437980c041c805A1EdcbA50c1Ce5db95118

echo "wrote $OUT/live-state.txt"
cat "$OUT/live-state.txt"
