#!/usr/bin/env bash
# H-06 Polynomial Trade — CI state-dump job (read-only).
# Writes a fresh live-state snapshot to ci-out/ for artifact upload.
set -uo pipefail
mkdir -p ci-out
export PATH="$PATH:$HOME/.foundry/bin"

OP="${OP_RPC_URL:-https://mainnet.optimism.io}"
ETH="${FORK_RPC_URL:-https://ethereum-rpc.publicnode.com}"

OUT=ci-out/state.txt
{
  echo "generated_utc=$(date -u +%FT%TZ)"
  echo "op_block=$(cast block-number --rpc-url "$OP" 2>/dev/null)"
  echo "eth_block=$(cast block-number --rpc-url "$ETH" 2>/dev/null)"
  echo
  echo "== Optimism vault balances =="
  for t in "sETH:0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49" "sBTC:0x298B9B95708152ff6968aafd889c6586e9169f1D" "sUSD:0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9"; do
    n=${t%%:*}; a=${t#*:}
    for v in "V2_call:0x2D46292cbB3C601c6e2c74C32df3A4FCe99b59C7" "V2_put:0xb28Df1b71a5b3a638eCeDf484E0545465a45d2Ec" "V2_quote:0xB7b4270cFD938F4F1C111ac819e7365E8Ce0300a" "V2_gamma:0x965e460bF5cb38BadA79fB2293c6304C799D0b1c" "V1_seth_call:0x331Cf6E3E59B18a8bc776A0F652aF9E2b42781c5" "V1_seth_put:0xFa923AA6b4DF5bea456DF37FA044B37F0FDDCdb4" "V1_sbtc_call:0xea48dD74BA1Ff41B705ba5Cf993B2D558e12D860" "V1_sbtc_put:0x23CB080dd0ECCdacbEB0BEb2a769215280B5087D"; do
      vn=${v%%:*}; va=${v#*:}
      echo "$vn $n balanceOf=$(cast call "$a" "balanceOf(address)(uint256)" "$va" --rpc-url "$OP" 2>/dev/null)"
    done
  done
  echo
  echo "== V2 vault accounting =="
  for v in "V2_call:0x2D46292cbB3C601c6e2c74C32df3A4FCe99b59C7" "V2_put:0xb28Df1b71a5b3a638eCeDf484E0545465a45d2Ec" "V2_quote:0xB7b4270cFD938F4F1C111ac819e7365E8Ce0300a" "V2_gamma:0x965e460bF5cb38BadA79fB2293c6304C799D0b1c"; do
    vn=${v%%:*}; va=${v#*:}
    echo "$vn totalFunds=$(cast call "$va" "totalFunds()(uint256)" --rpc-url "$OP" 2>/dev/null) paused=$(cast call "$va" "paused()(bool)" --rpc-url "$OP" 2>/dev/null) depositsPaused=$(cast call "$va" "depositsPaused()(bool)" --rpc-url "$OP" 2>/dev/null) tokenPrice=$(cast call "$va" "getTokenPrice()(uint256)" --rpc-url "$OP" 2>/dev/null)"
  done
  echo
  echo "== V1 vault status =="
  for v in "V1_seth_call:0x331Cf6E3E59B18a8bc776A0F652aF9E2b42781c5" "V1_sbtc_call:0xea48dD74BA1Ff41B705ba5Cf993B2D558e12D860"; do
    vn=${v%%:*}; va=${v#*:}
    echo "$vn paused=$(cast call "$va" "paused()(bool)" --rpc-url "$OP" 2>/dev/null) currentRound=$(cast call "$va" "currentRound()(uint256)" --rpc-url "$OP" 2>/dev/null) totalFunds=$(cast call "$va" "totalFunds()(uint256)" --rpc-url "$OP" 2>/dev/null)"
  done
  echo
  echo "== Zap =="
  echo "zap_eth=$(cast balance 0xB162f01C5BDA7a68292410aaA059E7Ce28D77c82 --rpc-url "$OP" 2>/dev/null)"
  echo "zap_usdc=$(cast call 0x7F5c764cBc14f9669B88837ca1490cCa17c31607 "balanceOf(address)(uint256)" 0xB162f01C5BDA7a68292410aaA059E7Ce28D77c82 --rpc-url "$OP" 2>/dev/null)"
  echo "registry_cast_impl=$(cast call 0x14D582327dF7A9885c299173dAd6Ae855a3E046d "getSigImplementation(bytes4)(address)" 0xe0e90acf --rpc-url "$OP" 2>/dev/null)"
  echo
  echo "== Ethereum bridge =="
  echo "bridge_eth=$(cast balance 0x034cbb620d1e0e4C2E29845229bEAc57083b04eC --rpc-url "$ETH" 2>/dev/null)"
  echo "bridge_weth=$(cast call 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 "balanceOf(address)(uint256)" 0x034cbb620d1e0e4C2E29845229bEAc57083b04eC --rpc-url "$ETH" 2>/dev/null)"
} > "$OUT" 2>&1

echo "wrote $OUT"
cat "$OUT"
