#!/usr/bin/env bash
# H-47 CI helper: probe public RPCs for Linea + Scroll, publish via GITHUB_ENV,
# and record archive availability for the historical Velocore fork block.
set -u
mkdir -p ci-out

pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  return 1
}

L=$(pick "https://rpc.linea.build" "https://linea.drpc.org" || true)
S=$(pick "https://scroll-rpc.publicnode.com" "https://scroll.drpc.org" "https://rpc.scroll.io" || true)

echo "picked linea=$L scroll=$S"

# archive check for Linea historical block 5,079,176
ARCH="no"
if [ -n "$L" ]; then
  r=$(curl -s -m 15 -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0xe2c67A9B15e9E7FF8A9Cb0dFb8feE5609923E5DB","0x4D8A18"]}' "$L" 2>/dev/null)
  case "$r" in *"0x"*result*) ARCH="yes";; esac
fi

if [ -n "${GITHUB_ENV:-}" ]; then
  [ -n "$L" ] && echo "LINEA_RPC_URL=$L" >> "$GITHUB_ENV"
  [ -n "$S" ] && echo "SCROLL_RPC_URL=$S" >> "$GITHUB_ENV"
fi

cat > ci-out/rpc-pick.json <<EOF
{"linea":"$L","scroll":"$S","linea_archive_block_5079176":"$ARCH","checked_at":"$(date -u +%FT%TZ)"}
EOF
cat ci-out/rpc-pick.json
