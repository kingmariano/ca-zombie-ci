#!/usr/bin/env bash
# Live (non-fork) state dump for Powercity Flex Protocol — read-only, keyless public RPC.
# Writes ci-out/live-state.json (+ a readable .txt). Never fails the job on RPC hiccups.
set -uo pipefail

RPC="${PULSE_RPC:-https://pulsechain-rpc.publicnode.com}"
OUT="ci-out"
mkdir -p "$OUT"

call() { # call <to> <sig> [args...]
  local to="$1"; shift
  cast call "$to" "$@" --rpc-url "$RPC" 2>/dev/null || echo "0x0"
}

BN=$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo 0)
HEX=0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39
HEXDC=0x1FE0319440A672526916C232EAEe4808254Bdb00
TM=0xC2D0720721d48cE85e20Dc9E01B8449D7eDd14CE
SP=0x271F576fD6DE465231320a0F9997ACb0C8b97e07
AP=0xE4FD443B26fA809A48EB658eA7edeB31E95c2144
PF=0x5f2529BC80bB9C0Bd7C417EA78CE2Cd6114B112C
PAIR1=0xf1f4ee610b2babb05c635f726ef8b0c568c8dc65
PAIR2=0x19bb45a7270177e303dee6eaa6f5ad700812ba98
PAIR3=0xe56043671df55de5cdf8459710433c10324de0ae
PAIR4=0x6753560538eca67617a9ce605178f788be7e524e

PRICE=$(call $PF "fetchPrice()(uint256)" | awk '{print $1}')
GOOD=$(call $PF "lastGoodPrice()(uint256)" | awk '{print $1}')
TROVES=$(call $TM "getTroveOwnersCount()(uint256)" | awk '{print $1}')
TCR=$(call $TM "getTCR(uint256)(uint256)" "${PRICE:-0}" | awk '{print $1}')
APHEX=$(call $HEX "balanceOf(address)(uint256)" $AP | awk '{print $1}')
SPD=$(call $SP "getTotalLUSDDeposits()(uint256)" | awk '{print $1}')
SUP=$(call $HEXDC "totalSupply()(uint256)" | awk '{print $1}')
R1=$(call $PAIR1 "getReserves()(uint112,uint112,uint32)" | tr '\n' ' ')
R2=$(call $PAIR2 "getReserves()(uint112,uint112,uint32)" | tr '\n' ' ')
R3=$(call $PAIR3 "getReserves()(uint112,uint112,uint32)" | tr '\n' ' ')
R4=$(call $PAIR4 "getReserves()(uint112,uint112,uint32)" | tr '\n' ' ')

cat > "$OUT/live-state.json" <<EOF
{
  "chain": "pulsechain",
  "chain_id": 369,
  "rpc": "keyless-public",
  "block": ${BN:-0},
  "oracle_fetchPrice_1e8": "${PRICE:-}",
  "oracle_lastGoodPrice_1e8": "${GOOD:-}",
  "trove_count": "${TROVES:-}",
  "system_TCR_1e8": "${TCR:-}",
  "activePool_HEX_raw": "${APHEX:-}",
  "stabilityPool_HEXDC_raw": "${SPD:-}",
  "HEXDC_totalSupply_raw": "${SUP:-}",
  "pair_HEX_WPLS_V1_0xf1f4ee": "${R1:-}",
  "pair_HEX_WPLS_V2_0x19bb45a7": "${R2:-}",
  "pair_WPLS_DAI_0xe56043": "${R3:-}",
  "pair_USDC_WPLS_0x675356": "${R4:-}",
  "note": "raw integer values as returned by the contracts; HEX/HEXDC have 8 decimals"
}
EOF

{
  echo "Powercity Flex Protocol — live state @ block ${BN:-0}"
  echo "oracle fetchPrice : ${PRICE:-} (1e8 scale, USD per HEX)"
  echo "trove count       : ${TROVES:-}"
  echo "system TCR        : ${TCR:-} (1e8)"
  echo "ActivePool HEX    : ${APHEX:-}"
  echo "SP HEXDC deposits : ${SPD:-}"
} > "$OUT/live-state.txt"

echo "live-state dump written"
exit 0
