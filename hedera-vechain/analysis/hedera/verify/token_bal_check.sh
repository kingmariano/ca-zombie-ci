#!/usr/bin/env bash
set -u
MIRROR="https://mainnet-public.mirrornode.hedera.com"
for acct in 0.0.1412503 0.0.1412465 0.0.1412524 0.0.1027588 0.0.1027587 0.0.833842 0.0.1758187 0.0.1375147 0.0.833845 0.0.793785 0.0.1412466 0.0.1412476 0.0.1412488; do
  n=$(curl -sS --max-time 30 "$MIRROR/api/v1/accounts/$acct/tokens?limit=100" | jq -r '[.tokens[]? | select(.token_id=="0.0.834116") | .balance] | add // "0"')
  echo "$acct HBARX=$n"
done
