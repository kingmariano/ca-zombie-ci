#!/usr/bin/env python3
"""Recursively fetch ALL Borrow logs for a market via the Aurora explorer v1 API (1000-log cap)."""
import json
import sys
import time
import urllib.request

API = "https://explorer.aurora.dev/api"
BORROW_TOPIC = "0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80"
MARKETS = {
    "auUSDC": "0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
    "auETH": "0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
    "auWBTC": "0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
    "auUSDT": "0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
    "auDAI": "0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
    "auWNEAR": "0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
    "auSTNEAR": "0x3195949f267702723bc614cAE037cdc8D1E94786",
    "auNEARX": "0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
    "auUSDCNative": "0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
    "auUSDTNative": "0xdDfd0407220026c6566979B5be6A4983d1247a3E",
}
LATEST = int(sys.argv[2], 16) if len(sys.argv) > 2 else None
NAME = sys.argv[1]
ADDR = MARKETS[NAME]
cache = {}


def get_logs(address, topic0, frm, to):
    key = (frm, to)
    if key in cache:
        return cache[key]
    url = (f"{API}?module=logs&action=getLogs&address={address}&topic0={topic0}"
           f"&fromBlock={frm}&toBlock={to}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for _ in range(4):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=60))
            r = d.get("result") or []
            cache[key] = r
            return r
        except Exception:
            time.sleep(2)
    raise RuntimeError(f"failed {frm}-{to}")


def main():
    out = []
    stack = [(0, LATEST)]
    calls = 0
    while stack:
        frm, to = stack.pop()
        if frm > to:
            continue
        logs = get_logs(ADDR, BORROW_TOPIC, frm, to)
        calls += 1
        if len(logs) >= 1000 and to > frm:
            mid = (frm + to) // 2
            stack.append((mid + 1, to))
            stack.append((frm, mid))
        else:
            out.extend(logs)
        if calls % 25 == 0:
            print(f"  calls={calls} stack={len(stack)} collected={len(out)}", flush=True)
    out.sort(key=lambda x: int(x["blockNumber"], 16))
    json.dump(out, open(f"/home/heisenberg/CA/aurigami/analysis/borrows_{NAME}.json", "w"))
    uniq = {}
    for lg in out:
        b = bytes.fromhex(lg["data"][2:])
        who = "0x" + b[12:32].hex()
        uniq[who] = uniq.get(who, 0) + 1
    print(f"{NAME}: logs={len(out)} unique_borrowers={len(uniq)} calls={calls}")
    json.dump(uniq, open(f"/home/heisenberg/CA/aurigami/analysis/borrowers_{NAME}.json", "w"))


if __name__ == "__main__":
    main()
