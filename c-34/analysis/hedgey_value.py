#!/usr/bin/env python3
"""Read ClaimCampaigns token balances directly on-chain (ground truth) for multichain token lists,
then query DexScreener for USD liquidity of each token. Read-only.
Input: hedgey_balances_input.json  {chain: {"rpc":..., "tokens":[addr,...], "native":...}}
Output: hedgey_valuations.json
"""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
INP = json.load(open(os.path.join(HERE, "hedgey_balances_input.json")))
UA = {"User-Agent": "zombie-hunt/read-only"}
ADDR = "0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511"

def rpc_call(rpc, to, data):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": to, "data": data}, "latest"]}).encode()
    req = urllib.request.Request(rpc, data=body, headers={**UA, "Content-Type": "application/json"})
    for i in range(5):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.load(r)
            if "result" in d:
                return int(d["result"], 16)
        except Exception:
            pass
        time.sleep(1 + i)
    return None

def dexscreener(addresses):
    out = {}
    for i in range(0, len(addresses), 25):
        chunk = addresses[i:i + 25]
        url = "https://api.dexscreener.com/latest/dex/tokens/" + ",".join(chunk)
        req = urllib.request.Request(url, headers=UA)
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.load(r)
        except Exception:
            d = {"pairs": None}
        pairs = d.get("pairs") or []
        for p in pairs:
            t = (p.get("baseToken") or {}).get("address", "").lower()
            liq = (p.get("liquidity") or {}).get("usd") or 0
            vol = (p.get("volume") or {}).get("h24") or 0
            price = p.get("priceUsd")
            if t:
                cur = out.setdefault(t, {"pairs": 0, "best_liq_usd": 0, "price_usd": None, "best_pair": None, "vol24": 0})
                cur["pairs"] += 1
                cur["vol24"] += float(vol or 0)
                if float(liq or 0) > cur["best_liq_usd"]:
                    cur["best_liq_usd"] = float(liq or 0)
                    cur["price_usd"] = float(price) if price else None
                    cur["best_pair"] = f"{p.get('chainId')}:{p.get('dexId')}:{p.get('pairAddress')}"
        time.sleep(0.4)
    return out

def main():
    res = {}
    all_tokens = []
    for chain, cfg in INP.items():
        res[chain] = {"tokens": {}, "native_wei": None}
        z = cfg.get("block")  # pinned block optional
        for t in cfg["tokens"]:
            data = "0x70a08231" + "0" * 24 + ADDR[2:].lower()
            bal = rpc_call(cfg["rpc"], t, data)
            res[chain]["tokens"][t.lower()] = {"symbol": cfg["symbols"].get(t.lower(), cfg["symbols"].get(t, "?")), "raw": bal}
            if bal:
                all_tokens.append(t.lower())
        # native
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_getBalance",
                           "params": [ADDR, "latest"]}).encode()
        try:
            req = urllib.request.Request(cfg["rpc"], data=body, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=45) as r:
                res[chain]["native_wei"] = int(json.load(r)["result"], 16)
        except Exception:
            pass
        time.sleep(0.3)
    ds = dexscreener(list(set(all_tokens)))
    total = 0.0
    print(f"{'chain':10} {'symbol':16} {'balance':>28} {'priceUsd':>14} {'liqUsd':>14} {'valueUsd':>12}")
    for chain, d in res.items():
        for t, v in d["tokens"].items():
            if v["raw"] is None or v["raw"] == 0:
                continue
            dec = INP[chain]["decimals"][t]
            bal = v["raw"] / 10 ** dec
            q = ds.get(t, {})
            price = q.get("price_usd")
            val = (bal * price) if price else None
            if val is not None:
                total += val
            print(f"{chain:10} {v['symbol']:16} {bal:>28.6f} {str(price):>14} {q.get('best_liq_usd', 0):>14.2f} {str(round(val,2) if val is not None else None):>12}")
    json.dump({"balances": res, "dexscreener": ds, "total_usd_dexscreener": round(total, 2)},
              open(os.path.join(HERE, "hedgey_valuations.json"), "w"), indent=1)
    print("TOTAL (DexScreener priced):", round(total, 2))

if __name__ == "__main__":
    main()
