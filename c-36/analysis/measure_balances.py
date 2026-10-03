#!/usr/bin/env python3
"""Measure live state (ETH balance, code, key selectors) for all 295 forgotten-eth contracts.
Read-only. Uses public RPC with batching + retries. Writes analysis/live_295.json.
"""
import json, time, sys, threading
import requests
from concurrent.futures import ThreadPoolExecutor

RPCS = [
    "https://ethereum-rpc.publicnode.com",
    "https://eth.drpc.org",
    "https://1rpc.io/eth",
]
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

# selectors: owner(), admin(), getOwner(), paused(), totalSupply(), name(), symbol(),
#            pendingOwner(), governance(), controller(), operator(), guardian()
SIGS = {
    "owner()": "0x8da5cb5b",
    "admin()": "0xf851a440",
    "getOwner()": "0x893d20e8",
    "paused()": "0x5c975abb",
    "totalSupply()": "0x18160ddd",
    "name()": "0x06fdde03",
    "symbol()": "0x95d89b41",
    "pendingOwner()": "0xe18a7b92",
    "governance()": "0x5aa6e675",
    "controller()": "0xf77c4791",
    "operator()": "0x570ca735",
    "guardian()": "0x452a9320",
    "withdrawable()": "0x3a5e3dab",
    "merkleRoot()": "0x2eb4a7ab",
}

def rpc_call(method, params, rpc, retries=4):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    for i in range(retries):
        try:
            r = requests.post(rpc, json=payload, headers=UA, timeout=25)
            j = r.json()
            if "result" in j:
                return j["result"]
            if "error" in j:
                return {"__error__": j["error"]}
        except Exception as e:
            pass
        time.sleep(0.4 * (i + 1))
    return None

def batch_call(calls, rpc, retries=3):
    """calls: list of (method, params). returns list of results (or error dicts)."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    for i in range(retries):
        try:
            r = requests.post(rpc, json=payload, headers=UA, timeout=40)
            j = r.json()
            out = [None] * len(calls)
            if isinstance(j, list):
                for item in j:
                    idx = item.get("id")
                    if "result" in item:
                        out[idx] = item["result"]
                    elif "error" in item:
                        out[idx] = {"__error__": item["error"]}
                return out
        except Exception:
            pass
        time.sleep(0.5 * (i + 1))
    return [None] * len(calls)

def main():
    rows = json.load(open("/home/heisenberg/CA/c-36/analysis/index_full.json"))
    block = rpc_call("eth_blockNumber", [], RPCS[0])
    blockn = int(block, 16)
    print("latest block", blockn)
    results = {}

    def measure(rpc):
        # build all calls per contract
        addrs = [r["contract"] for r in rows]
        out = {}
        lock = threading.Lock()
        def work(chunk):
            calls = []
            meta = []
            for a in chunk:
                calls.append(("eth_getBalance", [a, hex(blockn)])); meta.append((a, "bal"))
                calls.append(("eth_getCode", [a, hex(blockn)])); meta.append((a, "code"))
            res = batch_call(calls, rpc)
            with lock:
                for (a, kind), v in zip(meta, res):
                    out.setdefault(a, {})[kind] = v
        chunks = [addrs[i:i+10] for i in range(0, len(addrs), 10)]
        with ThreadPoolExecutor(max_workers=6) as ex:
            list(ex.map(work, chunks))
        return out

    # primary rpc
    state = measure(RPCS[0])
    missing = [a for a in [r["contract"] for r in rows] if not state.get(a, {}).get("bal") or not state.get(a, {}).get("code")]
    print("missing after primary:", len(missing))
    if missing:
        st2 = measure(RPCS[1])
        for a in missing:
            if st2.get(a):
                state[a] = st2[a]
    missing = [a for a in [r["contract"] for r in rows] if not state.get(a, {}).get("bal")]
    print("missing after fallback:", len(missing))
    if missing:
        for a in missing:
            state.setdefault(a, {})["bal"] = rpc_call("eth_getBalance", [a, hex(blockn)], RPCS[2])
            state[a]["code"] = rpc_call("eth_getCode", [a, hex(blockn)], RPCS[2])

    # selector probes (only for contracts with code) - sequential batches of 10
    live_addrs = [a for a in state if state[a].get("code") and state[a]["code"] != "0x"]
    print("contracts with code:", len(live_addrs))
    sel_calls = []
    sel_meta = []
    for a in live_addrs:
        for sig, sel in SIGS.items():
            sel_calls.append(("eth_call", [{"to": a, "data": sel}, hex(blockn)]))
            sel_meta.append((a, sig))
    # chunk 20
    for i in range(0, len(sel_calls), 20):
        res = batch_call(sel_calls[i:i+20], RPCS[0])
        for (a, sig), v in zip(sel_meta[i:i+20], res):
            state.setdefault(a, {}).setdefault("sel", {})[sig] = v

    json.dump({"block": blockn, "state": state}, open("/home/heisenberg/CA/c-36/analysis/live_295.json", "w"))
    # summary
    for r in rows:
        a = r["contract"]
        s = state.get(a, {})
        bal = s.get("bal")
        bal_eth = int(bal, 16) / 1e18 if isinstance(bal, str) else None
        code = s.get("code")
        r["live_eth"] = bal_eth
        r["has_code"] = bool(code and code != "0x")
        r["code_size"] = (len(code) - 2) // 2 if isinstance(code, str) and code != "0x" else 0
        sel = s.get("sel", {})
        def dec_addr(v):
            if isinstance(v, str) and len(v) == 66 and v != "0x" + "0"*64:
                return "0x" + v[-40:]
            return None
        def dec_bool(v):
            if isinstance(v, str) and v.startswith("0x"):
                try: return int(v, 16) != 0
                except: return None
            return None
        r["sel_owner"] = dec_addr(sel.get("owner()"))
        r["sel_admin"] = dec_addr(sel.get("admin()"))
        r["sel_getOwner"] = dec_addr(sel.get("getOwner()"))
        r["sel_paused"] = dec_bool(sel.get("paused()"))
        r["sel_totalSupply_raw"] = sel.get("totalSupply()") if isinstance(sel.get("totalSupply()"), str) else None
    json.dump(rows, open("/home/heisenberg/CA/c-36/analysis/index_full_live.json", "w"), indent=1)
    live = [r for r in rows if (r.get("live_eth") or 0) > 0.0001]
    live.sort(key=lambda r: -(r.get("live_eth") or 0))
    print(f"contracts with live ETH>0.0001: {len(live)}  total {sum(r['live_eth'] for r in live):.2f}")
    for r in live[:40]:
        print(f"{r['live_eth']:12.4f}  {str(r['name'])[:40]:42s} {r['contract']}  src={r['source']} cat={r['category']}")

if __name__ == "__main__":
    main()
