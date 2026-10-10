#!/bin/bash
GQL=https://graphql.mainnet.sui.io/graphql
STORAGE=0xbb4e2f4b6205c2e2a2db47aeb4f830796ec7c005f88537ee775986639bc442fe
for row in $(jq -r '.data.packageVersions.nodes[] | @base64' gate_matrix_versions.json); do
  addr=$(echo $row | base64 -d | jq -r .address); ver=$(echo $row | base64 -d | jq -r .version)
  body=$(cat <<JSON
{"query":"query(\$tx: JSON!) { simulateTransaction(transaction: \$tx, checksEnabled: false) { effects { status executionError { abortCode message identifier constant function { name } module { name } } } } }","variables":{"tx":{"sender":"0x0000000000000000000000000000000000000000000000000000000000000000","kind":{"kind":"PROGRAMMABLE_TRANSACTION","programmableTransaction":{"inputs":[{"kind":"SHARED","objectId":"$STORAGE","mutability":"IMMUTABLE"}],"commands":[{"moveCall":{"package":"$addr","module":"storage","function":"version_verification","arguments":[{"kind":"INPUT","input":0}]}}]}}}}}
JSON
)
  resp=$(echo "$body" | curl -s -m 30 $GQL -H 'Content-Type: application/json' --data-binary @-)
  echo "v$ver -> $(echo "$resp" | jq -c '.data.simulateTransaction.effects | {status, executionError}' )"
  sleep 0.35
done
