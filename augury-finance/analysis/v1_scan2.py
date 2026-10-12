#!/usr/bin/env python3
"""V1 (AugurDividendsV1) claimant scan — keyless public RPC.
- binary search stakedUserAddresses length
- scan userInfos for lastEpochClaimed==1 (epoch-2 eligible)
- compute owed for eligible users
Usage: python3 v1_scan2.py [start] [end]
"""
import json, urllib.request, time, sys

RPC = "https://polygon-bor-rpc.publicnode.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
V1 = "0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61bc2B2"
SEL_ADDR = "0x7fd77137"   # stakedUserAddresses(uint256)
SEL_UINFO = "0x43b0215f"  # userInfos(address)
SEL_OWED = "0x4b96f33b"   # calculateOwedDividendsFromNow_d6(address)

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers=UA)
        for attempt in range(6):
            try:
                resp = json.loads(urllib.request.urlopen(req, timeout=45).read()); break
            except Exception:
                if attempt == 5: raise
                time.sleep(1.5 * (attempt + 1))
        by_id = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            out.append(r.get("result", {"error": r.get("error")}))
    return out

def call(to, data): return ("eth_call", [{"to": to, "data": data}, "latest"])
def pad32(x): return hex(x)[2:].rjust(64, "0")

def get_addrs(idxs):
    res = batch([call(V1, SEL_ADDR + pad32(i)) for i in idxs])
    return [("0x" + r[-40:]) if isinstance(r, str) and len(r) >= 42 else None for r in res]

def user_infos(addrs):
    res = batch([call(V1, SEL_UINFO + a.lower().replace("0x", "").rjust(64, "0")) for a in addrs])
    outs = []
    for r in res:
        if isinstance(r, str) and len(r) >= 2 + 64*9:
            b = r[2:]
            w = [int(b[i*64:(i+1)*64], 16) for i in range(9)]
            outs.append(w)
        else:
            outs.append(None)
    return outs

def owed(addrs):
    res = batch([call(V1, SEL_OWED + a.lower().replace("0x", "").rjust(64, "0")) for a in addrs])
    return [int(r, 16) if isinstance(r, str) else None for r in res]

def main():
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    end = int(sys.argv[2]) if len(sys.argv) > 2 else 500
    # binary search length once
    lo, hi = 6000, 8000
    def exists(i):
        r = batch([call(V1, SEL_ADDR + pad32(i))])[0]
        return isinstance(r, str)
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if exists(mid): lo = mid
        else: hi = mid
    n = hi
    print("array length:", n)
    json.dump({"stakedUserAddresses_len": n}, open("v1_array_len.json", "w"), indent=1)

    eligible = []
    zero_claim = 0
    claimed = 0
    for chunk_start in range(start, min(end, n), 100):
        idxs = list(range(chunk_start, min(chunk_start + 100, n)))
        addrs = get_addrs(idxs)
        infos = user_infos(addrs)
        cand = []
        for a, w in zip(addrs, infos):
            if w is None: continue
            lec = w[4]
            if lec == 1: cand.append(a)
            elif lec == 0: zero_claim += 1
            else: claimed += 1
        if cand:
            ow = owed(cand)
            for a, o in zip(cand, ow):
                print(f"idx~{chunk_start}: eligible {a} owed={o/1e6 if o is not None else None} USDC")
                eligible.append({"addr": a, "owed_d6": o})
        print(f"scanned {chunk_start}-{chunk_start+len(idxs)-1}: eligible_total={len(eligible)} zero_claim={zero_claim} lec>=2={claimed}")
    json.dump({"n": n, "scanned": [start, end], "eligible": eligible, "zero_claim": zero_claim, "lec_ge2": claimed},
              open(f"v1_eligible_{start}_{end}.json", "w"), indent=1)

if __name__ == "__main__":
    main()
