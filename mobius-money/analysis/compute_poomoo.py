#!/usr/bin/env python3
"""Holders + claimable POOF/MOO for gauges whose reward tokens are POOF+MOO."""
import json, time, urllib.request, sys

RPC = "https://forno.celo.org"
GAUGES = [
    "0x1250D6dd3B51D20c14a8ECb10CC2dd713967767e",
    "0xCF34F4ec5DC9E09428A4f4a45475f6277694166c",
    "0x5489b2F0A1992b889F47601D71E068Fd15c63f26",
    "0x2459BDb59a3BF6Ab6C412Ac0b220e7CDA1D4ea26",
    "0xE7195E651Cc47853f0054d85c8ADFc79D532929f",
    "0xD0d57a6689188F854F996BEAE0Cb1949FDB5FF86",
    "0xCAEd243de23264Bdd8297c6eECcF320846eee18A",
]
TOKENS = {"POOF": "0x00400fcbf0816bebb94654259de7273f4a05c762",
          "MOO": "0x17700282592d6917f6a73d0bf8accf4d578c131e"}
SEL_BAL = "0x70a08231"
SEL_CLAIMABLE = "0x33fd6f74"
SEL_RIF = "0xf05cc058"
SEL_RI = "0x73861fb3"


def fetch(url, tries=6):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research)"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print(" retry", i, e, file=sys.stderr, flush=True)
            time.sleep(2 + 2 * i)
    raise RuntimeError(url)


def batch(calls, tries=6):
    out = []
    for i in range(0, len(calls), 60):
        chunk = calls[i:i + 60]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": t, "data": d}, "latest"]} for j, (t, d) in enumerate(chunk)]
        for a in range(tries):
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research)"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    res = json.loads(r.read().decode())
                break
            except Exception as e:
                print(" retry", i, e, file=sys.stderr, flush=True)
                time.sleep(2 + 3 * a)
        by_id = {x["id"]: x for x in res}
        for j in range(len(chunk)):
            x = by_id.get(j, {})
            out.append(x.get("result") if "error" not in x else None)
        time.sleep(0.2)
    return out


def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def dec(x):
    if x is None or x == "0x":
        return 0
    return int(x, 16)


def holders(g):
    out = []
    url = f"https://celo.blockscout.com/api/v2/tokens/{g}/holders"
    while url:
        d = fetch(url)
        for it in d.get("items", []):
            a = (it.get("address") or {}).get("hash")
            if a:
                out.append(a.lower())
        npp = d.get("next_page_params")
        if not npp:
            break
        q = "&".join(f"{k}={v}" for k, v in npp.items())
        url = f"https://celo.blockscout.com/api/v2/tokens/{g}/holders?{q}"
        time.sleep(0.4)
    return out


res = {"note": "claimable POOF/MOO for current holders", "gauges": {}}
for g in GAUGES:
    users = holders(g)
    entry = {"holders": len(users), "tokens": {}}
    for name, tok in TOKENS.items():
        I = dec(batch([(g, SEL_RI + enc(tok))])[0])
        calls = []
        for u in users:
            calls.append((g, SEL_BAL + enc(u)))
            calls.append((g, SEL_CLAIMABLE + enc(u) + enc(tok)))
            calls.append((g, SEL_RIF + enc(tok) + enc(u)))
        r = batch(calls)
        total = 0
        rows = []
        for k, u in enumerate(users):
            bal = dec(r[3 * k]); stored = dec(r[3 * k + 1]); rif = dec(r[3 * k + 2])
            pending = bal * (I - rif) // 10**18 if I > rif else 0
            cl = stored + pending
            total += cl
            rows.append({"user": u, "bal": str(bal), "stored": str(stored),
                         "rif": str(rif), "pending": str(pending), "claimable": str(cl)})
        rows.sort(key=lambda x: -int(x["claimable"]))
        entry["tokens"][name] = {"reward_integral": str(I), "sum_claimable_wei": str(total),
                                 "gauge_balance_wei": None, "rows": rows}
    res["gauges"][g] = entry
    print(g, {n: entry["tokens"][n]["sum_claimable_wei"] for n in entry["tokens"]}, flush=True)
json.dump(res, open("gauge-claimables-poomoo.json", "w"), indent=1)
print("DONE")
