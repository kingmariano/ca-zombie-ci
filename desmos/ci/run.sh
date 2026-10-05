#!/usr/bin/env bash
# C2-10 Desmos — heavy evidence pull + cost model (runs on GitHub Actions).
# Read-only: public REST/gRPC endpoints only. No keys, no transactions.
# Writes raw evidence to ci-out/raw/, model output to ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out/raw
RAW=ci-out/raw
REST="https://api.mainnet.desmos.network"
REST_ALT="https://desmos-rest.staketab.org"
OSMO="https://lcd.osmosis.zone"
GRPC="grpc.mainnet.desmos.network:443"
UA='User-Agent: zombie-hunt-ci'

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

get() { # get <url> <outfile> [tries]
  local url="$1" out="$2" tries="${3:-6}" i
  for i in $(seq 1 "$tries"); do
    if curl -s -m 30 -H "$UA" "$url" -o "$out" 2>/dev/null; then
      if jq -e . "$out" >/dev/null 2>&1; then return 0; fi
    fi
    sleep 2
  done
  log "WARN fetch failed: $url"
  return 1
}

# ---------------------------------------------------------------- grpcurl
if ! command -v grpcurl >/dev/null 2>&1; then
  log "installing grpcurl"
  curl -sL -o /tmp/grpcurl.tar.gz "https://github.com/fullstorydev/grpcurl/releases/download/v1.9.3/grpcurl_1.9.3_linux_x86_64.tar.gz" \
    && tar -xzf /tmp/grpcurl.tar.gz -C /tmp grpcurl || true
fi
GRPCURL=$(command -v grpcurl 2>/dev/null || echo /tmp/grpcurl)
"$GRPCURL" -version >/dev/null 2>&1 || { log "FATAL: no grpcurl"; exit 1; }

# ---------------------------------------------------------------- 1. height
log "1. height"
get "$REST/cosmos/base/tendermint/v1beta1/blocks/latest" "$RAW/latest-block.json"
python3 - "$RAW" <<'PY'
import json,sys
raw=sys.argv[1]
b=json.load(open(f"{raw}/latest-block.json"))
h=b["block"]["header"]
json.dump({"height":h["height"],"time":h["time"]},open(f"{raw}/height.json","w"),indent=2)
PY

# ---------------------------------------------------------------- 2. gov params
log "2. gov params (legacy subspace gov)"
for k in depositparams votingparams tallyparams; do
  get "$REST/cosmos/params/v1beta1/params?subspace=gov&key=$k" "$RAW/gov-$k.json"
done
python3 - "$RAW" <<'PY'
import json,sys
raw=sys.argv[1]
out={}
try:
    v=json.load(open(f"{raw}/gov-depositparams.json"))["param"]["value"]
    out.update(json.loads(v))
except Exception as e: out["deposit_err"]=str(e)
try:
    v=json.load(open(f"{raw}/gov-votingparams.json"))["param"]["value"]
    out.update(json.loads(v))
except Exception as e: out["voting_err"]=str(e)
try:
    v=json.load(open(f"{raw}/gov-tallyparams.json"))["param"]["value"]
    out.update(json.loads(v))
except Exception as e: out["tally_err"]=str(e)
json.dump(out,open(f"{raw}/gov-params.json","w"),indent=2)
print(json.dumps(out))
PY

# ---------------------------------------------------------------- 3. economics
log "3. staking / community pool / supply / distribution / mint"
get "$REST/cosmos/staking/v1beta1/pool" "$RAW/staking-pool-raw.json"
get "$REST/cosmos/distribution/v1beta1/community_pool" "$RAW/community-pool-raw.json"
get "$REST/cosmos/bank/v1beta1/supply" "$RAW/supply-raw.json"
get "$REST/cosmos/distribution/v1beta1/params" "$RAW/distribution-params.json"
get "$REST/cosmos/mint/v1beta1/params" "$RAW/mint-params.json"
get "$REST/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200" "$RAW/validators-raw.json"
python3 - "$RAW" <<'PY'
import json,sys
raw=sys.argv[1]
def L(n,d=None):
    try: return json.load(open(f"{raw}/{n}"))
    except Exception: return d
json.dump(L("staking-pool-raw.json",{}).get("pool",{}),open(f"{raw}/staking-pool.json","w"),indent=2)
json.dump(L("community-pool-raw.json",{}),open(f"{raw}/community-pool.json","w"),indent=2)
json.dump(L("supply-raw.json",{}),open(f"{raw}/supply.json","w"),indent=2)
json.dump(L("validators-raw.json",{}),open(f"{raw}/validators.json","w"),indent=2)
PY

# ---------------------------------------------------------------- 4. wasm
log "4. wasm params/codes/contracts"
"$GRPCURL" -max-time 30 "$GRPC" cosmwasm.wasm.v1.Query/Params > "$RAW/wasm-params.json" 2>/dev/null
"$GRPCURL" -max-time 30 "$GRPC" cosmwasm.wasm.v1.Query/Codes > "$RAW/wasm-codes.json" 2>/dev/null
python3 - "$RAW" "$GRPCURL" "$GRPC" <<'PY'
import json,sys,subprocess
raw,g,grpc=sys.argv[1],sys.argv[2],sys.argv[3]
codes=[]
try:
    d=json.load(open(f"{raw}/wasm-codes.json"))
    codes=d.get("codeInfos") or d.get("code_infos") or []
except Exception: pass
contracts={}
for c in codes:
    cid=c.get("codeId") or c.get("code_id")
    try:
        r=subprocess.run([g,"-max-time","20","-d",json.dumps({"code_id":str(cid)}),grpc,"cosmwasm.wasm.v1.Query/ContractsByCode"],capture_output=True,text=True,timeout=40)
        contracts[str(cid)]=json.loads(r.stdout).get("contracts",[])
    except Exception:
        contracts[str(cid)]=[]
json.dump({"contracts":contracts},open(f"{raw}/wasm-contracts.json","w"),indent=2)
json.dump({"n_codes":len(codes),"n_contracts":sum(len(v) for v in contracts.values()),"contracts":contracts},open(f"{raw}/wasm-contracts-summary.json","w"),indent=2)
print("codes",len(codes),"contracts",sum(len(v) for v in contracts.values()))
PY

# contract native balances
python3 - "$RAW" "$REST" <<'PY'
import json,sys,urllib.request,time
raw,rest=sys.argv[1],sys.argv[2]
d=json.load(open(f"{raw}/wasm-contracts.json"))
out={}
n=0
for cid,cl in d.get("contracts",{}).items():
    for c in cl:
        n+=1
        try:
            req=urllib.request.Request(f"{rest}/cosmos/bank/v1beta1/balances/{c}",headers={"User-Agent":"zombie-hunt-ci"})
            out[c]=json.load(urllib.request.urlopen(req,timeout=20)).get("balances",[])
        except Exception:
            out[c]=[]
        time.sleep(0.05)
json.dump({"contracts":out,"n":n},open(f"{raw}/contract-balances.json","w"),indent=2)
print("balances for",n,"contracts")
PY

# ---------------------------------------------------------------- 5. IBC
log "5. IBC channels / client freshness"
get "$REST/ibc/core/channel/v1/channels?pagination.limit=200" "$RAW/ibc-channels.json"
get "$REST/ibc/core/client/v1/client_states/07-tendermint-6" "$RAW/ibc-client-raw.json"
python3 - "$RAW" <<'PY'
import json,sys
raw=sys.argv[1]
try:
    d=json.load(open(f"{raw}/ibc-client-raw.json"))
    cs=d.get("client_state",{})
    out={"client_id":"07-tendermint-6","chain_id":cs.get("chain_id"),"latest_height":cs.get("latest_height"),
         "trusting_period":cs.get("trusting_period"),"unbonding_period":cs.get("unbonding_period"),
         "frozen_height":cs.get("frozen_height")}
except Exception as e:
    out={"error":str(e)}
json.dump(out,open(f"{raw}/ibc-client.json","w"),indent=2)
PY

# escrow balances for all transfer channels
python3 - "$RAW" "$REST" <<'PY'
import json,sys,hashlib,urllib.request,time
raw,rest=sys.argv[1],sys.argv[2]
CH="qpzry9x8gf2tvdw0s3jn54khce6mua7l"
def pm(v):
    G=[0x3b6a57b2,0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3];c=1
    for x in v:
        b=c>>25;c=(c&0x1ffffff)<<5^x
        for i in range(5): c^=G[i] if ((b>>i)&1) else 0
    return c
def he(h): return [ord(x)>>5 for x in h]+[0]+[ord(x)&31 for x in h]
def cv(d,f,t):
    a=0;b=0;r=[]
    for x in d:
        a=(a<<f)|x;b+=f
        while b>=t: b-=t;r.append((a>>b)&((1<<t)-1))
    if b: r.append((a<<(t-b))&((1<<t)-1))
    return r
def enc(h,d):
    p=pm(he(h)+d+[0]*6)^1;cs=[(p>>5*(5-i))&31 for i in range(6)]
    return h+"1"+"".join(CH[k] for k in d+cs)
def escrow(port,chan):
    pre=b"ics20-1\x00"+(port+"/"+chan).encode()
    return enc("desmos",cv(hashlib.sha256(pre).digest()[:20],8,5))
try:
    chans=json.load(open(f"{raw}/ibc-channels.json")).get("channels",[])
except Exception:
    chans=[]
out={}
for ch in chans:
    if ch.get("port_id")!="transfer":
        continue
    cid=ch.get("channel_id")
    addr=escrow("transfer",cid)
    try:
        req=urllib.request.Request(f"{rest}/cosmos/bank/v1beta1/balances/{addr}",headers={"User-Agent":"zombie-hunt-ci"})
        bals=json.load(urllib.request.urlopen(req,timeout=20)).get("balances",[])
    except Exception:
        bals=[]
    out[cid]={"address":addr,"state":ch.get("state"),"counterparty":ch.get("counterparty"),"balances":bals}
    time.sleep(0.05)
json.dump(out,open(f"{raw}/escrows.json","w"),indent=2)
print("escrows for",len(out),"transfer channels")
PY

# ---------------------------------------------------------------- 6. Osmosis
log "6. Osmosis pools scan (all pages) + DSM supply"
python3 - "$RAW" "$OSMO" <<'PY'
import json,sys,urllib.request,urllib.parse,time,hashlib
raw,osmo=sys.argv[1],sys.argv[2]
DSM_DENOM="ibc/"+hashlib.sha256("transfer/channel-135/udsm".encode()).hexdigest().upper()
def fetch(url):
    req=urllib.request.Request(url,headers={"User-Agent":"zombie-hunt-ci"})
    return json.load(urllib.request.urlopen(req,timeout=30))
pools=[]; key=None; page=0
while page<12:
    url=f"{osmo}/osmosis/gamm/v1beta1/pools?pagination.limit=1000"
    if key: url+="&pagination.key="+urllib.parse.quote(key)
    try:
        d=fetch(url)
    except Exception as e:
        print("gamm page err",e); break
    pools.extend(d.get("pools",[]))
    key=(d.get("pagination") or {}).get("next_key")
    page+=1
    if not key: break
    time.sleep(0.3)
# concentrated liquidity pools
cl=[]
key=None; page=0
while page<12:
    url=f"{osmo}/osmosis/concentratedliquidity/v1beta1/pools?pagination.limit=1000"
    if key: url+="&pagination.key="+urllib.parse.quote(key)
    try:
        d=fetch(url)
    except Exception as e:
        print("cl page err",e); break
    cl.extend(d.get("pools",[]))
    key=(d.get("pagination") or {}).get("next_key")
    page+=1
    if not key: break
    time.sleep(0.3)
sel=[]
for p in pools:
    blob=json.dumps(p)
    if DSM_DENOM in blob:
        sel.append({"id":p.get("id"),"type":"weighted/stableswap",
                    "assets":p.get("pool_assets") or p.get("pool_liquidity") or [],
                    "swap_fee":(p.get("pool_params") or {}).get("swap_fee")})
for p in cl:
    if DSM_DENOM in json.dumps(p):
        addr=p.get("address")
        bals=[]
        if addr:
            try:
                bals=fetch(f"{osmo}/cosmos/bank/v1beta1/balances/"+addr).get("balances",[])
            except Exception as e:
                print("cl bal err",e)
        sel.append({"id":p.get("id"),"type":"concentrated",
                    "assets":[{"denom":b.get("denom"),"amount":b.get("amount")} for b in bals],
                    "swap_fee":p.get("spread_factor")})
json.dump(sel,open(f"{raw}/osmosis-pools.json","w"),indent=2)
print("gamm pools",len(pools),"cl pools",len(cl),"dsm pools",len(sel))
try:
    s=fetch(f"{osmo}/cosmos/bank/v1beta1/supply/by_denom?denom="+urllib.parse.quote(DSM_DENOM))
    json.dump(s,open(f"{raw}/osmosis-dsm-supply.json","w"),indent=2)
except Exception as e:
    print("supply err",e)
PY

# prices
log "7. prices"
curl -s -m 25 -H "$UA" "https://coins.llama.fi/prices/current/coingecko:cosmos,coingecko:osmosis" -o "$RAW/llama-prices.json" || true
curl -s -m 25 -H "$UA" "https://api.coingecko.com/api/v3/simple/price?ids=desmos&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true" -o "$RAW/cg-dsm.json" || true
python3 - "$RAW" <<'PY'
import json,sys
raw=sys.argv[1]
out={}
try:
    d=json.load(open(f"{raw}/llama-prices.json"))["coins"]
    out["atom_usd"]=d.get("coingecko:cosmos",{}).get("price",0)
    out["osmo_usd"]=d.get("coingecko:osmosis",{}).get("price",0)
except Exception: pass
try:
    d=json.load(open(f"{raw}/cg-dsm.json"))
    out["dsm_usd_coingecko"]=d.get("desmos",{}).get("usd",0)
    out["dsm_market_cap"]=d.get("desmos",{}).get("usd_market_cap",0)
    out["dsm_vol_24h"]=d.get("desmos",{}).get("usd_24h_vol",0)
except Exception: pass
json.dump(out,open(f"{raw}/prices.json","w"),indent=2)
print(out)
PY

# ---------------------------------------------------------------- 8. endpoint survey
log "8. endpoint version survey"
python3 - "$RAW" <<'PY'
import json,sys,urllib.request
raw=sys.argv[1]
endpoints=[
 ("REST","https://api.mainnet.desmos.network"),
 ("REST","https://desmos-rest.staketab.org"),
 ("REST","https://lcd.desmos.bronbro.io"),
 ("REST","https://vidulum.declab.pro"),
 ("REST","https://desmos-api.noders.services"),
 ("REST","https://rest.cosmos.directory/desmos"),
 ("RPC","https://rpc.mainnet.desmos.network"),
 ("RPC","https://desmos-rpc.staketab.org"),
 ("RPC","https://rpc.desmos.bronbro.io"),
 ("RPC","https://desmos.declab.pro:26613"),
 ("RPC","https://desmos-rpc.noders.services"),
 ("RPC","https://rpc.cosmos.directory/desmos"),
]
out=[]
for kind,ep in endpoints:
    url=ep+("/cosmos/base/tendermint/v1beta1/node_info" if kind=="REST" else "/status")
    rec={"kind":kind,"endpoint":ep}
    try:
        req=urllib.request.Request(url,headers={"User-Agent":"zombie-hunt-ci"})
        d=json.load(urllib.request.urlopen(req,timeout=15))
        if kind=="REST":
            av=d.get("application_version",{})
        else:
            av=d.get("node_info",{})
            # cometbft /status has no build_deps; app version only via REST
            rec.update({"app_version":av.get("version"),"moniker":av.get("moniker")})
            out.append(rec); continue
        deps={x.get("path"):x.get("version") for x in av.get("build_deps",[])}
        rec.update({
          "app_version":av.get("version"),
          "git_commit":(av.get("git_commit") or "")[:10],
          "moniker":(d.get("default_node_info") or {}).get("moniker"),
          "sdk":deps.get("github.com/cosmos/cosmos-sdk"),
          "wasmvm":deps.get("github.com/CosmWasm/wasmvm"),
          "wasmd":deps.get("github.com/CosmWasm/wasmd"),
          "ibc_go":deps.get("github.com/cosmos/ibc-go/v7") or deps.get("github.com/cosmos/ibc-go/v6") or deps.get("github.com/cosmos/ibc-go/v8"),
          "cometbft":deps.get("github.com/cometbft/cometbft"),
        })
    except Exception as e:
        rec["error"]=str(e)[:120]
    out.append(rec)
json.dump(out,open(f"{raw}/endpoint-survey.json","w"),indent=2)
for r in out: print(r.get("kind"),r.get("endpoint"),r.get("app_version"),r.get("wasmvm"),r.get("ibc_go"),r.get("error",""))
PY

# ---------------------------------------------------------------- 9. cost model
log "9. cost model"
python3 analysis/cost_model.py "$RAW" ci-out | tee "$RAW/cost-model-stdout.txt"

# ---------------------------------------------------------------- 9b. assertions
log "9b. assertions"
ASSERT_RC=0
python3 ci/assertions.py "$RAW" ci-out | tee "$RAW/assertions-stdout.txt" || ASSERT_RC=$?

# ---------------------------------------------------------------- 10. manifest
log "10. manifest"
{
  echo "# C2-10 Desmos — CI evidence manifest"
  echo
  echo "Run: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(hostname)"
  echo
  echo "| file | bytes |"
  echo "|---|---|"
  for f in "$RAW"/*.json; do echo "| $(basename "$f") | $(stat -c%s "$f") |"; done
  echo
  echo "## Key headline (from cost-model.json)"
  python3 -c "import json;d=json.load(open('ci-out/cost-model.json'));print(json.dumps({'height':d['height'],'bonded_dsm':d['staking']['bonded_dsm'],'cp_dsm':d['community_pool']['dsm'],'dsm_price':d['dsm_price_usd'],'quorum_dsm':d['capture']['quorum_dsm'],'cp_realizable_usd':d['capture']['cp_realizable_dump_usd'],'onmarket_infeasible':d['capture']['onmarket_infeasible']},indent=2))"
} > ci-out/MANIFEST.md

# sanity: fail the job if the core snapshot is missing
for f in height.json gov-params.json staking-pool.json community-pool.json osmosis-pools.json; do
  [ -s "$RAW/$f" ] || { log "FATAL missing $f"; exit 1; }
done
log "DONE"
exit "${ASSERT_RC:-0}"
