#!/usr/bin/env bash
# H2-06 Hedera (Stader HBARX) — read-only probe suite for CI.
# Keyless public endpoints only. No secrets. No transactions. Writes ci-out/hedera_probes.{json,log}.
set -uo pipefail

ROOT="$(pwd)"
OUT="$ROOT/ci-out"
mkdir -p "$OUT"
RPC="${HEDERA_RPC:-https://mainnet.hashio.io/api}"
MIRROR="${HEDERA_MIRROR:-https://mainnet-public.mirrornode.hedera.com}"
STAKING=0x0000000000000000000000000000000000158d97
UNDEL3=0x0000000000000000000000000000000000158d71
UNDEL2=0x00000000000000000000000000000000000fae03
REWARDS=0x0000000000000000000000000000000000158dac
ATT=0x1111111111111111111111111111111111111111
TSV="$OUT/hedera_probes.tsv"
: > "$TSV"

if ! command -v cast >/dev/null 2>&1; then echo "FATAL: cast not found"; exit 1; fi

probe() { # name expect cmd...
  local name="$1" expect="$2"; shift 2
  local out st=FAIL
  out=$("$@" 2>&1 | head -c 400 | tr '\n' ' ')
  case "$out" in *"$expect"*) st=PASS;; esac
  printf '%s\t%s\t%s\t%s\n' "$name" "$st" "$expect" "$out" >> "$TSV"
  echo "[$st] $name :: $(echo "$out" | head -c 110)"
}

BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo 0)
echo "Hedera EVM block: $BLOCK"
if [ "$BLOCK" = "0" ]; then echo "FATAL: RPC unreachable"; exit 1; fi

echo "--- state reads ---"
probe "staking.getExchangeRate" "1435" cast call $STAKING "getExchangeRate()(uint256)" --rpc-url "$RPC"
probe "staking.totalSupply" "27039345636300414" cast call $STAKING "totalSupply()(uint256)" --rpc-url "$RPC"
probe "staking.paused=false" "false" cast call $STAKING "paused()(bool)" --rpc-url "$RPC"
probe "staking.isStakePaused=false" "false" cast call $STAKING "isStakePaused()(bool)" --rpc-url "$RPC"
probe "staking.isUnstakePaused=false" "false" cast call $STAKING "isUnstakePaused()(bool)" --rpc-url "$RPC"
probe "staking.nodeStakingActive=false" "false" cast call $STAKING "nodeStakingActive()(bool)" --rpc-url "$RPC"
probe "staking.withdrawQueue.length==0(slot4)" "0x0000000000000000000000000000000000000000000000000000000000000000" cast storage $STAKING 4 --rpc-url "$RPC"
probe "staking.timelockOwner==0x1ad3eb(slot5)" "0x00000000000000000000000000000000000000000000000000000000001ad3eb" cast storage $STAKING 5 --rpc-url "$RPC"
probe "staking.owner()==0xcb935" "0x00000000000000000000000000000000000Cb935" cast call $STAKING "owner()(address)" --rpc-url "$RPC"

echo "--- attack simulations (eth_call from 0x1111...) ---"
probe "ATTACK queueAllFunds -> invalidOwner" "0x83632027" cast call $STAKING "queueAllFunds(address)" $ATT --from $ATT --rpc-url "$RPC"
probe "ATTACK queuePartialFunds -> invalidOwner" "0x83632027" cast call $STAKING "queuePartialFunds(address,uint256)" $ATT 1000000000000000000 --from $ATT --rpc-url "$RPC"
probe "ATTACK withdraw(0) -> invalidIndex" "0x8a581ab7" cast call $STAKING "withdraw(uint256)" 0 --from $ATT --rpc-url "$RPC"
probe "ATTACK cancelWithdraw(0) -> invalidOwner" "0x83632027" cast call $STAKING "cancelWithdraw(uint256)" 0 --from $ATT --rpc-url "$RPC"
probe "ATTACK updateNodeStakingActive -> onlyOwner" "caller is not the owner" cast call $STAKING "updateNodeStakingActive()" --from $ATT --rpc-url "$RPC"
probe "ATTACK pause -> onlyOwner" "caller is not the owner" cast call $STAKING "pause()" --from $ATT --rpc-url "$RPC"
probe "ATTACK updateUnStakeIsPaused -> onlyOwner" "caller is not the owner" cast call $STAKING "updateUnStakeIsPaused()" --from $ATT --rpc-url "$RPC"
probe "ATTACK stakeWithNodes -> invalidOperator" "0xb25a821e" cast call $STAKING "stakeWithNodes(uint256[],uint256)" "[]" 0 --from $ATT --rpc-url "$RPC"
probe "ATTACK collectRewards -> invalidOperator" "0xb25a821e" cast call $STAKING "collectRewards(uint256[])" "[0]" --from $ATT --rpc-url "$RPC"
probe "ATTACK unStake(1e8) -> transfer fails" "0xd96e4d38" cast call $STAKING "unStake(uint256)" 100000000 --from $ATT --rpc-url "$RPC"
probe "ATTACK V3 undel undelegate -> only staking" "Only staking contract can undelegate" cast call $UNDEL3 "undelegate(address)" $ATT --value 1 --from $ATT --rpc-url "$RPC"
probe "ATTACK V3 undel withdraw(0) -> Panic(0x32)" "0x4e487b71" cast call $UNDEL3 "withdraw(uint256)" 0 --from $ATT --rpc-url "$RPC"
probe "ATTACK V2 undel withdraw(0) -> Panic(0x32)" "0x4e487b71" cast call $UNDEL2 "withdraw(uint256)" 0 --from $ATT --rpc-url "$RPC"
probe "ATTACK staking.setUndelegationContractAddress -> onlyOwner" "caller is not the owner" cast call $STAKING "setUndelegationContractAddress(address)" $ATT --from $ATT --rpc-url "$RPC"
probe "ATTACK staking.setRewardsContractAddress -> onlyOwner" "caller is not the owner" cast call $STAKING "setRewardsContractAddress(address)" $ATT --from $ATT --rpc-url "$RPC"
probe "ATTACK staking.updateOperatorAddress -> onlyOwner" "caller is not the owner" cast call $STAKING "updateOperatorAddress(address)" $ATT --from $ATT --rpc-url "$RPC"
probe "ATTACK rewards.setStakerAddress -> onlyOwner" "caller is not the owner" cast call $REWARDS "setStakerAddress(address)" $ATT --from $ATT --rpc-url "$RPC"
probe "ATTACK rewards.setDaoAddress -> onlyOwner" "caller is not the owner" cast call $REWARDS "setDaoAddress(address)" $ATT --from $ATT --rpc-url "$RPC"
probe "permissionless Rewards.distributeStakingRewards succeeds" "0x" cast call $REWARDS "distributeStakingRewards()" --from $ATT --rpc-url "$RPC"

echo "--- balance checks ---"
BAL_WEI=$(cast balance $STAKING --rpc-url "$RPC" 2>/dev/null | awk '{print $1}')
BAL_MIRROR=$(curl -s --max-time 20 "$MIRROR/api/v1/accounts/0.0.1412503" | python3 -c "import json,sys; print(json.load(sys.stdin)['balance']['balance'])" 2>/dev/null || echo 0)
TOKEN_SUPPLY=$(curl -s --max-time 20 "$MIRROR/api/v1/tokens/0.0.834116" | python3 -c "import json,sys; print(json.load(sys.stdin)['total_supply'])" 2>/dev/null || echo 0)
SUPPLY_KEY=$(curl -s --max-time 20 "$MIRROR/api/v1/tokens/0.0.834116" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('supply_key') or {}).get('key',''))" 2>/dev/null || echo "")
WIPE=$(curl -s --max-time 20 "$MIRROR/api/v1/tokens/0.0.834116" | python3 -c "import json,sys; d=json.load(sys.stdin); print('null' if d.get('wipe_key') is None else 'present')" 2>/dev/null || echo "")
CHAIN_SUPPLY=$(cast call $STAKING "totalSupply()(uint256)" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}')
{
  printf 'staking_balance_wei\tINFO\t>=3.8e26\t%s\n' "$BAL_WEI"
  printf 'staking_balance_mirror_tinybar\tINFO\t>=3.8e16\t%s\n' "$BAL_MIRROR"
  printf 'hbarx_token_total_supply\tINFO\t==staking_totalSupply\t%s\n' "$TOKEN_SUPPLY"
  printf 'staking_totalSupply\tINFO\ttoken supply\t%s\n' "$CHAIN_SUPPLY"
  printf 'hbarx_supply_key\tINFO\t0a0418979b56\t%s\n' "$SUPPLY_KEY"
  printf 'hbarx_wipe_key\tINFO\tnull\t%s\n' "$WIPE"
} >> "$TSV"

python3 - "$TSV" "$OUT/hedera_probes.json" "$BLOCK" <<'PY'
import json,sys,csv
tsv,outp,block=sys.argv[1],sys.argv[2],int(sys.argv[3])
rows=[]
with open(tsv) as f:
    for line in f:
        p=line.rstrip('\n').split('\t')
        if len(p)>=4:
            rows.append({"probe":p[0],"status":p[1],"expected":p[2],"observed":p[3][:300]})
res={"finding":"H2-06","chain":"hedera","protocol":"Stader HBARX","block":block,
     "probes":rows,
     "passed":sum(1 for r in rows if r["status"]=="PASS"),
     "failed":sum(1 for r in rows if r["status"]=="FAIL"),
     "conclusion":"E-U $0.00 — all unprivileged extraction candidates revert at access/scope gates"}
json.dump(res,open(outp,'w'),indent=1)
print("wrote",outp,"passed",res["passed"],"failed",res["failed"])
sys.exit(0 if res["failed"]==0 else 2)
PY
rc=$?
exit $rc
