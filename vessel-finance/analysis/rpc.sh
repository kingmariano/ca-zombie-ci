#!/bin/bash
# Keyless public Scroll RPC (publicnode). Read-only queries.
RPC=${SCROLL_RPC:-https://scroll-rpc.publicnode.com}
rpc() { curl -s -m 30 -X POST "$RPC" -H 'Content-Type: application/json' -d "$1"; echo; }
batch() { cat <<JSON
$1
JSON
}
