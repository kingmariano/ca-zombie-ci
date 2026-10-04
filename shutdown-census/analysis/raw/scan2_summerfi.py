#!/usr/bin/env python3
"""Batch-scan Summer.fi bot mappings via JSON-RPC (read-only). UA header avoids 403."""
import json, sys, time, urllib.request
from eth_hash.auto import keccak as k

def keccak256(b): return k(b)

UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research; read-only)"}

def rpc(url, calls, retries=5, sleep=1.5):
    payload = json.dumps(calls).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=payload, headers=UA)
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if i == retries - 1:
                raise
            print("   retry", i, str(e)[:80], file=sys.stderr)
            time.sleep(sleep * (i + 1))

def scan(url, bot, slot, first, last, batch=50, second=False):
    ids = list(range(first, last + 1))
    active = {}
    for i in range(0, len(ids), batch):
        chunk = ids[i:i + batch]
        calls = []
        for idx, tid in enumerate(chunk):
            key = keccak256(tid.to_bytes(32, "big") + slot.to_bytes(32, "big"))
            calls.append({"jsonrpc": "2.0", "id": idx, "method": "eth_getStorageAt",
                          "params": [bot, "0x" + key.hex(), "latest"]})
        resp = rpc(url, calls)
        by = {r.get("id"): r.get("result") for r in resp}
        for idx, tid in enumerate(chunk):
            v = by.get(idx)
            if v and int(v, 16) != 0:
                active[tid] = v
        print(f"  {bot[:10]} {i+len(chunk)}/{len(ids)} active={len(active)}", file=sys.stderr)
    if second:
        # read record slot+1 for active ids (cdpId / commandAddress+continuous)
        out = {}
        keys = list(active)
        for i in range(0, len(keys), batch):
            chunk = keys[i:i + batch]
            calls = []
            for idx, tid in enumerate(chunk):
                key = keccak256(tid.to_bytes(32, "big") + slot.to_bytes(32, "big"))
                key2 = (int.from_bytes(key, "big") + 1).to_bytes(32, "big")
                calls.append({"jsonrpc": "2.0", "id": idx, "method": "eth_getStorageAt",
                              "params": [bot, "0x" + key2.hex(), "latest"]})
            resp = rpc(url, calls)
            by = {r.get("id"): r.get("result") for r in resp}
            for idx, tid in enumerate(chunk):
                out[tid] = by.get(idx)
        return active, out
    return active

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "v2":
        jobs = {
            "eth_v2": ["https://ethereum-rpc.publicnode.com", "0x5743b5606e94fb534a31e1cefb3242c8a9422e5e", 2, 10000000001, 10000001119],
            "base_v2": ["https://mainnet.base.org", "0x96D494b4544Bb7c3CB687ef7a9886Ed469e01ed8", 2, 10000000001, 10000000588],
            "arb_v2": ["https://arb1.arbitrum.io/rpc", "0xE018AeA83728a037D8B6f76cCA0E8331cDAb937a", 2, 10000000001, 10000000857],
            "op_v2": ["https://mainnet.optimism.io", "0xb2e2a088d9705cd412CE6BF94e765743Ec26b1e4", 2, 10000000001, 10000000324],
        }
        which = sys.argv[2:] if len(sys.argv) > 2 else list(jobs)
        summary = {}
        for name in which:
            url, bot, slot, a, b = jobs[name]
            print("SCAN", name, file=sys.stderr)
            try:
                act, second = scan(url, bot, slot, a, b, second=True)
                json.dump({"active": act, "records": second}, open(f"summerfi_{name}_active2.json", "w"))
                summary[name] = len(act)
            except Exception as e:
                summary[name] = f"ERR {e}"
        print(json.dumps(summary))
