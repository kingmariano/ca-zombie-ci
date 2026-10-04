#!/usr/bin/env python3
"""RPC-log fallback for scan_chain.py when Etherscan V2 does not support a chain.

Enumerates PoolRegistered logs via eth_getLogs (full range first, chunked
fallback), then performs the same Vault state read, getPoolTokens scan and
pool-type probing as scan_chain.py.

Usage:
  python3 scan_chain_rpc.py --chain mode --chainid 34443 --rpc <rpc> \
      --vault <vault> --out chain-mode.json
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_chain as sc  # noqa: E402


def get_logs_rpc(rpc, vault, probe_chunk=2_000_000):
    latest_hex = sc.rpc_batch(rpc, [("eth_blockNumber", [])])[0]
    latest = int(latest_hex, 16)

    def query(frm, to):
        return sc.rpc_batch(rpc, [("eth_getLogs", [{
            "address": vault,
            "topics": [sc.TOPIC_POOL_REGISTERED],
            "fromBlock": hex(frm),
            "toBlock": hex(to),
        }])])[0]

    # Try full range first (some RPCs allow it when the result set is small).
    res = query(0, latest)
    if res is not None:
        print(f"[rpc-logs] full range 0..{latest}: {len(res)} logs", flush=True)
        return res

    print(f"[rpc-logs] full range rejected, chunking ({latest} blocks)", flush=True)
    logs, frm, step = [], 0, probe_chunk
    while frm <= latest:
        to = min(frm + step - 1, latest)
        res = query(frm, to)
        if res is None:
            step = max(step // 4, 10_000)
            if step == 10_000:
                raise RuntimeError(f"eth_getLogs failed at block {frm} with min chunk 10000")
            continue
        logs.extend(res)
        frm = to + 1
    print(f"[rpc-logs] chunked scan done: {len(logs)} logs", flush=True)
    return logs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chain", required=True)
    ap.add_argument("--chainid", type=int, required=True)
    ap.add_argument("--rpc", required=True)
    ap.add_argument("--vault", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    print(f"[{args.chain}] fetching PoolRegistered logs via eth_getLogs...", flush=True)
    logs = get_logs_rpc(args.rpc, args.vault)
    print(f"[{args.chain}] pools registered: {len(logs)}", flush=True)

    pools, seen = [], set()
    for lg in logs:
        topics = lg["topics"]
        pool_id = topics[1]
        pool_addr = "0x" + topics[2][-40:]
        if pool_id in seen:
            continue
        seen.add(pool_id)
        pools.append({"poolId": pool_id, "address": pool_addr,
                      "regBlock": int(lg["blockNumber"], 16)})

    vault_state = {}
    for name, data in [("pausedState", sc.SEL_PAUSED_STATE),
                       ("authorizer", sc.SEL_AUTHORIZER)]:
        try:
            vault_state[name] = sc.eth_call(args.rpc, args.vault, data)
        except Exception as e:  # noqa
            vault_state[name] = f"err:{e}"

    print(f"[{args.chain}] reading getPoolTokens...", flush=True)
    calls = [("eth_call", [{"to": args.vault,
                            "data": sc.SEL_GET_POOL_TOKENS + p["poolId"][2:]} , "latest"])
             for p in pools]
    results = sc.rpc_batch(args.rpc, calls, chunk=20)
    live = []
    for p, r in zip(pools, results):
        try:
            dec = sc.dec_get_pool_tokens(r)
        except Exception as e:  # noqa
            p["decode_error"] = str(e)
            dec = None
        if dec is None:
            p["tokens"], p["balances"] = [], []
            continue
        tokens, balances, last_change = dec
        p["tokens"], p["balances"], p["lastChangeBlock"] = tokens, balances, last_change
        if any(b > 0 for b in balances):
            live.append(p)
    print(f"[{args.chain}] pools with non-zero balances: {len(live)}", flush=True)

    for i, p in enumerate(live):
        try:
            probe = sc.probe_pool(args.rpc, p["address"])
            p["probe"] = probe
            p["type"] = sc.classify(probe)
        except Exception as e:  # noqa
            p["probe_error"] = str(e)
            p["type"] = "probe_failed"
        if (i + 1) % 25 == 0:
            print(f"[{args.chain}] probed {i+1}/{len(live)}", flush=True)

    out = {
        "chain": args.chain,
        "chainid": args.chainid,
        "vault": args.vault,
        "block": None,
        "vault_state_raw": vault_state,
        "pools_registered": len(pools),
        "pools_live": len(live),
        "pools": live,
        "all_pool_ids": [p["poolId"] for p in pools],
        "log_source": "eth_getLogs",
    }
    try:
        blk = sc.rpc_batch(args.rpc, [("eth_blockNumber", [])])[0]
        out["block"] = int(blk, 16)
    except Exception:  # noqa
        pass
    with open(args.out, "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{args.chain}] wrote {args.out}", flush=True)


if __name__ == "__main__":
    main()
