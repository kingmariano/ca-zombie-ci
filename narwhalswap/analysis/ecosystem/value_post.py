#!/usr/bin/env python3
"""Post-process strategy_scan.json: decode addrs, value live strategies, check fry servicers."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr

D = json.load(open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/strategy_scan.json"))
print("scan block:", D["block"])
st = D["strategies"]

def a(x):
    if x in (None, ""): return None
    if isinstance(x, str) and x.startswith("0x"): return x
    return "0x%040x" % int(x)

# decode address sigs
for k, d in st.items():
    for s in ("govAddress()", "owner()", "wantAddress()"):
        if s in d and isinstance(d[s], (int, str)):
            d[s + "_addr"] = a(d[s])

# farms summary
for k, d in st.items():
    if "farmsumm" in d:
        fs = d["farmsumm"]
        print("FARM", k, "pools:", fs.get("poolLength()"), "alloc:", fs.get("totalAllocPoint()"),
              "owner:", a(fs.get("owner()")) if fs.get("owner()") not in (None, "") else None,
              "grand_bal:", fs.get("grandv2.balanceOf(farm)") or fs.get("grandv1.balanceOf(farm)"))

live = [(k, d) for k, d in st.items() if (d.get("wantLockedTotal()") or 0) > 10**9 and "want" in d]
print("\nlive strategies (wantLockedTotal > 1e9 wei):", len(live))
for k, d in sorted(live, key=lambda x: -(x[1].get("wantLockedTotal()") or 0)):
    wlt = d.get("wantLockedTotal()"); sh = d.get("sharesTotal()"); bnb = d.get("bnb") or 0
    print(f"{k} want={d.get('want')} wlt={wlt} shares={sh} bnb={bnb} gov={d.get('govAddress()_addr')} owner={d.get('owner()_addr')} bal={d.get('bal')}")

# unique wants -> symbol/decimals + pair info
wants = {}
for k, d in st.items():
    w = d.get("want")
    if w and "wantLockedTotal()" in d: wants.setdefault(w, []).append(k)
print("\nunique wants:", len(wants))
WC = [("symbol()", w) for w in wants]
res = rpc_batch([("eth_call", [{"to": w, "data": sel("symbol()")}, "latest"]) for w in wants], timeout=120)
syms = {}
for w, r in zip(wants, res):
    try:
        if r and len(r) > 130:
            off = int(r[2:66], 16); ln = int(r[66+off*2:66+off*2+64], 16)
            syms[w] = bytes.fromhex(r[66+off*2+64:66+off*2+64+ln*2]).decode("utf-8","replace")
        else: syms[w] = "?"
    except Exception: syms[w] = "?"
# pair detection (pair factory())
res2 = rpc_batch([("eth_call", [{"to": w, "data": sel("factory()")}, "latest"]) for w in wants], timeout=120)
PCS_F = "0xca143ce32fe78f1f7019d7d551a6402fc5350c73"
NAR_F = "0xb9fa84912ff2383a617d8b433e926adf0dd3fea1"
pairinfo = {}
for w, r in zip(wants, res2):
    f = dec_addr(r) if r else None
    pairinfo[w] = f
# summaries
out = {"block": D["block"], "live": []}
print("\n--- live strategy value summary ---")
for k, d in sorted(live, key=lambda x: -(x[1].get("wantLockedTotal()") or 0)):
    w = d["want"]; wlt = d.get("wantLockedTotal()") or 0
    entry = {"strat": k, "want": w, "symbol": syms.get(w), "wlt_wei": str(wlt),
             "shares": str(d.get("sharesTotal()") or 0), "pair_factory": pairinfo.get(w),
             "gov": d.get("govAddress()_addr"), "owner": d.get("owner()_addr"),
             "onlyGov": d.get("onlyGov()"), "paused": d.get("paused()"), "bnb": str(d.get("bnb") or 0)}
    if pairinfo.get(w) in (PCS_F, NAR_F):
        r3 = rpc_batch([
            ("eth_call", [{"to": w, "data": sel("token0()")}, "latest"]),
            ("eth_call", [{"to": w, "data": sel("token1()")}, "latest"]),
            ("eth_call", [{"to": w, "data": sel("getReserves()")}, "latest"]),
            ("eth_call", [{"to": w, "data": sel("totalSupply()")}, "latest"]),
        ], timeout=60)
        t0 = dec_addr(r3[0]); t1 = dec_addr(r3[1])
        try:
            rr = r3[2][2:]; res0 = int(rr[0:64],16); res1 = int(rr[64:128],16)
        except Exception: res0 = res1 = 0
        ts = hexint(r3[3]) if r3[3] else 0
        entry.update({"token0": t0, "token1": t1, "res0": str(res0), "res1": str(res1), "lp_supply": str(ts)})
        WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
        BUSD = ["0xe9e7cea3dedca5984780bafc599bd69add087d56","0x55d398326f99059ff775485246999027b3197955"]
        bnb_side = None
        if t0 and t0.lower() == WBNB: bnb_side = res0
        if t1 and t1.lower() == WBNB: bnb_side = res1
        if bnb_side and ts:
            entry["bnb_value_of_held"] = bnb_side * wlt / ts / 1e18
        for busd_t in BUSD:
            if t0 and t0.lower() == busd_t and ts:
                entry["usd_value_of_held"] = 2 * (res0 / 1e18) * wlt / ts
            if t1 and t1.lower() == busd_t and ts:
                entry["usd_value_of_held"] = 2 * (res1 / 1e18) * wlt / ts
    out["live"].append(entry)
    print(json.dumps(entry)[:400])

# fry contracts check
fry_addrs = set()
for k, d in st.items():
    pass
G = json.load(open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/grand_enum.json"))
frys = set()
for label in ("v1", "v2"):
    for p in G["farms"][("grand_%s_farm" % label)]["pools"]:
        for kk in ("frySailing", "fryLanding"):
            if p[kk] and p[kk] != "0x"+"0"*40: frys.add(p[kk])
print("\n--- fry servicers:", len(frys))
rb = rpc_batch([("eth_getBalance", [f, "latest"]) for f in sorted(frys)] +
               [("eth_call", [{"to": f, "data": sel("owner()")}, "latest"]) for f in sorted(frys)] +
               [("eth_getCode", [f, "latest"]) for f in sorted(frys)], timeout=120)
n = len(frys)
fryout = []
for i, f in enumerate(sorted(frys)):
    bnb = hexint(rb[i]) or 0
    ownr = dec_addr(rb[n+i])
    cl = (len(rb[2*n+i]) - 2)//2
    fryout.append({"addr": f, "bnb": str(bnb), "owner": ownr, "code_size": cl})
    print(f, "bnb=", bnb/1e18, "owner=", ownr, "code=", cl)
out["fry"] = fryout
json.dump(out, open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/strategy_value.json", "w"), indent=1, default=str)
print("\nsaved strategy_value.json")
