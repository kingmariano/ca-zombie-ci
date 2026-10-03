#!/usr/bin/env python3
"""C-24 DxSale locker enumeration (raw). Saves JSON per target into ci-out/.

Targets: BSC legacy lockers (v1 buggy + fixed family), BSC V3 LP registry,
cross-chain lockers. Valuation/classification is a separate pass (ci_value.py).
"""
import json, os, sys, time, urllib.request

OUT = os.environ.get("CI_OUT", "ci-out")
os.makedirs(OUT, exist_ok=True)

BSC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"
ETH = os.environ.get("NODEREAL_ETH_RPC_URL") or os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
POLY = os.environ.get("POLYGON_RPC_URL") or "https://polygon-bor-rpc.publicnode.com"
ARB = os.environ.get("ARB_RPC_URL") or "https://arbitrum-one-rpc.publicnode.com"
AVAX = "https://avalanche-c-chain-rpc.publicnode.com"
GNOSIS = os.environ.get("GNOSIS_RPC_URL") or "https://gnosis-rpc.publicnode.com"

SEL = {
    "lockerNumberOpen": "0x65057350",
    "LockerRecord": "0x0e48606b",
    "UserLockerCount": "0xc7450462",
    "DXLOCKERLP": "0xae4f4df1",
    "balanceOf": "0x70a08231",
    "owner": "0x8da5cb5b",
    "lockFees": "0xab366292",
    "lockerIDCount": "0x2247b817",
    "AllLockRecord": "0x1e330895",
}

def enc_u(x): return hex(int(x))[2:].rjust(64, "0")
def enc_a(a): return a.lower().replace("0x", "").rjust(64, "0")
def u256(h):
    if not h or not isinstance(h, str) or h.startswith(("REVERT", "RPC_FAIL")) or h == "0x":
        return None
    try: return int(h, 16)
    except Exception: return None

class Rpc:
    def __init__(self, url, chunk=20, sleep=0.1, retries=5, tag="rpc"):
        self.url, self.chunk, self.sleep, self.retries, self.tag = url, chunk, sleep, retries, tag
        self.calls = 0
    def batch(self, calls):
        out = [None] * len(calls)
        for s in range(0, len(calls), self.chunk):
            sub = calls[s:s + self.chunk]
            for attempt in range(self.retries):
                payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                            "params": [{"to": to, "data": data}, "latest"]}
                           for i, (to, data) in enumerate(sub)]
                try:
                    req = urllib.request.Request(self.url, data=json.dumps(payload).encode(),
                                                 headers={"Content-Type": "application/json",
                                                          "User-Agent": "zombie-research/1.0"})
                    with urllib.request.urlopen(req, timeout=120) as r:
                        res = json.load(r)
                    for x in res:
                        i = x.get("id")
                        out[s + i] = (x.get("result") if "result" in x
                                      else "REVERT:" + x.get("error", {}).get("message", "")[:120])
                    break
                except Exception as e:
                    if attempt == self.retries - 1:
                        for i in range(len(sub)):
                            out[s + i] = "RPC_FAIL:" + str(e)[:60]
                    time.sleep(1.5 + 2.5 * attempt)
            self.calls += len(sub)
            time.sleep(self.sleep)
        return out

def enumerate_legacy(rpc, locker, max_ids=None):
    res = rpc.batch([(locker, SEL["owner"]), (locker, SEL["lockFees"]), (locker, SEL["lockerNumberOpen"])])
    owner = u256(res[0]); fees = u256(res[1]); total = u256(res[2]) or 0
    meta = {"locker": locker, "owner": "0x" + hex(owner)[2:].rjust(40, "0") if owner is not None else None,
            "lockFees": str(fees) if fees is not None else None, "lockerNumberOpen": total}
    ids = list(range(total))
    if max_ids: ids = ids[:max_ids]
    wres = rpc.batch([(locker, SEL["LockerRecord"] + enc_u(i)) for i in ids])
    wallets = []
    for r in wres:
        v = u256(r)
        if v is not None: wallets.append("0x" + hex(v)[2:].rjust(40, "0"))
    uniq = list(dict.fromkeys(wallets))
    # detect variants without the DXLOCKERLP(address,uint256) getter (older DxLock code)
    if uniq:
        probe = rpc.batch([(locker, SEL["DXLOCKERLP"] + enc_a(uniq[0]) + enc_u(0))])[0]
        if isinstance(probe, str) and probe.startswith("REVERT") and probe.endswith("0x"):
            return {"meta": meta, "records": [], "tokens": [], "note": "variant: no DXLOCKERLP getter"}
    counts = rpc.batch([(locker, SEL["UserLockerCount"] + enc_a(w)) for w in uniq])
    calls, mrec = [], []
    for w, c in zip(uniq, counts):
        n = u256(c) or 0
        for j in range(n):
            calls.append((locker, SEL["DXLOCKERLP"] + enc_a(w) + enc_u(j)))
            mrec.append((w, j))
    rres = rpc.batch(calls)
    records = []
    for (w, j), r in zip(mrec, rres):
        if not isinstance(r, str) or r.startswith(("REVERT", "RPC_FAIL")) or r == "0x":
            continue
        raw = r[2:]
        def word(k): return raw[k * 64:(k + 1) * 64]
        try:
            exists = int(word(0), 16) & 1
            locked = int(word(1), 16) & 1
            amount = int(word(3), 16)
            lt = int(word(4), 16); st = int(word(5), 16)
            lp = "0x" + word(6)[24:]
        except Exception:
            continue
        if not exists: continue
        records.append({"wallet": w, "idx": j, "locked": bool(locked), "amount": str(amount),
                        "lockedTime": lt, "startTime": st, "lp": lp})
    toks = list(dict.fromkeys(r["lp"] for r in records))
    bres = rpc.batch([(t, SEL["balanceOf"] + enc_a(locker)) for t in toks]) if toks else []
    balances = {t: (u256(b) or 0) for t, b in zip(toks, bres)}
    tokens = [{"lp": t, "balance": str(balances.get(t, 0))} for t in toks]
    return {"meta": meta, "records": records, "tokens": tokens}

def enumerate_v3(rpc, registry, max_ids=None):
    cnt = u256(rpc.batch([(registry, SEL["lockerIDCount"])])[0]) or 0
    ids = list(range(cnt))
    if max_ids: ids = ids[:max_ids]
    raw = rpc.batch([(registry, SEL["AllLockRecord"] + enc_u(i)) for i in ids])
    recs = []
    for i, r in enumerate(raw):
        if not isinstance(r, str) or r.startswith(("REVERT", "RPC_FAIL")) or r == "0x":
            continue
        w = r[2:]
        def word(k): return w[k * 64:(k + 1) * 64]
        try:
            created = int(word(0), 16)
            lock_owner = "0x" + word(1)[24:]
            lp_token = "0x" + word(2)[24:]
            lock_time = int(word(3), 16)
            escrow = "0x" + word(4)[24:]
            locked = bool(int(word(5), 16) & 1)
            amt = int(word(7), 16)
            exists = bool(int(word(9), 16) & 1)
            t0 = "0x" + word(10)[24:]; t1 = "0x" + word(11)[24:]
        except Exception:
            continue
        if not exists: continue
        recs.append({"id": i, "createdOn": created, "lockOwner": lock_owner, "lpToken": lp_token,
                     "lockTime": lock_time, "escrow": escrow, "locked": locked,
                     "lockedAmount": str(amt), "token0": t0, "token1": t1})
    bals = rpc.batch([(r["lpToken"], SEL["balanceOf"] + enc_a(r["escrow"])) for r in recs]) if recs else []
    for r, b in zip(recs, bals):
        r["escrowBalance"] = str(u256(b) or 0)
    return {"registry": registry, "count": cnt, "records": recs}

def save(name, obj):
    with open(f"{OUT}/{name}.json", "w") as f:
        json.dump(obj, f, indent=1)
    print(f"[saved] {name}: {len(obj.get('records', []))} records, {len(obj.get('tokens', []))} tokens", flush=True)

def main():
    rb = Rpc(BSC, tag="bsc")
    # record the block number for all reads
    try:
        payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}
        req = urllib.request.Request(BSC, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "z"})
        blk = json.load(urllib.request.urlopen(req, timeout=30)).get("result")
        print("BSC block:", int(blk, 16), flush=True)
        json.dump({"block": int(blk, 16)}, open(f"{OUT}/block.json", "w"))
    except Exception as e:
        print("block fetch failed:", e, flush=True)
    specs = [
        ("bsc_v1_0xEb3a", "0xEb3a9C56d963b971d320f889bE2fb8B59853e449"),
        ("bsc_0x8655", "0x8655E5c4D701186D16765d1CDcef6D5287E4679a"),
        ("bsc_0x5b5e", "0x5b5e94485c9628793B01A38762921Dc37B6829b6"),
        ("bsc_0x2D04", "0x2D045410f002A95EFcEE67759A92518fA3FcE677"),
        ("bsc_0x81E0", "0x81E0eF68e103Ee65002d3Cf766240eD1c070334d"),
    ]
    for name, locker in specs:
        print(f"[{name}] enumerating ...", flush=True)
        save(name, enumerate_legacy(rb, locker))
    print("[v3_bsc] enumerating registry ...", flush=True)
    save("v3_bsc", enumerate_v3(rb, "0xFEE2A3f4329e9A1828F46927bD424DB2C1624985"))

    cross = [
        ("eth_v1_0x1Ba0", ETH, "0x1Ba00C14F9E8D1113028a14507F1394Dc9310fbD"),
        ("eth_0xc68C", ETH, "0xc68C522682614A9F1D336f756c0C0D71352925D3"),
        ("eth_0xe740", ETH, "0xe74083baFE69cd74519C6a40a3Ad0723BD360BDD"),
        ("eth_0x916a", ETH, "0x916a8C33B784f6399Ce8b7aff59d4AAD29386B8E"),
        ("eth_0xBae2", ETH, "0xBae21D4247dd3818f720ab4210C095E84e980D96"),
        ("poly_v1_0xEb3a", POLY, "0xEb3a9C56d963b971d320f889bE2fb8B59853e449"),
        ("poly_0x6FCC", POLY, "0x6FCC2e4Efb4E05DdfC2154AbE209356d5A687666"),
        ("poly_0x0360", POLY, "0x036063706396Ad5Dc49241451E955fbE05899cDe"),
        ("poly_0xb556", POLY, "0xb5566a206a89bd9C004230e6F6ac7335C77043cd"),
        ("arb_0x51f4", ARB, "0x51f411d40641475576622c8fba77F1e917e96Df4"),
        ("arb_0xdf17", ARB, "0xdf17aC098Fa81373625e102061844C02ECCEc645"),
        ("avax_0x77D0", AVAX, "0x77D054b8e61A141CE51fc9Cc3E9E2C3B79F57809"),
        ("avax_0x10f4", AVAX, "0x10f485B855bE8E7D377fbE60E5D5676d88817b95"),
        ("gnosis_0x832C", GNOSIS, "0x832CcF861059Cb352515E89Cc54F1b13C6620D37"),
        ("gnosis_0x554d", GNOSIS, "0x554d523a54471F12dDE2152A7F33E159404d199e"),
        ("harmony_0x1345", "https://api.harmony.one", "0x13455DeE5199691f11ffBb4AAf59Af56F23b95aE"),
    ]
    for name, url, locker in cross:
        try:
            rpc = Rpc(url, tag=name)
            print(f"[{name}] enumerating ...", flush=True)
            save(name, enumerate_legacy(rpc, locker))
        except Exception as e:
            print(f"[{name}] FAILED: {e}", flush=True)
    print("ENUM DONE", flush=True)

if __name__ == "__main__":
    main()
