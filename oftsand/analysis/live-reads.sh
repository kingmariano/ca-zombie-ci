#!/usr/bin/env bash
# Live read-only state dump for C2-01 OFTSand. No transactions, no signing.
set -uo pipefail
OFT=0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF
EP=0x1a44076050125825900e736c501f859c50fe728c
SAND=0x3845badAde8e6dFF049820680d1F14bD3903a5d0
OUTDIR=/home/heisenberg/CA/oftsand/analysis

readchain() {
  local name=$1 rpc=$2
  local out=$OUTDIR/live-state-$name.txt
  local blk
  blk=$(cast block-number --rpc-url "$rpc")
  {
    echo "# chain=$name rpc=$rpc block=$blk ts=$(date -u +%FT%TZ)"
    echo "## OFT basic"
    for sig in "name()(string)" "symbol()(string)" "decimals()(uint8)" "totalSupply()(uint256)" "owner()(address)" "getAdmin()(address)" "getEnabled()(bool)" "getTrustedForwarder()(address)" "endpoint()(address)" "token()(address)" "sharedDecimals()(uint8)" "decimalConversionRate()(uint256)" "approvalRequired()(bool)" "nextNonce(uint32,bytes32)(uint64)"; do
      printf "%s = %s\n" "$sig" "$(cast call $OFT "$sig" --rpc-url "$rpc" 2>&1 | head -1)"
    done
    echo "balanceOf(OFT) = $(cast call $OFT "balanceOf(address)(uint256)" $OFT --rpc-url "$rpc" 2>&1 | head -1)"
    echo "native_balance = $(cast balance $OFT --rpc-url "$rpc" 2>&1 | head -1)"
    echo "## super operator / admin checks"
    echo "isSuperOperator(OFT) = $(cast call $OFT "isSuperOperator(address)(bool)" $OFT --rpc-url "$rpc" 2>&1 | head -1)"
    echo "## peers (LayerZero eids of interest)"
    for eid in 30101 30102 30184 30109 30110 30111 30112 30125 30150 30168 30175 30176 30183 30185 30188 30216 30332 30362 30365 30402 30406 30420 30433 30447 30452 30543 30567 30605 30624 30677 30691 30701 30712 30740 30745 30757 30810 30814 30832 30851 30907 30921 30944 30962 30980 30987 30991 31002 31011 31023 31040 31062 31073 31088 31094 31102 31115 31126 31140 31158 31173 31190 31202 31216 31238 31252 31267 31282 31301 31317 31335 31352 31368 31384 31400 31416 31432 31448 31464 31480 31496 31512 31528 31544 31560 31576 31592 31608 31624 31640 31656 31672 31688 31704 31720 31736 31752 31768 31784 31800; do
      v=$(cast call $OFT "peers(uint32)(bytes32)" $eid --rpc-url "$rpc" 2>/dev/null | head -1)
      [ -n "$v" ] && [ "$v" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && echo "peers($eid) = $v"
    done
    echo "(blank = all listed eids zero)"
    echo "## endpoint state"
    echo "Endpoint.delegates(OFT) = $(cast call $EP "delegates(address)(address)" $OFT --rpc-url "$rpc" 2>&1 | head -1)"
    for eid in 30101 30102 30184; do
      echo "Endpoint.getReceiveLibrary(OFT,$eid) = $(cast call $EP "getReceiveLibrary(address,uint32)(address,bool)" $OFT $eid --rpc-url "$rpc" 2>&1 | tr '\n' ' ')"
      echo "Endpoint.getSendLibrary(OFT,$eid) = $(cast call $EP "getSendLibrary(address,uint32)(address)" $OFT $eid --rpc-url "$rpc" 2>&1 | head -1)"
    done
  } > "$out"
  echo "wrote $out"
}

readchain eth https://ethereum-rpc.publicnode.com &
readchain bsc https://bsc-rpc.publicnode.com &
readchain base https://base-rpc.publicnode.com &
wait

# Ethereum adapter-specific: SAND balance locked
{
  blk=$(cast block-number --rpc-url https://ethereum-rpc.publicnode.com)
  echo "# eth adapter extra block=$blk"
  echo "SAND.balanceOf(adapter) = $(cast call $SAND "balanceOf(address)(uint256)" $OFT --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "SAND.totalSupply = $(cast call $SAND "totalSupply()(uint256)" --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "SAND.balanceOf(endpoint) = $(cast call $SAND "balanceOf(address)(uint256)" $EP --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "SAND.balanceOf(0x0) = $(cast call $SAND "balanceOf(address)(uint256)" 0x0000000000000000000000000000000000000000 --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "adapter.getEnabled = $(cast call $OFT "getEnabled()(bool)" --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "adapter.getAdmin = $(cast call $OFT "getAdmin()(address)" --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "adapter.owner = $(cast call $OFT "owner()(address)" --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "adapter.token = $(cast call $OFT "token()(address)" --rpc-url https://ethereum-rpc.publicnode.com)"
  echo "Endpoint.delegates(adapter) = $(cast call $EP "delegates(address)(address)" $OFT --rpc-url https://ethereum-rpc.publicnode.com)"
} >> $OUTDIR/live-state-eth.txt
echo "wrote eth extra"
