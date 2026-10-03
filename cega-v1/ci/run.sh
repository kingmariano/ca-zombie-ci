#!/usr/bin/env bash
# Cega V1 custom CI job: probe archive-capable RPCs, export fork env for forge tests,
# and write a machine-readable live-state snapshot into ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> cega-v1/
mkdir -p ci-out

ETH_BLOCK="${CEGA_ETH_BLOCK:-26112349}"
probe() { # url block -> prints url if state at block is available
  local u=$1 b=$2
  [ -z "$u" ] && return 1
  local r
  r=$(curl -s -m 15 -X POST -H 'Content-Type: application/json' \
        --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBalance\",\"params\":[\"0x56F00A399151EC74cf7bE8DC38225363E84975E6\",\"0x$(printf '%x' "$b")\"]}" "$u" 2>/dev/null)
  case "$r" in *result*) echo "$u"; return 0;; esac
  return 1
}

PICK=""
for u in "${BLOCKPI_RPC_URL:-}" "${NODEREAL_ETH_RPC_URL:-}" "https://eth.drpc.org" "${FORK_RPC_URL:-}" "${RPC_URL:-}"; do
  if PICK=$(probe "$u" "$ETH_BLOCK"); then break; fi
done
if [ -n "${PICK:-}" ]; then
  echo "CEGA_ETH_FORK=$PICK" >> "${GITHUB_ENV:-/dev/null}" || true
  echo "CEGA_ETH_BLOCK=$ETH_BLOCK" >> "${GITHUB_ENV:-/dev/null}" || true
  echo "[ci] ETH fork: archive at block $ETH_BLOCK"
else
  echo "CEGA_ETH_BLOCK=0" >> "${GITHUB_ENV:-/dev/null}" || true
  echo "[ci] ETH fork: no archive RPC, using latest"
fi

# Arbitrum: latest-state fork (no archive available publicly)
if [ -n "${ARB_RPC_URL:-}" ]; then
  echo "CEGA_ARB_FORK=$ARB_RPC_URL" >> "${GITHUB_ENV:-/dev/null}" || true
fi

# ---- state snapshot (read-only) -------------------------------------------
ETH="${PICK:-https://eth.drpc.org}"
ETH_HOST=$(printf '%s' "$ETH" | sed -E 's|(https?://[^/]+).*|\1|; s|(https?://[^/]+/[^/]+).*|\1|')
ARB="${ARB_RPC_URL:-https://arb1.arbitrum.io/rpc}"
USDC_ETH=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDC_ARB=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
{
  echo "{"
  echo "  \"snapshot_utc\": \"$(date -u +%FT%TZ)\","
  echo "  \"eth_fork_rpc_host\": \"$ETH_HOST\","
  echo "  \"eth_block\": $ETH_BLOCK,"
  echo "  \"eth_products_usdc\": {"
  first=1
  for a in 0x042021d59731d3fFA908c7c4211177137Ba362Ea 0x56F00A399151EC74cf7bE8DC38225363E84975E6 0x784e3C592A6231D92046bd73508B3aAe3A7cc815 0x2aAE28E495626F587677ca779838266DB9bD6Cd1 0x98b872604F36807169c096241ECD4646021de133 0xAB8631417271Dbb928169F060880e289877Ff158 0xcf81b51AecF6d88dF12Ed492b7b7f95bBc24B8Af 0x80ec1c0da9bfBB8229A1332D40615C5bA2AbbEA8 0x94C5D3C2fE4EF2477E562EEE7CCCF07Ee273B108 0x0730AA138062D8Cc54510aa939b533ba7c30f26B 0xF9B7BF3f4616209Aa9d412443Aa0f94449c63122 0xeF1CE301B311654419810c8F5DbBD7Eb595F3d96 0xDC60989aaa5fbA0C2435D755056b41A9Ff415F13 0x4511E45687b0F18152A03C4FD20E61fb9B373431 0x81468f8aB2d071f4F95862D5886fA57ad2B86b24 0xD4Ae9ce7DE8687a74dBC092526b47902b5CaaB26 0xf27952993b17bd60d3c03f64d70ec2613808344f 0xed803c5ee534dc4fd350f110c56e264432068b6b 0xb032134c3f5ac77b436b95983882294711d55c7c 0xcea6002ae60f764eced023787281d63da1528992 0x5C05bEF15fe2E4acC421C183A488B1381d45713E; do
    v=$(cast call $USDC_ETH "balanceOf(address)(uint256)" $a --block $ETH_BLOCK --rpc-url "$ETH" 2>/dev/null | awk '{print $1}')
    [ $first -eq 1 ] || echo ","
    first=0
    printf '    "%s": %s' "$a" "${v:-0}"
  done
  echo
  echo "  },"
  echo "  \"arb_products_usdc\": {"
  first=1
  for a in 0x6A9201Db9222cFb5164cfb8F192903270f8a6e93 0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed 0x4919e2554C690Fe2696DC17cCaB3D5f71Bc7a550 0x3408632Ee5F99A2a0dE7cF0b29BA888A5967066d 0x1B4Dc3476dB1E19DbDDcdA5440b23ED4FcC61Bee 0x0299A5B8D523ebccF5501177c35C0958774FdB38 0xdBe523D41b06138EaEBD3A81c0711F6DCab4726d 0x41A42A2206C9eB29d9e0486c94321618B309f6Ba 0x52f02F642eC91e19A614d23fF3da7ADe66326b64 0x3d0651F87fBCEB64aCa72aFa78112DCc6622cDee 0x03F48C289Eed2Fa712a67C4BA87769e7bC4213aD 0x692926af4744e14ed32bf7717c5cb4aaa0025aca; do
    v=$(cast call $USDC_ARB "balanceOf(address)(uint256)" $a --rpc-url "$ARB" 2>/dev/null | awk '{print $1}')
    [ $first -eq 1 ] || echo ","
    first=0
    printf '    "%s": %s' "$a" "${v:-0}"
  done
  echo
  echo "  }"
  echo "}"
} > ci-out/state_snapshot.json

echo "[ci] snapshot written:"
head -c 800 ci-out/state_snapshot.json
echo
