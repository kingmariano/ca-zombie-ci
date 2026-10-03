#!/usr/bin/env bash
# c-28 custom CI job: probe working RPCs, dump live governance/target state, build cost model.
# Writes valid JSON to ci-out/ (uploaded as artifact) and RPC choice files for the fork tests.
set -uo pipefail
mkdir -p ci-out

RAW=ci-out/state_raw.tsv
: > "$RAW"

# ---------- RPC probing ----------
pick_moonriver() {
  for u in "$MOONRIVER_RPC_URL" "https://moonriver.drpc.org" "https://moonriver.public.blastapi.io" "https://rpc.api.moonriver.moonbeam.network"; do
    [ -z "${u:-}" ] && continue
    cid=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' -H 'User-Agent: Mozilla/5.0' \
      --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' "$u" \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('result',''))" 2>/dev/null)
    if [ "$cid" = "0x505" ]; then echo "$u"; return 0; fi
  done
  return 1
}

pick_eth_archive() {
  for u in "${BLOCKPI_RPC_URL:-}" "${NODEREAL_ETH_RPC_URL:-}" "${RPC_URL:-}" "https://eth.drpc.org" "https://ethereum-rpc.publicnode.com"; do
    [ -z "${u:-}" ] && continue
    v=$(cast call 0x0AaCfbeC6a24756c20D41914F2caba817C0d8521 "balanceOf(address)(uint256)" 0x26881EacC00Bcccd7c4ebE14BD7840dD989Bf982 --block 25884984 --rpc-url "$u" 2>/dev/null | awk '{print $1}')
    if [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null; then echo "$u"; return 0; fi
  done
  return 1
}

R=$(pick_moonriver) && echo "moonriver rpc: $R" || { R="https://moonriver.drpc.org"; echo "moonriver rpc probe failed, fallback $R"; }
echo "$R" > ci-out/rpc_moonriver.txt
MBLK=$(cast block-number --rpc-url "$R" 2>/dev/null || echo 0)
echo "$MBLK" > ci-out/rpc_moonriver_block.txt

EA=$(pick_eth_archive) && echo "eth archive rpc found" || echo "NONE"
[ -n "${EA:-}" ] && echo "$EA" > ci-out/rpc_eth_archive.txt || echo "NONE" > ci-out/rpc_eth_archive.txt

E="${FORK_RPC_URL:-${RPC_URL:-https://ethereum-rpc.publicnode.com}}"
EBLK=$(cast block-number --rpc-url "$E" 2>/dev/null || echo 0)

# helper: call and normalize (strip " [sci]" annotations and quotes)
c() { cast call "$1" "$2" --rpc-url "$3" ${4:+--block "$4"} 2>/dev/null | sed 's/ \[.*//' | tr -d '"' | head -1; }

# ---------- Moonriver: Moonwell Apollo ----------
GOV=0x2BE2e230e89c59c8E20E633C524AD2De246e7370
TLMR=0x04e6322D196E0E4cCBb2610dd8B8f2871E160bd7
MFAM=0xBb8d88bcD9749636BC4D2bE22aaC4Bb3B01A58F1
PAIR=0xE6Bfc609A2e58530310D6964ccdd236fc93b4ADB
MARKETS="0x6E745367F4Ad2b3da7339aee65dC85d416614D90 0x6503D905338e2ebB550c9eC39Ced525b612E77aE 0xd0670AEe3698F66e2D4dAf071EB9c690d978BFA8 0x36918B66F9A3eC7a59d0007D8458DB17bDffBF21 0x93Ef8B7c6171BaB1C0A51092B2c9da8dc2ba0e9D 0xa0D116513Bd0B8f3F14e6Ea41556c6Ec34688e0f"

{
  printf 'moonriver_block\t%s\n' "$MBLK"
  printf 'ethereum_block\t%s\n' "$EBLK"
  printf 'apollo_proposalCount\t%s\n' "$(c $GOV 'proposalCount()(uint256)' "$R")"
  printf 'apollo_proposalThreshold\t%s\n' "$(c $GOV 'proposalThreshold()(uint256)' "$R")"
  printf 'apollo_currentQuorum\t%s\n' "$(c $GOV 'currentQuorum()(uint256)' "$R")"
  printf 'apollo_timelockAdmin\t%s\n' "$(c $TLMR 'admin()(address)' "$R")"
  printf 'apollo_timelockPendingAdmin\t%s\n' "$(c $TLMR 'pendingAdmin()(address)' "$R")"
  printf 'apollo_timelockDelay\t%s\n' "$(c $TLMR 'delay()(uint256)' "$R")"
  printf 'mfam_totalSupply\t%s\n' "$(c $MFAM 'totalSupply()(uint256)' "$R")"
  printf 'pair_token0\t%s\n' "$(c $PAIR 'token0()(address)' "$R")"
  res=$(cast call $PAIR 'getReserves()(uint112,uint112,uint32)' --rpc-url "$R" 2>/dev/null | sed 's/ \[.*//' | paste -sd' ' -)
  printf 'pair_reserves\t%s\n' "$res"
  for M in $MARKETS; do
    printf 'market_%s_symbol\t%s\n' "$M" "$(c $M 'symbol()(string)' "$R")"
    printf 'market_%s_underlying\t%s\n' "$M" "$(c $M 'underlying()(address)' "$R")"
    printf 'market_%s_cash\t%s\n' "$M" "$(c $M 'getCash()(uint256)' "$R")"
    printf 'market_%s_reserves\t%s\n' "$M" "$(c $M 'totalReserves()(uint256)' "$R")"
    printf 'market_%s_borrows\t%s\n' "$M" "$(c $M 'totalBorrows()(uint256)' "$R")"
    printf 'market_%s_admin\t%s\n' "$M" "$(c $M 'admin()(address)' "$R")"
    printf 'market_%s_pendingAdmin\t%s\n' "$M" "$(c $M 'pendingAdmin()(address)' "$R")"
  done
} >> "$RAW"

# ---------- Ethereum: Yam ----------
YTL=0x8b4f1616751117C38a0f84F9A146cca191ea3EC5
YGOV=0x2DA253835967D6E721C6c077157F9c9742934aeA
{
  printf 'yam_timelockAdmin\t%s\n' "$(c $YTL 'admin()(address)' "$E" "$EBLK")"
  printf 'yam_timelockPendingAdmin\t%s\n' "$(c $YTL 'pendingAdmin()(address)' "$E" "$EBLK")"
  printf 'yam_timelockDelay\t%s\n' "$(c $YTL 'delay()(uint256)' "$E" "$EBLK")"
  printf 'yam_governorProposalCount\t%s\n' "$(c $YGOV 'proposalCount()(uint256)' "$E" "$EBLK")"
  printf 'yam_farmMarGov\t%s\n' "$(c 0xffb607418dBEaB7A888e079A34Be28A30d8E1DE2 'gov()(address)' "$E" "$EBLK")"
  printf 'yam_farmFebGov\t%s\n' "$(c 0xc0AE1e1e172ECD4C56fD8043FD5Afe5a473E9835 'gov()(address)' "$E" "$EBLK")"
  printf 'yam_reserves2Yam\t%s\n' "$(c 0x0AaCfbeC6a24756c20D41914F2caba817C0d8521 'balanceOf(address)(uint256)' "$E" "$EBLK" 2>/dev/null)"
  printf 'yam_reserves2YamBal\t%s\n' "$(c 0x0AaCfbeC6a24756c20D41914F2caba817C0d8521 'balanceOf(address)(uint256)' "$E" "$EBLK")"
} >> "$RAW"

# reserves2 balance call needs the holder arg; redo properly
sed -i '/yam_reserves2Yam\t/d' "$RAW"
printf 'yam_reserves2Yam\t%s\n' "$(cast call 0x0AaCfbeC6a24756c20D41914F2caba817C0d8521 'balanceOf(address)(uint256)' 0x97990B693835da58A281636296D2Bf02787DEa17 --rpc-url "$E" --block "$EBLK" 2>/dev/null | sed 's/ \[.*//' | head -1)" >> "$RAW"

python3 - <<'PY'
import json, math
raw={}
for line in open('ci-out/state_raw.tsv'):
    line=line.rstrip('\n')
    if not line or '\t' not in line: continue
    k,v=line.split('\t',1)
    raw[k]=v
def num(k):
    v=raw.get(k,'')
    try: return int(v)
    except Exception: return None
state={
  "moonriver_block": num('moonriver_block'),
  "ethereum_block": num('ethereum_block'),
  "apollo": {
    "governor": "0x2BE2e230e89c59c8E20E633C524AD2De246e7370",
    "timelock": "0x04e6322D196E0E4cCBb2610dd8B8f2871E160bd7",
    "proposalCount": num('apollo_proposalCount'),
    "proposalThreshold": num('apollo_proposalThreshold'),
    "currentQuorum": num('apollo_currentQuorum'),
    "timelock_admin": raw.get('apollo_timelockAdmin',''),
    "timelock_pendingAdmin": raw.get('apollo_timelockPendingAdmin',''),
    "timelock_delay": num('apollo_timelockDelay'),
    "mfam_totalSupply": num('mfam_totalSupply'),
  },
  "solarbeam_pair": {
    "token0": raw.get('pair_token0',''),
    "reserves": raw.get('pair_reserves',''),
  },
  "markets": {},
  "yam": {
    "timelock_admin": raw.get('yam_timelockAdmin',''),
    "timelock_pendingAdmin": raw.get('yam_timelockPendingAdmin',''),
    "timelock_delay": num('yam_timelockDelay'),
    "governor_proposalCount": num('yam_governorProposalCount'),
    "farm_mar_gov": raw.get('yam_farmMarGov',''),
    "farm_feb_gov": raw.get('yam_farmFebGov',''),
    "yamreserves2_yam": raw.get('yam_reserves2Yam',''),
  },
}
for k,v in raw.items():
    if k.startswith('market_'):
        addr=k.split('_')[1]
        state['markets'].setdefault(addr,{})[k.split('_',2)[2]]=v
json.dump(state,open('ci-out/state.json','w'),indent=1)

# cost model
try:
    r0,r1,_=[int(x) for x in raw['pair_reserves'].split()[:3]]
    wmovr='0x98878b06940ae243284ca214f92bb71a2b032b8a'
    y,x=(r0,r1) if raw['pair_token0'].lower()==wmovr else (r1,r0)
    need=int(raw['apollo_proposalThreshold'])+10**18
    dx=(y*need*1000)//((x-need)*997)+1
    model={"threshold_mfam":str(need-10**18),"quorum_mfam":raw['apollo_currentQuorum'],
           "pool_mfam":str(x),"pool_wmovr":str(y),"mfam_needed":str(need),
           "wmovr_cost_wei":str(dx),"wmovr_cost_ether":dx/1e18}
    json.dump(model,open('ci-out/cost_model.json','w'),indent=1)
except Exception as e:
    json.dump({"error":str(e)},open('ci-out/cost_model.json','w'),indent=1)
PY

echo "== ci-out =="
ls -la ci-out/
cat ci-out/cost_model.json 2>/dev/null || true

# copy RPC probe files into the Foundry project so tests can read them within their root
mkdir -p poc/ci-out
cp ci-out/rpc_moonriver.txt ci-out/rpc_moonriver_block.txt ci-out/rpc_eth_archive.txt poc/ci-out/ 2>/dev/null || true
ls -la poc/ci-out/ 2>/dev/null || true
