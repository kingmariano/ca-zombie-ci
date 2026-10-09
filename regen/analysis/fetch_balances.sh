#!/usr/bin/env bash
# Fetch Regen module balances, wasm contracts, proposal details. Read-only, public LCD.
set -uo pipefail
LCD="${LCD:-https://regen-api.polkachu.com}"
OUT="$(dirname "$0")/raw"
mkdir -p "$OUT"

# module accounts from earlier fetch
for acct in bonded_tokens_pool distribution ecocredit ecocredit-basket fee_collector gov interchainaccounts marketplace-feepool mint not_bonded_tokens_pool protocolpool protocolpool_escrow transfer wasm; do
  addr=$(jq -r --arg n "$acct" '.accounts[] | select(.name==$n) | .base_account.address' "$OUT/module_accounts.json")
  [ -z "$addr" ] && continue
  curl -s -m 20 "$LCD/cosmos/bank/v1beta1/balances/$addr?pagination.limit=200" -o "$OUT/bal_$acct.json"
  echo "== $acct $addr =="; jq -c '.balances' "$OUT/bal_$acct.json"
done

# wasm codes + contracts
curl -s -m 20 "$LCD/cosmwasm/wasm/v1/codes?pagination.limit=200" -o "$OUT/wasm_codes.json"
echo "== wasm codes =="; jq -r '.code_infos[]? | "\(.code_id) \(.creator) \(.data_hash // "")"' "$OUT/wasm_codes.json" 2>/dev/null | head -40
