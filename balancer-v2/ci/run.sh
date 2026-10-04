#!/usr/bin/env bash
# Heavy job for the H-43 (balancer-v2) finding: end-to-end historical validation of the
# Nov-2025 ComposableStablePool exploit on an archive fork. Results -> ci-out/.
# Never prints or stores secrets.
set -uo pipefail
cd "$(dirname "$0")/.."   # finding folder root
mkdir -p ci-out

CANDIDATES=()
[ -n "${NODEREAL_ETH_RPC_URL:-}" ] && CANDIDATES+=("$NODEREAL_ETH_RPC_URL")
[ -n "${INFURA_API_KEY:-}" ] && CANDIDATES+=("https://mainnet.infura.io/v3/$INFURA_API_KEY")
[ -n "${ANKR_API_KEY:-}" ] && CANDIDATES+=("https://rpc.ankr.com/eth/$ANKR_API_KEY")
CANDIDATES+=("https://eth.drpc.org")

ARCH=""
for u in "${CANDIDATES[@]}"; do
  ok=$(curl -s -m 20 -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xDACf5Fa19b1f720111609043ac67A9818262850c","data":"0x876f303b"},"0x169e614"],"id":1}' \
        "$u" | grep -c '"result"' || true)
  if [ "$ok" = "1" ]; then ARCH="$u"; break; fi
done

echo "== H-43 historical sanity (archive fork, block 23717396) ==" > ci-out/historical-sanity.log
if [ -n "$ARCH" ]; then
  (cd poc && HIST_RPC_URL="$ARCH" forge test --match-test test_historical_sanity -vv) >> ci-out/historical-sanity.log 2>&1
  echo "forge_exit=$?" >> ci-out/historical-sanity.log
else
  echo "no archive RPC reachable; historical check skipped" >> ci-out/historical-sanity.log
fi
exit 0
