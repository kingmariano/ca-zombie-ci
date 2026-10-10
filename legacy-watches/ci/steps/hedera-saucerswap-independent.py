#!/usr/bin/env python3
"""Independent full sweep: SaucerSwap V1 (Hedera) pair-balance vs reserve check.

Purpose: definitively resolve the corpus claim "SaucerSwap V1: $314.6k USDC (800 pairs)
skim excess = measurement artifact".

Method: batched JSON-RPC eth_call against Hedera relay https://mainnet.hashio.io/api
(SaucerSwapV1Factory 0.0.1062784 = 0x0000000000000000000000000000000000103780).
For every pair index: allPairs(i), token0, token1, getReserves, balanceOf(pair) x2.
- correct_excess_i = balance_i - reserve_i (skim-able if > 0; skim() selector verified on pairs)
- flipped sums (b0-r1, b1-r0) recorded to test the "index mix-up" artifact hypothesis.
Read-only; public endpoints only; no keys. Falls back to mirror-node single calls if needed.
"""
import json, urllib.request, concurrent.futures, time, os, sys

RPC = "https://mainnet.hashio.io/api"
MIRROR = "https://mainnet-public.mirrornode.hedera.com/api/v1/contracts/call"
FACTORY = "0x0000000000000000000000000000000000103780"
BATCH = 50
WORKERS = 4

def rpc_batch(calls):
    """calls: list of (to,data). Returns list of results (str or None)."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]} for i, (to, data) in enumerate(calls)]
    for t in range(4):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            r = json.load(urllib.request.urlopen(req, timeout=60))
            if isinstance(r, list):
                res = [None] * len(calls)
                for item in r:
                    i = item.get("id")
                    if isinstance(i, int) and item.get("result") not in (None, "0x"):
                        res[i] = item["result"]
                return res
        except Exception:
            time.sleep(0.5 * (t + 1))
    # fallback: mirror node one-by-one
    out = []
    for to, data in calls:
        try:
            body = json.dumps({"block": "latest", "data": data, "to": to}).encode()
            req = urllib.request.Request(MIRROR, data=body,
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            out.append(json.load(urllib.request.urlopen(req, timeout=30)).get("result"))
        except Exception:
            out.append(None)
    return out

def word(h, i):
    return h[2 + 64 * i:2 + 64 * (i + 1)]

def main():
    t0 = time.time()
    n = int(rpc_batch([(FACTORY, "0x574f2ba3")])[0], 16)
    print(f"allPairsLength={n}", flush=True)
    if os.environ.get("SWEEP_MAX"):
        n = min(n, int(os.environ["SWEEP_MAX"]))
        print(f"SWEEP_MAX active -> {n}", flush=True)
    blk = None
    try:
        req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(),
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        blk = int(json.load(urllib.request.urlopen(req, timeout=20))["result"], 16)
    except Exception:
        pass
    print(f"hedera EVM block ~{blk}", flush=True)

    pairs = [None] * n
    def fetch_chunk(chunk):
        calls = [(FACTORY, "0x1e3dd18b" + hex(i)[2:].zfill(64)) for i in chunk]
        res = rpc_batch(calls)
        for i, r in zip(chunk, res):
            if r: pairs[i] = "0x" + word(r, 0)[24:]
    chunks = [list(range(i, min(i + BATCH, n))) for i in range(0, n, BATCH)]
    with concurrent.futures.ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(fetch_chunk, chunks))
    npairs = sum(1 for p in pairs if p)
    print(f"pairs fetched={npairs} ({time.time()-t0:.0f}s)", flush=True)

    # token0/token1
    t01 = {}
    def fetch_t01(chunk):
        calls = []
        idx = []
        for i in chunk:
            p = pairs[i]
            if not p: continue
            calls += [(p, "0x0dfe1681"), (p, "0xd21220a7")]
            idx += [(i, 0), (i, 1)]
        res = rpc_batch(calls)
        for (i, j), r in zip(idx, res):
            if r:
                t01.setdefault(i, {})[j] = "0x" + word(r, 0)[24:]
    with concurrent.futures.ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(fetch_t01, chunks))
    print(f"token0/1 fetched={len(t01)} ({time.time()-t0:.0f}s)", flush=True)

    # reserves
    resv = {}
    def fetch_resv(chunk):
        calls = [(pairs[i], "0x0902f1ac") for i in chunk if pairs[i]]
        res = rpc_batch(calls)
        j = 0
        for i in chunk:
            if not pairs[i]: continue
            r = res[j]; j += 1
            if r:
                resv[i] = (int(word(r, 0), 16), int(word(r, 1), 16))
    with concurrent.futures.ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(fetch_resv, chunks))
    print(f"reserves fetched={len(resv)} ({time.time()-t0:.0f}s)", flush=True)

    # balances
    bals = {}
    def fetch_bals(chunk):
        calls = []; idx = []
        for i in chunk:
            if i not in resv or i not in t01: continue
            for j in (0, 1):
                tok = t01[i].get(j)
                if tok:
                    calls.append((tok, "0x70a08231" + pairs[i][2:].zfill(64)))
                    idx.append((i, j))
        res = rpc_batch(calls)
        for (i, j), r in zip(idx, res):
            if r:
                bals.setdefault(i, {})[j] = int(r, 16)
    with concurrent.futures.ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(fetch_bals, chunks))
    print(f"balances fetched={len(bals)} ({time.time()-t0:.0f}s)", flush=True)

    pos = []
    flip0 = flip1 = neg = 0
    for i in range(n):
        if i not in resv or i not in bals: continue
        b = bals[i]; r0, r1 = resv[i]
        for j, r in ((0, r0), (1, r1)):
            if j in b:
                e = b[j] - r
                if e > 0:
                    pos.append({"pair": pairs[i], "token": t01[i].get(j), "excess_raw": str(e),
                                "balance": str(b[j]), "reserve": str(r)})
                elif e < 0:
                    neg += 1
        if 0 in b and b[0] - r1 > 0: flip0 += b[0] - r1
        if 1 in b and b[1] - r0 > 0: flip1 += b[1] - r0

    out = {
        "factory": FACTORY, "hedera_evm_block": blk, "all_pairs_length": n,
        "pairs_scanned": npairs, "reserves_read": len(resv), "balances_read": len(bals),
        "correct_positive_excess_count": len(pos), "correct_positive_excess": pos[:100],
        "pairs_with_balance_lt_reserve": neg,
        "flipped_sum_b0_minus_r1_raw": str(flip0), "flipped_sum_b1_minus_r0_raw": str(flip1),
        "elapsed_s": round(time.time() - t0, 1),
    }
    os.makedirs("ci-out", exist_ok=True)
    json.dump(out, open("ci-out/hedera-saucerswap-independent.json", "w"), indent=1)
    print(json.dumps({k: v for k, v in out.items() if k != "correct_positive_excess"}, indent=1))
    print("DONE")

if __name__ == "__main__":
    main()
