#!/usr/bin/env bash
# C2-01 OFTSand — CI snapshot job (read-only mainnet; no transactions).
# Writes a reproducible latest-block state dump to ci-out/.
set -uo pipefail
OUT=ci-out
mkdir -p "$OUT"
OFT=0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF
EP=0x1a44076050125825900e736c501f859c50fE728c
SAND=0x3845badAde8e6dFF049820680d1F14bD3903a5d0
ATT=0x1111111111111111111111111111111111111111

echo "date=$(date -u +%FT%TZ)" > "$OUT/live-state.txt"

for pair in \
  "eth|${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}" \
  "base|${BASE_RPC_URL:-https://base-rpc.publicnode.com}" \
  "bsc|${BSC_RPC_URL:-https://bsc-rpc.publicnode.com}"; do
  name=${pair%%|*}; rpc=${pair##*|}
  {
    echo "## chain=$name"
    echo "block=$(cast block-number --rpc-url "$rpc" 2>&1)"
    echo "owner=$(cast call $OFT 'owner()(address)' --rpc-url "$rpc" 2>&1)"
    echo "getAdmin=$(cast call $OFT 'getAdmin()(address)' --rpc-url "$rpc" 2>&1)"
    echo "getEnabled=$(cast call $OFT 'getEnabled()(bool)' --rpc-url "$rpc" 2>&1)"
    echo "endpoint=$(cast call $OFT 'endpoint()(address)' --rpc-url "$rpc" 2>&1)"
    echo "token=$(cast call $OFT 'token()(address)' --rpc-url "$rpc" 2>&1)"
    for eid in 30101 30102 30184; do
      echo "peers($eid)=$(cast call $OFT 'peers(uint32)(bytes32)' $eid --rpc-url "$rpc" 2>&1)"
    done
    echo "Endpoint.delegates(OFT)=$(cast call $EP 'delegates(address)(address)' $OFT --rpc-url "$rpc" 2>&1)"
    echo "OFT.native=$(cast balance $OFT --rpc-url "$rpc" 2>&1)"
    echo "OFT.balanceOf(self)=$(cast call $OFT 'balanceOf(address)(uint256)' $OFT --rpc-url "$rpc" 2>&1)"
    echo "OFT.totalSupply=$(cast call $OFT 'totalSupply()(uint256)' --rpc-url "$rpc" 2>&1)"
    # live approveAndCall -> Endpoint.setDelegate primitive (eth_call only, no state change)
    INNER=$(cast calldata "setDelegate(address)" $ATT 2>/dev/null)
    INNER_PAD=$(cast concat-hex "$INNER" 0x0000000000000000000000000000000000000000000000000000000000000000 2>/dev/null)
    OUTER=$(cast calldata "approveAndCall(address,uint256,bytes)" $EP 0 "$INNER_PAD" 2>/dev/null)
    echo "approveAndCall->setDelegate eth_call: $(cast call $OFT "$OUTER" --from $ATT --rpc-url "$rpc" 2>&1 | head -1)"
  } >> "$OUT/live-state.txt" 2>&1
done

# real SAND locked in the Ethereum adapter + canonical supply
{
  echo "## eth adapter SAND"
  echo "SAND.balanceOf(adapter)=$(cast call $SAND 'balanceOf(address)(uint256)' $OFT --rpc-url "${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}" 2>&1)"
  echo "SAND.totalSupply=$(cast call $SAND 'totalSupply()(uint256)' --rpc-url "${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}" 2>&1)"
} >> "$OUT/live-state.txt" 2>&1

cat "$OUT/live-state.txt"
