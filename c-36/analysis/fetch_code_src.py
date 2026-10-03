#!/usr/bin/env python3
"""Fetch code + selectors + Blockscout source metadata for all 295 contracts."""
import json, time, re, threading
import requests
from concurrent.futures import ThreadPoolExecutor

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}
RPC = "https://ethereum-rpc.publicnode.com"

def rpc_batch(calls, retries=3):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    for i in range(retries):
        try:
            r = requests.post(RPC, json=payload, headers=UA, timeout=60)
            j = r.json()
            out = [None]*len(calls)
            if isinstance(j, list):
                for item in j:
                    idx = item.get("id")
                    if "result" in item: out[idx] = item["result"]
                    elif "error" in item: out[idx] = {"__error__": item["error"]}
                return out
        except Exception:
            pass
        time.sleep(0.5*(i+1))
    return [None]*len(calls)

def extract_selectors(code_hex):
    if not code_hex or code_hex == "0x": return []
    b = bytes.fromhex(code_hex[2:])
    sels = set()
    i = 0
    n = len(b)
    while i < n:
        op = b[i]
        if op == 0x63 and i+4 < n:  # PUSH4
            sels.add(b[i+1:i+5].hex())
            i += 5
        elif 0x60 <= op <= 0x7f:
            i += op - 0x5f + 1
        else:
            i += 1
    return sorted(sels)

def bs_fetch(addr):
    for attempt in range(3):
        try:
            r = requests.get(f"https://eth.blockscout.com/api/v2/smart-contracts/{addr}", headers=UA, timeout=30)
            if r.status_code == 200:
                return r.json()
            if r.status_code == 404:
                return {"__notfound__": True}
        except Exception:
            pass
        time.sleep(1.0*(attempt+1))
    return None

def main():
    rows = json.load(open("/home/heisenberg/CA/c-36/analysis/index_full.json"))
    addrs = [r["contract"] for r in rows]
    block = int(requests.post(RPC, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, headers=UA, timeout=20).json()["result"], 16)
    print("block", block)
    code = {}
    for i in range(0, len(addrs), 10):
        chunk = addrs[i:i+10]
        res = rpc_batch([("eth_getCode", [a, hex(block)]) for a in chunk])
        for a, c in zip(chunk, res):
            code[a] = c
    print("codes fetched")

    src = {}
    lock = threading.Lock()
    def work(a):
        r = bs_fetch(a)
        with lock:
            src[a] = r
    with ThreadPoolExecutor(max_workers=4) as ex:
        list(ex.map(work, addrs))
    print("blockscout fetched")

    out = {"block": block, "contracts": {}}
    for r in rows:
        a = r["contract"]
        c = code.get(a)
        s = src.get(a) or {}
        rec = {
            "selectors": extract_selectors(c),
            "code_size": (len(c)-2)//2 if c and c != "0x" else 0,
            "bs_name": s.get("name"),
            "bs_verified": s.get("is_verified"),
            "bs_proxy_type": (s.get("proxy_type") if isinstance(s.get("proxy_type"), str) else None),
            "bs_implementations": [i.get("address_hash") for i in (s.get("implementations") or [])] if isinstance(s.get("implementations"), list) else [],
            "bs_language": s.get("language"),
        }
        out["contracts"][a] = rec
    json.dump(out, open("/home/heisenberg/CA/c-36/analysis/code_src_295.json", "w"))
    # summary
    ver = sum(1 for a, v in out["contracts"].items() if v["bs_verified"])
    print(f"verified: {ver}/295; dead code: {sum(1 for v in out['contracts'].values() if v['code_size']==0)}")

if __name__ == "__main__":
    main()
