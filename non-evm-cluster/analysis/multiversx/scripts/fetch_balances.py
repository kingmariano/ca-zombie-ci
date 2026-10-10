#!/usr/bin/env python3
"""Read-only balance fetcher for MultiversX candidate contracts (keyless public API).
Usage: python3 fetch_balances.py
Writes: ../raw/candidate_balances.json  (address -> account, tokens, nfts count, delegation-legacy)
Prints a summary table.
"""
import json, os, sys, time, urllib.request

BASE = "https://api.multiversx.com"
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")

def get(path, retries=4, timeout=45):
    url = BASE + path
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "research-readonly/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if i == retries - 1:
                return {"__error__": str(e), "__path__": path}
            time.sleep(1.5 * (i + 1))

def main():
    with open(os.path.join(RAW, "candidates.json")) as f:
        cands = json.load(f)
    out = {}
    for c in cands["targets"]:
        name, addr, cat = c["name"], c["address"], c["category"]
        if addr in out:
            continue
        rec = {"name": name, "category": cat}
        rec["account"] = get(f"/accounts/{addr}")
        rec["tokens"] = get(f"/accounts/{addr}/tokens?size=100")
        rec["nfts"] = get(f"/accounts/{addr}/nfts?size=100")
        rec["delegation_legacy"] = get(f"/accounts/{addr}/delegation-legacy")
        out[addr] = rec
        print(f"[{len(out):3d}] {name:42s} {addr[:20]}... bal={rec['account'].get('balance','?')}", flush=True)
        time.sleep(0.12)
    os.makedirs(RAW, exist_ok=True)
    dest = os.path.join(RAW, "candidate_balances.json")
    tmp = dest + ".tmp"
    with open(tmp, "w") as f:
        json.dump(out, f, indent=1)
    os.replace(tmp, dest)
    print("wrote", dest)

    # summary
    print("\n=== SUMMARY (EGLD + ESDT) ===")
    for addr, rec in out.items():
        acc = rec["account"]
        if "__error__" in acc:
            print(f"{rec['name']:42s} ERROR {acc['__error__'][:60]}")
            continue
        e = int(acc.get("balance", 0)) / 1e18
        toks = rec["tokens"]
        tsum = ""
        if isinstance(toks, list) and toks:
            parts = []
            for t in toks[:6]:
                try:
                    d = t.get("decimals", 18)
                    v = int(t.get("balance", "0")) / (10 ** d)
                    usd = t.get("valueUsd")
                    p = (f"{v:,.4f} {t['identifier']}" if v < 1e6 else f"{v:,.0f} {t['identifier']}")
                    if usd:
                        p += f" (${usd:,.0f})"
                    parts.append(p)
                except Exception:
                    parts.append(t.get("identifier", "?"))
            tsum = "; ".join(parts)
        print(f"{rec['name']:42s} EGLD={e:>14,.4f}  tokens[{len(toks) if isinstance(toks,list) else '?'}]: {tsum}")

if __name__ == "__main__":
    main()
