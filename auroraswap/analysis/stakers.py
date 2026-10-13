#!/usr/bin/env python3
"""Enumerate BRLMasterChef stakers (Deposit events) and compute exact pending BRL
per (pid,user) from current on-chain userInfo + pool accBRLPerShare. Read-only."""
import json
import os
import time
import urllib.parse
import urllib.request

BASE = os.path.dirname(__file__)
MC = "0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE"
RPC = os.environ.get("AURORA_RPC", "https://mainnet.aurora.dev")
DEPOSIT = "0x90890809c654f11d6e72a28fa60149770a0d11ec6c92319d6ceb2bb0a4ea1a15"
API = f"https://explorer.aurora.dev/api/v2/addresses/{MC}/logs"


def http_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


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


def w(h, i=0):
    if not h or h == "0x" or len(h) < 2 + (i + 1) * 64:
        return None
    return int(h[2 + i * 64 : 2 + (i + 1) * 64], 16)


def main():
    # 1) collect all Deposit events (user, pid)
    users = set()
    params = None
    pages = 0
    while True:
        url = API + "?topic=" + DEPOSIT
        if params:
            url += "&" + urllib.parse.urlencode(params)
        d = http_json(url)
        items = d.get("items", [])
        for it in items:
            t = it.get("topics") or []
            if len(t) >= 3:
                user = "0x" + t[1][-40:]
                pid = int(t[2], 16)
                users.add((pid, user))
        pages += 1
        params = d.get("next_page_params")
        if not params or pages > 400:
            break
        time.sleep(0.25)
    print(f"pages {pages}, distinct (pid,user) pairs: {len(users)}")

    # 2) read current userInfo + acc per pool
    accs = {}
    for pid in sorted({p for p, _ in users}):
        pi = call(MC, "0x1526fe27" + hex(pid)[2:].rjust(64, "0"))
        accs[pid] = w(pi, 3)
    rows = []
    for pid, user in sorted(users):
        ui = call(MC, "0x93f1a40b" + hex(pid)[2:].rjust(64, "0") + user.lower().replace("0x", "").rjust(64, "0"))
        amt, debt = w(ui, 0), w(ui, 1)
        acc = accs.get(pid) or 0
        pending = amt * acc // 10**12 - debt if amt else 0
        if pending < 0:
            pending = 0
        rows.append({"pid": pid, "user": user, "amount": amt, "rewardDebt": debt, "pending": pending})
    json.dump(rows, open(os.path.join(BASE, "stakers.json"), "w"), indent=1)

    active = [r for r in rows if r["amount"] > 0]
    pend = [r for r in rows if r["pending"] > 0]
    print(f"stakers with amount>0: {len(active)}; with pending>0: {len(pend)}")
    tot = sum(r["pending"] for r in pend)
    print(f"TOTAL pending BRL (current acc, before gap update): {tot/1e18:,.2f}")
    owner = "0xfdf4af84764e67333985af2db9b1fe57dfec8251"
    own_pend = sum(r["pending"] for r in pend if r["user"].lower() == owner)
    print(f"  of which MC owner: {own_pend/1e18:,.2f} BRL")
    print("top 15 pending:")
    for r in sorted(pend, key=lambda x: -x["pending"])[:15]:
        print(f"  pid {r['pid']:>2} user {r['user']} amount {r['amount']/1e18:>20,.6f} pending {r['pending']/1e18:>16,.2f} BRL")


if __name__ == "__main__":
    main()
