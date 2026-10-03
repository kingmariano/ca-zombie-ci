#!/usr/bin/env python3
"""Enumerate a DxSale-style locker: all lock records + current token balances.

Usage: enumerate_locker.py <rpc> <locker> <out.json> [--max-records N] [--batch 20]
Output: JSON with locker meta, records[], tokens[] (balance), and a drainability
classification:
  - token has balance > 0
  - for each record with exists & locked & amount>0 & lp==token & amount<=balance:
      drainer = record wallet
      replay  = (code family lacks time gate)  [set via --buggy flag]
  Classification of a token: 'replayable' if any eligible record (buggy family),
  'single-claim' if only expired records (fixed family), else 'no-record'.
"""
import json, sys, time, urllib.request, urllib.error

SEL = {
    "lockerNumberOpen": "0x65057350",
    "LockerRecord": "0x0e48606b",
    "UserLockerCount": "0xc7450462",
    "DXLOCKERLP": "0xae4f4df1",
    "unlockToken": "0xdd2e0ac0",
    "balanceOf": "0x70a08231",
    "tokenBalance": "0xeedc966a",
    "owner": "0x8da5cb5b",
    "lockFees": "0xab366292",
}

def enc_u256(x): return hex(x)[2:].rjust(64, "0")
def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")

class Rpc:
    def __init__(self, url, chunk=20, sleep=0.12, retries=5):
        self.url, self.chunk, self.sleep, self.retries = url, chunk, sleep, retries
        self.n = 0
    def batch(self, calls):
        out = [None] * len(calls)
        for start in range(0, len(calls), self.chunk):
            sub = calls[start:start + self.chunk]
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
                        out[start + i] = (x.get("result") if "result" in x
                                          else "REVERT:" + x.get("error", {}).get("message", "")[:130])
                    break
                except Exception:
                    if attempt == self.retries - 1:
                        out[start + i] = "RPC_FAIL"
                    time.sleep(1.5 + 2.5 * attempt)
            self.n += len(sub)
            time.sleep(self.sleep)
        return out

def u256(h):
    if not h or not isinstance(h, str) or h.startswith(("REVERT", "RPC_FAIL")) or h == "0x":
        return None
    return int(h, 16)

def main():
    rpc_url, locker, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    max_records = None
    if "--max-records" in sys.argv:
        max_records = int(sys.argv[sys.argv.index("--max-records") + 1])
    rpc = Rpc(rpc_url)
    meta = {}
    owner = u256(rpc.batch([(locker, SEL["owner"])])[0])
    fees = u256(rpc.batch([(locker, SEL["lockFees"])])[0])
    total = u256(rpc.batch([(locker, SEL["lockerNumberOpen"])])[0])
    meta = {"locker": locker, "owner": ("0x" + hex(owner)[2:].rjust(40, "0")) if owner else None,
            "lockFees": fees, "lockerNumberOpen": total}
    print("meta:", json.dumps(meta), file=sys.stderr)

    ids = list(range(total))
    if max_records:
        ids = ids[:max_records]
    wallets_res = rpc.batch([(locker, SEL["LockerRecord"] + enc_u256(i)) for i in ids])
    wallets = []
    for r in wallets_res:
        v = u256(r)
        if v is not None:
            wallets.append("0x" + hex(v)[2:].rjust(40, "0"))
    # keep order of first appearance
    uniq = list(dict.fromkeys(wallets))
    print("ids:", len(ids), "unique wallets:", len(uniq), file=sys.stderr)

    counts_res = rpc.batch([(locker, SEL["UserLockerCount"] + enc_addr(w)) for w in uniq])
    calls, meta_rec = [], []
    for w, c in zip(uniq, counts_res):
        n = u256(c) or 0
        for j in range(n):
            calls.append((locker, SEL["DXLOCKERLP"] + enc_addr(w) + enc_u256(j)))
            meta_rec.append((w, j))
    print("record calls:", len(calls), file=sys.stderr)
    recs_res = rpc.batch(calls)
    records = []
    for (w, j), r in zip(meta_rec, recs_res):
        if not r or not isinstance(r, str) or r.startswith(("REVERT", "RPC_FAIL")) or r == "0x":
            continue
        raw = r[2:]
        def word(k): return raw[k * 64:(k + 1) * 64]
        try:
            exists = int(word(0), 16) & 1
            locked = int(word(1), 16) & 1
            amount = int(word(3), 16)
            locked_time = int(word(4), 16)
            start_time = int(word(5), 16)
            lp = "0x" + word(6)[24:]
        except Exception:
            continue
        if not exists:
            continue
        records.append({"wallet": w, "idx": j, "locked": bool(locked), "amount": str(amount),
                        "lockedTime": locked_time, "startTime": start_time, "lp": lp})
    print("records parsed:", len(records), file=sys.stderr)

    toks = list(dict.fromkeys(r["lp"] for r in records))
    bal_res = rpc.batch([(t, SEL["balanceOf"] + enc_addr(locker)) for t in toks]) if toks else []
    balances = {}
    for t, b in zip(toks, bal_res):
        balances[t] = u256(b) or 0
    tokens = [{"lp": t, "balance": str(balances.get(t, 0)), "records": sum(1 for r in records if r["lp"] == t)}
              for t in toks]
    nz = [t for t in tokens if int(t["balance"]) > 0]
    print("tokens:", len(tokens), "with balance:", len(nz), file=sys.stderr)
    json.dump({"meta": meta, "records": records, "tokens": tokens}, open(out_path, "w"), indent=1)
    print("wrote", out_path, file=sys.stderr)
    print("rpc calls:", rpc.n, file=sys.stderr)

if __name__ == "__main__":
    main()
