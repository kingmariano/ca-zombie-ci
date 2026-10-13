#!/usr/bin/env python3
"""SharkSwap DEX (Base) CI re-check — read-only live state at latest block.
Writes ci-out/live_recheck.json. Never prints or stores RPC URLs.
"""
import json, os, urllib.request, re, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "ci-out")
os.makedirs(OUT, exist_ok=True)

RPC = os.environ.get("BASE_RPC_URL") or "https://base-rpc.publicnode.com"
UA = {"User-Agent": "research", "Content-Type": "application/json"}

def rpc(m, p, tries=3):
    last = None
    for _ in range(tries):
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": m, "params": p}).encode()
            req = urllib.request.Request(RPC, data=body, headers=UA)
            d = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
            if "result" in d:
                return d["result"]
            last = d.get("error")
        except Exception as e:
            last = str(e)[:100]
    raise RuntimeError("rpc fail: " + str(last)[:120])

FACTORY = "0x57592d44eb60011500961ef177bff8d8691d5a8b"
SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "balanceOf": "0x70a08231",
    "feeTo": "0x017e7e58",
    "feeToSetter": "0x094b7415",
}
KNOWN_ROLES = {
    "0x1239660af62d515bfecd4ee09c58d2cd32504605": "burn/locked",
    "0xbe4ec6286bf4b557d098e303fa3570584bda1eb9": "feeTo-EOA",
    "0x27160d3b618ee073efaaee596b6be37018d18e4a": "team-EOA",
    "0x68586610448bb167d56b92d6b25dc7f196042679": "team-EOA2",
}

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def num(hexs):
    return int(hexs, 16)

def addr_of(hexs):
    return "0x" + hexs[-40:]

bn = num(rpc("eth_blockNumber", []))
n = num(call(FACTORY, SEL["allPairsLength"]))
feeTo = addr_of(call(FACTORY, SEL["feeTo"]))
feeToSetter = addr_of(call(FACTORY, SEL["feeToSetter"]))
res = {"block": bn, "factory": FACTORY, "n_pairs": n, "feeTo": feeTo, "feeToSetter": feeToSetter,
       "pairs": [], "totals": {}}

tokens = set()
for i in range(n):
    p = addr_of(call(FACTORY, SEL["allPairs"] + hex(i)[2:].rjust(64, "0")))
    t0 = addr_of(call(p, SEL["token0"]))
    t1 = addr_of(call(p, SEL["token1"]))
    rr = call(p, SEL["getReserves"])[2:]
    r0, r1 = int(rr[0:64], 16), int(rr[64:128], 16)
    ts = num(call(p, SEL["totalSupply"]))
    b0 = num(call(t0, SEL["balanceOf"] + p[2:].rjust(64, "0")))
    b1 = num(call(t1, SEL["balanceOf"] + p[2:].rjust(64, "0")))
    rec = {"pair": p, "token0": t0, "token1": t1, "reserve0": r0, "reserve1": r1,
           "totalSupply": ts, "balance0": b0, "balance1": b1,
           "excess0": b0 - r0, "excess1": b1 - r1, "known_lp": {}}
    for a, name in KNOWN_ROLES.items():
        b = num(call(p, SEL["balanceOf"] + a[2:].rjust(64, "0")))
        if b:
            rec["known_lp"][name] = b
    res["pairs"].append(rec)
    tokens.add(t0); tokens.add(t1)

# prices via DefiLlama (public)
prices = {}
try:
    tlist = sorted(tokens)
    for i in range(0, len(tlist), 40):
        keys = ",".join("base:" + a.lower() for a in tlist[i:i + 40])
        req = urllib.request.Request("https://coins.llama.fi/prices/current/" + keys,
                                     headers={"User-Agent": "research"})
        d = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
        for k, v in d.get("coins", {}).items():
            prices[k.split(":", 1)[1].lower()] = v.get("price")
except Exception as e:
    res["price_error"] = str(e)[:120]

def usd(tok, amt):
    p = prices.get(tok.lower())
    if p is None:
        return None
    # decimals: assume 18 unless known 6-dec stables
    dec = 6 if tok.lower() in {
        "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
        "0xd9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca",
        "0xeb466342c4d449bc9f53a865d5cb90586f405215"} else 18
    return amt / 10 ** dec * p

tot = p_tot = s_tot = h_tot = 0.0
max_excess = 0
for rec in res["pairs"]:
    u0, u1 = usd(rec["token0"], rec["reserve0"]), usd(rec["token1"], rec["reserve1"])
    v = (u0 or 0) + (u1 or 0)
    rec["usd_total"] = round(v, 2)
    max_excess = max(max_excess, rec["excess0"] + rec["excess1"])
    ts = rec["totalSupply"]
    accounted = 0
    for name, b in rec["known_lp"].items():
        accounted += b
        if name == "burn/locked":
            s_tot += b / ts * v if ts else 0
        else:
            p_tot += b / ts * v if ts else 0
    if ts and ts > accounted:
        s_tot += (ts - accounted) / ts * v
    tot += v
res["totals"] = {"usd_total": round(tot, 2), "usd_privileged_team": round(p_tot, 2),
                 "usd_burned_stuck": round(s_tot, 2), "max_excess_wei": max_excess}
json.dump(res, open(os.path.join(OUT, "live_recheck.json"), "w"), indent=1)
print("block", bn, "pairs", n, "total_usd", round(tot, 2),
      "P", round(p_tot, 2), "S", round(s_tot, 2), "max_excess", max_excess)
