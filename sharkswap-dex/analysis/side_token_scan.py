#!/usr/bin/env python3
"""1) For all non-canonical side tokens in SharkSwap pairs: find mint-like selectors and
test with eth_call from a fresh address (READ-ONLY simulation).
2) For all LP holders: check whether holder is a contract.
Outputs: analysis/side_token_scan.json
"""
import json, os, urllib.request, re

D = os.path.dirname(os.path.abspath(__file__))
RPC = "https://base-rpc.publicnode.com"
UA = {"User-Agent": "research", "Content-Type": "application/json"}

def rpc(m, p):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": m, "params": p}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    d = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
    if "result" in d:
        return d["result"]
    e = d.get("error") or {}
    raise RuntimeError(str(e.get("message"))[:160] + "|" + str(e.get("data"))[:160])

st = json.load(open(os.path.join(D, "live_state.json")))
pr = json.load(open(os.path.join(D, "prices.json")))
lp_h = json.load(open(os.path.join(D, "lp_holders.json")))
CANON = {
    "0x4200000000000000000000000000000000000006", "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
    "0xd9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca", "0x50c5725949a6f0c72e6c4a641f24049a917db0cb",
    "0x2ae3f1ec7f1f5012cfeab0185bfc7aa3cf0dec22", "0xeb466342c4d449bc9f53a865d5cb90586f405215",
}
byp = {x["pair"]: x for x in pr["pairs"]}
FRESH = "0x2222222222222222222222222222222222222222"

def code(addr):
    c = rpc("eth_getCode", [addr, "latest"])
    return c if c != "0x" else None

def push4s(c):
    b = bytes.fromhex(c[2:])
    out, i = set(), 0
    while i < len(b) - 4:
        if b[i] == 0x63:
            out.add("0x" + b[i + 1:i + 5].hex())
            i += 5
        else:
            i += 1
    return sorted(out)

MINT_SELS = {
    "0x40c10f19": [("addr,uint256", FRESH[2:].rjust(64, "0") + hex(10**18)[2:].rjust(64, "0"))],
    "0xa0712d68": [("uint256", hex(10**18)[2:].rjust(64, "0"))],
    "0x1249c58b": [("()", "")],
    "0xb6b55f25": [("uint256", hex(10**18)[2:].rjust(64, "0"))],
    "0xd0e30db0": [("()", "")],
    "0x6a627842": [("addr", FRESH[2:].rjust(64, "0"))],
}

# collect side tokens with values
side = {}
for pv, p in st["pairs"].items():
    for k in ("0", "1"):
        t = p["token" + k]
        if t.lower() in CANON:
            continue
        v = byp.get(pv, {}).get("usd" + k) or 0
        other = p["token" + ("1" if k == "0" else "0")]
        otherv = byp.get(pv, {}).get("usd" + ("1" if k == "0" else "0")) or 0
        e = side.setdefault(t.lower(), {"addr": t, "symbols": set(), "pairs": [], "max_pair_usd": 0})
        e["symbols"].add(p["symbol" + k])
        e["pairs"].append(pv)
        e["max_pair_usd"] = max(e["max_pair_usd"], otherv)

out = {"side_tokens": {}, "lp_contract_holders": []}

for t, e in sorted(side.items(), key=lambda kv: -kv[1]["max_pair_usd"]):
    c = code(t)
    rec = {"addr": t, "symbol": "/".join(sorted(e["symbols"])),
           "n_pairs": len(e["pairs"]), "max_counterparty_usd": round(e["max_pair_usd"], 2),
           "has_code": bool(c)}
    if c:
        sels = push4s(c)
        mint_sels = [s for s in sels if s in MINT_SELS]
        rec["mint_selectors"] = {}
        for s in mint_sels:
            for argsname, args in MINT_SELS[s]:
                try:
                    res = rpc("eth_call", [{"from": FRESH, "to": t, "data": s + args}, "latest"])
                    rec["mint_selectors"][s] = {"sig": argsname, "PUBLIC_SUCCESS": True, "ret": res[:66]}
                except Exception as ex:
                    rec["mint_selectors"].setdefault(s, {"sig": argsname, "PUBLIC_SUCCESS": False,
                                                        "revert": str(ex)[:140]})
        rec["n_selectors"] = len(sels)
    out["side_tokens"][t] = rec
    print(f"{e['max_pair_usd']:>9.2f} {rec['symbol']:>14} {t} code={bool(c)} " +
          (f"mint={json.dumps(rec.get('mint_selectors'))[:150]}" if c else ""))

# LP holders that are contracts
seen = set()
for lp, v in lp_h["holders"].items():
    if "holders" not in v:
        continue
    for h in v["holders"]:
        a = h["address"].lower()
        if a in seen:
            continue
        seen.add(a)
        try:
            c = code(a)
        except Exception:
            c = "err"
        if c:
            out["lp_contract_holders"].append({"address": a, "lp_token": lp,
                                               "symbols": f"{v.get('symbol0')}/{v.get('symbol1')}",
                                               "balance": h["balance"]})
            print("CONTRACT LP HOLDER:", a, v.get("symbol0"), v.get("symbol1"), h["balance"][:20])

json.dump(out, open(os.path.join(D, "side_token_scan.json"), "w"), indent=1)
print("wrote side_token_scan.json")
