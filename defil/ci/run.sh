#!/usr/bin/env bash
# DeFIL Phase-2 — CI evidence dump (read-only RPC reads; no secrets printed/stored).
# Writes ci-out/state.json with the live custody state and the gate simulations.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root (defil/)

R="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
mkdir -p ci-out

BLK=$(cast block-number --rpc-url "$R" 2>/dev/null || echo 0)
echo "[defil] rpc ok, latest=$BLK"

c() { # c <addr> <sig> [args...]
  local a="$1"; shift
  cast call "$a" "$@" --rpc-url "$R" 2>/dev/null | head -1
}
cf() { # cf <from> <addr> <sig> [args...]
  local f="$1"; shift; local a="$1"; shift
  cast call "$a" "$@" --from "$f" --rpc-url "$R" 2>&1 | head -1
}

FILST=0x7346aD4c8cD1886Ff6D16072bCeA5DFC0bc24Ca2
DFL=0x09ce2B746C32528B7d864A1e3979Bd97d2f095AB
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
LP=0xa2f6a219a51B4682E34a13a94C160d6c79cDcA35
ST_LP=0x9E08bD9A1E3880902688B32d563046cab74d2f2f
ST_FILST=0x01aABBAd98a7638B7f8d65E7Ec42560F1aFBbF0C
ST_DFL=0xB685Bfdad9DA7093168AB75204BbcaDF0C69c823
FM=0xcd429F23088b3FA4AAbFF61dD5F9E534793f9944
NFT=0xad1ED31e70b569D78D1930537179A940DdA4A9CF
UNIT=0x6B4F20B2259Eebb97945b6EF549a1c44FcA6Cd81
CFILST=0x71DD9CD476c73F7C94a82E3F00a8eD29268602e1
ATT=0x000000000000000000000000000000000000BEEF
TOP=0xF2Ba8F66c4eb4dB715f29e6f90A8744F04A7dfa9
CFHOLD=0x9A26F4D07A28afED9E1A93656C98b1377Edeac32

{
  echo "{"
  echo "  \"chain\": \"ethereum\","
  echo "  \"block\": $BLK,"
  echo "  \"lp_total_supply\": \"$(c $LP 'totalSupply()(uint256)')\","
  echo "  \"lp_in_staking\": \"$(c $LP 'balanceOf(address)(uint256)' $ST_LP)\","
  echo "  \"pair_reserves\": \"$(c $LP 'getReserves()(uint112,uint112,uint32)' | tr '\n' ',' | sed 's/,$//')\","
  echo "  \"pair_usdt_balance\": \"$(c $USDT 'balanceOf(address)(uint256)' $LP)\","
  echo "  \"lp_staking_totalDeposits\": \"$(c $ST_LP 'totalDeposits()(uint256)')\","
  echo "  \"filst_staking_totalDeposits\": \"$(c $ST_FILST 'totalDeposits()(uint256)')\","
  echo "  \"dfl_staking_totalDeposits\": \"$(c $ST_DFL 'totalDeposits()(uint256)')\","
  echo "  \"filst_total_supply\": \"$(c $FILST 'totalSupply()(uint256)')\","
  echo "  \"filst_minted_via_manage\": \"$(c $FM 'getTotalMintedAmount()(uint256)')\","
  echo "  \"mining_nft_staked_total\": \"$(c $FM 'totalStakedMiningNftAmount()(uint256)')\","
  echo "  \"nft_100001_at_manage\": \"$(c $NFT 'balanceOf(address,uint256)(uint256)' $FM 100001)\","
  echo "  \"nft_100006_at_manage\": \"$(c $NFT 'balanceOf(address,uint256)(uint256)' $FM 100006)\","
  echo "  \"unitroller_dfl\": \"$(c $DFL 'balanceOf(address)(uint256)' $UNIT)\","
  echo "  \"cfilst_cash\": \"$(c $CFILST 'getCash()(uint256)')\","
  echo "  \"top_staker_share\": \"$(c $ST_LP 'accountState(address)(uint256,uint256,uint256)' $TOP | head -1)\","
  echo "  \"gate_outsider_withdraw\": \"$(cf $ATT $ST_LP 'withdraw(uint256)(uint256)' 1000000000000000)\","
  echo "  \"gate_outsider_claim\": \"$(cf $ATT $ST_LP 'claim(address,uint256)(uint256)' $ATT 1)\","
  echo "  \"gate_outsider_mint_filst\": \"$(cf $ATT $FM 'mint(address,uint256,uint256)' $ATT 100001 1)\","
  echo "  \"gate_outsider_unitroller_claim\": \"$(cf $ATT $UNIT 'claim(address,uint256)(uint256)' $ATT 1000000000000000000)\","
  echo "  \"ho_top_staker_withdraw_ok\": \"$(cf $TOP $ST_LP 'withdraw(uint256)(uint256)' 978272219496394154)\","
  echo "  \"ho_cfilst_redeem_ok\": \"$(cf $CFHOLD $CFILST 'redeem(uint256)(uint256)' 3102080794000000000000)\""
  echo "}"
} > ci-out/state.json

python3 - <<'PY' > ci-out/exit_liquidity.json
import json
rF = 1396416006144015505577894
rU = 714487847125
def out(x):
    a = x*997
    return a*rU//(rF*1000+a)
data = {
  "note": "AMM out for selling X FILST into pair 0xa2f6a219 (0.3% fee, floor); reserves as of 2026-10-11",
  "usdt_reserve_1e6": rU,
  "filst_reserve_1e18": str(rF),
  "out_usdt_1e6_for_100k_filst": out(100_000*10**18),
  "out_usdt_1e6_for_full_filst_side": out(rF),
  "out_usdt_1e6_for_100m_filst": out(100_000_000*10**18),
  "asymptote_usdt_1e6": rU*997//1000,
}
print(json.dumps(data, indent=1))
PY

cat ci-out/state.json | head -40
echo "[defil] wrote ci-out/state.json + ci-out/exit_liquidity.json"
