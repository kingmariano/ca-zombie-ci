#!/usr/bin/env python3
"""
BurgerSwap (BSC) — stale-price dump model (second-stage CI job).

For every funded BurgerSwap pair, ask: can an unprivileged attacker acquire the
cheap side on PancakeSwap V2 (the deepest BSC venue) and dump it into the dead
BurgerSwap pair at BurgerSwap's stale implied price, extracting the real side?

Both venues are constant-product AMMs with 0.3% swap fees, so the whole path is
modeled exactly with on-chain reserves (no price oracle needed):

  cost(x)   = WBNB needed to buy x of `mal` on PancakeSwap  (getAmountIn)
  gain(x)   = real tokens out of the BurgerSwap pair for x of `mal` (getAmountOut)
  profit(x) = value_in_WBNB(gain(x)) - cost(x) * (1 + flash_fee)

profit is maximised numerically over x. Read-only, public RPC, no secrets.
Writes ci-out/stale_dump.json and prints the ranked table.
"""
import json, os, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "ci-out")
UA = {"User-Agent": "Mozilla/5.0 zombie-ci", "Content-Type": "application/json"}

def env(*names):
    for n in names:
        v = os.environ.get(n)
        if v:
            return v
    return None

RPCS = [u for u in [env("BSC_RPC_URL"), "https://bsc-rpc.publicnode.com",
                    "https://bsc.drpc.org", "https://binance.llamarpc.com"] if u]

def rpc_batch(calls, timeout=120):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [{"to": t, "data": d}, "latest"]}
               for i, (t, d) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for url in RPCS:
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, data=body, headers=UA)
                d = json.loads(urllib.request.urlopen(req, timeout=timeout).read())
                if isinstance(d, list):
                    out = [None] * len(calls)
                    for it in d:
                        i = it.get("id")
                        if isinstance(i, int):
                            out[i] = it.get("result")
                    return out
            except Exception as e:
                last = str(e)[:60]
                time.sleep(1.5 + 2 * attempt)
    raise RuntimeError("batch failed: " + str(last))

PANCAKE_FACTORY = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
PANCAKE_ROUTER = "0x10ED43C718714eb63d5aA57B78B54704E256024E"
PLATFORM = "0xB099D7dbC415bf5491B0ca6fdCcFddF8b7EDCE12"
WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
BURGER = "0xae9269f27437f0fcbc232d39ec814844a51d6b8f"
USDT = "0x55d398326f99059ff775485246999027b3197955"
BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56"
USDC = "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d"
FLASH_FEE = 0.0009  # 0.09% typical flash-loan fee (documented assumption)

# tokens whose extracted value can be credibly realised (stablecoins / blue chips).
# Anything else is not counted (you cannot sell an illiquid scam token for real value).
SELLABLE = {
    "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",  # WBNB
    "0x55d398326f99059ff775485246999027b3197955",  # USDT
    "0xe9e7cea3dedca5984780bafc599bd69add087d56",  # BUSD
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",  # USDC
    "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c",  # BTCB
    "0x2170ed0880ac9a755fd29b2688956bd959f933f8",  # ETH
    "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82",  # CAKE
    "0x7083609fce4d1d8dc0c979aab8c869ea2c873402",  # DOT
    "0x1d2f0da169ceb9fc7b3144628db156f3f6c60dbe",  # XRP
    "0xf8a0bf9cf54bb92f17374d9e9a321e6a111a51bd",  # LINK
    "0x4338665cbb7b2485a8855a139b75d5e34ab0db94",  # LTC
    "0xba2ae424d960c26247dd6c32edc70b295c744c43",  # DOGE
    "0x3ee2200efb3400fabb9aacf31297cbdd1d435d47",  # ADA
    "0x16939ef78684453bfdfb47825f8a5f714f12623a",  # XTZ
    "0x8ff795a6f4d97e7887c79bea79aba5cc76444adf",  # BCH
    "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3",  # DAI
    "0xcc42724c6683b7e57334c4e856f4c9965ed682bd",  # MATIC
    "0x4b0f1812e5df2a09796481ff14017e6005508003",  # TWT
    "0xf307910a4c7bbc79691fd374889b36d8531b08e3",  # BAND
    "0xe02df9e3e622debdd69fb838bb799e3f168902c5",  # BAKE
    "0x0eb3a705fc54725037cc9e008bdede697f62f335",  # ATOM
    "0x56b6fb708fc5732dec1afc8d8556423a2edccbd6",  # EOS
    "0x947950bcc74888a40ffa2593c5798f11fc9124c4",  # SFP
    "0xad6caeb6ab9663798c5f55d8d7ee1d4b4b1a5a3f",  # BURGER
    "0xae9269f27437f0fcbc232d39ec814844a51d6b8f",  # BURGER (real addr)
}

def sig(s):
    import subprocess
    return subprocess.run(["cast", "sig", s], capture_output=True, text=True).stdout.strip()

SEL = {s: sig(s) for s in ["getPair(address,address)", "getReserves()", "token0()", "decimals()",
                           "swapPrecondition(address)"]}

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def addr(h):
    return "0x" + h[-40:] if isinstance(h, str) and len(h) >= 42 else None

def amt_out(x, rin, rout, fee=0.003):
    if x <= 0 or rin <= 0 or rout <= 0:
        return 0.0
    return (1 - fee) * x * rout / (rin + (1 - fee) * x)

def amt_in(y, rin, rout, fee=0.003):
    """input needed for exact output y (getAmountIn)."""
    if y <= 0 or y >= rout:
        return float("inf")
    return rin * y / ((1 - fee) * (rout - y)) + 1

def value_in_wbnb(token, amount, ctx):
    """value a token amount in WBNB using its Pancake WBNB/BUSD/USDT pair or llama price."""
    token = token.lower()
    if token == WBNB:
        return amount
    if token not in SELLABLE:
        return None  # no credible market to value/sell the extracted token
    lp = ctx["llama"].get(token)
    if lp and ctx["llama"].get(WBNB):
        return amount * lp / ctx["llama"][WBNB]
    return None

def main():
    pairs = json.load(open(os.path.join(OUT, "pairs.json")))
    # collect the token universe we care about
    toks = set()
    for r in pairs:
        if r["usd_reserve"] >= 3:
            for t in (r["token0"], r["token1"]):
                if t:
                    toks.add(t.lower())
    toks.discard(WBNB)
    print("tokens to look up on PancakeSwap:", len(toks), flush=True)

    # Pancake pairs vs WBNB / BUSD / USDT
    lookup = []
    for t in toks:
        for base in (WBNB, BUSD, USDT):
            lookup.append((t, base))
    pancake = {}
    for i in range(0, len(lookup), 60):
        chunk = lookup[i:i + 60]
        rs = rpc_batch([(PANCAKE_FACTORY, SEL["getPair(address,address)"] + enc_addr(t) + enc_addr(b))
                        for t, b in chunk])
        found = []
        for (t, b), r in zip(chunk, rs):
            p = addr(r) if r and r != "0x" else None
            if p and p != "0x0000000000000000000000000000000000000000":
                found.append((t, b, p))
        if found:
            rs2 = rpc_batch([(p, SEL["token0()"]) for _, _, p in found] +
                            [(p, SEL["getReserves()"]) for _, _, p in found])
            L = len(found)
            for j, (t, b, p) in enumerate(found):
                t0 = addr(rs2[j]) if rs2[j] and rs2[j] != "0x" else None
                rr = rs2[L + j]
                if not t0 or not rr or len(rr) < 130:
                    continue
                r0 = int(rr[2:66], 16); r1 = int(rr[66:130], 16)
                t1 = b if t0 == t else t
                key = (min(t, b), max(t, b))
                pancake[key] = {"pair": p, "t0": t0, "t1": t1, "r0": r0, "r1": r1}
        if (i // 60) % 3 == 0:
            print(f"  pancake {i+len(chunk)}/{len(lookup)}", flush=True)

    # base token WBNB spot values (BUSD/USDT pairs vs WBNB)
    base_wbnb = {WBNB: 1.0}
    for base in (BUSD, USDT, USDC):
        p = pancake.get((min(base, WBNB), max(base, WBNB)))
        if p and p["t0"] and p["t1"]:
            r_tok, r_w = (p["r0"], p["r1"]) if p["t0"] == base else (p["r1"], p["r0"])
            if r_tok > 0:
                base_wbnb[base] = r_w / r_tok
    print("base->WBNB:", base_wbnb, flush=True)

    # llama prices for tokens without pancake pairs
    llama = {}
    tl = [t for t in toks if (min(t, WBNB), max(t, WBNB)) not in pancake]
    for i in range(0, len(tl), 80):
        chunk = tl[i:i + 80]
        try:
            url = "https://coins.llama.fi/prices/current/" + ",".join(f"bsc:{a}" for a in chunk)
            req = urllib.request.Request(url, headers=UA)
            d = json.loads(urllib.request.urlopen(req, timeout=45).read())
            for k, v in (d.get("coins") or {}).items():
                a = k.split(":")[-1].lower()
                if v.get("price") is not None:
                    llama[a] = float(v["price"])
        except Exception as e:
            print("llama fail", str(e)[:60], flush=True)
        time.sleep(0.3)
    try:
        req = urllib.request.Request("https://coins.llama.fi/prices/current/bsc:" + WBNB, headers=UA)
        d = json.loads(urllib.request.urlopen(req, timeout=30).read())
        for k, v in (d.get("coins") or {}).items():
            llama[WBNB] = float(v["price"])
    except Exception:
        pass
    print("llama prices:", len(llama), flush=True)

    ctx = {"pancake": pancake, "base_wbnb": base_wbnb, "llama": llama}

    results = []
    for r in pairs:
        if r["usd_reserve"] < 3:
            continue
        t0, t1 = (r["token0"] or "").lower(), (r["token1"] or "").lower()
        d0, d1 = int(r.get("dec0") or 18), int(r.get("dec1") or 18)
        # raw units (Pancake reserves are raw)
        r0 = (r["reserve0"] or 0) * 10 ** d0
        r1 = (r["reserve1"] or 0) * 10 ** d1
        best = {"profit_usd": 0.0, "mal": None, "real": None, "x": 0.0, "gate": None}
        for mal, real, rmal, rreal in ((t0, t1, r0, r1), (t1, t0, r1, r0)):
            if rmal <= 0 or rreal <= 0:
                continue
            key = (min(mal, WBNB), max(mal, WBNB))
            pp = pancake.get(key)
            if not pp:
                continue
            # pancake reserves for mal vs WBNB
            p_mal, p_wbnb = (pp["r0"], pp["r1"]) if pp["t0"] == mal else (pp["r1"], pp["r0"])
            if p_mal <= 0 or p_wbnb < 0.01e18:
                continue  # no credible acquisition market
            # real token value in WBNB
            vreal = value_in_wbnb(real, 1.0, ctx) if real != WBNB else 1.0
            if vreal is None or vreal <= 0:
                continue
            wbnb_price = llama.get(WBNB) or 0.0
            if wbnb_price <= 0:
                continue
            xmax = min(rmal * 0.999, p_mal * 0.999)
            if xmax <= 0:
                continue

            def profit(x):
                if x <= 0 or x >= p_mal:
                    return -1e30
                out_real = amt_out(x, rmal, rreal)
                # cost to BUY x of mal on PancakeSwap: pay WBNB, receive mal
                cost = amt_in(x, p_wbnb, p_mal)
                if cost == float("inf"):
                    return -1e30
                return out_real * vreal - cost * (1 + FLASH_FEE)

            # coarse grid + refinement
            best_x, best_p = 0.0, 0.0
            N = 160
            for i in range(1, N):
                x = xmax * i / N
                p = profit(x)
                if p > best_p:
                    best_p, best_x = p, x
            if best_x > 0:
                lo = best_x * 0.9
                hi = min(best_x * 1.1, xmax)
                for _ in range(60):
                    m1 = lo + (hi - lo) / 3
                    m2 = hi - (hi - lo) / 3
                    if profit(m1) < profit(m2):
                        lo = m1
                    else:
                        hi = m2
                x = (lo + hi) / 2
                p = profit(x)
                if p > best_p:
                    best_p, best_x = p, x
            if best_p / 1e18 * wbnb_price > best["profit_usd"]:
                # platform gate: if swapPrecondition(mal) is false the attacker must fund a
                # mal/BURGER pair with >=0.2004% of the mal/WBNB pair's WBNB value (in BURGER)
                bypass_wbnb = 0.0
                gate = None
                try:
                    r_gate = rpc_batch([(PLATFORM, SEL["swapPrecondition(address)"] + enc_addr(mal))])[0]
                    gate = bool(int(r_gate, 16)) if isinstance(r_gate, str) and r_gate != "0x" else None
                except Exception:
                    gate = None
                if gate is False and real == WBNB:
                    bypass_wbnb = 0.002004 * (rreal / 1e18)
                net_p = best_p / 1e18 - bypass_wbnb
                best = {"profit_usd": round(best_p / 1e18 * wbnb_price, 2), "profit_wbnb": round(best_p / 1e18, 6),
                        "net_profit_usd": round(net_p * wbnb_price, 2), "bypass_wbnb": round(bypass_wbnb, 6),
                        "gate": gate,
                        "mal": mal, "real": real, "x": best_x,
                        "pancake_wbnb_liq": round(p_wbnb / 1e18, 4),
                        "burger_implied_wbnb_per_mal": (rreal / rmal if rmal else 0),
                        "pancake_spot_wbnb_per_mal": (p_wbnb / p_mal if p_mal else 0)}
        if best["profit_usd"] > 0:
            results.append({"pair": r["pair"], "sym0": r["sym0"], "sym1": r["sym1"],
                            "usd_reserve": r["usd_reserve"], **best})
    results.sort(key=lambda x: -x["profit_usd"])
    json.dump(results, open(os.path.join(OUT, "stale_dump.json"), "w"), indent=1)
    tot = sum(x["profit_usd"] for x in results)
    print(f"stale-dump candidates: {len(results)}  total profit bound: ${tot:,.2f}")
    for r in results[:25]:
        print(f"  {r['pair']} {r['sym0']}/{r['sym1']} reserve=${r['usd_reserve']} "
              f"dump {r['mal'][:10]}->{r['real'][:10]} profit=${r['profit_usd']} x={r['x']:.4g}")
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
