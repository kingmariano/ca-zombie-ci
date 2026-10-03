#!/usr/bin/env python3
"""Sample DxSale locker records and find live-drainable (record, token) pairs.

For each sampled global id -> wallet -> records, read current token balance in
locker and simulate unlockToken(recordIndex) from the record owner via eth_call.
A successful simulation means the owner can transfer lock.amount right now.
"""
import json, sys, time, urllib.request, urllib.error

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://bsc-rpc.publicnode.com"
LOCKER = sys.argv[2]
N_IDS = int(sys.argv[3]) if len(sys.argv) > 3 else 400

SEL = {
    "LockerRecord": "0x0e48606b",
    "UserLockerCount": "0xc7450462",
    "DXLOCKERLP": "0xae4f4df1",
    "unlockToken": "0xdd2e0ac0",
    "balanceOf": "0x70a08231",
}

def enc_u256(x):
    return hex(x)[2:].rjust(64, "0")

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def rpc_batch(calls, retries=4, chunk=20):
    """calls: list of (to, data). returns list of results (mapped by id)."""
    out = [None] * len(calls)
    for start in range(0, len(calls), chunk):
        sub = calls[start:start + chunk]
        for attempt in range(retries):
            payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]}
                       for i, (to, data) in enumerate(sub)]
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "zombie-research/1.0"})
                with urllib.request.urlopen(req, timeout=120) as r:
                    res = json.load(r)
                for x in res:
                    i = x.get("id")
                    out[start + i] = x.get("result") if "result" in x else ("REVERT:" + (x.get("error", {}).get("message", "")[:130]))
                break
            except Exception as e:
                if attempt == retries - 1:
                    raise
                time.sleep(2 + 3 * attempt)
        time.sleep(0.15)
    return out

def u256(h):
    if not h or not isinstance(h, str) or h.startswith("REVERT") or h == "0x":
        return None
    return int(h, 16)

def main():
    # 1) sample global ids
    total = u256(rpc_batch([(LOCKER, SEL["lockerNumberOpen"] if False else "0x65057350")])[0])
    print("lockerNumberOpen:", total, file=sys.stderr)
    ids = list(range(0, total, max(1, total // N_IDS)))[:N_IDS]
    if (total - 1) not in ids:
        ids.append(total - 1)
    wallets = []
    res = rpc_batch([(LOCKER, SEL["LockerRecord"] + enc_u256(i)) for i in ids])
    for i, r in zip(ids, res):
        w = u256(r)
        if w is not None:
            wallets.append("0x" + hex(w)[2:].rjust(40, "0"))
    wallets = list(dict.fromkeys(wallets))
    print("sampled ids:", len(ids), "unique wallets:", len(wallets), file=sys.stderr)

    # 2) per-wallet counts
    counts = rpc_batch([(LOCKER, SEL["UserLockerCount"] + enc_addr(w)) for w in wallets])
    # 3) per-wallet records (cap 40 each)
    record_calls = []
    record_meta = []
    for w, c in zip(wallets, counts):
        n = min(u256(c) or 0, 40)
        for j in range(n):
            record_calls.append((LOCKER, SEL["DXLOCKERLP"] + enc_addr(w) + enc_u256(j)))
            record_meta.append((w, j))
    print("record calls:", len(record_calls), file=sys.stderr)
    rres = rpc_batch(record_calls)

    now = int(time.time())
    parsed = []
    for (w, j), r in zip(record_meta, rres):
        if not r or r.startswith("REVERT") or r == "0x":
            continue
        raw = r[2:]
        def word(k):
            return raw[k*64:(k+1)*64]
        exists = int(word(0), 16) & 1
        locked = int(word(1), 16) & 1
        amount = int(word(3), 16)
        lockedTime = int(word(4), 16)
        startTime = int(word(5), 16)
        lp = "0x" + word(6)[24:]
        if exists and locked and amount > 0:
            parsed.append({"wallet": w, "idx": j, "amount": amount, "lockedTime": lockedTime,
                           "startTime": startTime, "lp": lp, "future": lockedTime > now})

    print("locked records in sample:", len(parsed), file=sys.stderr)
    # 4) token balances for those lp tokens
    toks = list(dict.fromkeys(p["lp"] for p in parsed))
    bals = rpc_batch([(t, SEL["balanceOf"] + enc_addr(LOCKER)) for t in toks]) if toks else []
    tb = {t: (u256(b) or 0) for t, b in zip(toks, bals)}
    # 5) simulate unlockToken
    sim_calls = [(LOCKER, SEL["unlockToken"] + enc_u256(p["idx"])) for p in parsed]
    sims = rpc_batch(sim_calls)
    ok = []
    for p, s in zip(parsed, sims):
        p["tokenBalance"] = tb.get(p["lp"], 0)
        p["sim"] = "OK" if (s is not None and not str(s).startswith("REVERT")) else str(s)[:150]
        if p["sim"] == "OK":
            ok.append(p)
    print(json.dumps({"locker": LOCKER, "total": total, "sampled": len(parsed), "drainable": ok,
                      "all_locked": parsed}, indent=1))

if __name__ == "__main__":
    main()
