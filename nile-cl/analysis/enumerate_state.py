#!/usr/bin/env python3
"""Nile CL live-state enumeration (read-only, keyless public RPC).

Outputs (analysis/):
  pools_state.json       - every factory pool: tokens, slot0, liquidity, protocolFees, balances
  gauges_state.json      - every Voter pool: gauge, isAlive, feeDistributor, reward tokens, balances
  nfp_summary.json       - NFP manager: total supply + per-owner token id range (light)
"""
import json, time, urllib.request, os, sys

RPCS = [u for u in [os.environ.get("LINEA_PUBLIC_RPC"),
                    "https://rpc.linea.build", "https://linea.drpc.org",
                    "https://linea-rpc.publicnode.com"] if u]
FACTORY = "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42"
FACTORY_DEPLOY_BLOCK = 1768866  # etherscan getcontractcreation
VOTER = "0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869"
NFP = "0xAAA78E8C4241990B4ce159E105dA08129345946A"
HERE = os.path.dirname(os.path.abspath(__file__))

S = {
    "protocolFees": "0x1ad8b03b",
    "slot0": "0x3850c7bd",
    "liquidity": "0x1a686502",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "balanceOf": "0x70a08231",
    "gauges": "0xb9a09fd5",
    "isAlive": "0x1703e5f9",
    "feeDistributors": "0x49e4974a",
    "length": "0x1f7b6d32",
    "pools": "0xac4afa38",
    "getRewardTokens": "0xc4f59f9b",
    "ownerOf": "0x6352211e",
    "totalSupply": "0x18160ddd",
}
UA = {"User-Agent": "Mozilla/5.0", "Content-Type": "application/json"}
_id = 0

def rpc_batch(calls, retries=5, pause=0.15):
    """calls: list of (method, params) -> list of results (None on per-call error)."""
    global _id
    payload, ids = [], []
    for m, p in calls:
        _id += 1
        ids.append(_id)
        payload.append({"jsonrpc": "2.0", "id": _id, "method": m, "params": p})
    body = json.dumps(payload).encode()
    last = None
    for a in range(retries):
        for url in RPCS:
            try:
                req = urllib.request.Request(url, data=body, headers=UA)
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.load(r)
                if isinstance(res, dict) and res.get("error"):
                    raise RuntimeError(res["error"])
                out = {x["id"]: x.get("result") for x in res}
                time.sleep(pause)
                return [out.get(i) for i in ids]
            except Exception as e:
                last = e
                time.sleep(0.8)
    raise RuntimeError(f"rpc batch failed on all endpoints: {last}")

def eth_call(to, selector, arg_hex=""):
    return ("eth_call", [{"to": to, "data": selector + arg_hex}, "latest"])

def get_logs(address, topic0, from_block=0x0, to_block="latest"):
    return ("eth_getLogs", [{"address": address, "topics": [topic0],
                             "fromBlock": hex(from_block), "toBlock": to_block}])

def dec_u256(word): return int(word, 16) if word and word != "0x" else 0
def dec_addr(word): return "0x" + word[-40:].lower()

def main():
    # ---- pools from triage enumeration + on-chain verification (factory() on each pool)
    TRIAGE = "/home/heisenberg/CA/l2-triage-b/ci-out/results.json"
    tri = json.load(open(TRIAGE))
    pool_list = []
    for proto in tri["protocols"]:
        if proto.get("slug") == "nile-cl":
            for t in proto["targets"]:
                pool_list = [r["pool"] for r in t["pools"]]
    print(f"pools from triage: {len(pool_list)}")
    # verify each pool: factory() == FACTORY
    ver = []
    S_factory = "0xc45a0155"  # factory()
    for i in range(0, len(pool_list), 10):
        chunk = pool_list[i:i+10]
        res = rpc_batch([eth_call(p, S_factory) for p in chunk])
        for p, r in zip(chunk, res):
            ok = bool(r) and dec_addr(r) == FACTORY.lower()
            ver.append({"pool": p, "factory_ok": ok})
    bad = [v for v in ver if not v["factory_ok"]]
    print(f"pools verified factory(): {len(ver)-len(bad)}/{len(ver)} (bad: {len(bad)})")
    # scan recent 300k blocks for new PoolCreated events
    latest = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
    new_logs = []
    for start in range(latest - 300000, latest, 10000):
        try:
            r = rpc_batch([get_logs(FACTORY, "0x783cca1c0412dd0d695e784568c96da2e9c22ff989357a2e8b1d9b2b4e6b7118",
                                    from_block=start, to_block=start + 9999)])[0]
            new_logs += r or []
        except Exception as e:
            print("log scan chunk err", start, e)
    new_pools = sorted({dec_addr(l["data"][-64:]) for l in new_logs})
    print(f"new pools in last 300k blocks: {len(new_pools)}")
    pools = sorted(set(pool_list) | set(new_pools))
    json.dump({"count": len(pools), "pools": pools, "verified": ver,
               "new_pools_last_300k": new_pools, "block": latest},
              open(f"{HERE}/pool_list.json", "w"), indent=1)

    # ---- per-pool reads: tokens, slot0, liquidity, protocolFees
    rows = []
    for i in range(0, len(pools), 10):
        chunk = pools[i:i+10]
        calls = []
        for p in chunk:
            calls += [eth_call(p, S["token0"]), eth_call(p, S["token1"]),
                      eth_call(p, S["slot0"]), eth_call(p, S["liquidity"]),
                      eth_call(p, S["protocolFees"])]
        res = rpc_batch(calls)
        for j, p in enumerate(chunk):
            r = res[j*5:j*5+5]
            t0 = dec_addr(r[0]) if r[0] else None
            t1 = dec_addr(r[1]) if r[1] else None
            slot0 = r[2] or "0x"
            w = [slot0[2:][k*64:(k+1)*64] for k in range(len(slot0[2:])//64)]
            pf = r[4] or "0x"
            pw = [pf[2:][k*64:(k+1)*64] for k in range(len(pf[2:])//64)]
            rows.append({
                "pool": p, "token0": t0, "token1": t1,
                "sqrtPriceX96": int(w[0], 16) if w else 0,
                "tick": int(w[1], 16) - (1 << 256) if w and int(w[1], 16) >= (1 << 255) else (int(w[1], 16) if w else 0),
                "liquidity": dec_u256(r[3]),
                "protocolFees0": int(pw[0], 16) if len(pw) > 0 else 0,
                "protocolFees1": int(pw[1], 16) if len(pw) > 1 else 0,
            })
        print(f"pools {i+len(chunk)}/{len(pools)}", flush=True)
    json.dump(rows, open(f"{HERE}/pools_state.json", "w"), indent=1)

    # ---- per-pool balances of token0/token1 (separate pass; different arg)
    for i in range(0, len(rows), 10):
        chunk = rows[i:i+10]
        calls = []
        for r in chunk:
            calls += [eth_call(r["token0"], S["balanceOf"], "0"*24 + r["pool"][2:]),
                      eth_call(r["token1"], S["balanceOf"], "0"*24 + r["pool"][2:])]
        res = rpc_batch(calls)
        for j in range(len(chunk)):
            chunk[j]["balance0"] = dec_u256(res[2*j])
            chunk[j]["balance1"] = dec_u256(res[2*j+1])
        print(f"balances {i+len(chunk)}/{len(rows)}", flush=True)
    json.dump(rows, open(f"{HERE}/pools_state.json", "w"), indent=1)

    # ---- voter: pool -> gauge -> fedist
    n = dec_u256(rpc_batch([eth_call(VOTER, S["length"])])[0])
    print("voter pools:", n)
    g_rows = []
    for i in range(n):
        pl = dec_addr(rpc_batch([eth_call(VOTER, S["pools"], hex(i)[2:].rjust(64, "0"))])[0])
        g_rows.append({"idx": i, "pool": pl})
    for i in range(0, n, 10):
        chunk = g_rows[i:i+10]
        calls = []
        for r in chunk:
            calls.append(eth_call(VOTER, S["gauges"], "0"*24 + r["pool"][2:]))
        res = rpc_batch(calls)
        for j in range(len(chunk)):
            chunk[j]["gauge"] = dec_addr(res[j]) if res[j] else None
        calls = []
        for r in chunk:
            if r["gauge"]:
                calls.append(eth_call(VOTER, S["isAlive"], "0"*24 + r["gauge"][2:]))
            else:
                calls.append(("eth_blockNumber", []))
        res = rpc_batch(calls)
        for j in range(len(chunk)):
            chunk[j]["alive"] = (res[j] == "0x" + "0"*63 + "1") if chunk[j]["gauge"] else False
        calls = []
        for r in chunk:
            if r["gauge"]:
                calls.append(eth_call(VOTER, S["feeDistributors"], "0"*24 + r["gauge"][2:]))
            else:
                calls.append(("eth_blockNumber", []))
        res = rpc_batch(calls)
        for j in range(len(chunk)):
            chunk[j]["feeDistributor"] = dec_addr(res[j]) if (chunk[j]["gauge"] and res[j]) else None
        print(f"gauges {i+len(chunk)}/{n}", flush=True)
    json.dump(g_rows, open(f"{HERE}/gauges_state.json", "w"), indent=1)

    # ---- reward token balances for gauges + fee distributors
    def reward_tokens(addr):
        raw = rpc_batch([eth_call(addr, S["getRewardTokens"])])[0]
        if not raw or raw == "0x":
            return []
        b = bytes.fromhex(raw[2:])
        # string-encoded address[] return: offset, len, items
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off+32], "big")
        toks = []
        for k in range(ln):
            w = b[off+32+k*32: off+64+k*32]
            toks.append("0x" + w[-20:].hex())
        return toks

    for r in g_rows:
        toks = []
        if r.get("gauge"):
            try:
                toks += [("gauge", t) for t in reward_tokens(r["gauge"])]
            except Exception as e:
                print("gauge rewards err", r["gauge"], e)
        if r.get("feeDistributor"):
            try:
                toks += [("fed", t) for t in reward_tokens(r["feeDistributor"])]
            except Exception as e:
                print("fed rewards err", r["feeDistributor"], e)
        r["rewards"] = [t for _, t in toks]
        # balances
        calls, keys = [], []
        for src, t in toks:
            who = r["gauge"] if src == "gauge" else r["feeDistributor"]
            calls.append(eth_call(t, S["balanceOf"], "0"*24 + who[2:]))
            keys.append((src, t))
        if calls:
            res = rpc_batch(calls)
            r["balances"] = {f"{src}:{t}": dec_u256(v) for (src, t), v in zip(keys, res)}
        else:
            r["balances"] = {}
        print("rewards", r["idx"], r["pool"], len(toks), flush=True)
    json.dump(g_rows, open(f"{HERE}/gauges_state.json", "w"), indent=1)

    # ---- NFP manager summary
    ts = dec_u256(rpc_batch([eth_call(NFP, S["totalSupply"])])[0])
    blk = rpc_batch([("eth_blockNumber", [])])[0]
    json.dump({"nfpTotalSupply": ts, "block": blk},
              open(f"{HERE}/nfp_summary.json", "w"), indent=1)
    print("NFP totalSupply:", ts, "block:", blk)

if __name__ == "__main__":
    main()
