#!/bin/bash
# Dev-inspect matrix: call storage::version_verification(storage) on each package version
GQL=https://graphql.mainnet.sui.io/graphql
STORAGE=0xbb4e2f4b6205c2e2a2db47aeb4f830796ec7c005f88537ee775986639bc442fe
ORIG=0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca
# get version addresses
VERS=$(curl -s -m 30 $GQL -H 'Content-Type: application/json' -d "{\"query\":\"{ packageVersions(address: \\\"$ORIG\\\", first: 50) { nodes { address version } } }\"}")
echo "$VERS" > gate_matrix_versions.json
for row in $(echo "$VERS" | jq -r '.data.packageVersions.nodes[] | @base64'); do
  addr=$(echo $row | base64 -d | jq -r .address); ver=$(echo $row | base64 -d | jq -r .version)
  body=$(cat <<JSON
{"query":"query(\$tx: JSON!) { simulateTransaction(transaction: \$tx, checksEnabled: false) { effects { status } } }","variables":{"tx":{"sender":"0x0000000000000000000000000000000000000000000000000000000000000000","kind":{"kind":"PROGRAMMABLE_TRANSACTION","programmableTransaction":{"inputs":[{"kind":"SHARED","objectId":"$STORAGE","mutability":"IMMUTABLE"}],"commands":[{"moveCall":{"package":"$addr","module":"storage","function":"version_verification","arguments":[{"kind":"INPUT","input":0}]}}]}}}}}
JSON
)
  resp=$(echo "$body" | curl -s -m 30 $GQL -H 'Content-Type: application/json' --data-binary @-)
  status=$(echo "$resp" | jq -r '.data.simulateTransaction.effects.status // "ERR"')
  err=$(echo "$resp" | jq -r '.errors[0].message // empty')
  echo "v$ver $addr -> $status $err"
  sleep 0.4
done
