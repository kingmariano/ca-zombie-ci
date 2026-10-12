#!/usr/bin/env python3
"""Augury Finance L2-P2 heavy enumeration (runs in CI, writes ci-out/).

Job A: scan legacy AugurDividendsV1 stakedUserAddresses (6,088) ->
       lastEpochClaimed distribution + total claimable owed (H-O quantification).
Job B: scan the shared AuguryStateRepositoryV1 userAddresses (8,773) against the
       four AuguryStateBasedDividendsV1 contracts -> live unclaimed dividends
       per contract + smallest claimable share (bounds the replay drain).
Read-only; uses POLYGON_RPC_URL when present, else a keyless public RPC.
"""
import json, os, sys, time, urllib.request, traceback
from concurrent.futures import ThreadPoolExecutor, as_completed

RPC = os.environ.get("POLYGON_RPC_URL") or "https://polygon-bor-rpc.publicnode.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
DEADLINE = time.time() + float(os.environ.get("SCAN_MINUTES", "20")) * 60
WORKERS = int(os.environ.get("SCAN_WORKERS", "4"))
CHUNK = int(os.environ.get("SCAN_CHUNK", "25"))

V1 = "0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61bc2B2"
REPO = "0x8709278f89D6fB589f1188F6b415d3eDEe88a2F6"
SB = {
    "SB0_OMEN": "0xf6380D9b4CC3a0a180d5f1D78e3b7a33ec3048E3",
    "SB1_OMENUSDC": "0x9E8eE4F17F17371d53e2fB19BDDE7a084215bb0E",
    "SB17_OMENWETH": "0x070aEf7a90bD7B4B3b43355C81c56011D5B2A238",
    "SB18_OMENWPOL": "0x33c3834262903d6bCecB0Ba936fc65CAa4d11B26",
}
SEL = {
    "v1_addr": "0x7fd77137",   # V1.stakedUserAddresses(uint256)
    "v1_uinfo": "0x43b0215f",  # V1.userInfos(address)
    "v1_owed": "0x4b96f33b",   # V1.calculateOwedDividendsFromNow_d6(address)
    "repo_addr": "0x502c9bd5", # REPO.userAddresses(uint256)
    "sb_unc": "0x8fc91480",    # SB.calculateUnclaimedDividends(address)
}

def pad_int(x): return hex(x)[2:].rjust(64, "0")
def pad_addr(a): return a.lower().replace("0x", "").rjust(64, "0")
def call(to, data): return ("eth_call", [{"to": to, "data": data}, "latest"])

def rpc_batch(calls, tries=6):
    payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    delay = 1.0
    for a in range(tries):
        try:
            req = urllib.request.Request(RPC, data=body, headers=UA)
            resp = json.loads(urllib.request.urlopen(req, timeout=90).read())
            by = {r["id"]: r for r in resp}
            return [by.get(j, {}).get("result", {"error": True}) for j in range(len(calls))]
        except Exception as e:
            if a == tries - 1:
                return [{"error": str(e)} for _ in calls]
            time.sleep(delay); delay *= 1.6
    return []

def rpc_batch_split(calls, maxlen=25):
    """Split large batches to stay within provider batch limits."""
    out = []
    for i in range(0, len(calls), maxlen):
        out.extend(rpc_batch(calls[i:i + maxlen]))
    return out

def probe_len(addr, selector, hi=30000):
    def exists(i):
        return isinstance(rpc_batch([call(addr, selector + pad_int(i))])[0], str)
    if not exists(0):
        return 0
    lo = 0
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if exists(mid): lo = mid
        else: hi = mid
    return hi

def fetch_addrs(addr, selector, n):
    def work(start):
        idxs = list(range(start, min(start + CHUNK, n)))
        res = rpc_batch([call(addr, selector + pad_int(k)) for k in idxs])
        return [(i, ("0x" + r[-40:]) if isinstance(r, str) and len(r) >= 42 else None) for i, r in zip(idxs, res)]
    out = {}
    with ThreadPoolExecutor(max_workers=WORKERS) as ex:
        futs = [ex.submit(work, s) for s in range(0, n, CHUNK)]
        done = 0
        for f in as_completed(futs):
            for i, a in f.result():
                out[i] = a
            done += 1
            if done % 40 == 0:
                print(f"  addrs {len(out)}/{n}", flush=True)
    return [out.get(i) for i in range(n)]

def job_v1():
    print("== Job A: V1 scan", flush=True)
    n = probe_len(V1, SEL["v1_addr"])
    print("V1 stakedUserAddresses:", n, flush=True)
    addrs = [a for a in fetch_addrs(V1, SEL["v1_addr"], n) if a]
    lec = {}
    owed_sum = 0; owed_cnt = 0; zero_cnt = 0; top = []

    def work(start):
        chunk = addrs[start:start + CHUNK]
        res = rpc_batch([call(V1, SEL["v1_uinfo"] + pad_addr(a)) for a in chunk])
        cands = []
        local = {}
        for a, r in zip(chunk, res):
            if not isinstance(r, str) or len(r) < 2 + 64 * 9:
                continue
            w = [int(r[2 + k*64:2 + (k+1)*64], 16) for k in range(9)]
            v = w[4]
            local[v] = local.get(v, 0) + 1
            if v == 1:
                cands.append(a)
        if cands:
            res2 = rpc_batch([call(V1, SEL["v1_owed"] + pad_addr(a)) for a in cands])
            owed = [(a, int(r2, 16)) for a, r2 in zip(cands, res2) if isinstance(r2, str)]
            return local, owed
        return local, []

    with ThreadPoolExecutor(max_workers=WORKERS) as ex:
        futs = [ex.submit(work, s) for s in range(0, len(addrs), CHUNK)]
        for f in as_completed(futs):
            local, owed = f.result()
            for k, v in local.items():
                lec[k] = lec.get(k, 0) + v
            for a, o in owed:
                if o > 0:
                    owed_sum += o; owed_cnt += 1
                    top.append({"addr": a, "owed_usdc": o / 1e6})
                else:
                    zero_cnt += 1
    top.sort(key=lambda x: -x["owed_usdc"])
    res = {
        "array_len": n, "scanned": len(addrs),
        "lec_distribution": {str(k): v for k, v in sorted(lec.items())},
        "eligible_lec1_with_owed_count": owed_cnt,
        "eligible_lec1_zero_count": zero_cnt,
        "eligible_owed_sum_usdc": round(owed_sum / 1e6, 6),
        "top10_owed": top[:10],
    }
    json.dump(res, open("ci-out/v1_claimants.json", "w"), indent=1)
    print("Job A:", json.dumps({k: v for k, v in res.items() if k != "top10_owed"}), flush=True)
    return res

def job_sb():
    print("== Job B: SB scan", flush=True)
    n = probe_len(REPO, SEL["repo_addr"])
    print("repo userAddresses:", n, flush=True)
    raddrs = [a for a in fetch_addrs(REPO, SEL["repo_addr"], n) if a]
    per = {k: {"sum": 0, "cnt": 0, "min": None, "max": 0, "top": []} for k in SB}

    def work(start):
        chunk = raddrs[start:start + CHUNK]
        calls = []
        for a in chunk:
            for k in SB:
                calls.append(call(SB[k], SEL["sb_unc"] + pad_addr(a)))
        res = rpc_batch_split(calls, 25)
        rows = []
        for j, a in enumerate(chunk):
            for ki, k in enumerate(SB):
                r = res[j * len(SB) + ki]
                if isinstance(r, str):
                    v = int(r, 16)
                    if v > 0:
                        rows.append((k, a, v))
        return rows

    with ThreadPoolExecutor(max_workers=WORKERS) as ex:
        futs = [ex.submit(work, s) for s in range(0, len(raddrs), CHUNK)]
        for f in as_completed(futs):
            for k, a, v in f.result():
                d = per[k]
                d["sum"] += v; d["cnt"] += 1
                d["min"] = v if d["min"] is None else min(d["min"], v)
                d["max"] = max(d["max"], v)
                d["top"].append({"addr": a, "unclaimed_usdc": v / 1e6})
    out = {}
    for k in SB:
        per[k]["top"].sort(key=lambda x: -x["unclaimed_usdc"])
        out[k] = {
            "unclaimed_sum_usdc": round(per[k]["sum"] / 1e6, 6),
            "claimant_count": per[k]["cnt"],
            "min_share_usdc": (per[k]["min"] / 1e6) if per[k]["min"] else None,
            "max_share_usdc": per[k]["max"] / 1e6,
            "top10": per[k]["top"][:10],
        }
    res = {"repo_len": n, "scanned": len(raddrs), "per_contract": out}
    json.dump(res, open("ci-out/sb_unclaimed.json", "w"), indent=1)
    print("Job B:", json.dumps({k: {kk: vv for kk, vv in v.items() if kk != "top10"} for k, v in out.items()}), flush=True)
    return res

if __name__ == "__main__":
    os.makedirs("ci-out", exist_ok=True)
    t0 = time.time()
    try:
        v1 = job_v1()
        sb = job_sb() if time.time() < DEADLINE else {"skipped": "deadline"}
        summary = {"rpc_host": RPC.split("//")[-1].split("/")[0], "elapsed_sec": round(time.time() - t0, 1),
                   "v1": v1, "sb": sb}
        json.dump(summary, open("ci-out/scan_summary.json", "w"), indent=1)
        print("DONE in", summary["elapsed_sec"], "s", flush=True)
    except Exception:
        traceback.print_exc()
        sys.exit(1)
