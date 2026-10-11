#!/usr/bin/env bash
# CI evidence job (muscadine): re-read live Base state at CI time into ci-out/state-ci.txt
# Read-only. Uses the CI-provided BASE_RPC_URL (never printed).
set -uo pipefail
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
mkdir -p ci-out
OUT=ci-out/state-ci.txt
: > "$OUT"
BLK=$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo "ERR")
echo "block=$BLK" >> "$OUT"
VAULTS="usdc_v1:0xf7e26Fa48A568b8b0038e104DfD8ABdf0f99074F cbbtc_v1:0xAeCc8113a7bD0CFAF7000EA7A31afFD4691ff3E9 weth_v1:0x21e0d366272798da3A977FEBA699FCB91959d120 usdc_prime:0x89712980cb434ef5ae4ab29349419eb976b0b496 weth_prime:0xd6dcad2f7da91fbb27bda471540d9770c97a5a43 cbbtc_prime:0x99dcd0d75822ba398f13b2a8852b07c7e137ec70 usdc_frontier:0x314fD07319ef645bA7D548915CCd91F4788A1839"
for pair in $VAULTS; do
  n="${pair%%:*}"; a="${pair##*:}"
  ta=$(cast call "$a" "totalAssets()(uint256)" --rpc-url "$RPC" 2>/dev/null || echo ERR)
  ts=$(cast call "$a" "totalSupply()(uint256)" --rpc-url "$RPC" 2>/dev/null || echo ERR)
  echo "$n addr=$a totalAssets=$ta totalSupply=$ts" >> "$OUT"
done
GATE=0xb7f2598ac79a3c6406dddb81edcc60ea72a134b9
echo "gate.roleSetter=$(cast call $GATE 'roleSetter()(address)' --rpc-url "$RPC" 2>/dev/null || echo ERR)" >> "$OUT"
echo "gate.isWhitelisted(0xdead)=$(cast call $GATE 'isWhitelisted(address)(bool)' 0x000000000000000000000000000000000000dEaD --rpc-url "$RPC" 2>/dev/null || echo ERR)" >> "$OUT"
echo "gate.isWhitelisted(holder9e28)=$(cast call $GATE 'isWhitelisted(address)(bool)' 0x9e284c8Aa44132C911140950D93e44f027199CC5 --rpc-url "$RPC" 2>/dev/null || echo ERR)" >> "$OUT"
P=0x89712980cb434ef5ae4ab29349419eb976b0b496
echo "usdc_prime.executableAt(setSendAssetsGate(0))=$(cast call $P 'executableAt(bytes)(uint256)' 0x871c979c0000000000000000000000000000000000000000000000000000000000000000 --rpc-url "$RPC" 2>/dev/null || echo ERR)" >> "$OUT"
echo "usdc_prime.sendAssetsGate=$(cast call $P 'sendAssetsGate()(address)' --rpc-url "$RPC" 2>/dev/null || echo ERR)" >> "$OUT"
echo "usdc_prime.forceDeallocatePenalty(adapter)=$(cast call $P 'forceDeallocatePenalty(address)(uint256)' 0xC2ec18c8049ab354756304Fb8F9e45e084097972 --rpc-url "$RPC" 2>/dev/null || echo ERR)" >> "$OUT"
cat "$OUT"
