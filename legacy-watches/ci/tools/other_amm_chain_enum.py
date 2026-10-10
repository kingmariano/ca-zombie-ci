#!/usr/bin/env python3
"""
other_amm_chain_enum.py -- H2-09 hedera-other-amm group (non-Hedera chains).

Generic Uniswap-V2-fork pair enumeration + excess computation for
WanSwap (Wanchain), ArthSwap V2 (Astar), Beamswap V2 (Moonbeam).

For every pair:  excess_i = token_i.balanceOf(pair) - getReserves().reserve_i
Positive excess = exact amount a permissionless skim(pair) would transfer.
Also records token metadata and optional skim eth_call simulation for top pairs.

Public keyless RPCs only, read-only (eth_call/eth_blockNumber; no tx sends).
No secrets.

Usage:
    other_amm_chain_enum.py --name wanswap --rpc https://... --factory 0x... --out DIR
    [--limit N] [--skim-top N] [--block N]
"""
import argparse
import json
import os
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

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


def call_batches(items, url, batch_size=BATCH, workers=5):
    chunks = [items[i:i + batch_size] for i in range(0, len(items), batch_size)]

    def run(idx_chunk):
        idx, chunk = idx_chunk
        payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
                   for i, (m, p) in enumerate(chunk)]
        resp = rpc_post(url, payload)
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
    ap.add_argument("--name", required=True)
    ap.add_argument("--rpc", required=True)
    ap.add_argument("--factory", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--skim-top", type=int, default=0)
    ap.add_argument("--block", type=str, default="latest")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    rpc = args.rpc
    latest = as_int(rpc_post(rpc, {"jsonrpc": "2.0", "id": 0, "method": "eth_blockNumber",
                                   "params": []})["result"])
    blk = args.block if args.block != "latest" else hex(latest)
    print(f"[i] {args.name}: latest={latest} pinned={blk}")

    n = as_int(rpc_post(rpc, {"jsonrpc": "2.0", "id": 0, "method": "eth_call",
                              "params": [{"to": args.factory, "data": SEL["allPairsLength"]}, blk]})["result"])
    n = min(n, args.limit) if args.limit else n
    print(f"[i] allPairsLength={n}")

    items = [("eth_call", [{"to": args.factory, "data": SEL["allPairs"] + format(i, "064x")}, blk])
             for i in range(n)]
    res = call_batches(items, rpc)
    pairs = [{"idx": i, "pair": as_addr(r) if err is None else None, "err": err}
             for i, (err, r) in enumerate(res)]
    with open(os.path.join(args.out, "pairs.json"), "w") as f:
        json.dump({"name": args.name, "block": latest, "pinned_block": blk,
                   "factory": args.factory, "n_total": n, "pairs": pairs}, f)
    print(f"[i] {len(pairs)} pairs -> pairs.json ({GLOBAL_POSTS} posts)")

    ok = [p for p in pairs if p["pair"]]
    calls = []
    for p in ok:
        pa = p["pair"]
        calls += [
            ("eth_call", [{"to": pa, "data": SEL["token0"]}, blk]),
            ("eth_call", [{"to": pa, "data": SEL["token1"]}, blk]),
            ("eth_call", [{"to": pa, "data": SEL["getReserves"]}, blk]),
        ]
    res = call_batches(calls, rpc)
    pd = {}
    idx = 0
    for p in ok:
        t0 = as_addr(res[idx][1]) if res[idx][0] is None else None
        t1 = as_addr(res[idx + 1][1]) if res[idx + 1][0] is None else None
        rv = res[idx + 2][1] if res[idx + 2][0] is None else None
        r0 = r1 = ts = None
        if rv and rv != "0x":
            w = rv[2:].rjust(192, "0")
            r0, r1, ts = int(w[0:64], 16), int(w[64:128], 16), int(w[128:192], 16)
        pd[p["pair"]] = {"idx": p["idx"], "token0": t0, "token1": t1, "reserve0": r0,
                         "reserve1": r1, "ts": ts, "err": res[idx][0] or res[idx + 1][0] or res[idx + 2][0]}
        idx += 3

    calls = []
    keys = []
    for p in ok:
        d = pd[p["pair"]]
        if d["token0"] is None or d["token1"] is None:
            continue
        calls.append(("eth_call", [{"to": d["token0"], "data": SEL["balanceOf"] + pad_addr(p["pair"])}, blk]))
        calls.append(("eth_call", [{"to": d["token1"], "data": SEL["balanceOf"] + pad_addr(p["pair"])}, blk]))
        keys.append(p["pair"])
    res = call_batches(calls, rpc)
    for i, k in enumerate(keys):
        b0 = as_int(res[2 * i][1]) if res[2 * i][0] is None else None
        b1 = as_int(res[2 * i + 1][1]) if res[2 * i + 1][0] is None else None
        pd[k]["bal0"], pd[k]["bal0_err"] = b0, res[2 * i][0]
        pd[k]["bal1"], pd[k]["bal1_err"] = b1, res[2 * i + 1][0]
        if b0 is not None and pd[k]["reserve0"] is not None:
            pd[k]["excess0"] = b0 - pd[k]["reserve0"]
        if b1 is not None and pd[k]["reserve1"] is not None:
            pd[k]["excess1"] = b1 - pd[k]["reserve1"]
    with open(os.path.join(args.out, "pairdata.json"), "w") as f:
        json.dump({"name": args.name, "block": latest, "pinned_block": blk,
                   "factory": args.factory, "pairs": pd}, f)
    print(f"[i] pair data -> pairdata.json ({GLOBAL_POSTS} posts)")

    tokens = sorted({d["token0"] for d in pd.values() if d.get("token0")} |
                    {d["token1"] for d in pd.values() if d.get("token1")})
    calls = []
    for t in tokens:
        calls += [
            ("eth_call", [{"to": t, "data": SEL["decimals"]}, blk]),
            ("eth_call", [{"to": t, "data": SEL["symbol"]}, blk]),
            ("eth_call", [{"to": t, "data": SEL["totalSupply"]}, blk]),
        ]
    res = call_batches(calls, rpc)
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
    with open(os.path.join(args.out, "tokens.json"), "w") as f:
        json.dump(tok, f, indent=1)
    print(f"[i] {len(tok)} tokens -> tokens.json ({GLOBAL_POSTS} posts)")

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
                top.append({"pair": pa, "idx": d["idx"], "side": side, "token": tk,
                            "excess_raw": ex, "pair_balance": d["bal" + side],
                            "reserve": d["reserve" + side],
                            "decimals": tok.get(tk, {}).get("decimals"),
                            "symbol": tok.get(tk, {}).get("symbol")})
    top.sort(key=lambda x: x["excess_raw"], reverse=True)
    with open(os.path.join(args.out, "excess.json"), "w") as f:
        json.dump({"name": args.name, "block": latest, "pinned_block": blk, "factory": args.factory,
                   "n_pairs": len(pd), "token_excess_raw": token_excess,
                   "top_positive_excess": top}, f, indent=1)
    print(f"[i] {len(top)} positive excess entries -> excess.json")
    for row in top[:10]:
        print("    ", row["idx"], row["pair"], row["symbol"], row["excess_raw"], f"dec={row['decimals']}")

    if args.skim_top > 0:
        sims = []
        seen = set()
        for row in top:
            if len(seen) >= args.skim_top:
                break
            if row["pair"] in seen:
                continue
            seen.add(row["pair"])
            sims.append(row)
        out = []
        attacker = "0x00000000000000000000000000000000deadbeef"
        for row in sims:
            pa = row["pair"]
            item = ("eth_call", [{"from": attacker, "to": pa, "data": SEL["skim"] + pad_addr(attacker)}, blk])
            r = call_batches([item], rpc, batch_size=1, workers=1)[0]
            out.append({"pair": pa, "idx": row["idx"], "token": row["token"], "symbol": row["symbol"],
                        "excess_raw": row["excess_raw"], "call_err": r[0], "call_result": r[1]})
            print(f"[i] skim sim {pa} -> err={r[0]}")
        with open(os.path.join(args.out, "skim_sims.json"), "w") as f:
            json.dump({"name": args.name, "block": latest, "pinned_block": blk, "sims": out}, f, indent=1)

    print(f"[done] {args.name} posts={GLOBAL_POSTS}")


if __name__ == "__main__":
    main()
