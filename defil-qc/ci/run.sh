#!/usr/bin/env bash
# DeFIL QC-1 adversarial re-audit — CI evidence dump (read-only RPC reads; no secrets).
# Produces ci-out/qc-evidence.json with:
#   - fresh custody state (ETH + BSC)
#   - ETH<->BSC bytecode identity for the unverified-on-BSC core contracts
#   - fresh outsider gate simulations (mint / withdraw / claim / borrow / reduceReserves)
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root (defil-qc/)

ER="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
BR="${BSC_FORK_RPC_URL:-${BSC_RPC_URL:-https://bsc-rpc.publicnode.com}}"
mkdir -p ci-out

eblk=$(cast block-number --rpc-url "$ER" 2>/dev/null || echo 0)
bblk=$(cast block-number --rpc-url "$BR" 2>/dev/null || echo 0)
echo "[defil-qc] eth block=$eblk bsc block=$bblk"

c() { local a="$1"; shift; cast call "$a" "$@" --rpc-url "$ER" 2>/dev/null | head -1; }
cb() { local a="$1"; shift; cast call "$a" "$@" --rpc-url "$BR" 2>/dev/null | head -1; }
crt() { local a="$1"; shift; cast call "$a" "$@" --rpc-url "$ER" 2>/dev/null | tr '\n' '|'; }
cbt() { local a="$1"; shift; cast call "$a" "$@" --rpc-url "$BR" 2>/dev/null | tr '\n' '|'; }
cf() { local f="$1"; shift; local a="$1"; shift; cast call "$a" "$@" --from "$f" --rpc-url "$ER" 2>&1 | head -1; }
cfb() { local f="$1"; shift; local a="$1"; shift; cast call "$a" "$@" --from "$f" --rpc-url "$BR" 2>&1 | head -1; }

FILST=0x7346aD4c8cD1886Ff6D16072bCeA5DFC0bc24Ca2
DFL=0x09ce2B746C32528B7d864A1e3979Bd97d2f095AB
EFIL=0x2a2cB9bA73289D4D068BD57D3c26165DaD5Cb628
USDT=0xdAC17F958D2ee523a2206206994597C13D831ec7
LP=0xa2f6a219a51B4682E34a13a94C160d6c79cDcA35
ST_LP=0x9E08bD9A1E3880902688B32d563046cab74d2f2f
FM=0xcd429F23088b3FA4AAbFF61dD5F9E534793f9944
NFT=0xad1ED31e70b569D78D1930537179A940DdA4A9CF
NFTM=0x9cFcB73Cb365eD7f38dcf3bc60d2aEAFe0D502E2
UNIT=0x6B4F20B2259Eebb97945b6EF549a1c44FcA6Cd81
CEFIL=0x036cF3821eA246E935feEF1c29ED8DdFFaC1dBB0
CFILST=0x71DD9CD476c73F7C94a82E3F00a8eD29268602e1
ATT=0x000000000000000000000000000000000000BEEF

BFILST=0x899e2a220CBC6eb1Ab154211353EDED74BC1e266
BFM=0x81dA506420364b3d960229dFc8B9315acEF22dC5
BNFT=0xB02F118013150C7F2D4F2030E15F198E1CaA60eb
BNFTM=0x3e3945c7e5cb7a6286b48A016d9D52B5826c3F4e
BMINER=0xbE8fB7dB7425f9B1f67DC58ac31dDAFc532DEC9c
BLP=0xecf6aA34b19e31311eB92768888bdDd25aa72933
BST_LP=0xde6239b3138910c68f318e799b3d332925e9929f

# --- bytecode identity for the core (unverified-on-BSC) contracts ---
hash_eth() { cast code --rpc-url "$ER" "$1" | tr 'A-F' 'a-f' | cast keccak; }
hash_bsc() { cast code --rpc-url "$BR" "$1" | tr 'A-F' 'a-f' | cast keccak; }
h_fm_e=$(hash_eth $FM);    h_fm_b=$(hash_bsc $BFM)
h_nft_e=$(hash_eth $NFT);  h_nft_b=$(hash_bsc $BNFT)
h_nftm_e=$(hash_eth $NFTM); h_nftm_b=$(hash_bsc $BNFTM)
h_mm_e=$(hash_eth 0x2D7a678EB9196D0dE4F5467141038dbc949C97a1); h_mm_b=$(hash_bsc $BMINER)

# --- fresh NFT enumeration ---
eth_sum=0; for id in $(seq 100001 100011); do v=$(c $NFT 'balanceOf(address,uint256)(uint256)' $FM $id); eth_sum=$((eth_sum + ${v%% *})); done
bsc_sum=0; for id in $(seq 100001 100012); do v=$(cb $BNFT 'balanceOf(address,uint256)(uint256)' $BFM $id); bsc_sum=$((bsc_sum + ${v%% *})); done

{
  echo "{"
  echo "  \"finding\": \"DeFIL — L2 QC-1 adversarial re-audit\","
  echo "  \"date\": \"2026-10-13\","
  echo "  \"eth_block\": $eblk,"
  echo "  \"bsc_block\": $bblk,"
  echo "  \"bytecode_identity_eth_bsc\": {"
  echo "    \"FILSTManage\": \"$([ "$h_fm_e" = "$h_fm_b" ] && echo IDENTICAL || echo DIFFERENT)\","
  echo "    \"MiningNFT\": \"$([ "$h_nft_e" = "$h_nft_b" ] && echo IDENTICAL || echo DIFFERENT)\","
  echo "    \"MiningNFTManage\": \"$([ "$h_nftm_e" = "$h_nftm_b" ] && echo IDENTICAL || echo DIFFERENT)\","
  echo "    \"MinerManage\": \"$([ "$h_mm_e" = "$h_mm_b" ] && echo IDENTICAL || echo DIFFERENT)\""
  echo "  },"
  echo "  \"eth\": {"
  echo "    \"lp_total_supply\": \"$(c $LP 'totalSupply()(uint256)')\","
  echo "    \"lp_in_staking\": \"$(c $LP 'balanceOf(address)(uint256)' $ST_LP)\","
  echo "    \"pair_reserves\": \"$(crt $LP 'getReserves()(uint112,uint112,uint32)')\","
  echo "    \"pair_filst_balance\": \"$(c $FILST 'balanceOf(address)(uint256)' $LP)\","
  echo "    \"pair_usdt_balance\": \"$(c $USDT 'balanceOf(address)(uint256)' $LP)\","
  echo "    \"nft_current_id\": \"$(c $NFT 'getCurrentTokenId()(uint256)')\","
  echo "    \"nft_units_escrowed\": $eth_sum,"
  echo "    \"nft_staked_total\": \"$(c $FM 'totalStakedMiningNftAmount()(uint256)')\","
  echo "    \"filst_supply\": \"$(c $FILST 'totalSupply()(uint256)')\","
  echo "    \"filst_minted_via_manage\": \"$(c $FM 'getTotalMintedAmount()(uint256)')\","
  echo "    \"unitroller_dfl\": \"$(c $DFL 'balanceOf(address)(uint256)' $UNIT)\","
  echo "    \"dfl_current_speed\": \"$(c $UNIT 'dflCurrentSpeed()(uint256)')\","
  echo "    \"dfl_market_pct_0\": \"$(c $UNIT 'dflMarketPercentages(uint256)(uint256)' 0)\","
  echo "    \"cefil_cash_efil\": \"$(c $CEFIL 'getCash()(uint256)')\","
  echo "    \"cefil_reserve_keeper\": \"$(c $CEFIL 'reserveKeeper()(address)')\","
  echo "    \"cfilst_cash_filst\": \"$(c $CFILST 'getCash()(uint256)')\","
  echo "    \"gate_outsider_mint_filst\": \"$(cf $ATT $FM 'mint(address,uint256,uint256)' $ATT 100001 1)\","
  echo "    \"gate_outsider_whitelist\": \"$(cf $ATT 0x2D7a678EB9196D0dE4F5467141038dbc949C97a1 'addToWhiteList(address,string,string,string)' $ATT f0evil 0x 0x)\","
  echo "    \"gate_outsider_nftm_mint\": \"$(cf $ATT $NFTM 'mint(uint256)' 1)\","
  echo "    \"gate_outsider_lp_withdraw\": \"$(cf $ATT $ST_LP 'withdraw(uint256)(uint256)' 1000000000000000)\","
  echo "    \"gate_outsider_claimDFL\": \"$(cf $ATT $UNIT 'claim(address,uint256)(uint256)' $ATT 1000000000000000000)\","
  echo "    \"gate_cfilst_borrow\": \"$(cf $ATT $CFILST 'borrow(uint256)(uint256)' 1000000000000000000)\","
  echo "    \"gate_cefil_borrow_nocoll\": \"$(cf $ATT $CEFIL 'borrow(uint256)(uint256)' 1000000000000000000)\","
  echo "    \"gate_outsider_reduce_reserves\": \"$(cf $ATT $CEFIL '_reduceReserves(address,uint256)(uint256)' $ATT 1)\","
  echo "    \"efil_uni_pairs_weth\": \"$(c 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f 'getPair(address,address)(address)' $EFIL 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)\""
  echo "  },"
  echo "  \"bsc\": {"
  echo "    \"filst_supply\": \"$(cb $BFILST 'totalSupply()(uint256)')\","
  echo "    \"nft_current_id\": \"$(cb $BNFT 'getCurrentTokenId()(uint256)')\","
  echo "    \"nft_units_escrowed\": $bsc_sum,"
  echo "    \"nft_staked_total\": \"$(cb $BFM 'totalStakedMiningNftAmount()(uint256)')\","
  echo "    \"lp_total_supply\": \"$(cb $BLP 'totalSupply()(uint256)')\","
  echo "    \"lp_in_staking\": \"$(cb $BLP 'balanceOf(address)(uint256)' $BST_LP)\","
  echo "    \"pair_reserves\": \"$(cbt $BLP 'getReserves()(uint112,uint112,uint32)')\","
  echo "    \"gate_outsider_mint_filst\": \"$(cfb $ATT $BFM 'mint(address,uint256,uint256)' $ATT 100001 1)\","
  echo "    \"gate_outsider_whitelist\": \"$(cfb $ATT $BMINER 'addToWhiteList(address,string,string,string)' $ATT f0evil 0x 0x)\","
  echo "    \"gate_cfilst_borrow\": \"$(cfb $ATT 0xC28207990B0EE4847e56f98b0b9F526b302A9273 'borrow(uint256)(uint256)' 1000000000000000000)\","
  echo "    \"gate_cefil_borrow_nocoll\": \"$(cfb $ATT 0x0c6D278afc34eAC4539ee33192E28275955A1BE6 'borrow(uint256)(uint256)' 1000000000000000000)\","
  echo "    \"mfil_total_supply\": \"$(cb 0x3C392C3FBE6ADA6049373478A4f8dD668Ab27b0C 'totalSupply()(uint256)')\""
  echo "  }"
  echo "}"
} > ci-out/qc-evidence.json

cat ci-out/qc-evidence.json
echo "[defil-qc] wrote ci-out/qc-evidence.json"
