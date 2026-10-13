#!/usr/bin/env python3
"""Read full BRLMasterChef pool state: poolInfo + correct lpSupply (balanceOf(MC))."""
import json
import os
import time
import urllib.request

RPC = os.environ.get("AURORA_RPC", "https://mainnet.aurora.dev")
MC = "0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE"
BASE = os.path.dirname(__file__)


def rpc(method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for a in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                out = json.load(r)
            if "result" in out:
                return out["result"]
        except Exception:  # noqa: BLE001
            pass
        time.sleep(1 + 2 * a)
    return None


def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])


def batch(calls, block="latest", chunk=10):
    res = []
    for i in range(0, len(calls), chunk):
        part = calls[i : i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": t, "data": d}, block]} for j, (t, d) in enumerate(part)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        out = None
        for a in range(5):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    out = json.load(r)
                break
            except Exception:  # noqa: BLE001
                time.sleep(1 + 2 * a)
        by_id = {it["id"]: it.get("result") for it in out}
        res.extend(by_id.get(j) for j in range(len(part)))
        time.sleep(0.2)
    return res


def word(h, i):
    if not h or h == "0x":
        return None
    return int(h[2 + i * 64 : 2 + (i + 1) * 64], 16)


def addr(h, i):
    w = word(h, i)
    return None if w is None else "0x" + hex(w)[2:].rjust(40, "0")


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    n = word(call(MC, "0x081e3eda"), 0)  # poolLength()
    print("block", block, "poolLength", n)
    out = []
    for pid in range(n):
        pi = call(MC, "0x1526fe27" + hex(pid)[2:].rjust(64, "0"))  # poolInfo(uint256)
        if pi is None:
            continue
        lp = addr(pi, 0)
        alloc = word(pi, 1)
        last = word(pi, 2)
        acc = word(pi, 3)
        fee = word(pi, 4)
        sup = word(call(lp, "0x70a08231" + MC.lower().replace("0x", "").rjust(64, "0")), 0)
        out.append({"pid": pid, "lpToken": lp, "allocPoint": alloc, "lastRewardBlock": last,
                    "accBRLPerShare": acc, "depositFeeBP": fee, "lpSupply": sup})
        print(f"pid {pid:>2} alloc {alloc:>6} last {last} acc {acc} supply {sup} lp {lp}")
    json.dump({"block": block, "pools": out}, open(os.path.join(BASE, "mc_pool_detail.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
