#!/usr/bin/env python3
"""Enumerate DxSale V3 LP-storage registry: records -> escrow balances.

Registry: 0xFEE2A3f4329e9A1828F46927bD424DB2C1624985 (BSC)
AllLockRecord(uint256) returns:
 (uint256 createdOn, address lockOwner, address lockedLPTokens, uint256 lockTime,
  address lpLockContract, bool locked, string logo, uint256 lockedAmount,
  uint256 countID, bool exists, address token0Addr, address token1Addr)
"""
import json, sys, time, urllib.request

RPC = sys.argv[1]
REG = sys.argv[2]
OUT = sys.argv[3]
SEL_ALL = "0x1e330895"  # AllLockRecord(uint256)
SEL_CNT = None

def enc_u(x): return hex(x)[2:].rjust(64, "0")
def enc_a(a): return a.lower().replace("0x", "").rjust(64, "0")

class Rpc:
    def __init__(self, url, chunk=20, sleep=0.1, retries=5):
        self.url, self.chunk, self.sleep, self.retries = url, chunk, sleep, retries
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
                except Exception:
                    if attempt == self.retries - 1:
                        out[s + i] = "RPC_FAIL"
                    time.sleep(1.5 + 2.5 * attempt)
            time.sleep(self.sleep)
        return out

def u256(h):
    if not h or not isinstance(h, str) or h.startswith(("REVERT", "RPC_FAIL")) or h == "0x":
        return None
    return int(h, 16)

def main():
    rpc = Rpc(RPC)
    cnt = u256(rpc.batch([(REG, "0x2247b817")])[0])  # lockerIDCount() guess
    if cnt is None:
        # try common getter names via raw storage? fallback: known 2558
        cnt = 2558
    print("lockerIDCount:", cnt, file=sys.stderr)
    recs = []
    raw = rpc.batch([(REG, SEL_ALL + enc_u(i)) for i in range(cnt)])
    for i, r in enumerate(raw):
        if not r or not isinstance(r, str) or r.startswith(("REVERT", "RPC_FAIL")) or r == "0x":
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
            count_id = int(word(8), 16)
            exists = bool(int(word(9), 16) & 1)
            t0 = "0x" + word(10)[24:]
            t1 = "0x" + word(11)[24:]
        except Exception:
            continue
        if not exists:
            continue
        recs.append({"id": i, "createdOn": created, "lockOwner": lock_owner, "lpToken": lp_token,
                     "lockTime": lock_time, "escrow": escrow, "locked": locked,
                     "lockedAmount": str(amt), "countID": count_id, "token0": t0, "token1": t1})
    print("records:", len(recs), file=sys.stderr)
    # balances of LP tokens in escrows
    calls = []
    for r in recs:
        calls.append((r["lpToken"], "0x70a08231" + enc_a(r["escrow"])))
    bals = rpc.batch(calls) if calls else []
    for r, b in zip(recs, bals):
        r["escrowBalance"] = str(u256(b) or 0)
    nz = [r for r in recs if int(r["escrowBalance"]) > 0]
    print("records with escrow balance > 0:", len(nz), file=sys.stderr)
    json.dump({"registry": REG, "count": cnt, "records": recs}, open(OUT, "w"), indent=1)
    print("wrote", OUT, file=sys.stderr)

if __name__ == "__main__":
    main()
