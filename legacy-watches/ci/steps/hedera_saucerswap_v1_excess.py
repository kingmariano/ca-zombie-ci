#!/usr/bin/env python3
"""
hedera_saucerswap_v1_excess.py -- H2-09 hedera-other-amm group.

Enumerate ALL SaucerSwap V1 (Uniswap V2 fork on Hedera) pairs via the factory,
then for every pair compute:
    excess_i = token_i.balanceOf(pair) - getReserves().reserve_i
This is the exact amount a permissionless skim(pair) call would transfer when
positive (Uniswap V2 `skim` sends balanceOf(pair)-reserve to the `to` arg).

Also records: per-token decimals/symbol, USD pricing hints (USDC/WHBAR are
priced by the caller; see analysis README), and optional skim eth_call
simulation for the top-N excess pairs.

Public keyless RPCs only. No secrets. Read-only (eth_call / eth_blockNumber
only; never sends a transaction).

Usage:
    python3 hedera_saucerswap_v1_excess.py [--limit N] [--skim-top N] [--out DIR]
Env:
    HEDERA_RPC     override primary RPC (default https://mainnet.hashio.io/api)
    OUT_DIR        output dir (default ../analysis/hedera-other-amm/raw relative
                   to this file via ../../analysis/...)

Outputs (JSON): pairs.json, pairdata.json, tokens.json, excess.json, skim_sims.json
"""
import argparse
import json
import os
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

DEFAULT_RPCS = [
    "https://mainnet.hashio.io/api",
    "https://295.rpc.thirdweb.com",
]
FACTORY = "0x0000000000000000000000000000000000103780"  # 0.0.1062784 SaucerSwapV1Factory
BATCH = 10
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (zombie-hunt-ii; readonly)"}

SEL = {
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "balanceOf": "0x70a08231",
    "allPairs": "0x1e3dd18b",
    "allPairsLength": "0x574f2ba3",
    "skim": "0xbc25cf77",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
    "name": "0x06fdde03",
    "totalSupply": "0x18160ddd",
}

GLOBAL_POSTS = 0


def rpc_post(url, payload, tries=4):
    global GLOBAL_POSTS
    for t in range(tries):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=UA)
            with urllib.request.urlopen(req, timeout=90) as r:
                GLOBAL_POSTS += 1
                return json.loads(r.read())
        except Exception:
            if t == tries - 1:
                raise
            time.sleep(1.0 * (t + 1))


def call_batches(items, rpcs, batch_size=BATCH, workers=5):
    """items: list of (method, params). Returns list of (err_or_None, result) in order."""
    chunks = [items[i:i + batch_size] for i in range(0, len(items), batch_size)]

    def run(idx_chunk):
        idx, chunk = idx_chunk
        payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
                   for i, (m, p) in enumerate(chunk)]
        last_exc = None
        for url in rpcs:
            try:
                resp = rpc_post(url, payload)
                if not isinstance(resp, list):
                    raise RuntimeError("non-batch response")
                break
            except Exception as e:  # noqa: BLE001
                last_exc = e
                resp = None
        if resp is None:
            raise last_exc
        byid = {r.get("id"): r for r in resp}
        out = []
        for i, _ in enumerate(chunk):
            r = byid.get(i, {})
            if r.get("error"):
                out.append((str(r["error"].get("message", r["error"]))[:180], None))
            else:
                out.append((None, r.get("result")))
        return idx, out

    results = [None] * len(chunks)
    with ThreadPoolExecutor(max_workers=workers) as ex:
        for idx, out in ex.map(run, list(enumerate(chunks))):
            results[idx] = out
    flat = []
    for r in results:
        flat.extend(r)
    return flat


def pad_addr(addr):
    return addr[2:].lower().rjust(64, "0")


def as_addr(result):
    if not result or result == "0x":
        return None
    return "0x" + result[-40:].lower()


def as_int(result):
    if not result or result == "0x":
        return None
    return int(result, 16)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="only first N pairs (0=all)")
    ap.add_argument("--skim-top", type=int, default=0, help="simulate skim for top-N excess pairs")
    ap.add_argument("--out", type=str, default="")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = args.out or os.path.normpath(os.path.join(here, "..", "..", "analysis", "hedera-other-amm", "raw", "saucerswap-v1"))
    os.makedirs(out_dir, exist_ok=True)
    rpcs = [os.environ.get("HEDERA_RPC")] if os.environ.get("HEDERA_RPC") else DEFAULT_RPCS

    latest = as_int(rpc_post(rpcs[0], {"jsonrpc": "2.0", "id": 0, "method": "eth_blockNumber",
                                       "params": []})["result"])
    # -1000: let the mirror-node-backed HTS account lookup ingest the block
    blk = hex(latest - 1000)
    print(f"[i] latest={latest} pinned_block={blk}")

    n = as_int(rpc_post(rpcs[0], {"jsonrpc": "2.0", "id": 0, "method": "eth_call",
                                  "params": [{"to": FACTORY, "data": SEL["allPairsLength"]}, blk]})["result"])
    n = min(n, args.limit) if args.limit else n
    print(f"[i] allPairsLength={n}")

    # ---- 1. enumerate pairs ----
    items = [("eth_call", [{"to": FACTORY, "data": SEL["allPairs"] + format(i, "064x")}, blk])
             for i in range(n)]
    res = call_batches(items, rpcs)
    pairs = []
    for err, r in res:
        pairs.append({"idx": len(pairs), "pair": as_addr(r) if err is None else None, "err": err})
    with open(os.path.join(out_dir, "pairs.json"), "w") as f:
        json.dump({"block": latest, "pinned_block": blk, "factory": FACTORY, "n_total": n, "pairs": pairs}, f)
    print(f"[i] enumerated {len(pairs)} pairs -> pairs.json ({GLOBAL_POSTS} posts so far)")

    # ---- 2. per-pair data: token0/token1/getReserves/balanceOf x2 (5 calls/pair) ----
    ok_pairs = [p for p in pairs if p["pair"]]
    calls = []
    for p in ok_pairs:
        pa = p["pair"]
        calls += [
            ("eth_call", [{"to": pa, "data": SEL["token0"]}, blk]),
            ("eth_call", [{"to": pa, "data": SEL["token1"]}, blk]),
            ("eth_call", [{"to": pa, "data": SEL["getReserves"]}, blk]),
        ]
    res = call_batches(calls, rpcs)
    pd = {}
    idx = 0
    for p in ok_pairs:
        t0 = as_addr(res[idx][1]) if res[idx][0] is None else None
        t1 = as_addr(res[idx + 1][1]) if res[idx + 1][0] is None else None
        rv = res[idx + 2][1] if res[idx + 2][0] is None else None
        r0 = r1 = ts = None
        if rv and rv != "0x":
            w = rv[2:].rjust(192, "0")
            r0, r1, ts = int(w[0:64], 16), int(w[64:128], 16), int(w[128:192], 16)
        pd[p["pair"]] = {"idx": p["idx"], "token0": t0, "token1": t1,
                         "reserve0": r0, "reserve1": r1, "ts": ts,
                         "err": res[idx][0] or res[idx + 1][0] or res[idx + 2][0]}
        idx += 3

    # balances (2 calls/pair, only where tokens parsed)
    calls = []
    keys = []
    for p in ok_pairs:
        d = pd[p["pair"]]
        if d["token0"] is None or d["token1"] is None:
            continue
        pa = p["pair"]
        calls.append(("eth_call", [{"to": d["token0"], "data": SEL["balanceOf"] + pad_addr(pa)}, blk]))
        calls.append(("eth_call", [{"to": d["token1"], "data": SEL["balanceOf"] + pad_addr(pa)}, blk]))
        keys.append(p["pair"])
    res = call_batches(calls, rpcs)
    for i, k in enumerate(keys):
        b0 = as_int(res[2 * i][1]) if res[2 * i][0] is None else None
        b1 = as_int(res[2 * i + 1][1]) if res[2 * i + 1][0] is None else None
        pd[k]["bal0"] = b0
        pd[k]["bal0_err"] = res[2 * i][0]
        pd[k]["bal1"] = b1
        pd[k]["bal1_err"] = res[2 * i + 1][0]
        if b0 is not None and pd[k]["reserve0"] is not None:
            pd[k]["excess0"] = b0 - pd[k]["reserve0"]
        if b1 is not None and pd[k]["reserve1"] is not None:
            pd[k]["excess1"] = b1 - pd[k]["reserve1"]
    with open(os.path.join(out_dir, "pairdata.json"), "w") as f:
        json.dump({"block": latest, "pinned_block": blk, "factory": FACTORY, "pairs": pd}, f)
    print(f"[i] pair data for {len(pd)} pairs -> pairdata.json ({GLOBAL_POSTS} posts so far)")

    # ---- 3. token metadata for unique tokens ----
    tokens = sorted({d["token0"] for d in pd.values() if d.get("token0")} |
                    {d["token1"] for d in pd.values() if d.get("token1")})
    calls = []
    for t in tokens:
        calls += [
            ("eth_call", [{"to": t, "data": SEL["decimals"]}, blk]),
            ("eth_call", [{"to": t, "data": SEL["symbol"]}, blk]),
            ("eth_call", [{"to": t, "data": SEL["totalSupply"]}, blk]),
        ]
    res = call_batches(calls, rpcs)
    tok = {}
    for i, t in enumerate(tokens):
        dec = as_int(res[3 * i][1]) if res[3 * i][0] is None else None
        sym = None
        sres = res[3 * i + 1][1]
        if res[3 * i + 1][0] is None and isinstance(sres, str) and len(sres) > 130:
            try:
                ln = int(sres[2 + 64:2 + 128], 16)
                sym = bytes.fromhex(sres[2 + 128:2 + 128 + ln * 2]).decode("utf-8", "replace")
            except Exception:  # noqa: BLE001
                sym = None
        ts = as_int(res[3 * i + 2][1]) if res[3 * i + 2][0] is None else None
        tok[t] = {"decimals": dec, "symbol": sym, "totalSupply": ts,
                  "err": res[3 * i][0] or res[3 * i + 1][0]}
    with open(os.path.join(out_dir, "tokens.json"), "w") as f:
        json.dump(tok, f, indent=1)
    print(f"[i] metadata for {len(tok)} unique tokens -> tokens.json ({GLOBAL_POSTS} posts so far)")

    # ---- 4. excess summary + rankings ----
    token_excess = {}
    top = []
    for pa, d in pd.items():
        for side in ("0", "1"):
            tk = d.get("token" + side)
            ex = d.get("excess" + side)
            if tk is None or ex is None:
                continue
            if ex != 0:
                token_excess[tk] = token_excess.get(tk, 0) + ex
            if ex > 0:
                top.append({"pair": pa, "idx": d["idx"], "side": side, "token": tk, "excess_raw": ex,
                            "pair_balance": d["bal" + side], "reserve": d["reserve" + side],
                            "decimals": tok.get(tk, {}).get("decimals"),
                            "symbol": tok.get(tk, {}).get("symbol")})
    top.sort(key=lambda x: x["excess_raw"], reverse=True)
    with open(os.path.join(out_dir, "excess.json"), "w") as f:
        json.dump({"block": latest, "pinned_block": blk, "factory": FACTORY,
                   "n_pairs": len(pd),
                   "token_excess_raw": token_excess,
                   "top_positive_excess": top}, f, indent=1)
    print(f"[i] excess computed; {len(top)} positive entries -> excess.json")
    for row in top[:15]:
        print("    ", row["idx"], row["pair"], row["symbol"], row["excess_raw"], f"dec={row['decimals']}")

    # ---- 5. optional skim simulation for top-N pairs (eth_call, read-only) ----
    if args.skim_top > 0:
        import subprocess
        sims = []
        seen = set()
        for row in top:
            if len(seen) >= args.skim_top:
                break
            pa = row["pair"]
            if pa in seen:
                continue
            seen.add(pa)
            # fresh throwaway address, no code/no balance
            attacker = "0x00000000000000000000000000000000deadbeef"
            # order the queue: dedupe free; size is bounded by skim-top
            sims.append((pa, row, attacker))
        out = []
        for pa, row, attacker in sims:
            # eth_call pair.skim(attacker) from attacker; reverts if not callable/transfer fails
            item = ("eth_call", [{"from": attacker, "to": pa, "data": SEL["skim"] + pad_addr(attacker)}, blk])
            r = call_batches([item], rpcs, batch_size=1, workers=1)[0]
            # attempt trace via debug_traceCall if supported
            trace = None
            try:
                tp = rpc_post(rpcs[0], {"jsonrpc": "2.0", "id": 0, "method": "debug_traceCall",
                                        "params": [{"from": attacker, "to": pa,
                                                    "data": SEL["skim"] + pad_addr(attacker)}, blk,
                                                   {"tracer": "callTracer"}]})
                trace = tp.get("result")
            except Exception as e:  # noqa: BLE001
                trace = {"error": str(e)[:120]}
            out.append({"pair": pa, "idx": row["idx"], "token": row["token"],
                        "excess_raw": row["excess_raw"], "symbol": row["symbol"],
                        "call_err": r[0], "call_result": r[1], "trace": trace})
            print(f"[i] skim sim {pa} -> err={r[0]} result={str(r[1])[:40]}")
        with open(os.path.join(out_dir, "skim_sims.json"), "w") as f:
            json.dump({"block": latest, "pinned_block": blk, "sims": out}, f, indent=1)

    print(f"[done] total RPC posts={GLOBAL_POSTS}")


if __name__ == "__main__":
    main()
