#!/usr/bin/env python3
"""Enumerate ALL Cozy Set (CSET) tokens on Optimism via explorer search, then
batch-read asset/setState/totalSupply/USDC.e balance for each at the latest block.

Public RPC only. Read-only.
"""
import json
import subprocess
import sys
import time
from urllib.parse import urlencode
from concurrent.futures import ThreadPoolExecutor

EXPLORER = "https://explorer.optimism.io"
RPC = "https://optimism-rpc.publicnode.com"
USDC = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"


def curl_json(url):
    out = subprocess.run(["curl", "-s", "-m", "60", url, "-H", "User-Agent: Mozilla/5.0"],
                         capture_output=True, text=True, timeout=90)
    return json.loads(out.stdout)


def rpc_batch(calls):
    """calls: list of (method, params) -> list of results"""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    out = subprocess.run(["curl", "-s", "-m", "60", "-X", "POST", RPC, "-H", "Content-Type: application/json",
                          "-d", json.dumps(payload)], capture_output=True, text=True, timeout=120)
    try:
        data = json.loads(out.stdout)
    except Exception:
        return [None] * len(calls)
    res = [None] * len(calls)
    if isinstance(data, dict):
        return res
    for item in data:
        if "result" in item:
            res[item["id"]] = item["result"]
    return res


def sig(s):
    out = subprocess.run(["cast", "sig", s], capture_output=True, text=True)
    return out.stdout.strip()


SEL_ASSET = sig("asset()")
SEL_STATE = sig("setState()")
SEL_TS = sig("totalSupply()")
SEL_BAL = sig("balanceOf(address)")
print("selectors:", SEL_ASSET, SEL_STATE, SEL_TS, SEL_BAL, file=sys.stderr)


def pad(addr):
    return addr.lower().replace("0x", "").rjust(64, "0")


def enc(sel, addr=None):
    if addr is None:
        return sel
    return sel + pad(addr)


def probe(token):
    calls = [
        ("eth_call", [{"to": token, "data": enc(SEL_ASSET)}, "latest"]),
        ("eth_call", [{"to": token, "data": enc(SEL_STATE)}, "latest"]),
        ("eth_call", [{"to": token, "data": enc(SEL_TS)}, "latest"]),
        ("eth_call", [{"to": USDC, "data": enc(SEL_BAL, token)}, "latest"]),
    ]
    r = rpc_batch(calls)
    def as_int(x):
        if not x or x == "0x":
            return None
        return int(x, 16)
    def as_addr(x):
        if not x or x == "0x":
            return None
        return "0x" + x[-40:]
    return {
        "token": token,
        "asset": as_addr(r[0]),
        "setState": as_int(r[1]),
        "totalSupply": as_int(r[2]),
        "usdce": as_int(r[3]),
    }


def main():
    tokens = {}
    for q in ["Cozy Set", "Cozy PToken"]:
        params = {"q": q, "type": "ERC-20"}
        pages = 0
        while True:
            url = f"{EXPLORER}/api/v2/tokens?" + urlencode(params)
            d = curl_json(url)
            items = d.get("items", [])
            for it in items:
                tokens[it["address_hash"]] = (it.get("name"), it.get("symbol"))
            pages += 1
            nxt = d.get("next_page_params")
            if not nxt or pages > 60:
                break
            cursor = nxt.get("contract_address_hash")
            if not cursor:
                break
            params = {"q": q, "type": "ERC-20", "contract_address_hash": cursor}
            time.sleep(0.3)
        print(f"query={q!r} pages={pages}", file=sys.stderr)

    addrs = list(tokens.keys())
    results = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        for res in ex.map(probe, addrs):
            results.append(res)

    out = {"rpc": "publicnode (public)", "usdc": USDC, "count": len(results), "sets": results}
    with open(sys.argv[1] if len(sys.argv) > 1 else "all_sets.json", "w") as fh:
        json.dump(out, fh, indent=1)

    print("=== Tokens with USDC.e balance > 0 ===")
    for r in sorted(results, key=lambda x: -(x["usdce"] or 0)):
        if (r["usdce"] or 0) > 0:
            nm = tokens.get(r["token"], (None, None))
            print(f"{r['token']} {nm} asset={r['asset']} state={r['setState']} supply={r['totalSupply']} usdce={r['usdce']/1e6:.6f}")


if __name__ == "__main__":
    main()
