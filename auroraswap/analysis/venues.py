#!/usr/bin/env python3
"""Arb realizability: check other Aurora V2 venues for the tokens involved in
deviating AuroraSwap pools. Read-only, public RPC."""
import json
import os
import time
import urllib.request

RPC = os.environ.get("AURORA_RPC", "https://mainnet.aurora.dev")
BASE = os.path.dirname(__file__)
scan = json.load(open(os.path.join(BASE, "pairs_scan.json")))
meta = json.load(open(os.path.join(BASE, "tokens_meta.json")))
prices = json.load(open(os.path.join(BASE, "prices.json")))

FACTORIES = {
    "amaterasu": "0x34696b6cE48051048f07f4cAfa39e3381242c3eD",
    "nearpad": "0x34484b4E416f5d4B45D4Add0B6eF6Ca08FcED8f1",
    "wannaswap": "0x7928D4FeA7b2c90C732c10aFF59cf403f0C38246",
    "auroraswap": "0xC5E1DaeC2ad401eBEBdd3E32516d90Ab251A3aA3",
    "trisolaris?": "0xc66f594268041db60507f00703b152492fb176e7",
}
NEAR = "0xc42c30ac6cc15fac9bd938618bcaa1a1fae8501d"


def rpc(method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for a in range(4):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                out = json.load(r)
            if "result" in out:
                return out["result"]
        except Exception:  # noqa: BLE001
            pass
        time.sleep(1 + a)
    return None


def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])


def word(h, i=0):
    if not h or h == "0x" or len(h) < 2 + (i + 1) * 64:
        return None
    return int(h[2 + i * 64 : 2 + (i + 1) * 64], 16)


def addr(h, i=0):
    w = word(h, i)
    return None if w is None else "0x" + hex(w)[2:].rjust(40, "0")


def px(tok):
    for k, v in prices.items():
        if k.lower() == f"aurora:{tok}".lower():
            return v.get("price")
    return None


# find token addresses by symbol in our meta
by_sym = {}
for t, m in meta.items():
    if m.get("symbol"):
        by_sym.setdefault(m["symbol"], t)
targets = ["APE", "BNB", "MATIC", "USDT.e", "USDC.e", "WETH", "AURORA", "TRI", "WANNA", "ROSE"]
print("token addresses by symbol:", {s: by_sym.get(s) for s in targets})

print()
print("=== other Aurora V2 factories ===")
for name, fac in FACTORIES.items():
    n = word(call(fac, "0x574f2ba3"))  # allPairsLength()
    print(f"{name:12} {fac} allPairsLength={n}")

print()
print("=== pools on other venues for the arb-relevant tokens ===")
for name, fac in FACTORIES.items():
    if name == "auroraswap":
        continue
    for sym in ["APE", "BNB", "MATIC", "USDT.e", "USDC.e", "WETH", "AURORA"]:
        tok = by_sym.get(sym)
        if not tok:
            continue
        pair = addr(call(fac, "0xe6a43905" + tok.lower().replace("0x", "").rjust(64, "0") + NEAR.replace("0x", "").rjust(64, "0")))
        if not pair or int(pair, 16) == 0:
            continue
        t0 = addr(call(pair, "0x0dfe1681"))
        t1 = addr(call(pair, "0xd21220a7"))
        res = call(pair, "0x0902f1ac")
        r0, r1 = word(res, 0), word(res, 1)
        ts = word(call(pair, "0x18160ddd"))
        m0, m1 = meta.get(t0, {}), meta.get(t1, {})
        d0, d1 = (m0.get("decimals") or 18), (m1.get("decimals") or 18)
        a0, a1 = r0 / 10**d0, r1 / 10**d1
        p0, p1 = px(t0), px(t1)
        val = (a0 * p0 + a1 * p1) if (p0 and p1) else None
        pool_p0_in_1 = (a1 / a0) if a0 > 0 else None
        mkt = (p0 / p1) if (p0 and p1) else None
        dev = (pool_p0_in_1 / mkt - 1) * 100 if (pool_p0_in_1 and mkt) else None
        print(f"  {name:10} {str(m0.get('symbol')):>8}/{str(m1.get('symbol')):<8} pair {pair} "
              f"res {a0:,.4f}/{a1:,.4f} value={'${:,.2f}'.format(val) if val else 'n/a'} dev={('%.2f%%' % dev) if dev is not None else 'n/a'} ts={ts}")
