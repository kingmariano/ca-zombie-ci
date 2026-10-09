#!/usr/bin/env python3
"""Decode main-market obligation headers; rank stored-liquidatable; fetch top-N full accounts.
Read-only. Outputs to /tmp/opencode and save-solend/analysis."""
import json, base64, time, urllib.request, collections, os

RPCS = ["https://api.mainnet-beta.solana.com", "https://solana-rpc.publicnode.com"]
rpc_idx = 0

def rpc(method, params, retries=8, timeout=240):
    global rpc_idx
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    delay = 1.0
    for i in range(retries):
        url = RPCS[rpc_idx % len(RPCS)]
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.load(r)
            if "error" in out:
                raise RuntimeError(str(out["error"])[:200])
            return out["result"]
        except Exception as e:
            if i == retries - 1: raise
            rpc_idx += 1
            time.sleep(delay); delay *= 1.6

def u(b, o, n): return int.from_bytes(b[o:o+n], "little")
def u128(b, o): return u(b, o, 16)
ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n: n, r = divmod(n, 58); s = ALPH[r] + s
    return "1" * (len(b) - len(b.lstrip(b"\0"))) + (s or "")

def main():
    raw = json.load(open("/tmp/opencode/main_oblig_headers.json"))
    rows = []
    for it in raw:
        b = base64.b64decode(it["account"]["data"][0])
        rows.append({
            "obligation": it["pubkey"], "slot": u(b, 1, 8), "stale": b[9] != 0,
            "market": b58(b[10:42]), "owner": b58(b[42:74]),
            "deposited": u128(b, 74) / 1e18, "borrowed": u128(b, 90) / 1e18,
            "borrowed_ub": u128(b, 106) / 1e18, "allowed": u128(b, 122) / 1e18,
            "unhealthy": u128(b, 138) / 1e18, "iso": b[154] != 0,
            "super_unhealthy": u128(b, 155) / 1e18, "unweighted": u128(b, 171) / 1e18,
            "closeable": b[187] != 0, "n_dep": b[202], "n_bor": b[203],
        })
    json.dump(rows, open("/tmp/opencode/main_oblig_headers_decoded.json", "w"))
    debt = [r for r in rows if r["n_bor"] > 0]
    liq = [r for r in debt if r["unhealthy"] > 0 and r["borrowed"] >= r["unhealthy"]]
    near = [r for r in debt if r["unhealthy"] > 0 and r["borrowed"] >= 0.9 * r["unhealthy"] and r["borrowed"] < r["unhealthy"]]
    print(f"main obligations={len(rows)} withDebt={len(debt)} storedLiquidatable={len(liq)} near90={len(near)}")
    print(f"storedLiquidatable borrowed_value sum=${sum(r['borrowed'] for r in liq):,.0f}")
    print(f"storedLiquidatable unhealthy sum=${sum(r['unhealthy'] for r in liq):,.0f}")
    slotc = collections.Counter((r["slot"] // 10_000_000) * 10_000_000 for r in debt)
    print("debt obligations by lastUpdate slot bucket (10M):", dict(sorted(slotc.items())[-8:]))
    top = sorted(liq, key=lambda r: -r["borrowed"])[:4000]
    json.dump([r["obligation"] for r in top], open("/tmp/opencode/main_top_liq.json", "w"))
    print("top stored-liquidatable by borrowed_value:")
    for r in top[:15]:
        print(f"  {r['obligation'][:16]} borrowed ${r['borrowed']:>14,.2f} unhealthy ${r['unhealthy']:>14,.2f} ratio {r['borrowed']/r['unhealthy']:5.2f} slot {r['slot']} dep {r['n_dep']} bor {r['n_bor']}")
    # fetch full accounts for top
    out = {}
    obls = [r["obligation"] for r in top]
    for i in range(0, len(obls), 50):
        batch = obls[i:i+50]
        res = rpc("getMultipleAccounts", [batch, {"encoding": "base64", "commitment": "confirmed"}])
        for a, acc in zip(batch, res["value"]):
            if acc is not None:
                out[a] = base64.b64decode(acc["data"][0]).hex()
        if i % 500 == 0:
            print(f"  fetched {i+len(batch)}/{len(obls)}")
            json.dump(out, open("/tmp/opencode/main_top_liq_full.json", "w"))
        time.sleep(0.4)
    json.dump(out, open("/tmp/opencode/main_top_liq_full.json", "w"))
    print("full accounts fetched:", len(out))

if __name__ == "__main__":
    main()
