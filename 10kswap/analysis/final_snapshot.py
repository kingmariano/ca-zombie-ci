#!/usr/bin/env python3
"""Final consolidated snapshot for the 10KSwap deep-dive, at one explicit block.
Read-only. Writes analysis/final_snapshot.json.

Per pair: tokens, reserves, actual balances (skim check), totalSupply,
LP held by feeTo (protocol fee claim) and by address 0 (locked MINIMUM_LIQUIDITY).
Prices from DefiLlama coins-api.
"""
import json, sys, os, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

D = os.path.dirname(os.path.abspath(__file__))
FACTORY = "0x1c0a36e26a8f822e0d81f20a5a562b16a8f8a3dfd99801367dd2aea8f1a87a2"
FEETO = "0x98707809b39a3b14d9f5004bc1fe77721baa2d8b67fd54ed5794f60671de0"
SYMS = {
 "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7": "ETH",
 "0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8": "USDC",
 "0xda114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3": "DAI",
 "0x68f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8": "USDT",
 "0x3fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac": "WBTC",
 "0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d": "STRK",
}
LLAMA = {
 "ETH": "ethereum:0x0000000000000000000000000000000000000000",
 "USDC": "ethereum:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
 "DAI": "ethereum:0x6b175474e89094c44da98b954eedeac495271d0f",
 "USDT": "ethereum:0xdac17f958d2ee523a2206206994597c13d831ec7",
 "WBTC": "ethereum:0x2260fac5e5542a773aa44fbcfedf7c193bc2c599",
 "STRK": "starknet:0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
}


def prices():
    keys = ",".join(LLAMA.values())
    req = urllib.request.Request("https://coins.llama.fi/prices/current/" + keys,
                                 headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.loads(r.read().decode())
    out = {}
    for sym, key in LLAMA.items():
        v = d.get("coins", {}).get(key)
        out[sym] = v.get("price") if v else None
    return out


def main():
    blk = sn.rpc("starknet_blockNumber", [])
    blkh = sn.rpc("starknet_getBlockWithTxHashes", ["latest"])
    ts = int(blkh.get("timestamp", 0))
    out = {"block": blk, "block_timestamp": ts, "factory": FACTORY, "feeTo": FEETO, "pairs": {}}

    ret = sn.call(FACTORY, "allPairsLength")
    n = sn.felt(ret[0])
    pairs = [sn.hexaddr(r[0]) for r in sn.batch_calls([(FACTORY, sn.selector("allPairs"), [i]) for i in range(n)])]

    sel = {k: sn.selector(k) for k in ("token0", "token1", "getReserves", "totalSupply", "balanceOf")}
    calls, order = [], []
    for p in pairs:
        calls.append((p, sel["token0"], [])); order.append((p, "token0"))
        calls.append((p, sel["token1"], [])); order.append((p, "token1"))
        calls.append((p, sel["getReserves"], [])); order.append((p, "reserves"))
        calls.append((p, sel["totalSupply"], [])); order.append((p, "totalSupply"))
        calls.append((p, sel["balanceOf"], [FEETO])); order.append((p, "lp_feeto"))
        calls.append((p, sel["balanceOf"], [0])); order.append((p, "lp_addr0"))
    rets = sn.batch_calls(calls)
    st = {}
    for (p, name), r in zip(order, rets):
        st.setdefault(p, {})[name] = r
    # token balances of each pair
    calls2, order2 = [], []
    for p in pairs:
        t0 = sn.hexaddr(st[p]["token0"][0]); t1 = sn.hexaddr(st[p]["token1"][0])
        calls2.append((t0, sel["balanceOf"], [p])); order2.append((p, "bal0"))
        calls2.append((t1, sel["balanceOf"], [p])); order2.append((p, "bal1"))
    rets2 = sn.batch_calls(calls2)
    for (p, name), r in zip(order2, rets2):
        st[p][name] = r

    px = prices()
    out["prices"] = px
    tot = fee_tot = lock_tot = user_tot = 0.0
    tot_excess = 0
    for p in pairs:
        s = st[p]
        t0, t1 = sn.hexaddr(s["token0"][0]), sn.hexaddr(s["token1"][0])
        r0, r1 = sn.felt(s["reserves"][0]), sn.felt(s["reserves"][1])
        ts_ = sn.u256(s["totalSupply"])
        lp_fee = sn.u256(s["lp_feeto"]); lp_0 = sn.u256(s["lp_addr0"])
        b0 = sn.u256(s["bal0"]); b1 = sn.u256(s["bal1"])
        s0, s1 = SYMS.get(t0, t0[:10]), SYMS.get(t1, t1[:10])
        usd = (r0 / 10**18 * px.get(s0, 0) if s0 in ("ETH","DAI","STRK") else
               r0 / 10**(6 if s0 in ("USDC","USDT") else 8) * px.get(s0, 0)) + \
              (r1 / 10**18 * px.get(s1, 0) if s1 in ("ETH","DAI","STRK") else
               r1 / 10**(6 if s1 in ("USDC","USDT") else 8) * px.get(s1, 0))
        excess0, excess1 = b0 - r0, b1 - r1
        tot_excess += excess0 + excess1
        fee_usd = usd * lp_fee / ts_ if ts_ else 0
        lock_usd = usd * lp_0 / ts_ if ts_ else 0
        user_usd = usd * (ts_ - lp_fee - lp_0) / ts_ if ts_ else 0
        tot += usd; fee_tot += fee_usd; lock_tot += lock_usd; user_tot += user_usd
        out["pairs"][p] = {"token0": t0, "token1": t1, "sym0": s0, "sym1": s1,
                           "reserve0": r0, "reserve1": r1, "bal0": b0, "bal1": b1,
                           "excess0": excess0, "excess1": excess1,
                           "totalSupply": ts_, "lp_feeTo": lp_fee, "lp_addr0": lp_0,
                           "usd": round(usd, 2), "feeTo_usd": round(fee_usd, 2)}
    out["totals"] = {"reserves_usd": round(tot, 2), "feeTo_claim_usd": round(fee_tot, 2),
                     "locked_usd": round(lock_tot, 4), "user_lp_usd": round(user_tot, 2),
                     "sum_excess_raw": tot_excess}
    print(json.dumps(out["totals"], indent=1))
    print("block:", blk, "ts:", ts)
    with open(os.path.join(D, "final_snapshot.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote final_snapshot.json")


if __name__ == "__main__":
    main()
