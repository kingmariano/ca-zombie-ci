#!/usr/bin/env python3
"""Independent verification of SithSwap's on-chain curve math (read-only).

For the top pools by TVL, compare on-chain getAmountOut with a from-scratch
reimplementation of the Velodrome-v2 formulas (which the Cairo pair ports),
and verify the K-invariant binds exactly at the quoted output (out+1 breaks it).

Writes ci-out/math_check.json.
"""
import json, os, sys, time, random, urllib.request, urllib.error
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis"))
from sn import selector

RPCS = ["https://api.cartridge.gg/x/starknet/mainnet", "https://starknet.drpc.org"]
if os.environ.get("ALCHEMY_API_KEY"):
    RPCS.insert(0, "https://starknet-mainnet.g.alchemy.com/v2/" + os.environ["ALCHEMY_API_KEY"])
_last = [0.0]
def rpc(method, params, tries=10):
    last = None
    for attempt in range(tries):
        url = RPCS[attempt % len(RPCS)]
        dt = time.time() - _last[0]
        if dt < 0.35:
            time.sleep(0.35 - dt)
        _last[0] = time.time()
        try:
            body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
            req = urllib.request.Request(url, data=body,
                                         headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 research"})
            with urllib.request.urlopen(req, timeout=45) as r:
                j = json.loads(r.read())
            if "error" in j:
                last = j["error"]
                time.sleep(0.5 + attempt * 0.7)
                continue
            return j["result"]
        except Exception as e:
            last = str(e)
            time.sleep(0.7 + attempt * 0.8)
    raise RuntimeError(f"{method} failed: {last}")

ONE = 10 ** 18

def k_stable(x, y, d0, d1):
    # exact port of Velodrome v2 _k (and SithSwap library k) with floor divisions
    _x = x * ONE // d0
    _y = y * ONE // d1
    _a = (_x * _y) // ONE
    _b = ((_x * _x) // ONE + (_y * _y) // ONE)
    return (_a * _b) // ONE

def k_volatile(x, y):
    return x * y

def f_(x0, y):
    a = (x0 * y) // ONE
    b = ((x0 * x0) // ONE + (y * y) // ONE)
    return (a * b) // ONE

def d_(x0, y):
    return (3 * x0 * ((y * y) // ONE)) // ONE + (((x0 * x0) // ONE) * x0) // ONE

def get_y(x0, xy, y):
    for _ in range(255):
        k = f_(x0, y)
        if k < xy:
            dy = ((xy - k) * ONE) // d_(x0, y)
            if dy == 0:
                if k == xy:
                    return y
                if f_(x0, y + 1) > xy:
                    return y + 1
                dy = 1
            y = y + dy
        else:
            dy = ((k - xy) * ONE) // d_(x0, y)
            if dy == 0:
                if k == xy or f_(x0, y - 1) < xy:
                    return y
                dy = 1
            y = y - dy
    raise RuntimeError("convergence not reached")

def u256(felts):
    return int(felts[0], 16) + (int(felts[1], 16) << 128)

def block_id(b):
    return b if isinstance(b, (str, dict)) else {"block_number": int(b)}

def call_u256(addr, fn, calldata=None, block="latest"):
    res = rpc("starknet_call", {
        "request": {"contract_address": hex(addr), "entry_point_selector": selector(fn),
                    "calldata": [hex(x) for x in (calldata or [])]},
        "block_id": block_id(block),
    })
    return u256(res)

def get_amount_out(pair, amount_in, token_in, block="latest"):
    res = rpc("starknet_call", {
        "request": {"contract_address": hex(pair), "entry_point_selector": selector("getAmountOut"),
                    "calldata": [hex(amount_in & ((1 << 128) - 1)), hex(amount_in >> 128), hex(token_in)]},
        "block_id": block_id(block),
    })
    return u256(res)

def stable_expected_out(r0, r1, dec0, dec1, net):
    x = r0 * ONE // dec0
    y = r1 * ONE // dec1
    xy = k_stable(r0, r1, dec0, dec1)
    x0 = x + (net * ONE // dec0)
    y_new = get_y(x0, xy, y)
    return (y - y_new) * dec1 // ONE

def main():
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    d = json.load(open(os.path.join(base, "analysis", "pairs_priced.json")))
    meta = d["meta"]
    pairs = d["pairs"]
    # top pools by TVL, prefer funded
    pairs = [p for p in pairs if p.get("usd", 0) > 1]
    pairs.sort(key=lambda p: -p["usd"])
    max_pools = int(os.environ.get("MATH_MAX_POOLS", "40"))
    top = pairs[:max_pools]
    block = rpc("starknet_blockNumber", [])
    results = []
    for p in top:
        try:
            t0, t1 = [int(t, 16) for t in p["tokens"]]
            pair_addr = int(p["pair"], 16)
            # fresh state at the pinned block (avoid stale-reserve mismatches)
            r0 = call_u256(pair_addr, "getReserve0", None, block)
            r1 = call_u256(pair_addr, "getReserve1", None, block)
            md = rpc("starknet_call", {"request": {"contract_address": hex(pair_addr),
                     "entry_point_selector": selector("getMetadata"), "calldata": []},
                     "block_id": block_id(block)})
            stable = int(md[1], 16)
            dec0 = int(md[4], 16)
            dec1 = int(md[5], 16)
            fee0 = int(rpc("starknet_call", {"request": {"contract_address": hex(pair_addr),
                          "entry_point_selector": selector("getFee0"), "calldata": []},
                          "block_id": block_id(block)})[0], 16)
            # one-directional swap: token0 in, token1 out
            amount_in = max(r0 // 1000, dec0 // 1000)
            chain_out = get_amount_out(pair_addr, amount_in, t0, block)
            fee = amount_in * fee0 // 10 ** 6
            net = amount_in - fee
            if stable:
                exp_out = stable_expected_out(r0, r1, dec0, dec1, net)
                k_before = k_stable(r0, r1, dec0, dec1)
                def k_after(out):
                    return k_stable(r0 + net, r1 - out, dec0, dec1)
            else:
                exp_out = net * r1 // (r0 + net)
                k_before = k_volatile(r0, r1)
                def k_after(out):
                    return k_volatile(r0 + net, r1 - out)
            # binary search max out that satisfies K (bounded by reserve1-1)
            lo, hi = 0, min(r1 - 1, 2 * (chain_out + 10 ** 9) + 10 ** 12)
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if k_after(mid) >= k_before:
                    lo = mid
                else:
                    hi = mid - 1
            max_out = lo
            k_gap = max_out - chain_out
            res = {
                "pair": p["pair"], "pid": p["pid"], "stable": stable, "usd": p["usd"],
                "reserves_fresh": [r0, r1], "amount_in": amount_in, "chain_out": chain_out,
                "expected_out": exp_out, "out_match": chain_out == exp_out,
                "k_after_ge_before": k_after(chain_out) >= k_before,
                "k_after_plus1_lt_before": k_after(chain_out + 1) < k_before,
                "max_out_k_ok": max_out, "k_gap_wei": k_gap,
            }
            results.append(res)
            print(json.dumps(res), flush=True)
            time.sleep(0.2)
        except Exception as e:
            results.append({"pair": p.get("pair"), "error": str(e)[:200]})
            print("ERR", p.get("pair"), str(e)[:150], flush=True)
    outp = os.path.join(base, "ci-out")
    os.makedirs(outp, exist_ok=True)
    ok = [r for r in results if r.get("out_match") and r.get("k_after_ge_before")]
    json.dump({"block": block, "checked": len(results), "out_match_and_bind": len(ok), "results": results},
              open(os.path.join(outp, "math_check.json"), "w"), indent=1)
    print(f"block={block} checked={len(results)} exact_match+bind={len(ok)}", flush=True)

if __name__ == "__main__":
    main()
