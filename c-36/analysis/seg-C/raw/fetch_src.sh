#!/bin/bash
# Fetch Blockscout smart-contract JSON for seg-C addresses (read-only)
cd "$(dirname "$0")"
mkdir -p src
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
for a in $(jq -r '.[]' ../../seg_C_addrs.json); do
  f="src/${a}.json"
  if [ -s "$f" ]; then continue; fi
  curl -s -H "User-Agent: $UA" "https://eth.blockscout.com/api/v2/smart-contracts/${a}" -o "$f"
  sleep 0.25
done
echo DONE
