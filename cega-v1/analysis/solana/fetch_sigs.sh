#!/usr/bin/env bash
# Fetch signatures for addresses of interest (READ-ONLY).
set -u
RPC="${RPC:-https://api.mainnet-beta.solana.com}"
D="/home/heisenberg/CA/cega-v1/analysis/solana"
fetch() { # $1 name, $2 address, $3 limit
  curl -s -m 40 "$RPC" -H 'Content-Type: application/json' -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getSignaturesForAddress\",\"params\":[\"$2\",{\"limit\":$3}]}" > "$D/sigs_$1.json"
  sleep 0.8
}
fetch prober FoCZvQdRkj7PuAqGupo9XXS7aEtSfGG8SpoZAxHg4DjN 50
fetch signer_whl HWLAWoYXBuLGAyZYy4LtEa54mo4gyUjRyL3FXytoW8i9 50
fetch upgrade_authority 5d8d3PSxKDb6knunoweZ8jZYoDmgEEGMVJdqJBTgjvRx 30
fetch product_supercharger HGAp6kzGpk9NwYLA1xmNH5AjJx3M37SvBXc7kWfST9dz 40
fetch product_cc2 5LZJ8MscKPUGToyWtZERSwgKBJ3svPn8rT9Lcp5UnrcY 40
fetch product_gofast2 9r8JiBWhSr1XnxKsNBuHu8ERcjPmUsRy4bJ4g8xVXfMg 40
fetch product_insanic2 HkGKcjAsjKp4hUWbQ6yRj2ZLnD52kEVcuk6eVxW3Vr7C 40
fetch product_genesis2 45eBn7xcCvUpc84XoepADHcqbMXCkstn8XKo4thLgckB 40
echo DONE
