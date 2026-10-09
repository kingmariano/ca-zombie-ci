#!/usr/bin/env bash
# C2-27 Regen governance-capture re-verification — CI job (public, keyless endpoints only).
# Writes ci-out/regen-evidence.{json,md}. Read-only: no transactions.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out
OUT_JSON=ci-out/regen-evidence.json
OUT_MD=ci-out/regen-evidence.md
LCD="https://regen-api.polkachu.com"
RPC="https://regen-rpc.polkachu.com"
TMP=$(mktemp -d)

echo "== C2-27 Regen CI verification =="
date -u

# ---------- helpers ----------
fetch() { curl -s -m 30 "$1" -o "$2"; }

# ---------- 1. chain basics ----------
fetch "$LCD/cosmos/base/tendermint/v1beta1/node_info" "$TMP/node_info.json"
fetch "$LCD/cosmos/base/tendermint/v1beta1/blocks/latest" "$TMP/latest_block.json"
fetch "$LCD/cosmos/staking/v1beta1/pool" "$TMP/staking_pool.json"
fetch "$LCD/cosmos/bank/v1beta1/supply/by_denom?denom=uregen" "$TMP/supply_uregen.json"
fetch "$LCD/cosmos/bank/v1beta1/supply/by_denom?denom=eco.uC.NCT" "$TMP/supply_nct.json"
fetch "$LCD/cosmos/protocolpool/v1/community_pool" "$TMP/community_pool.json"
fetch "$LCD/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200" "$TMP/validators_bonded.json"
fetch "$LCD/regen/ecocredit/basket/v1/basket-balances/eco.uC.NCT?pagination.limit=500" "$TMP/basket_balances.json"
fetch "$LCD/cosmos/bank/v1beta1/denom_owners/eco.uC.NCT?pagination.limit=200" "$TMP/nct_owners.json"
fetch "$LCD/cosmos/gov/v1/proposals?pagination.limit=12&pagination.reverse=true" "$TMP/proposals.json"

# gov params via ABCI (LCD route unimplemented on this build)
curl -s -m 30 "$RPC/abci_query?path=%22%2Fcosmos.gov.v1.Query%2FParams%22&data=0x" -o "$TMP/abci_gov_params.json"

# ---------- 2. prices ----------
fetch "https://coins.llama.fi/prices/current/coingecko:regen,coingecko:toucan-protocol-nature-carbon-tonne" "$TMP/dl_prices.json"
fetch "https://api.coingecko.com/api/v3/simple/price?ids=regen,toucan-protocol-nature-carbon-tonne&vs_currencies=usd" "$TMP/cg_prices.json"
fetch "https://api.llama.fi/protocol/toucan-protocol" "$TMP/dl_toucan.json"

# ---------- 3. Polygon bridge state (public RPCs, read-only eth_call) ----------
BRIDGE=0xdC1Dfa22824Af4e423a558bbb6C53a31c3c11DCC
: > "$TMP/poly.json"
for RP in https://polygon-bor-rpc.publicnode.com https://polygon.llamarpc.com https://1rpc.io/matic; do
  if cast call "$BRIDGE" "paused()(bool)" --rpc-url "$RP" >/dev/null 2>&1; then
    echo "{\"rpc\":\"$RP\"}" > "$TMP/poly.json"
    cast call "$BRIDGE" "paused()(bool)" --rpc-url "$RP" 2>/dev/null | head -1 > "$TMP/poly_paused.txt"
    cast call "$BRIDGE" "totalTransferred()(uint256)" --rpc-url "$RP" 2>/dev/null | head -1 > "$TMP/poly_total.txt"
    for pair in "admin:0x0000000000000000000000000000000000000000000000000000000000000000:0xCDe1E9f9c7DCAd2242BD85d158A00181aA89B36b" \
                "pauser:0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a:0xd4b3e6b915c5f5ba93eebbae0939b130e15c65b9" \
                "issuer:0xcac94cc97926b467b27e8ef2be28223f53520310d15d3903d606348ece1fa886:0x87A13b0A5cE9e621f266b9C68B7014EFCFdddE0a"; do
      name=${pair%%:*}; rest=${pair#*:}; role=${rest%%:*}; addr=${rest##*:}
      echo "$name=$(cast call "$BRIDGE" "hasRole(bytes32,address)(bool)" "$role" "$addr" --rpc-url "$RP" 2>/dev/null | head -1)" >> "$TMP/poly_roles.txt"
    done
    break
  fi
done

# ---------- 4. compute model ----------
python3 - "$TMP" "$OUT_JSON" <<'PYEOF'
import json, sys, base64, struct
tmp, outjson = sys.argv[1], sys.argv[2]

def rd(name, default=None):
    try: return json.load(open(f"{tmp}/{name}"))
    except Exception: return default

def varint(b, i):
    s=0; v=0
    while True:
        x=b[i]; i+=1; v|=(x&0x7f)<<s
        if not x&0x80: break
        s+=7
    return v,i

def parse(b):
    out=[]; i=0
    while i<len(b):
        tag,i=varint(b,i); f,w=tag>>3,tag&7
        if w==0: v,i=varint(b,i); out.append((f,"varint",v))
        elif w==2:
            ln,i=varint(b,i); out.append((f,"bytes",b[i:i+ln])); i+=ln
        elif w==5: out.append((f,"fixed32",struct.unpack("<I",b[i:i+4])[0])); i+=4
        elif w==1: out.append((f,"fixed64",struct.unpack("<Q",b[i:i+8])[0])); i+=8
        else: break
    return out

# gov params decode (ABCI value: params message nested in a wrapper field)
gov={}
try:
    raw=base64.b64decode(rd("abci_gov_params.json")["result"]["response"]["value"])
    top=parse(raw)
    # locate the nested params message: the bytes field whose parse contains quorum/threshold strings
    p=None
    for f,t,v in sorted([x for x in top if x[1]=="bytes"], key=lambda x:-len(x[2])):
        sub=parse(v)
        strs=[y.decode(errors="ignore") for _,tt,y in sub if tt=="bytes" and isinstance(y,bytes) and len(y)<32]
        if any(s.startswith("0.4") or s.startswith("0.5") or s=="uregen" for s in strs) or any(x==1 and tt=="bytes" for x,tt,_ in sub):
            p=v; break
    assert p is not None, "params message not found"
    for f,t,v in parse(p):
        if f==1 and t=="bytes":
            c={x:y for x,tt,y in parse(v) if tt=="bytes"}
            gov["min_deposit"]=f'{int(c[2])/1e6:g} {c[1].decode()}'
        elif f==2 and t=="bytes":
            gov["max_deposit_period_s"]=parse(v)[0][2]
        elif f==3 and t=="bytes":
            gov["voting_period_s"]=parse(v)[0][2]
        elif f in (4,5,6,7,8,11,16) and t=="bytes":
            names={4:"quorum",5:"threshold",6:"veto_threshold",7:"min_initial_deposit_ratio",8:"proposal_cancel_ratio",11:"expedited_threshold",16:"min_deposit_ratio"}
            gov[names[f]]=v.decode()
        elif f==10 and t=="bytes":
            gov["expedited_voting_period_s"]=parse(v)[0][2]
        elif f==15 and t=="varint":
            gov["burn_vote_veto"]=bool(v)
except Exception as e:
    gov={"error":str(e)}

pool=rd("staking_pool.json",{}).get("pool",{})
bonded=int(pool.get("bonded_tokens","0"))/1e6
notbonded=int(pool.get("not_bonded_tokens","0"))/1e6
supply=int(rd("supply_uregen.json",{}).get("amount",{}).get("amount","0"))/1e6
nct_supply=int(rd("supply_nct.json",{}).get("amount",{}).get("amount","0"))/1e6
cp=sum(int(x["amount"]) for x in rd("community_pool.json",{}).get("pool",[]))/1e6

# basket backing
bb=rd("basket_balances.json",{}).get("balances",[])
basket_total=sum(float(x["balance"]) for x in bb)

# NCT owners total
owners=rd("nct_owners.json",{}).get("denom_owners",[])
owners_total=sum(int(o["balance"]["amount"]) for o in owners)/1e6

# validators
vals=rd("validators_bonded.json",{}).get("validators",[])
val_sum=sum(int(v["tokens"]) for v in vals)/1e6
top2=sum(sorted((int(v["tokens"]) for v in vals), reverse=True)[:2])/1e6

# proposals tallies (yes, abstain, no, veto)
props=[]
for p in rd("proposals.json",{}).get("proposals",[]):
    t=p.get("final_tally_result",{})
    props.append({"id":p["id"],"status":p["status"].replace("PROPOSAL_STATUS_",""),
                  "yes":int(t.get("yes_count","0")),"abstain":int(t.get("abstain_count","0")),
                  "no":int(t.get("no_count","0")),"veto":int(t.get("veto_count","0"))})

# prices
dlp=rd("dl_prices.json",{}).get("coins",{})
cgp=rd("cg_prices.json",{})
regen_dl=dlp.get("coingecko:regen",{}).get("price")
nct_dl=dlp.get("coingecko:toucan-protocol-nature-carbon-tonne",{}).get("price")
regen_cg=cgp.get("regen",{}).get("usd")
nct_cg=cgp.get("toucan-protocol-nature-carbon-tonne",{}).get("usd")
toucan_chain=rd("dl_toucan.json",{}).get("currentChainTvls",{})

# latest block
lb=rd("latest_block.json",{}).get("block",{}).get("header",{})
height=lb.get("height"); btime=lb.get("time")
ver=rd("node_info.json",{}).get("application_version",{}).get("version")

# model math
q=float(gov.get("quorum",0.4))
X_self = bonded*q/(1-q)
price_use = regen_cg or regen_dl or 0
X_usd = X_self*price_use
cp_usd_cg = cp*(regen_cg or 0)
cp_usd_dl = cp*(regen_dl or 0)
nct_usd_cg = nct_supply*(nct_cg or 0)
nct_usd_dl = nct_supply*(nct_dl or 0)
# marginal: attacker top-up needed if validators deliver V yes
V_recent_fail=28.5e6; V_recent_pass=35.0e6
X_marg_fail=max(0.0,(q*bonded - V_recent_fail)/ (1-q))
X_marg_pass=max(0.0,(q*bonded - V_recent_pass)/ (1-q))
veto_block = top2/(X_self+top2) > float(gov.get("veto_threshold",0.334))

ev={
 "generated_utc": __import__("datetime").datetime.utcnow().isoformat()+"Z",
 "chain": {"id":"regen-1","version":ver,"height":height,"time":btime},
 "gov_params": gov,
 "staking": {"bonded_regen":bonded,"not_bonded_regen":notbonded,"bonded_validators":len(vals),"validator_tokens_sum":val_sum,"top2_validator_bloc_regen":top2},
 "supply": {"uregen":supply,"eco_uC_NCT":nct_supply},
 "community_pool_regen": cp,
 "community_pool_usd": {"cg":cp_usd_cg,"dl":cp_usd_dl},
 "nct_basket": {"backing_credits_total":basket_total,"batches":len(bb),"market_value_usd_cg":nct_usd_cg,"market_value_usd_dl":nct_usd_dl,"holders":len(owners),"owners_sum":owners_total},
 "prices": {"regen_cg":regen_cg,"regen_dl":regen_dl,"nct_cg":nct_cg,"nct_dl":nct_dl},
 "toucan_chain_tvls_usd": toucan_chain,
 "capture_model": {
   "quorum_q":q,
   "self_sufficient_stake_regen":X_self,
   "self_sufficient_cost_usd_cg":X_usd,
   "self_sufficient_cost_usd_dl":X_self*(regen_dl or 0),
   "marginal_topup_if_validators_28_5M_yes":X_marg_fail,
   "marginal_topup_if_validators_35M_yes":X_marg_pass,
   "top2_bloc_can_veto_self_sufficient":bool(veto_block),
   "proceeds_cp_usd_cg":cp_usd_cg,"proceeds_cp_usd_dl":cp_usd_dl,
   "deposit_only_proposal_cost_usd":200*(regen_cg or 0)
 },
 "proposals_recent": props,
 "polygon_bridge": {
   "address": "0xdC1Dfa22824Af4e423a558bbb6C53a31c3c11DCC",
   "rpc": open(f"{tmp}/poly.json").read().strip() if __import__("os").path.exists(f"{tmp}/poly.json") else "none",
   "paused": open(f"{tmp}/poly_paused.txt").read().strip() if __import__("os").path.exists(f"{tmp}/poly_paused.txt") else "unavailable",
   "totalTransferred_raw": open(f"{tmp}/poly_total.txt").read().strip() if __import__("os").path.exists(f"{tmp}/poly_total.txt") else "unavailable",
   "roles": open(f"{tmp}/poly_roles.txt").read().splitlines() if __import__("os").path.exists(f"{tmp}/poly_roles.txt") else []
 }
}
json.dump(ev, open(outjson,"w"), indent=2)

md=[]
md.append("# C2-27 Regen — CI verification snapshot")
md.append(f"- generated: {ev['generated_utc']}")
md.append(f"- chain: regen-1 {ver} height {height} ({btime})")
md.append(f"- gov params: quorum {gov.get('quorum')}, threshold {gov.get('threshold')}, veto {gov.get('veto_threshold')}, voting_period {gov.get('voting_period_s')}s, min_deposit {gov.get('min_deposit')}, burn_vote_veto {gov.get('burn_vote_veto')}")
md.append(f"- bonded: {bonded:,.6f} REGEN; not-bonded: {notbonded:,.6f}; supply: {supply:,.6f}")
md.append(f"- community pool (protocolpool): {cp:,.6f} REGEN = ${cp_usd_cg:,.2f} (CG) / ${cp_usd_dl:,.2f} (DL)")
md.append(f"- NCT: supply {nct_supply:,.6f}; basket backing {basket_total:,.6f} credits; market value ${nct_usd_cg:,.2f} (CG) / ${nct_usd_dl:,.2f} (DL)")
md.append(f"- REGEN price: CG ${regen_cg} / DL ${regen_dl}")
md.append(f"- self-sufficient capture: {X_self:,.2f} REGEN = ${X_usd:,.2f} (CG) / ${X_self*(regen_dl or 0):,.2f} (DL)")
md.append(f"- marginal top-up if validators deliver 28.5M yes: {X_marg_fail:,.2f} REGEN; if 35M yes: {X_marg_pass:,.2f} REGEN")
md.append(f"- top-2 validator bloc can veto self-sufficient capture: {veto_block}")
md.append(f"- Toucan chain TVLs: {json.dumps(toucan_chain)}")
md.append(f"- Polygon bridge paused={ev['polygon_bridge']['paused']} roles={ev['polygon_bridge']['roles']}")
md.append("")
md.append("| prop | status | yes | abstain | no | veto |")
md.append("|---|---|---|---|---|---|")
for p in props: md.append(f"| {p['id']} | {p['status']} | {p['yes']:,} | {p['abstain']:,} | {p['no']:,} | {p['veto']:,} |")
open("ci-out/regen-evidence.md","w").write("\n".join(md)+"\n")
print("\n".join(md[:12]))
PYEOF

echo "== written: $OUT_JSON $OUT_MD =="
ls -la ci-out/
