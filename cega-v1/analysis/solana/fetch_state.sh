#!/usr/bin/env bash
# Fetch Cega V1 Solana on-chain state. READ-ONLY. Rate-limit friendly.
set -u
RPC="${RPC:-https://api.mainnet-beta.solana.com}"
PROG="3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs"
PROGDATA="28qdJRKpfu1VGBbrSk7MEhdQV2fnfLyRNC4vsv6rVtQc"
D="/home/heisenberg/CA/cega-v1/analysis/solana"
TOKEN="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
TOKEN22="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"

rpc() { # $1 = name, $2 = json body
  curl -s -m 40 "$RPC" -H 'Content-Type: application/json' -d "$2" > "$D/$1"
  sleep 0.7
}

# 1. Raw product accounts (285 bytes)
rpc products_raw.json "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getProgramAccounts\",\"params\":[\"$PROG\",{\"encoding\":\"base64\",\"filters\":[{\"dataSize\":285}]}]}"

# 2. ProgramData account (full)
rpc programdata.json "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getAccountInfo\",\"params\":[\"$PROGDATA\",{\"encoding\":\"base64\"}]}"

# 3. Token accounts owned by the program itself
rpc token_accts_program.json "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTokenAccountsByOwner\",\"params\":[\"$PROG\",{\"programId\":\"$TOKEN\"},{\"encoding\":\"jsonParsed\"}]}"
rpc token22_accts_program.json "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTokenAccountsByOwner\",\"params\":[\"$PROG\",{\"programId\":\"$TOKEN22\"},{\"encoding\":\"jsonParsed\"}]}"

# 4. For each product PDA, token accounts where owner = PDA
jq -r '.result[] | .pubkey' "$D/products_raw.json" | while read -r pda; do
  curl -s -m 40 "$RPC" -H 'Content-Type: application/json' -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTokenAccountsByOwner\",\"params\":[\"$pda\",{\"programId\":\"$TOKEN\"},{\"encoding\":\"jsonParsed\",\"dataSlice\":{\"offset\":64,\"length\":72}}]}" > "$D/tokens_$pda.json"
  sleep 0.7
  curl -s -m 40 "$RPC" -H 'Content-Type: application/json' -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getBalance\",\"params\":[\"$pda\"]}" > "$D/balance_$pda.json"
  sleep 0.7
done

# 5. Signatures for program (last 100)
rpc sigs_program.json "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getSignaturesForAddress\",\"params\":[\"$PROG\",{\"limit\":100}]}"

echo "FETCH DONE"
