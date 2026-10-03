#!/usr/bin/env python3
"""Fetch current scLINK balances + account state for all candidate addresses."""
import json, time, urllib.request

RPC = "https://rpcapi.fantom.network"
CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"
LINKM = "0x2359012ebe36cca231203d78b914284947b58aa3"

SEL = {
    "balanceOf": "0x70a08231",
    "borrowBalanceCurrent": "0x17bfdfbc",
    "borrowBalanceStored": "0x95dd9193",
    "getAssetsIn": "0xabfceffc",
    "getAccountLiquidity": "0x5ec88c79",
    "accountTokens": "0x56e67728",  # wrong; placeholder
    "exchangeRateCurrent": "0xbd6d894d",
}

def pad(a): return a[2:].lower().rjust(64, "0")

def post(payload):
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    for a in range(5):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=60).read())
        except Exception:
            if a == 4: raise
            time.sleep(1)

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        resp = post(payload)
        by_id = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            out.append(r.get("result") if "result" in r else {"error": r.get("error")})
    return out

def call(to, sel, arg=None, block="latest"):
    data = sel + (pad(arg) if arg else "")
    return ["eth_call", [{"to": to, "data": data}, block]]

def main():
    actors = json.load(open("/home/heisenberg/CA/scream/analysis/sclink_actors.json"))
    addrs = set()
    for b in actors["borrowers"]:
        addrs.add(b["addr"])
    for h in actors["holders"]:
        addrs.add(h["addr"])
    # also every address that ever appeared in scLINK logs (any field)
    for line in open("/home/heisenberg/CA/scream/analysis/sclink_logs.jsonl"):
        lg = json.loads(line)
        data = lg["data"][2:]
        for i in range(0, len(data), 64):
            w = data[i:i+64]
            if len(w) == 64 and w[:24] == "0" * 24:
                addrs.add("0x" + w[24:])
    import os
    if os.path.exists("/home/heisenberg/CA/scream/analysis/all_addrs.json"):
        addrs |= set(json.load(open("/home/heisenberg/CA/scream/analysis/all_addrs.json")))
    addrs = sorted(addrs)
    print("candidate addresses:", len(addrs))

    # 1) scLINK balances
    calls = [call(LINKM, SEL["balanceOf"], a) for a in addrs]
    res = batch(calls)
    bal = {}
    for a, r in zip(addrs, res):
        bal[a] = int(r, 16) if isinstance(r, str) and r != "0x" else 0
    nz = {a: v for a, v in bal.items() if v > 0}
    print("current scLINK holders among candidates:", len(nz))
    print("total balance covered:", sum(nz.values())/1e8)

    # 2) borrow balances (current = accrued) for all candidates on scLINK
    calls = [call(LINKM, SEL["borrowBalanceCurrent"], a) for a in addrs]
    res = batch(calls)
    debt = {}
    for a, r in zip(addrs, res):
        debt[a] = int(r, 16) if isinstance(r, str) and r != "0x" else None
    dbt = {a: v for a, v in debt.items() if v}
    print("current scLINK borrowers among candidates:", len(dbt), "total:", sum(dbt.values())/1e18)

    out = {"block": None, "holders": nz, "borrowers": dbt}
    json.dump(out, open("/home/heisenberg/CA/scream/analysis/sclink_accounts.json", "w"), indent=2)
    for a, v in sorted(nz.items(), key=lambda kv: -kv[1])[:30]:
        print(f"HOLD {a} {v/1e8:.4f} ctokens debt={debt.get(a)}")
    print()
    for a, v in sorted(dbt.items(), key=lambda kv: -kv[1])[:30]:
        print(f"DEBT {a} {v/1e18:.6f} LINK bal={bal.get(a,0)/1e8:.4f}")

if __name__ == "__main__":
    main()
