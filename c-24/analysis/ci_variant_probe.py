#!/usr/bin/env python3
"""Probe DxSale variant lockers (no DXLOCKERLP getter): find currently-successful
unlockToken(j) calls per sampled wallet. Outputs ci-out/variant_probe.json."""
import json, os, sys, time, urllib.request

OUT = os.environ.get("CI_OUT", "ci-out")
os.makedirs(OUT, exist_ok=True)
BSC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"
ETH = os.environ.get("NODEREAL_ETH_RPC_URL") or os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
SEL_LR = "0x0e48606b"
SEL_UNLOCK = "0xdd2e0ac0"

def enc_u(x): return hex(int(x))[2:].rjust(64, "0")

def batch(rpc, calls, chunk=10):
    out = [None] * len(calls)
    for s in range(0, len(calls), chunk):
        sub = calls[s:s + chunk]
        for attempt in range(4):
            payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [c, "latest"]}
                       for i, c in enumerate(sub)]
            try:
                req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json", "User-Agent": "z"})
                res = json.load(urllib.request.urlopen(req, timeout=90))
                for x in res:
                    out[s + x["id"]] = "OK" if "result" in x else "REVERT:" + x.get("error", {}).get("message", "")[:100]
                break
            except Exception as e:
                if attempt == 3:
                    for i in range(len(sub)):
                        out[s + i] = "RPC_FAIL:" + str(e)[:60]
                time.sleep(1 + 2 * attempt)
        time.sleep(0.08)
    return out

def probe(rpc, locker, total, step, maxj):
    ids = list(range(0, total, step))
    wres = batch(rpc, [{"to": locker, "data": SEL_LR + enc_u(i)} for i in ids], chunk=15)
    wallets = []
    for i, r in zip(ids, wres):
        if isinstance(r, str) and r.startswith("0x") and len(r) >= 42:
            wallets.append((i, "0x" + r[-40:]))
    calls, meta = [], []
    for i, w in wallets:
        for j in range(maxj + 1):
            calls.append({"to": locker, "data": SEL_UNLOCK + enc_u(j), "from": w})
            meta.append((i, w, j))
    res = batch(rpc, calls, chunk=10)
    ok = [{"id": i, "wallet": w, "index": j} for (i, w, j), r in zip(meta, res) if r == "OK"]
    return {"locker": locker, "total": total, "sampled_wallets": len(wallets), "successes": ok}

def main():
    results = []
    for locker, total, step in [("0x2D045410f002A95EFcEE67759A92518fA3FcE677", 4938, 3),
                                ("0x81E0eF68e103Ee65002d3Cf766240eD1c070334d", 3970, 3)]:
        print(f"[probe] {locker}", flush=True)
        results.append(probe(BSC, locker, total, step, 3))
        print(f"  successes: {len(results[-1]['successes'])}", flush=True)
    json.dump(results, open(f"{OUT}/variant_probe.json", "w"), indent=1)
    print("VARIANT PROBE DONE", flush=True)

if __name__ == "__main__":
    main()
