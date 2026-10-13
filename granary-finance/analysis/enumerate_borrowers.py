#!/usr/bin/env python3
"""Enumerate Granary borrowers (debt-token holders) and scan for liquidatable positions.

Holder sources: GoldRush token_holders_v2 (5 chains); Blockscout getTokenHolders (metis).
Reads: debt-token balanceOf + pool.getUserAccountData per user. Read-only, public RPCs.
"""
import json, os, sys, time, urllib.request, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
GR = os.environ.get("GOLD_RUSH_API_KEY", "")

CHAINS = {
    "optimism":  {"cov": "optimism-mainnet", "rpc": "https://mainnet.optimism.io"},
    "arbitrum":  {"cov": "arbitrum-mainnet", "rpc": "https://arb1.arbitrum.io/rpc"},
    "avalanche": {"cov": "avalanche-mainnet", "rpc": "https://avalanche-c-chain-rpc.publicnode.com"},
    "bsc":       {"cov": "bsc-mainnet", "rpc": "https://bsc-rpc.publicnode.com"},
    "ethereum":  {"cov": "eth-mainnet", "rpc": "https://ethereum-rpc.publicnode.com"},
    "base":      {"cov": "base-mainnet", "rpc": "https://base-rpc.publicnode.com"},
    "metis":     {"bs": "https://andromeda-explorer.metis.io", "rpc": "https://metis-rpc.publicnode.com"},
}

SIG = {
    "balanceOf": "0x70a08231",
    "accountData": "0xbf92857c",   # getUserAccountData(address)
    "reserveData": "0x28dd2d01",   # getUserReserveData(address,address)
}

_id = [0]
def _post(url, payload, timeout=40):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "granary-audit/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def rpc(url, method, params, retries=3):
    for a in range(retries):
        try:
            _id[0] += 1
            res = _post(url, {"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params})
            if "result" in res: return res["result"]
        except Exception as e:
            if a == retries - 1: return {"__err__": str(e)}
            time.sleep(0.5 * (a + 1))
    return None

def batch(url, calls, chunk=10, retries=2):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = []
        for m, p in part:
            _id[0] += 1
            payload.append({"jsonrpc": "2.0", "id": _id[0], "method": m, "params": p})
        got = None
        for a in range(retries):
            try:
                res = _post(url, payload)
                byid = {r.get("id"): r for r in res}
                got = [byid.get(c["id"], {}).get("result") for c in payload]
                break
            except Exception as e:
                if a == retries - 1: got = [None]*len(part)
                else: time.sleep(0.7 * (a + 1))
        out.extend(got)
        time.sleep(0.05)
    return out

def http_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "granary-audit/1.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode())

def holders_cached(chain, key, fetch):
    cache = os.path.join(HERE, f"holders-{chain}-{key}.json")
    if os.path.exists(cache):
        try:
            d = json.load(open(cache))
            if time.time() - d.get("ts", 0) < 86400 and d.get("holders"):
                return d["holders"]
        except Exception:
            pass
    hs = fetch()
    json.dump({"ts": time.time(), "holders": hs}, open(cache, "w"))
    return hs

def holders_goldrush(chain_name, token):
    """v2 paginated first; if v2 hides items (returns total_count but empty), fall back to v1 (no page params)."""
    out = []
    for page in range(1, 11):
        url = (f"https://api.covalenthq.com/v1/{chain_name}/tokens/{token}/token_holders_v2/"
               f"?page-size=100&page-number={page}&key={GR}")
        try:
            d = http_json(url)
        except Exception as e:
            print("  goldrush err", e); break
        if d.get("error"):
            print("  goldrush error:", d.get("error_message")); break
        items = (d.get("data") or {}).get("items", [])
        out += [it["address"] for it in items]
        if len(items) < 100: break
        time.sleep(0.3)
    if not out:
        url = (f"https://api.covalenthq.com/v1/{chain_name}/tokens/{token}/token_holders/"
               f"?page-size=100&key={GR}")
        try:
            d = http_json(url)
            items = (d.get("data") or {}).get("items", [])
            out += [it["address"] for it in items]
        except Exception as e:
            print("  goldrush v1 err", e)
    return out

def holders_blockscout(bs, token):
    out = []
    for page in range(1, 6):
        url = f"{bs}/api?module=token&action=getTokenHolders&contractaddress={token}&page={page}&offset=100"
        try:
            d = http_json(url)
        except Exception as e:
            print("  blockscout err", e); break
        res = d.get("result") or []
        out += [r["address"] for r in res]
        if len(res) < 100: break
        time.sleep(0.3)
    return out

def u(x):
    try: return int(x, 16) if isinstance(x, str) else None
    except Exception: return None

def scan(chain):
    cfg = CHAINS[chain]
    url = os.environ.get(f"{chain.upper()}_RPC_URL") or cfg["rpc"]
    st = json.load(open(os.path.join(HERE, f"state-{chain}.json")))
    pool = st["pool"]
    reserves = [r for r in st["reserves"] if isinstance(r, dict) and "config" in r]
    debt_tokens = [(r["assetSymbol"], r["variableDebtToken"], r["stableDebtToken"]) for r in reserves]
    print(f"[{chain}] pool={pool} debtTokens={len(debt_tokens)}")

    users = set()
    for sym, vd, sd in debt_tokens:
        if "cov" in cfg:
            hs = holders_cached(chain, f"vd-{sym}".replace("/", "_"), lambda: holders_goldrush(cfg["cov"], vd))
        elif "bs" in cfg:
            hs = holders_cached(chain, f"vd-{sym}".replace("/", "_"), lambda: holders_blockscout(cfg["bs"], vd))
        else:
            hs = []
        print(f"  holders {sym} vDebt: {len(hs)}", flush=True)
        users.update(a.lower() for a in hs)
    users = sorted(users)
    print(f"[{chain}] unique candidate debtors: {len(users)}")

    # balanceOf on each debt token to confirm current debt (skip token if total 0)
    live = {}
    active_tokens = [(s, v, sd) for s, v, sd in debt_tokens
                     if (next((r.get("variableDebtTotal") or 0 for r in reserves if r["assetSymbol"] == s), 0) > 0
                         or next((r.get("stableDebtTotal") or 0 for r in reserves if r["assetSymbol"] == s), 0) > 0)]
    calls = []
    for usr in users:
        for sym, vd, sd in active_tokens:
            calls.append(("eth_call", [{"to": vd, "data": SIG["balanceOf"] + usr[2:].rjust(64, "0")}, "latest"]))
            calls.append(("eth_call", [{"to": sd, "data": SIG["balanceOf"] + usr[2:].rjust(64, "0")}, "latest"]))
    res = []
    per_user = 2 * len(active_tokens)
    for i in range(0, len(users), 100):
        grp = calls[i*per_user:(i+100)*per_user]
        res.extend(batch(url, grp, chunk=10))
        print(f"[{chain}] balanceOf progress {min(i+100, len(users))}/{len(users)}", flush=True)
    k = 0
    for usr in users:
        debts = {}
        for sym, vd, sd in active_tokens:
            vb = u(res[k]); sb = u(res[k+1]); k += 2
            if (vb or 0) > 0: debts[sym + ":v"] = vb
            if (sb or 0) > 0: debts[sym + ":s"] = sb
        if debts:
            live[usr] = debts
    print(f"[{chain}] debtors with live debt: {len(live)}", flush=True)

    # account data for all live debtors
    usrs = sorted(live)
    calls = [("eth_call", [{"to": pool, "data": SIG["accountData"] + usr[2:].rjust(64, "0")}, "latest"]) for usr in usrs]
    res = []
    for i in range(0, len(calls), 100):
        res.extend(batch(url, calls[i:i+100], chunk=10))
        print(f"[{chain}] accountData progress {min(i+100, len(calls))}/{len(calls)}", flush=True)
    acct = {}
    for usr, r in zip(usrs, res):
        if isinstance(r, str) and len(r) >= 2 + 6*64:
            s = r[2:]
            acct[usr] = {
                "totalCollateralBase": int(s[0:64], 16),
                "totalDebtBase": int(s[64:128], 16),
                "availableBorrowsBase": int(s[128:192], 16),
                "currentLiquidationThreshold": int(s[192:256], 16),
                "ltv": int(s[256:320], 16),
                "healthFactor": int(s[320:384], 16),
            }
        else:
            acct[usr] = {"error": str(r)[:120]}

    liquidatable = {usr: a for usr, a in acct.items()
                    if a.get("healthFactor") is not None and a["healthFactor"] < 10**18 and a.get("totalDebtBase", 0) > 0}
    print(f"[{chain}] LIQUIDATABLE (HF<1): {len(liquidatable)}")
    for usr, a in sorted(liquidatable.items(), key=lambda kv: -kv[1]["totalDebtBase"]):
        hf = a["healthFactor"] / 1e18
        print(f"  {usr} HF={hf:.4f} collateral=${a['totalCollateralBase']/1e8:,.2f} debt=${a['totalDebtBase']/1e8:,.2f} debts={live[usr]}")

    out = {"chain": chain, "block": st.get("block"), "pool": pool,
           "candidates": len(users), "live_debtors": live, "account": acct,
           "liquidatable": liquidatable}
    with open(os.path.join(HERE, f"borrowers-{chain}.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{chain}] saved borrowers-{chain}.json")

if __name__ == "__main__":
    for ch in sys.argv[1:] or CHAINS:
        try:
            scan(ch)
        except Exception as e:
            import traceback; traceback.print_exc()
            print(f"[{ch}] FAILED: {e}")
