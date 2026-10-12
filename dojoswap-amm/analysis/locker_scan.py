#!/usr/bin/env python3
"""Enumerate all locks in the Kira locker (code 1178) and value each locked LP
against the Dojoswap pair reserves. Also list other code-1178 instances."""
import json, base64, urllib.request, time

LCDS = ["https://injective-api.polkachu.com", "https://injective-rest.publicnode.com"]

def get(path, timeout=30):
    last = None
    for lcd in LCDS:
        try:
            req = urllib.request.Request(lcd + path, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
    raise RuntimeError(str(last))

def cwq(contract, query):
    b64 = base64.b64encode(json.dumps(query, separators=(",", ":")).encode()).decode()
    return get(f"/cosmwasm/wasm/v1/contract/{contract}/smart/{b64}").get("data", {})

# all code-1178 contracts
cc = get("/cosmwasm/wasm/v1/code/1178/contracts?pagination.limit=200").get("contracts", [])
print("locker instances:", cc)

pairs = {p["liquidity_token"]: p for p in json.load(open("pairs-live.json"))["pairs"]}
pools = {r["contract"]: r["pool"] for r in json.load(open("pairs-live.json"))["pools"] if "pool" in r}
PRICES = {
    "inj": (18, 7.719961405375492),
    "peggy0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599": (8, 83278.67701171205),
    "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7": (6, 0.9990592309077597),
    "peggy0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": (18, 2526.309369639584),
    "peggy0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": (6, 0.9996446058349336),
}

now = int(time.time())
all_locks = []
for locker in cc:
    try:
        d = cwq(locker, {"get_liquidities": {}})
    except Exception as e:
        print(locker, "ERR", e); continue
    cfg = cwq(locker, {"get_config": {}})
    print(f"\n== locker {locker} cfg={cfg} locks={len(d.get('liquidities', []))}")
    for lp in d.get("liquidities", []):
        lp["locker"] = locker
        lp["expired"] = int(lp["locktime"]) < now
        all_locks.append(lp)

print(f"\ntotal locks: {len(all_locks)}, expired: {sum(1 for l in all_locks if l['expired'])}")

# group by LP denom
from collections import defaultdict
by_lp = defaultdict(list)
for l in all_locks:
    by_lp[l["denom"]].append(l)

total_usd = 0.0
for lp_denom, locks in by_lp.items():
    amt = sum(int(l["amount"]) for l in locks)
    pinfo = pairs.get(lp_denom)
    val = None
    if pinfo:
        pool = pools.get(pinfo["contract_addr"])
        ts = int(pool["total_share"]) if pool else 0
        if ts:
            share = amt / ts
            v = 0.0; priced = True
            for a in pool["assets"]:
                k = a["info"].get("native_token", {}).get("denom") or ("CW20:" + a["info"]["token"]["contract_addr"])
                if k in PRICES:
                    dec, usd = PRICES[k]
                    v += int(a["amount"]) / 10**dec * usd
                else:
                    priced = False
            val = {"pair": pinfo["contract_addr"], "share": share, "pool_usd_priced": v,
                   "lp_value_priced": v * share, "fully_priced": priced}
    print(f"\nLP {lp_denom}: {len(locks)} locks, locked={amt}")
    print(f"   pair={pinfo['contract_addr'] if pinfo else 'NOT A DOJOSWAP LP'} val={val}")
    if val and val.get("lp_value_priced"):
        total_usd += val["lp_value_priced"]
    for l in locks[:6]:
        print(f"   id={l['id']} owner={l['owner']} amount={l['amount']} locktime={l['locktime']} expired={l['expired']}")
print(f"\nTOTAL claimable-by-anyone (priced Dojoswap LP value): ${total_usd:,.2f}")
json.dump({"locks": all_locks, "by_lp": {k: v for k, v in by_lp.items()},
           "total_usd_priced": total_usd}, open("locker-locks.json", "w"), indent=1)
