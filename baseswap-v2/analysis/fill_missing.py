#!/usr/bin/env python3
"""Gap-fill scan: fetch ALL 8,290 pair addresses, diff against the CI scan coverage,
and check skim-excess for the missing pairs only.

RPC comes from env RPC_GAPFILL (never printed/written). Read-only.
Writes analysis/missing_scan.json
"""
import json, os, sys, time, urllib.request, random
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RPC = os.environ.get("RPC_GAPFILL") or ""
if not RPC:
    print("ERROR: set RPC_GAPFILL env var (not persisted)"); sys.exit(2)
FACTORY = "0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB"
COVERED = os.path.join(ROOT, "analysis", "ci2-backup", "pairs.json")
OUT = os.path.join(ROOT, "analysis", "missing_scan.json")
SEL = {"allPairs": "0x1e3dd18b", "getReserves": "0x0902f1ac", "totalSupply": "0x18160ddd",
       "token0": "0x0dfe1681", "token1": "0xd21220a7", "balanceOf": "0x70a08231"}

def redact(s):
    return str(s).replace(RPC, "<rpc>")

def enc_uint(n):
    return hex(n)[2:].rjust(64, "0")

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def post(payload, retries=8):
    last = None
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json",
                                                  "User-Agent": "Mozilla/5.0 research"})
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
            time.sleep(1.0 * (a + 1) + random.random())
    raise RuntimeError("rpc fail: " + redact(last))

def batch(calls, chunk=50, workers=3):
    """calls: list of (to, data). Returns results aligned; failed chunks -> None entries."""
    chunks = [calls[i:i + chunk] for i in range(0, len(calls), chunk)]
    def one(ch):
        payload = [{"jsonrpc": "2.0", "id": k + 1, "method": "eth_call",
                    "params": [{"to": to, "data": data}, "latest"]} for k, (to, data) in enumerate(ch)]
        try:
            res = post(payload)
        except Exception as e:
            print("[skip chunk]", redact(e)[:120], flush=True)
            return [None] * len(ch)
        byid = {x["id"]: x for x in res}
        out = []
        for k in range(len(ch)):
            it = byid.get(k + 1, {})
            if "error" in it:
                err = str(it["error"]).lower()
                out.append("__REVERT__" if "revert" in err or "execution" in err else None)
            else:
                out.append(it.get("result"))
        return out
    out = []
    with ThreadPoolExecutor(max_workers=workers) as ex:
        for r in ex.map(one, chunks):
            out.extend(r)
    return out

def du(h):
    if not h or h == "0x" or h == "__REVERT__":
        return None
    return int(h, 16)

def da(h):
    if not h or len(h) < 42:
        return None
    return "0x" + h[-40:]

def main():
    t0 = time.time()
    # 1. all pairs
    calls = [(FACTORY, SEL["allPairs"] + enc_uint(i)) for i in range(8290)]
    res = batch(calls, chunk=100, workers=2)
    all_pairs = []
    for r in res:
        a = da(r)
        if a:
            all_pairs.append(a.lower())
    print("allPairs fetched:", len(all_pairs), "in", round(time.time() - t0, 1), "s", flush=True)

    covered = {p["pair"].lower() for p in json.load(open(COVERED))}
    # also count CI v2 addresses seen at all (tokens phase) -> covered rows only is conservative
    missing = [p for p in all_pairs if p not in covered]
    print("covered:", len(covered), "| missing:", len(missing), flush=True)

    # 2. state + balances for missing pairs
    calls = []
    for p in missing:
        calls += [(p, SEL["token0"]), (p, SEL["token1"]), (p, SEL["getReserves"]), (p, SEL["totalSupply"])]
    r = batch(calls, chunk=100, workers=2)
    rows = []
    idx_bal = []
    calls_bal = []
    for i, p in enumerate(missing):
        t0_ = da(r[4 * i]); t1_ = da(r[4 * i + 1]); rv = r[4 * i + 2]; sup = du(r[4 * i + 3])
        res0 = res1 = None
        if rv and len(rv) >= 194:
            res0 = int(rv[2:66], 16); res1 = int(rv[66:130], 16)
        row = {"pair": p, "token0": t0_, "token1": t1_, "reserve0": res0, "reserve1": res1,
               "totalSupply": sup}
        rows.append(row)
        if t0_:
            calls_bal.append((t0_, SEL["balanceOf"] + enc_addr(p))); idx_bal.append((i, 0))
        if t1_:
            calls_bal.append((t1_, SEL["balanceOf"] + enc_addr(p))); idx_bal.append((i, 1))
    print("state fetched in", round(time.time() - t0, 1), "s", flush=True)
    rb = batch(calls_bal, chunk=100, workers=2)
    for (i, side), v in zip(idx_bal, rb):
        rows[i]["balance0" if side == 0 else "balance1"] = du(v)
    print("balances fetched in", round(time.time() - t0, 1), "s", flush=True)

    excess = []
    for row in rows:
        e0 = (row["balance0"] - row["reserve0"]) if (row.get("balance0") is not None and row["reserve0"] is not None) else None
        e1 = (row["balance1"] - row["reserve1"]) if (row.get("balance1") is not None and row["reserve1"] is not None) else None
        row["excess0"] = e0; row["excess1"] = e1
        if (e0 and e0 > 0) or (e1 and e1 > 0):
            excess.append(row)
    stats = {
        "all_pairs": len(all_pairs), "covered_in_ci_v2": len(covered), "missing_checked": len(missing),
        "missing_with_tokens": len([r for r in rows if r["token0"] and r["token1"]]),
        "missing_with_reserves": len([r for r in rows if r["reserve0"] is not None]),
        "missing_with_balances": len([r for r in rows if r.get("balance0") is not None and r.get("balance1") is not None]),
        "missing_zero_supply": len([r for r in rows if r["totalSupply"] == 0]),
        "excess_pairs": len(excess),
        "elapsed_s": round(time.time() - t0, 1),
        "rpc": "<redacted>",
    }
    json.dump({"stats": stats, "excess_pairs": excess, "rows": rows}, open(OUT, "w"))
    print("STATS", json.dumps(stats), flush=True)

if __name__ == "__main__":
    main()
