#!/usr/bin/env bash
# Swerve custom CI evidence job: dump live state at the fork block into ci-out/.
# Read-only. RPC from env (FORK_RPC_URL set by workflow; fallback publicnode). No secrets printed.
set -u
RPC="${FORK_RPC_URL:-https://ethereum-rpc.publicnode.com}"
OUT=ci-out
mkdir -p "$OUT"
P=0x329239599afB305DA0A2eC69c58F8a6697F9F88d
LP=0x77c6e4a580c0dce4e5c7a17d0bc077188a83a059
G=0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa
DAO=0x2638d2680AB4914126ee05b9c5EE95bAC311A95E
{
echo "== Swerve live state @ $(date -u +%FT%TZ) =="
B=$(cast block-number --rpc-url "$RPC")
echo "block: $B"
echo "block timestamp: $(cast block "$B" --rpc-url "$RPC" --field timestamp)"
echo "pool owner(): $(cast call $P 'owner()(address)' --rpc-url "$RPC")"
echo "pool A(): $(cast call $P 'A()(uint256)' --rpc-url "$RPC")"
echo "pool fee(): $(cast call $P 'fee()(uint256)' --rpc-url "$RPC")"
echo "pool admin_fee(): $(cast call $P 'admin_fee()(uint256)' --rpc-url "$RPC")"
echo "pool is_killed(slot15): $(cast storage $P 15 --rpc-url "$RPC")"
echo "pool kill_deadline(slot14): $(cast storage $P 14 --rpc-url "$RPC")"
echo "pool admin_actions_deadline: $(cast call $P 'admin_actions_deadline()(uint256)' --rpc-url "$RPC")"
echo "pool transfer_ownership_deadline: $(cast call $P 'transfer_ownership_deadline()(uint256)' --rpc-url "$RPC")"
echo "pool future_owner: $(cast call $P 'future_owner()(address)' --rpc-url "$RPC")"
echo "pool virtual price: $(cast call $P 'get_virtual_price()(uint256)' --rpc-url "$RPC")"
for i in 0 1 2 3; do
  echo "coin[$i]=$(cast call $P 'coins(int128)(address)' $i --rpc-url "$RPC") bal_virtual=$(cast call $P 'balances(int128)(uint256)' $i --rpc-url "$RPC") bal_actual=$(cast call $(cast call $P 'coins(int128)(address)' $i --rpc-url "$RPC") 'balanceOf(address)(uint256)' $P --rpc-url "$RPC")"
done
echo "swUSD totalSupply: $(cast call $LP 'totalSupply()(uint256)' --rpc-url "$RPC")"
echo "swUSD minter slot6: $(cast storage $LP 6 --rpc-url "$RPC")"
echo "gauge totalSupply: $(cast call $G 'totalSupply()(uint256)' --rpc-url "$RPC")"
echo "gauge lp_token: $(cast call $G 'lp_token()(address)' --rpc-url "$RPC")"
echo "DAO proxy USDT: $(cast call 0xdAC17F958D2ee523a2206206994597C13D831ec7 'balanceOf(address)(uint256)' $DAO --rpc-url "$RPC")"
echo "== admin paths from random caller (expect revert) =="
A=0x1111111111111111111111111111111111111111
for fn in "withdraw_admin_fees()" "commit_transfer_ownership(address)" "apply_transfer_ownership()" "kill_me()" "unkill_me()"; do
  case "$fn" in
    "commit_transfer_ownership(address)") res=$(cast call --from $A $P "$fn" $A --rpc-url "$RPC" 2>&1 | head -1);;
    *) res=$(cast call --from $A $P "$fn" --rpc-url "$RPC" 2>&1 | head -1);;
  esac
  echo "  $fn -> ${res:0:90}"
done
echo "== staker exit simulation (gauge.withdraw is state-changing; checkpoint check) =="
S=0x15fba769de1fc3bdaf5aec3ab87d340ae20a519e
echo "  user_checkpoint from staker: $(cast call --from $S $G 'user_checkpoint(address)' $S --rpc-url "$RPC" 2>&1 | head -1)"
echo "  staker gauge balance: $(cast call $G 'balanceOf(address)(uint256)' $S --rpc-url "$RPC")"
echo "== source hashes (local files) =="
sha256sum analysis/sources/*.sol 2>/dev/null || true
} > "$OUT/live_state.txt" 2>&1
cat "$OUT/live_state.txt"
