#!/usr/bin/env python3
"""Stage 3: fee-vault token balances, gauge token/LP balances, DefiLlama prices,
llama snapshot extraction. All reads pinned to the same explicit block as stage 2.
Outputs: nest_value_stage3.json, nest_prices.json, llama_latest.json
"""
import sys, json, time, urllib.request
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

BASE = "/home/heisenberg/CA/hyperevm-residuals/analysis"
BLOCK = 47620218
B = hex(BLOCK)
ZERO = "0x0000000000000000000000000000000000000000"


def pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def dec_u(r):
    return int(r, 16) if r and r != "0x" else None


def dec_addr(r):
    return ("0x" + r[-40:]) if r and len(r) >= 42 else None


def main():
    raw = json.load(open(f"{BASE}/nest_value_raw.json"))
    if raw["block"] != BLOCK:
        print("WARN raw block", raw["block"], "!= stage3", BLOCK)
    pools = {p["id"]: p for p in json.load(open(f"{BASE}/nest_pools_api.json"))}
    gauges_map = raw["gauges_map"]
    vaults_map = raw["vaults_map"]

    calls, meta = [], []

    # (a) fee vault balances for pool tokens
    for v, plist in vaults_map.items():
        pool = plist[0]
        p = pools[pool]
        for k in ("token0", "token1"):
            t = p[k]["tokenAddress"]
            calls.append(("eth_call", [{"to": t, "data": "0x70a08231" + pad(v)}, B]))
            meta.append(("vaultbal", v, f"{pool}:{k}:{t}"))

    # (b) gauge token0/token1 balances + LP balanceOf
    for g, plist in gauges_map.items():
        pool = plist[0]
        p = pools[pool]
        for k in ("token0", "token1"):
            t = p[k]["tokenAddress"]
            calls.append(("eth_call", [{"to": t, "data": "0x70a08231" + pad(g)}, B]))
            meta.append(("gaugebaltok", g, f"{pool}:{k}:{t}"))
        tok = dec_addr  # placeholder
        # LP balance: TOKEN() for V2 is the pair itself
        g_row = raw["gauge_rows"].get(g, {})
        token = g_row.get("TOKEN")
        if token and token.lower() != ZERO:
            calls.append(("eth_call", [{"to": token, "data": "0x70a08231" + pad(g)}, B]))
            meta.append(("gaugebllp", g, f"{pool}:{token}"))

    # (c) double-check NEST balances / veNEST stats at same block
    for to, sig in (("0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035", "0x18160ddd"),
                    ("0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074", "0x047fc9aa"),
                    ("0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074", "0x94340b05"),
                    ("0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074", "0xe1ba0c00")):
        calls.append(("eth_call", [{"to": to, "data": sig}, B]))
        meta.append(("core2", to, sig))

    # (d) weird tokens decimals retry + name/code
    for t in ("0x9d0E8f5b25384C7310CB8C6aE32C8fbeb645d083", "0x78cc152A531DBde2F3Fe7001ad659fa120Fa893b"):
        calls.append(("eth_call", [{"to": t, "data": "0x313ce567"}, B])); meta.append(("weird", t, "decimals"))
        calls.append(("eth_call", [{"to": t, "data": "0x18160ddd"}, B])); meta.append(("weird", t, "totalSupply"))
        calls.append(("eth_getCode", [t, B])); meta.append(("weird", t, "code"))

    print("calls:", len(calls))
    cm = list(zip(calls, meta))
    out = {"block": BLOCK, "vault_balances": {}, "gauge_token_balances": {}, "gauge_lp_balances": {},
           "core2": {}, "weird": {}}
    for i in range(0, len(cm), 20):
        part = cm[i:i + 20]
        res = batch([c for c, _ in part], chunk=20)
        for (c, m), r in zip(part, res):
            kind, key, what = m
            if kind == "vaultbal":
                out["vault_balances"].setdefault(key, {})[what] = dec_u(r)
            elif kind == "gaugebaltok":
                out["gauge_token_balances"].setdefault(key, {})[what] = dec_u(r)
            elif kind == "gaugebllp":
                out["gauge_lp_balances"].setdefault(key, {})[what] = dec_u(r)
            elif kind == "core2":
                out["core2"].setdefault(key, {})[what] = dec_u(r)
            elif kind == "weird":
                if what == "code":
                    out["weird"].setdefault(key, {})["code_size"] = (len(r) - 2) // 2 if r and r != "0x" else 0
                else:
                    out["weird"].setdefault(key, {})[what] = dec_u(r)

    json.dump(out, open(f"{BASE}/nest_value_stage3.json", "w"), indent=1)
    print("stage3 saved")
    nzv = {v: {k: x for k, x in tv.items() if x} for v, tv in out["vault_balances"].items()}
    nzv = {k: v for k, v in nzv.items() if v}
    print("vaults with nonzero balances:", len(nzv))
    for k, v in list(nzv.items())[:15]:
        print(" ", k, v)
    ng = {v: {k: x for k, x in tv.items() if x} for v, tv in out["gauge_token_balances"].items()}
    ng = {k: v for k, v in ng.items() if v}
    print("gauges with nonzero token balances:", len(ng))
    for k, v in list(ng.items())[:10]:
        print(" ", k, v)
    print("gauge_lp_balances:", json.dumps(out["gauge_lp_balances"], indent=1))
    print("weird:", json.dumps(out["weird"], indent=1))

    # ---- prices ----
    toks = [m for m in raw["token_meta"].keys()]
    ids = ",".join("hyperliquid:" + t for t in toks)
    req = urllib.request.Request("https://coins.llama.fi/prices/current/" + ids, headers={"User-Agent": "Mozilla/5.0"})
    prices = json.loads(urllib.request.urlopen(req, timeout=60).read())
    json.dump(prices, open(f"{BASE}/nest_prices.json", "w"), indent=1)
    got = prices.get("coins", {})
    print("prices fetched:", len(got), "/", len(toks))
    missing = [t for t in toks if ("hyperliquid:" + t) not in got and ("hyperliquid:" + t.lower()) not in got]
    print("missing prices:", missing)

    # ---- llama snapshot latest ----
    snap = json.load(open("/tmp/opencode/llama-nest-cl.json"))
    latest_tokens = snap["tokens"][-1]
    latest_usd = snap["tokensInUsd"][-1]
    slim = {"date": latest_tokens.get("date"), "tokens": latest_tokens.get("tokens"), "usd": latest_usd.get("tokens")}
    json.dump(slim, open(f"{BASE}/llama_latest.json", "w"), indent=1)
    print("llama latest date:", slim["date"])
    for k, v in slim["tokens"].items():
        print(f"  {k:>12} {v:>22}  ${slim['usd'].get(k,0):>14,.0f}")


if __name__ == "__main__":
    main()
