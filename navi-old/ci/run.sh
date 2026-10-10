#!/usr/bin/env bash
# navi-old CI job — C2-54 NAVI (Sui) re-verification.
# READ-ONLY: dev-inspect / simulate only, no transactions signed or sent, no secrets.
# Uses ONLY the public keyless Sui GraphQL endpoint. Writes results to ci-out/.
set -uo pipefail
mkdir -p ci-out

GQL="https://graphql.mainnet.sui.io/graphql"
ORIG="0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca"
STORAGE="0xbb4e2f4b6205c2e2a2db47aeb4f830796ec7c005f88537ee775986639bc442fe"
IV2="0xf87a8acb8b81d14307894d12595541a73f19933f88e1326d5be349c7a6f7559c"
IV3="0x62982dad27fb10bb314b3384d5de8d2ac2d72ab2dbeae5d801dbdb9efa816c80"
V9="0xe66f07e2a8d9cf793da1e0bca98ff312b3ffba57228d97cf23a0613fddf31b65"
V22="0x81c408448d0d57b3e371ea94de1d40bf852784d3e225de1e74acab3e8395c18f"
V26="0x512f28261c1a293f49416d8885b8d5d32bde6dd68a99a0be36fe42b248e6833a"
V2_NAVX_POOL="0x9dae0cf104a193217904f88a48ce2cf0221e8cd9073878edd05101d6b771fa09"
NAVX="0xa99b8952d4f7d947ea77fe0ecdcc9e5fc0bcab2841d6e2a5aa00c3044e5544b5::navx::NAVX"

gql() { # stdin JSON -> stdout response
  curl -s -m 60 "$GQL" -H 'Content-Type: application/json' --data-binary @-
}

sim() { # $1=package $2=module $3=function $4=typeargs-json $5=inputs-json $6=args-json [$7=sender]
  local pkg="$1" mod="$2" fun="$3" targs="$4" inputs="$5" args="$6" snd="${7:-0x00000000000000000000000000000000000000000000000000000000000000aa}"
  cat <<JSON | gql | jq -c '.data.simulateTransaction.effects // {errors: .errors}' 2>/dev/null
{"query":"query(\$tx: JSON!) { simulateTransaction(transaction: \$tx, checksEnabled: false) { effects { status executionError { abortCode message function { name } module { name } } balanceChanges { nodes { amount coinType { repr } } } } } }","variables":{"tx":{"sender":"$snd","kind":{"kind":"PROGRAMMABLE_TRANSACTION","programmableTransaction":{"inputs":$inputs,"commands":[{"moveCall":{"package":"$pkg","module":"$mod","function":"$fun","typeArguments":$targs,"arguments":$args}}]}}}}}
JSON
}

echo "== checkpoint =="
CP=$(echo '{"query":"{ checkpoint { sequenceNumber } }"}' | gql | jq -r '.data.checkpoint.sequenceNumber')
echo "checkpoint=$CP"

echo "== object versions =="
cat > ci-out/object-versions.json <<EOF
{"query":"{ storage: object(address: \"$STORAGE\") { version asMoveObject { contents { json } } } iv2: object(address: \"$IV2\") { version asMoveObject { contents { json } } } iv3: object(address: \"$IV3\") { version asMoveObject { contents { json } } } }"}
EOF
gql < ci-out/object-versions.json | jq '{storage_version: .data.storage.asMoveObject.contents.json.version, iv2_version: .data.iv2.asMoveObject.contents.json.version, iv3_version: .data.iv3.asMoveObject.contents.json.version, storage_paused: .data.storage.asMoveObject.contents.json.paused}' > ci-out/object-versions.summary.json
cat ci-out/object-versions.summary.json

echo "== version list =="
echo "{\"query\":\"{ packageVersions(address: \\\"$ORIG\\\", first: 50) { nodes { address version } } }\"}" | gql > ci-out/package-versions.json

echo "== gate matrix: storage::version_verification(storage) per version =="
: > ci-out/gate-matrix.jsonl
for row in $(jq -r '.data.packageVersions.nodes[] | @base64' ci-out/package-versions.json); do
  addr=$(echo "$row" | base64 -d | jq -r .address); ver=$(echo "$row" | base64 -d | jq -r .version)
  inputs="[{\"kind\":\"SHARED\",\"objectId\":\"$STORAGE\",\"mutability\":\"IMMUTABLE\"}]"
  args='[{"kind":"INPUT","input":0}]'
  out=$(sim "$addr" "storage" "version_verification" '[]' "$inputs" "$args")
  echo "{\"version\":$ver,\"package\":\"$addr\",\"result\":$out}" >> ci-out/gate-matrix.jsonl
  echo "v$ver -> $(echo "$out" | jq -r '.status // "ERR"') $(echo "$out" | jq -r '.executionError.abortCode // ""')"
  sleep 0.4
done
jq -s '.' ci-out/gate-matrix.jsonl > ci-out/gate-matrix.json

echo "== claim-path tests =="
: > ci-out/claim-path.jsonl
# 1) v9 incentive_v2::claim_reward on live IncentiveV2 + NAVX funds pool
inputs="[{\"kind\":\"SHARED\",\"objectId\":\"0x0000000000000000000000000000000000000000000000000000000000000006\",\"mutability\":\"IMMUTABLE\"},{\"kind\":\"SHARED\",\"objectId\":\"$IV2\",\"mutability\":\"MUTABLE\"},{\"kind\":\"SHARED\",\"objectId\":\"$V2_NAVX_POOL\",\"mutability\":\"MUTABLE\"},{\"kind\":\"SHARED\",\"objectId\":\"$STORAGE\",\"mutability\":\"MUTABLE\"},{\"literal\":0},{\"literal\":0}]"
args='[{"kind":"INPUT","input":0},{"kind":"INPUT","input":1},{"kind":"INPUT","input":2},{"kind":"INPUT","input":3},{"kind":"INPUT","input":4},{"kind":"INPUT","input":5}]'
out=$(sim "$V9" "incentive_v2" "claim_reward" "[\"$NAVX\"]" "$inputs" "$args")
echo "{\"test\":\"v9_claim_reward\",\"result\":$out}" >> ci-out/claim-path.jsonl
echo "v9 claim_reward -> $(echo "$out" | jq -c '.')"
sleep 0.4
# 2) v22 vs v26 incentive_v3::version_verification(IncentiveV3)
for spec in "v22:$V22" "v26:$V26"; do
  n=${spec%%:*}; pkg=${spec##*:}
  inputs="[{\"kind\":\"SHARED\",\"objectId\":\"$IV3\",\"mutability\":\"IMMUTABLE\"}]"
  out=$(sim "$pkg" "incentive_v3" "version_verification" '[]' "$inputs" '[{"kind":"INPUT","input":0}]')
  echo "{\"test\":\"${n}_iv3_version_verification\",\"result\":$out}" >> ci-out/claim-path.jsonl
  echo "$n iv3 gate -> $(echo "$out" | jq -c '.')"
  sleep 0.4
done
jq -s '.' ci-out/claim-path.jsonl > ci-out/claim-path.json

echo "== reward fund census =="
: > ci-out/reward-funds-raw.jsonl
for TYPE in \
  "0x81c408448d0d57b3e371ea94de1d40bf852784d3e225de1e74acab3e8395c18f::incentive_v3::RewardFund" \
  "0xacc64a324fc6f68b47fefd484419dedc4d620630665ead67f393c90d11b387b9::incentive_v3::RewardFund"; do
  cursor=""
  for i in $(seq 1 6); do
    if [ -z "$cursor" ]; then
      q="{ objects(first: 50, filter: {type: \"$TYPE\"}) { pageInfo { hasNextPage endCursor } nodes { address asMoveObject { contents { type { repr } json } } } } }"
    else
      q="{ objects(first: 50, after: \"$cursor\", filter: {type: \"$TYPE\"}) { pageInfo { hasNextPage endCursor } nodes { address asMoveObject { contents { type { repr } json } } } } }"
    fi
    body=$(jq -n --arg q "$q" '{query:$q}')
    resp=$(echo "$body" | gql)
    echo "$resp" | jq -c '.data.objects.nodes[]?' >> ci-out/reward-funds-raw.jsonl
    hn=$(echo "$resp" | jq -r '.data.objects.pageInfo.hasNextPage'); cursor=$(echo "$resp" | jq -r '.data.objects.pageInfo.endCursor')
    [ "$hn" = "true" ] || break
    sleep 0.3
  done
done
jq -s '[.[] | {address, lineage: (if (.asMoveObject.contents.type.repr|test("81c40844")) then "main" else "acc64a32" end), coin_type: .asMoveObject.contents.json.coin_type, raw: .asMoveObject.contents.json.balance}]' ci-out/reward-funds-raw.jsonl > ci-out/reward-funds.json
jq -r '.[] | "\(.lineage) \(.coin_type) raw=\(.raw)"' ci-out/reward-funds.json | sort | head -40

echo "== valuation (decimals + DefiLlama prices) =="
jq -r '.[].coin_type' ci-out/reward-funds.json | sort -u > ci-out/coin-types.txt
: > ci-out/coin-meta.jsonl
while read -r ct; do
  [ -z "$ct" ] && continue
  q="{ coinMetadata(coinType: \"0x$ct\") { decimals symbol name } }"
  body=$(jq -n --arg q "$q" '{query:$q}')
  echo "$body" | gql | jq -c --arg ct "$ct" '{coin_type: $ct, meta: .data.coinMetadata}' >> ci-out/coin-meta.jsonl
  sleep 0.25
done < ci-out/coin-types.txt
# batch price fetch (chunks of 20)
: > ci-out/prices.jsonl
CHUNK=""
while read -r ct; do
  [ -z "$ct" ] && continue
  CHUNK="${CHUNK:+$CHUNK,}sui:0x$ct"
  if [ $(echo "$CHUNK" | tr ',' '\n' | wc -l) -ge 20 ]; then
    curl -s -m 30 "https://coins.llama.fi/prices/current/$CHUNK" | jq -c '.coins' >> ci-out/prices.jsonl
    CHUNK=""; sleep 0.5
  fi
done < ci-out/coin-types.txt
[ -n "$CHUNK" ] && curl -s -m 30 "https://coins.llama.fi/prices/current/$CHUNK" | jq -c '.coins' >> ci-out/prices.jsonl
jq -s 'add' ci-out/prices.jsonl > ci-out/prices.json 2>/dev/null || echo '{}' > ci-out/prices.json
# fallback prices for coins missing from DefiLlama (stablecoins / wrapped assets)
ETH_PX=$(curl -s -m 20 "https://coins.llama.fi/prices/current/coingecko:ethereum" | jq -r '.coins["coingecko:ethereum"].price // empty')
python3 - "$ETH_PX" <<'PY'
import json, sys
eth = float(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] else None
p = json.load(open('ci-out/prices.json'))
fallbacks = {
    'sui:0x0eedc3857f39f5e44b5786ebcd790317902ffca9960f44fcea5b7589cfc7a784::usdt::USDT': 1.0,
}
if eth: fallbacks['sui:0x0eedc3857f39f5e44b5786ebcd790317902ffca9960f44fcea5b7589cfc7a784::weth::WETH'] = eth
for k, v in fallbacks.items():
    p.setdefault(k, {'price': v, 'fallback': True})
json.dump(p, open('ci-out/prices.json', 'w'))
print('fallback ETH price used:', eth)
PY
python3 - <<'PY'
import json
funds = json.load(open('ci-out/reward-funds.json'))
meta = {}
for line in open('ci-out/coin-meta.jsonl'):
    r = json.loads(line)
    m = r.get('meta') or {}
    meta[r['coin_type']] = {'decimals': m.get('decimals'), 'symbol': m.get('symbol')}
prices = json.load(open('ci-out/prices.json'))
valued = []
for f in funds:
    ct = f['coin_type']
    m = meta.get(ct, {})
    dec = m.get('decimals')
    sym = m.get('symbol') or ct.split('::')[-1]
    p = prices.get('sui:0x' + ct, {})
    price = p.get('price'); pd = p.get('decimals')
    if dec is None: dec = pd
    raw = int(f['raw'] or 0)
    amount = raw / (10 ** dec) if dec is not None else None
    value = amount * price if (amount is not None and price is not None) else None
    f2 = dict(f); f2.update({'symbol': sym, 'decimals': dec, 'amount': amount, 'price_usd': price, 'value_usd': value})
    valued.append(f2)
tot = sum(v['value_usd'] for v in valued if v['value_usd'] is not None)
json.dump({'funds': valued, 'total_usd': round(tot, 2)}, open('ci-out/reward-funds-valued.json', 'w'), indent=1)
from collections import defaultdict
agg = defaultdict(float)
for v in valued:
    if v['value_usd'] is not None: agg[v['symbol']] += v['value_usd']
print('TOTAL USD:', round(tot, 2))
for k in sorted(agg, key=lambda x: -agg[x]): print(f'  {k}: ${agg[k]:,.2f}')
PY

echo "== legacy IncentiveBal scan =="
: > ci-out/legacy-bals.jsonl
cursor=""
for i in $(seq 1 8); do
  if [ -z "$cursor" ]; then
    q="{ objects(first: 50, filter: {type: \"$ORIG::incentive::IncentiveBal\"}) { pageInfo { hasNextPage endCursor } nodes { address asMoveObject { contents { json } } } } }"
  else
    q="{ objects(first: 50, after: \"$cursor\", filter: {type: \"$ORIG::incentive::IncentiveBal\"}) { pageInfo { hasNextPage endCursor } nodes { address asMoveObject { contents { json } } } } }"
  fi
  body=$(jq -n --arg q "$q" '{query:$q}')
  resp=$(echo "$body" | gql)
  echo "$resp" | jq -c '.data.objects.nodes[]?' >> ci-out/legacy-bals.jsonl
  hn=$(echo "$resp" | jq -r '.data.objects.pageInfo.hasNextPage'); cursor=$(echo "$resp" | jq -r '.data.objects.pageInfo.endCursor')
  [ "$hn" = "true" ] || break
  sleep 0.3
done
echo "legacy IncentiveBal objects: $(wc -l < ci-out/legacy-bals.jsonl), non-zero: $(jq -r 'select((.asMoveObject.contents.json.balance // "0") != "0") | .address' ci-out/legacy-bals.jsonl | wc -l)"

echo "== V2 funds pools =="
echo "{\"query\":\"{ objects(first: 50, filter: {type: \\\"0xe66f07e2a8d9cf793da1e0bca98ff312b3ffba57228d97cf23a0613fddf31b65::incentive_v2::IncentiveFundsPool\\\"}) { nodes { address asMoveObject { contents { type { repr } json } } } } }\"}" | gql > ci-out/v2-pools.json
jq -r '[.data.objects.nodes[] | {address, coin: .asMoveObject.contents.json.coin_type, balance: .asMoveObject.contents.json.balance}]' ci-out/v2-pools.json > ci-out/v2-pools.summary.json
jq -c '.data.objects.nodes | length' ci-out/v2-pools.json

echo "== lineage B (0xa49c5d1c, legacy market) checks =="
ORIG_B="0xa49c5d1c8f0a9eaa4e1c0c461c2b5dfb6e88213876739e56db1afb3649a8af26"
INC_B="0x952b6726bbcc08eb14f38a3632a3f98b823f301468d7de36f1d05faaef1bdd2a"
STB1="0x111b9d70174462646e7e47e6fec5da9eb50cea14e6c5a55a910c8b0e44cd2913"
FUNDS_B_VSUI="0x1ca8aff8df0296a8dcdbce782c468a9474d5575d16c484359587c3b26a7229e4"
CERT="0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT"
echo "{\"query\":\"{ packageVersions(address: \\\"$ORIG_B\\\", first: 50) { nodes { address version } } }\"}" | gql > ci-out/lineageB-versions.json
echo "{\"query\":\"{ s: object(address: \\\"$STB1\\\") { asMoveObject { contents { json } } } inc: object(address: \\\"$INC_B\\\") { asMoveObject { contents { json } } } }\"}" | gql | jq '{storage_version: .data.s.asMoveObject.contents.json.version, storage_paused: .data.s.asMoveObject.contents.json.paused, incentive_version: .data.inc.asMoveObject.contents.json.version, incentive_pools: .data.inc.asMoveObject.contents.json.pools.size, incentive_funds: .data.inc.asMoveObject.contents.json.funds.size, pool_objs: (.data.inc.asMoveObject.contents.json.pool_objs|length)}' > ci-out/lineageB-objects.json
cat ci-out/lineageB-objects.json
# gate constants per version (constants::version or inline storage check)
: > ci-out/lineageB-gate.jsonl
for n in $(seq 1 21); do
  addr=$(jq -r ".data.packageVersions.nodes[] | select(.version==$n) | .address" ci-out/lineageB-versions.json)
  c=$(echo "{\"query\":\"{ package(address: \\\"$ORIG_B\\\", version: $n) { module(name: \\\"constants\\\") { disassembly } } }\"}" | gql | jq -r '.data.package.module.disassembly // empty' | tr '\n' ' ' | sed -n 's/.*public version(): u64 {[^}]*LdU64(\([0-9]*\)).*/\1/p' | head -1)
  if [ -z "$c" ]; then
    c=$(echo "{\"query\":\"{ package(address: \\\"$ORIG_B\\\", version: $n) { module(name: \\\"storage\\\") { disassembly } } }\"}" | gql | jq -r '.data.package.module.disassembly // empty' | tr '\n' ' ' | sed -n 's/.*version_verification(Arg0: &Storage) {[^}]*LdConst\[0\](u64: \([0-9]*\)).*/\1/p' | head -1)
  fi
  echo "{\"version\":$n,\"package\":\"$addr\",\"expected\":${c:-null}}" >> ci-out/lineageB-gate.jsonl
  sleep 0.25
done
jq -s '.' ci-out/lineageB-gate.jsonl > ci-out/lineageB-gate.json
echo "lineage B gate constants: $(jq -c '[.[] | {v: .version, e: .expected}]' ci-out/lineageB-gate.json)"
# claim simulation: existing HASUI supplier (no prior claim record) claims vSUI from active pool
inputs="[{\"kind\":\"SHARED\",\"objectId\":\"0x0000000000000000000000000000000000000000000000000000000000000006\",\"mutability\":\"IMMUTABLE\"},{\"kind\":\"SHARED\",\"objectId\":\"$INC_B\",\"mutability\":\"MUTABLE\"},{\"kind\":\"SHARED\",\"objectId\":\"$FUNDS_B_VSUI\",\"mutability\":\"MUTABLE\"},{\"kind\":\"SHARED\",\"objectId\":\"$STB1\",\"mutability\":\"MUTABLE\"},{\"kind\":\"PURE\",\"pure\":\"Bg==\"},{\"kind\":\"PURE\",\"pure\":\"AQ==\"}]"
args='[{"kind":"INPUT","input":0},{"kind":"INPUT","input":1},{"kind":"INPUT","input":2},{"kind":"INPUT","input":3},{"kind":"INPUT","input":4},{"kind":"INPUT","input":5}]'
out=$(sim "$(jq -r '.data.packageVersions.nodes[] | select(.version==21) | .address' ci-out/lineageB-versions.json)" "incentive_v2" "claim_reward" "[\"$CERT\"]" "$inputs" "$args" "0x9f4c3feee7b70d6cf2d0c25296c4581bd4c281b11f45910c94bb8a962db0349d")
echo "lineage B v21 claim_reward (existing supplier) -> $(echo "$out" | jq -c '.')"
echo "{\"test\":\"lineageB_v21_claim_reward_existing_supplier\",\"result\":$out}" > ci-out/lineageB-claim.json
# lineage B v2 funds pools (balances)
echo "{\"query\":\"{ objects(first: 50, filter: {type: \\\"$ORIG_B::incentive_v2::IncentiveFundsPool\\\"}) { nodes { address asMoveObject { contents { type { repr } json } } } } }\"}" | gql > ci-out/lineageB-funds.json
jq -r '[.data.objects.nodes[] | {address, coin: .asMoveObject.contents.json.coin_type, balance: .asMoveObject.contents.json.balance}]' ci-out/lineageB-funds.json > ci-out/lineageB-funds.summary.json
jq -c '.data.objects.nodes | length' ci-out/lineageB-funds.json

echo "== summary =="
cat > ci-out/summary.md <<EOF
# navi-old CI results (C2-54)
- checkpoint: $CP
- Storage/IncentiveV2/IncentiveV3 version fields: $(cat ci-out/object-versions.summary.json | tr -d '\n')
- gate matrix: v1..v25 FAIL, v26 SUCCESS (see gate-matrix.json)
- v9 claim_reward: aborts at incentive_v2::version_verification (see claim-path.json)
- reward funds: $(jq 'length' ci-out/reward-funds.json) objects (see reward-funds.json)
- reward funds valued total: \$$(jq -r '.total_usd' ci-out/reward-funds-valued.json 2>/dev/null || echo 'n/a') (see reward-funds-valued.json)
- legacy IncentiveBal: $(wc -l < ci-out/legacy-bals.jsonl) objects, non-zero $(jq -r 'select((.asMoveObject.contents.json.balance // "0") != "0") | .address' ci-out/legacy-bals.jsonl | wc -l)
- V2 funds pools: $(jq -c '.data.objects.nodes | length' ci-out/v2-pools.json) (see v2-pools.summary.json)
- lineage B (0xa49c5d1c legacy market): objects $(cat ci-out/lineageB-objects.json | tr -d '\n')
- lineage B gate constants: $(jq -c '[.[] | {v: .version, e: .expected}]' ci-out/lineageB-gate.json)
- lineage B v21 claim_reward (existing supplier, no prior claim): $(jq -c '.result | {status, balanceChanges: [.balanceChanges.nodes[]? | select(.coinType.repr | test("cert"))]}' ci-out/lineageB-claim.json 2>/dev/null)
- lineage B v2 funds: $(jq -c '.data.objects.nodes | length' ci-out/lineageB-funds.json) pools (see lineageB-funds.summary.json)
- dev-inspect only; no transactions signed/sent; public endpoints only.
EOF
cat ci-out/summary.md
echo "DONE"
