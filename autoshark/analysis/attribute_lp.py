#!/usr/bin/env python3
"""Attribute finFactory pair value: balanceOf(known contracts) x pair value; also flag unknown holders.
Read-only, public RPC only."""
import json, requests
RPC = "https://bsc-rpc.publicnode.com"
SEL_BAL = "0x70a08231"
KNOWN = {
    "feeTo_distributor": "0x593CC303170367FCB249abdd08Aaaa736d552BA5",
    "feeVault_squid": "0xe0B4Add509BAB9d04cA92541272C87CDB822FA32",
    "MasterOcean": "0x8857af8205f224870dea119e2c75af386efb192a",
    "MasterSquid": "0x86a47ddd4c6522251d6a5a5800f3f24c03332cb4",
    "jawsPool": "0x5D2112Ba0969EC66012380C1fb88F2A3D182Eb90",
    "helper": "0xBd17385A935C8D77d15DB2E2C0e1BDE82fdFCe44",
    "team_EOA": "0x91d6136a45c10a8567ae9e2aac193d65fd4c7e01",
}

def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")

def call_batch(items):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [{"to": t, "data": d}, "latest"]}
               for i, (t, d) in enumerate(items)]
    r = requests.post(RPC, json=payload, timeout=60).json()
    out = []
    for item in sorted(r, key=lambda x: x["id"]):
        out.append(item.get("result"))
    return out

def main():
    d = json.load(open("/home/heisenberg/CA/autoshark/analysis/pairs_raw.json"))
    pairs = d["pairs"]
    addrs = sorted({v["token0"] for v in pairs.values()} | {v["token1"] for v in pairs.values()})
    prices = {}
    for i in range(0, len(addrs), 90):
        q = ",".join("bsc:" + a.lower() for a in addrs[i:i+90])
        r = requests.get(f"https://coins.llama.fi/prices/current/{q}", timeout=30).json()
        prices.update(r.get("coins", {}))
    def price(t):
        c = prices.get("bsc:" + t.lower()); return c["price"] if c else None

    # pair value
    pv = {}
    toks = d["tokens"]
    for p, v in pairs.items():
        r0, r1 = v["reserves"] or (0, 0)
        p0 = price(v["token0"]); p1 = price(v["token1"])
        d0 = toks[v["token0"]]["decimals"] or 18; d1 = toks[v["token1"]]["decimals"] or 18
        pv[p] = (p0 * r0 / 10**d0 if p0 else 0) + (p1 * r1 / 10**d1 if p1 else 0)

    totals = {k: 0.0 for k in KNOWN}
    detail = {k: [] for k in KNOWN}
    plist = list(pairs.keys())
    for name, who in KNOWN.items():
        res = call_batch([(p, SEL_BAL + enc_addr(who)) for p in plist])
        for p, r in zip(plist, res):
            if not r or r == "0x":
                continue
            bal = int(r, 16)
            if bal == 0:
                continue
            ts = pairs[p]["totalSupply"] or 0
            share = bal / ts if ts else 0
            usd = pv[p] * share
            if usd > 0.01 or share > 0.01:
                detail[name].append({"pair": p, "lp_balance": bal, "lp_share": round(share, 6),
                                     "pair_value_usd": round(pv[p], 2), "attrib_usd": round(usd, 2)})
                totals[name] += usd
    print(json.dumps({k: {"total_usd": round(v, 2), "positions": len(detail[k])} for k, v in totals.items()}, indent=1))
    out = {"block": d["block"], "pair_value_total_usd": round(sum(pv.values()), 2),
           "attribution": {k: {"total_usd": round(totals[k], 2), "positions": sorted(detail[k], key=lambda x: -x["attrib_usd"])[:15]} for k in KNOWN}}
    json.dump(out, open("/home/heisenberg/CA/autoshark/analysis/lp_attribution.json", "w"), indent=1)
    # per-contract top positions
    for k in KNOWN:
        print("\n==", k, f"total ${totals[k]:,.2f}")
        for pos in sorted(detail[k], key=lambda x: -x["attrib_usd"])[:6]:
            print(f"   pair {pos['pair']} share={pos['lp_share']*100:.2f}% pairval=${pos['pair_value_usd']:,.0f} -> ${pos['attrib_usd']:,.2f}")

if __name__ == "__main__":
    main()
