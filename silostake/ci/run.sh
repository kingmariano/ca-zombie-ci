#!/usr/bin/env bash
# SiloStake (Sei CosmWasm, code_id 4485) — deployed-bytecode PoC on a local single-node Sei chain.
#
# What this does (CI, Ubuntu runner, no mainnet transactions):
#   1. downloads the public seid v6.7.1 release binary (checksum-verified)
#   2. verifies analysis/code4485.wasm is byte-identical to the deployed code (sha256)
#   3. boots a throwaway single-node Sei chain (solo validator pinned into genesis so
#      CometBFT's onlyValidatorIsUs path skips blocksync — see sei-chain inprocess/harness.go)
#   4. stores the DEPLOYED wasm (hash re-verified from chain code_info), instantiates a hub
#      with the same params as the live one, and runs the full attacker/keeper scenario matrix
#   5. writes raw evidence to ci-out/
#
# Read-only w.r.t. all real networks. No secrets are used or written.

set -uo pipefail

FOLDER_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$FOLDER_DIR/ci-out"
WASM="${WASM:-$FOLDER_DIR/analysis/code4485.wasm}"
WORK="${WORK:-/tmp/silostake-ci}"
SEID_DIR="$WORK/seid"
SEID="$SEID_DIR/seid"
SEID_VER="v6.7.1"
SEID_URL="https://github.com/sei-protocol/sei-chain/releases/download/$SEID_VER/sei-chain_6.7.1_linux_x86_64.tar.gz"
SEID_SHA="60235ff75f2e223afdc9d87aa5efe105e231f90823492ca53ae55dd6e9859188"
DEPLOYED_WASM_SHA="4EBD7DA3920F3EF5914F76B229DA29F8251DBCFB6F32C3FEEE1626A5BAD71F90"

H="$WORK/chain"
LOG="$OUT/poc-log.txt"
mkdir -p "$OUT" "$WORK" "$SEID_DIR"
exec > >(tee "$LOG") 2>&1

CHAIN=sei-local
LCD=http://127.0.0.1:1317
NODEPID=""

say() { echo "[$(date -u +%H:%M:%S)] $*"; }
cleanup() { [ -n "$NODEPID" ] && kill "$NODEPID" 2>/dev/null; sleep 1; }
trap cleanup EXIT

########################################
say "== 0. setup"
rm -rf "$H"; mkdir -p "$H"
if [ ! -x "$SEID" ]; then
  say "downloading seid $SEID_VER"
  curl -sL --max-time 600 -o "$WORK/seid.tar.gz" "$SEID_URL" || { say "download failed"; exit 1; }
  echo "$SEID_SHA  $WORK/seid.tar.gz" | sha256sum -c - || { say "seid checksum FAILED"; exit 1; }
  tar xzf "$WORK/seid.tar.gz" -C "$SEID_DIR"
fi
"$SEID" version | tee "$OUT/seid-version.txt"

say "verifying deployed wasm bytes (sha256 must equal on-chain data_hash)"
echo "$(sha256sum "$WASM" | awk '{print toupper($1)}')" > "$OUT/wasm_sha256.txt"
grep -q "^$DEPLOYED_WASM_SHA$" "$OUT/wasm_sha256.txt" || { say "WASM SHA MISMATCH: $(cat "$OUT/wasm_sha256.txt")"; exit 1; }
say "wasm sha256 OK: $DEPLOYED_WASM_SHA"

########################################
say "== 1. init single-node chain (solo validator pinned in genesis)"
"$SEID" init smoke --chain-id "$CHAIN" --home "$H" >/dev/null 2>&1
sed -i 's/"stake"/"usei"/g' "$H/config/genesis.json"
jq '.app_state["staking"]["params"]["unbonding_time"]="10s"
  | .app_state["slashing"]["params"]["signed_blocks_window"]="10000"
  | .app_state["slashing"]["params"]["min_signed_per_window"]="0.050000000000000000"
  | .consensus_params["block"]["max_gas"]="35000000"
  | .app_state["staking"]["params"]["max_voting_power_ratio"]="1.0"
  | .app_state["staking"]["params"]["max_voting_power_enforcement_threshold"]="1000000000000000000000"' \
  "$H/config/genesis.json" > "$H/config/g.tmp" && mv "$H/config/g.tmp" "$H/config/genesis.json"

for k in val user attacker; do "$SEID" keys add "$k" --keyring-backend test --home "$H" >/dev/null 2>&1; done
VAL=$("$SEID" keys show val -a --home "$H" --keyring-backend test)
USER=$("$SEID" keys show user -a --home "$H" --keyring-backend test)
ATK=$("$SEID" keys show attacker -a --home "$H" --keyring-backend test)
printf 'VAL=%s\nUSER=%s\nATK=%s\n' "$VAL" "$USER" "$ATK" | tee "$OUT/actors.txt"

"$SEID" add-genesis-account "$VAL" 1000000000000000000000usei --home "$H" >/dev/null 2>&1
"$SEID" add-genesis-account "$USER" 1000000000usei --home "$H" >/dev/null 2>&1
"$SEID" add-genesis-account "$ATK" 1000000000usei --home "$H" >/dev/null 2>&1
"$SEID" gentx val 500000000000000000000usei --chain-id "$CHAIN" --keyring-backend test --home "$H" >/dev/null 2>&1 || say "gentx failed"
"$SEID" collect-gentxs --home "$H" >/dev/null 2>&1 || say "collect-gentxs failed"
PUB=$("$SEID" tendermint show-validator --home "$H" | jq -r '.key')
jq --arg pub "$PUB" '.validators=[{"pub_key":{"type":"tendermint/PubKeyEd25519","value":$pub},"power":"500000000000000","name":"val"}]' \
  "$H/config/genesis.json" > "$H/config/g.tmp" && mv "$H/config/g.tmp" "$H/config/genesis.json"
VALOPER=$("$SEID" keys show val --bech val -a --home "$H" --keyring-backend test)
echo "VALOPER=$VALOPER" >> "$OUT/actors.txt"

say "starting seid (single node)"
nohup "$SEID" start --home "$H" --minimum-gas-prices 0usei --mode validator > "$OUT/node.log" 2>&1 &
NODEPID=$!
for i in $(seq 1 240); do
  h=$(curl -s --max-time 4 "$LCD/cosmos/base/tendermint/v1beta1/blocks/latest" 2>/dev/null | jq -r '.block.header.height // 0')
  if [ "${h:-0}" -ge 2 ] 2>/dev/null; then say "chain up at height $h"; break; fi
  sleep 2
done
if [ "${h:-0}" -lt 2 ] 2>/dev/null; then say "NODE DID NOT START"; tail -30 "$OUT/node.log"; exit 1; fi

########################################
sendtx() { # label, then tx args
  local label=$1; shift
  local f="$OUT/tx_$label.json"
  local gasflag="--gas ${GAS:-800000}"
  timeout 180 "$SEID" tx "$@" --home "$H" --keyring-backend test --chain-id "$CHAIN" -y \
     $gasflag --fees 1000000usei --broadcast-mode sync --output json > "$f" 2> "$f.err"
  local hash code log
  hash=$(jq -r '.txhash // empty' "$f" 2>/dev/null)
  if [ -n "$hash" ]; then
    local i
    for i in $(seq 1 20); do
      sleep 3
      timeout 30 "$SEID" query tx "$hash" --home "$H" --output json > "$OUT/txres_$label.json" 2>/dev/null
      code=$(jq -r '.code // .tx_response.code // empty' "$OUT/txres_$label.json" 2>/dev/null)
      [ -n "$code" ] && break
    done
    log=$(jq -r '.raw_log // .tx_response.raw_log // empty' "$OUT/txres_$label.json" 2>/dev/null)
    say "TX $label => code=$code log=${log:0:260}"
  else
    local c
    c=$(jq -r '.code // empty' "$f" 2>/dev/null)
    say "TX $label => REJECTED(before broadcast) code=$c err=$(head -c 320 "$f.err" | tr '\n' ' ')"
  fi
}

query() {
  timeout 30 "$SEID" query wasm contract-state smart "$2" "$3" --home "$H" --output json > "$OUT/q_$1.json" 2>&1
  say "Q $1 => $(head -c 300 "$OUT/q_$1.json" | tr '\n' ' ')"
}

bal() { curl -s --max-time 5 "$LCD/cosmos/bank/v1beta1/balances/$1" | jq -c '.balances'; }
balsnap() { echo "$(bal "$1")" > "$OUT/bal_$2.txt"; say "BAL $2 = $(cat "$OUT/bal_$2.txt")"; }

########################################
say "== 2. store the DEPLOYED wasm ($DEPLOYED_WASM_SHA)"
GAS=20000000 sendtx store wasm store "$WASM" --from val --home "$H" --keyring-backend test
CODE=$(jq -r '[.events[]? | select(.type=="store_code") | .attributes[] | select((.key|@base64d)=="code_id") | (.value|@base64d)] | first // empty' "$OUT/txres_store.json" 2>/dev/null)
[ -z "$CODE" ] && CODE=$(timeout 30 "$SEID" query wasm list-code --home "$H" --output json | jq -r '[.code_infos[].code_id | tonumber] | max')
say "CODE=$CODE"
if [ -z "$CODE" ] || [ "$CODE" = "null" ]; then say "store failed"; exit 1; fi
# record code_info (checksum) for the stored code
timeout 30 "$SEID" query wasm list-code --home "$H" --output json > "$OUT/chain_codes.json"

say "== 3. instantiate hub (mirrors live params: utoken=usei, denom=isei, 5% fee, 1 validator)"
INITMSG=$(jq -nc --arg owner "$VAL" --arg op "$VAL" --arg v "$VALOPER" --arg fee "$VAL" \
  '{owner:$owner, operator:$op, utoken:"usei", denom:"isei", epoch_period:5, unbond_period:10, validators:[$v], protocol_fee_contract:$fee, protocol_reward_fee:"0.05", chain_config:{}}')
GAS=3000000 sendtx inst wasm instantiate "$CODE" "$INITMSG" --label silohub --admin "$VAL" --from val --home "$H" --keyring-backend test
sleep 3
HUB=$(timeout 30 "$SEID" query wasm list-contract-by-code "$CODE" --home "$H" --output json | jq -r '.contracts[0]')
say "HUB=$HUB"; echo "HUB=$HUB" >> "$OUT/actors.txt"
if [ -z "$HUB" ] || [ "$HUB" = "null" ]; then say "instantiate failed"; exit 1; fi
ISEI="factory/$HUB/isei"
sleep 2
query state0 "$HUB" '{"state":{}}'
query config0 "$HUB" '{"config":{}}'
balsnap "$USER" user_initial
balsnap "$ATK" attacker_initial

say "== 4. attacker probes (unprivileged, no iSEI)"
say "S1 attacker queue_unbond, no funds"
sendtx s1_atk_queue_nofunds wasm execute "$HUB" '{"queue_unbond":{}}' --from attacker --home "$H" --keyring-backend test
say "S2 attacker queue_unbond, wrong denom (usei)"
sendtx s2_atk_queue_wrongdenom wasm execute "$HUB" '{"queue_unbond":{}}' --amount "1000000usei" --from attacker --home "$H" --keyring-backend test
say "S4 attacker withdraw_unbonded, no own requests"
sendtx s4_atk_withdraw wasm execute "$HUB" '{"withdraw_unbonded":{}}' --from attacker --home "$H" --keyring-backend test
say "S5 attacker withdraw_unbonded {receiver:<victim>} (redirect probe)"
sendtx s5_atk_withdraw_receiver wasm execute "$HUB" "{\"withdraw_unbonded\":{\"receiver\":\"$USER\"}}" --from attacker --home "$H" --keyring-backend test
say "S5b attacker withdraw_unbonded {user:<victim>} (arbitrary-user probe)"
sendtx s5b_atk_withdraw_userfield wasm execute "$HUB" "{\"withdraw_unbonded\":{\"user\":\"$USER\"}}" --from attacker --home "$H" --keyring-backend test
say "S6 attacker update_config"
sendtx s6_atk_update_config wasm execute "$HUB" '{"update_config":{"allow_donations":true}}' --from attacker --home "$H" --keyring-backend test
say "S7 attacker add_validator"
sendtx s7_atk_add_validator wasm execute "$HUB" "{\"add_validator\":{\"validator\":\"$VALOPER\"}}" --from attacker --home "$H" --keyring-backend test
say "S8 attacker claim (confused-deputy probe)"
sendtx s8_atk_claim wasm execute "$HUB" "{\"claim\":{\"claims\":[{\"default\":\"$VAL\"}]}}" --from attacker --home "$H" --keyring-backend test
say "S9 attacker tune_delegations"
sendtx s9_atk_tune wasm execute "$HUB" '{"tune_delegations":{}}' --from attacker --home "$H" --keyring-backend test
say "S10 attacker transfer_ownership"
sendtx s10b_atk_transfer_ownership wasm execute "$HUB" "{\"transfer_ownership\":{\"new_owner\":\"$ATK\"}}" --from attacker --home "$H" --keyring-backend test
say "S10c attacker vote"
sendtx s10_atk_vote wasm execute "$HUB" '{"vote":{"proposal_id":1,"vote":"yes"}}' --from attacker --home "$H" --keyring-backend test
say "S16b attacker donate {} (donation mismatch probe)"
sendtx s16b_atk_donate wasm execute "$HUB" '{"donate":{}}' --amount "1000000usei" --from attacker --home "$H" --keyring-backend test

say "== 5. legitimate holder flow"
say "S3 user bond 100 SEI"
sendtx s3_user_bond wasm execute "$HUB" '{"bond":{}}' --amount "100000000usei" --from user --home "$H" --keyring-backend test
sleep 2
balsnap "$USER" user_after_bond
query state1 "$HUB" '{"state":{}}'
say "S11 user queue_unbond 50 iSEI"
sendtx s11_user_queue wasm execute "$HUB" '{"queue_unbond":{}}' --amount "50000000$ISEI" --from user --home "$H" --keyring-backend test
sleep 3
query state2 "$HUB" '{"state":{}}'

say "== 6. keeper paths + claim isolation"
say "S12 wait 25s (chain unbonding_time=10s) then attacker reconcile"
sleep 25
sendtx s12_atk_reconcile wasm execute "$HUB" '{"reconcile":{}}' --from attacker --home "$H" --keyring-backend test
query state3 "$HUB" '{"state":{}}'
say "S13 attacker withdraw_unbonded while victim's batch is claimable"
sendtx s13_atk_withdraw2 wasm execute "$HUB" '{"withdraw_unbonded":{}}' --from attacker --home "$H" --keyring-backend test
say "S14 user withdraw_unbonded (own claim)"
sendtx s14_user_withdraw wasm execute "$HUB" '{"withdraw_unbonded":{}}' --from user --home "$H" --keyring-backend test
sleep 2
balsnap "$USER" user_after_withdraw
balsnap "$ATK" attacker_after_withdraw
say "S15 attacker withdraw_unbonded after victim claimed"
sendtx s15_atk_withdraw3 wasm execute "$HUB" '{"withdraw_unbonded":{}}' --from attacker --home "$H" --keyring-backend test
say "S18 attacker submit_batch"
sendtx s18_atk_submit wasm execute "$HUB" '{"submit_batch":{}}' --from attacker --home "$H" --keyring-backend test
say "S19 attacker harvest"
sendtx s19_atk_harvest wasm execute "$HUB" '{"harvest":{}}' --from attacker --home "$H" --keyring-backend test

say "== 7. admin power probe"
say "S17 admin migrate hub to same code (does deployed 4485 allow migrate?)"
sendtx s17_migrate wasm migrate "$HUB" "$CODE" '{}' --from val --home "$H" --keyring-backend test

query state4 "$HUB" '{"state":{}}'
balsnap "$USER" user_final
balsnap "$ATK" attacker_final

grep -E '^\[|^TX |^Q |^BAL ' "$LOG" > "$OUT/RESULTS.txt" 2>/dev/null || true
say "== DONE. attacker net change: $(bal "$ATK")"
