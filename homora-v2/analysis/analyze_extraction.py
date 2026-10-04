#!/usr/bin/env python3
"""Compute true collateral values + liquidation extraction economics per chain.

Inputs: scan JSON (positions/values), backing JSON (underlying/rate/staked).
Outputs: extraction JSON + printed summary.

- True collateral value: LP reserves priced with DefiLlama USD prices (or ERC20 price),
  scaled by wrapper backing ratio (staked/backed vs bank-held shares).
- Liquidation profit: oracle.convertForLiquidation(debt, coll, id, debtAmount) gives the
  collateral units a liquidator receives for paying the position's full debt; required
  payment to take all collateral = debtAmount * collSize / bounty (if bounty >= collSize),
  else full debt. Profit = collateral value taken - payment true value.
"""
import json
import sys
import time
import requests
from eth_abi import encode, decode
from eth_utils import keccak, to_checksum_address

MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
LLAMA = "https://coins.llama.fi/prices/current/"

CHAIN_LLAMA = {"ethereum": "ethereum", "avalanche": "avax", "optimism": "optimism", "fantom": "fantom", "ethereum_legacy": "ethereum"}


def sel(sig):
    depth = 0
    base = sig
    for i, ch in enumerate(sig):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                base = sig[: i + 1]
                break
    return keccak(text=base)[:4]


class Rpc:
    def __init__(self, url):
        self.url = url
        self.id = 0
        self.s = requests.Session()
        self.s.headers.update({"User-Agent": "Mozilla/5.0 research"})

    def batch(self, calls, chunk=40, retries=4):
        out = []
        for i in range(0, len(calls), chunk):
            part = calls[i:i + chunk]
            payload = []
            for to, data in part:
                self.id += 1
                payload.append({"jsonrpc": "2.0", "id": self.id, "method": "eth_call",
                                "params": [{"to": to, "data": "0x" + data.hex()}, "latest"]})
            ok = False
            for attempt in range(retries):
                try:
                    r = self.s.post(self.url, json=payload, timeout=120)
                    res = r.json()
                    if isinstance(res, dict):
                        res = [res]
                    res = sorted(res, key=lambda x: x.get("id", 0))
                    out.extend([x.get("result") for x in res])
                    ok = True
                    break
                except Exception:
                    time.sleep(2.0 * (attempt + 1))
            if not ok:
                out.extend([None] * len(part))
        return out

    def call(self, to, data):
        return self.batch([(to, data)], chunk=1)[0]


def mc(rpc, calls, chunk=40):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        arr = [(to_checksum_address(t), True, d) for t, d in part]
        data = sel("aggregate3((address,bool,bytes)[])") + encode(["(address,bool,bytes)[]"], [arr])
        res = rpc.call(MULTICALL3, data)
        if res is None:
            out.extend([None] * len(part))
            continue
        try:
            dd = decode(["(bool,bytes)[]"], bytes.fromhex(res[2:]))[0]
            out.extend([bytes(b) if ok else None for ok, b in dd])
        except Exception:
            out.extend([None] * len(part))
    return out


def dec(types, raw):
    if raw is None:
        return None
    if isinstance(raw, str):
        if raw == "0x" or len(raw) < 34:
            return None
        raw = bytes.fromhex(raw[2:])
    if len(raw) < 32:
        return None
    try:
        return decode(types, raw)
    except Exception:
        return None


def fetch_prices(chain_llama, tokens):
    prices = {}
    toks = sorted(set(t.lower() for t in tokens if t))
    for i in range(0, len(toks), 60):
        part = toks[i:i + 60]
        url = LLAMA + ",".join(f"{chain_llama}:{t}" for t in part)
        try:
            r = requests.get(url, timeout=30)
            d = r.json().get("coins", {})
            for k, v in d.items():
                prices[k.split(":")[1].lower()] = v.get("price", 0)
        except Exception as e:
            print("price fetch error", e, file=sys.stderr)
        time.sleep(0.3)
    return prices


def main(scan_path, backing_path, rpc_url, out_path):
    scan = json.load(open(scan_path))
    back = json.load(open(backing_path))
    chain = scan["chain"]
    llama = CHAIN_LLAMA.get(chain, chain)
    rpc = Rpc(rpc_url)
    bank = scan["bank"]
    oracle = scan["params"]["oracle"]

    # token set for prices
    toks = set()
    for u, v in back.get("underlying", {}).items():
        if v.get("token0"):
            toks.add(v["token0"])
        if v.get("token1"):
            toks.add(v["token1"])
        if not v.get("token0"):
            toks.add(u)
    for pid, p in scan["positions"].items():
        for t in (p or {}).get("debtTokens", []):
            toks.add(t)
    prices = fetch_prices(llama, toks)
    # tokens metadata
    meta = dict(back.get("tokens", {}))
    for u, v in back.get("underlying", {}).items():
        if u not in meta:
            meta[u] = {"symbol": v.get("symbol"), "decimals": v.get("decimals")}

    def dec_of(t):
        return (meta.get(t) or {}).get("decimals") or 18

    def px(t):
        return prices.get(t.lower(), 0)

    # backing ratios per (wrapper, pid/staking)
    agg = {}
    for k, v in back["ids"].items():
        w = v["wrapper"]
        pid = v.get("chefPid")
        key = (w, pid) if pid is not None else (w, None)
        a = agg.setdefault(key, {"bank": 0, "staked": None})
        a["bank"] += int(v.get("bankShares") or 0)
        if v.get("stakedAmount") is not None:
            a["staked"] = int(v["stakedAmount"])
    for w, wv in back.get("wrappers", {}).items():
        sb = wv.get("stakedBalance")
        if sb is not None:
            agg[(w, None)] = {"bank": agg.get((w, None), {}).get("bank", 0), "staked": int(sb)}
    # wrapper underlying balances (for werc20-style wrappers)
    wbal_calls = []
    wbal_keys = []
    for k, v in back["ids"].items():
        w = v["wrapper"]
        u = v["underlying"]
        wv = back["wrappers"].get(w, {})
        if not wv.get("chef") and not wv.get("staking") and u:
            wbal_calls.append((u, sel("balanceOf(address)(uint256)") + encode(["address"], [w])))
            wbal_keys.append(k)
    wbals = mc(rpc, wbal_calls, chunk=40)
    wbal_map = {}
    for k, r in zip(wbal_keys, wbals):
        d = dec(["uint256"], r)
        wbal_map[k] = int(d[0]) if d else None

    # collateral values
    results = {}
    for pid, p in scan["positions"].items():
        if not p or p.get("collSize") in (None, "0"):
            continue
        w = p["collToken"]
        cid = p["collId"]
        key = f"{w}:{cid}"
        v = back["ids"].get(key)
        if not v:
            continue
        shares = int(p["collSize"])
        rate = int(v.get("rate") or 2 ** 112)
        und_amount = shares * rate / 2 ** 112  # raw underlying units
        u = v["underlying"]
        uv = back["underlying"].get(u, {})
        if uv.get("token0") and uv.get("reserves0") is None and uv.get("reserve0") is not None:
            pass
        if uv.get("token0") and uv.get("totalSupply"):
            ts = int(uv["totalSupply"])
            r0 = int(uv["reserve0"])
            r1 = int(uv["reserve1"])
            t0, t1 = uv["token0"], uv["token1"]
            lp_val = (r0 / 10 ** dec_of(t0) * px(t0) + r1 / 10 ** dec_of(t1) * px(t1)) / (ts / 1e18) if ts else 0
            und_price = lp_val  # per 1e18 raw LP units
            kind = "LP"
            underlying_info = {"token0": t0, "token1": t1, "r0": r0, "r1": r1, "ts": ts, "lp_usd_per_1e18": lp_val}
        else:
            und_price = px(u)  # per whole token
            kind = "ERC20"
            underlying_info = {"symbol": uv.get("symbol")}
        true_coll = und_amount / 10 ** dec_of(u) * und_price if kind == "ERC20" else und_amount / 1e18 * und_price

        # backing ratio
        pid_key = v.get("chefPid")
        bkey = (w, pid_key) if pid_key is not None else (w, None)
        a = agg.get(bkey, {})
        ratio = None
        if a.get("staked") is not None and a.get("bank"):
            ratio = min(1.0, a["staked"] / a["bank"])
        elif key in wbal_map and wbal_map[key] is not None and shares:
            ratio = min(1.0, wbal_map[key] / shares)
        true_coll_backed = true_coll * (ratio if ratio is not None else 1.0)

        debt_true = 0.0
        for t, d in zip(p.get("debtTokens", []), p.get("debts", [])):
            debt_true += int(d) / 10 ** dec_of(t) * px(t)

        results[pid] = {
            "owner": p["owner"], "collToken": w, "collId": cid, "shares": str(shares),
            "underlying": u, "kind": kind, "und_amount": f"{und_amount:.6f}",
            "true_coll_usd": round(true_coll, 2), "backing_ratio": ratio,
            "true_coll_backed_usd": round(true_coll_backed, 2),
            "debt_true_usd": round(debt_true, 2),
            "collETH_oracle": p.get("collETH"), "borrowETH_oracle": p.get("borrowETH"),
            "liquidatable": p.get("liquidatable"),
            "debtTokens": p.get("debtTokens"), "debts": p.get("debts"),
            "underlying_info": underlying_info,
        }

    # liquidation economics for liquidatable positions
    liq_calls = []
    liq_meta = []
    for pid, r in results.items():
        if not r.get("liquidatable"):
            continue
        # use first debt token with positive debt
        for t, d in zip(r["debtTokens"], r["debts"]):
            if int(d) > 0:
                liq_calls.append((oracle, sel("convertForLiquidation(address,address,uint256,uint256)") +
                                  encode(["address", "address", "uint256", "uint256"], [t, r["collToken"], int(r["collId"]), int(d)])))
                liq_meta.append((pid, t, int(d)))
                break
    lraws = mc(rpc, liq_calls, chunk=40)
    for (pid, t, d), raw in zip(liq_meta, lraws):
        r = results[pid]
        b = dec(["uint256"], raw)
        bounty = int(b[0]) if b else None
        shares = int(r["shares"])
        pay = d
        if bounty and bounty >= shares:
            pay = d * shares // bounty
        recv_shares = min(shares, (bounty * pay // d) if bounty else 0)
        recv_val = r["true_coll_backed_usd"] * (recv_shares / shares) if shares else 0
        cost = pay / 10 ** dec_of(t) * px(t)
        r["liq"] = {
            "debtToken": t, "debtRaw": str(d), "bountyRaw": str(bounty),
            "payRaw": str(pay), "recvShares": str(recv_shares),
            "cost_usd": round(cost, 2), "recv_usd": round(recv_val, 2),
            "profit_usd": round(recv_val - cost, 2),
        }

    out = {"chain": chain, "bank": bank, "oracle": oracle, "prices": prices, "positions": results}
    json.dump(out, open(out_path, "w"), indent=1)

    liq = [r for r in results.values() if r.get("liquidatable")]
    tot_coll = sum(r["true_coll_backed_usd"] for r in results.values())
    tot_profit = sum(r.get("liq", {}).get("profit_usd", 0) for r in liq)
    print(f"{chain}: positions-with-coll={len(results)} total_true_coll=${tot_coll:,.2f} liquidatable={len(liq)} est_liq_profit=${tot_profit:,.2f}")
    top = sorted(liq, key=lambda r: -r.get("liq", {}).get("profit_usd", 0))[:8]
    for r in top:
        print(f"   pid? coll=${r['true_coll_backed_usd']:,.2f} debt=${r['debt_true_usd']:,.2f} liq={r.get('liq')}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
