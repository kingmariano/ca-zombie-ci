#!/usr/bin/env python3
"""For the top-value option pairs on each chain, read the option-level claim decomposition:
totalPosition(Long0/Long1/Short) and positionOf(pool / tokens contract / liquidityTokens contract / zero).
Position enum: Long0=0, Long1=1, Short=2.
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RPC = {
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "base": "https://mainnet.base.org",
    "optimism": "https://mainnet.optimism.io",
    "polygon": "https://polygon.drpc.org",
    "mantle": "https://rpc.mantle.xyz",
    "hyperliquid": "https://rpc.hyperliquid.xyz/evm",
    "xlayer": "https://rpc.xlayer.tech",
    "polygon-zkevm": "https://zkevm-rpc.com",
}
SEL = {
    "totalPosition": "0xb7fb542d",  # totalPosition(uint256,uint256,uint8)
    "positionOf": "0xaf2f91ea",     # positionOf(uint256,uint256,address,uint8)
    "liquidityOf": "0xf78333a3",    # liquidityOf(uint256,uint256,address)
    "totalLiquidity": "0xb15044ac",
}
TOKENS = {  # per chain: TimeswapV2Token, TimeswapV2LiquidityToken (v2.5) + older versions
    "ethereum": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c", "0x1f741e2b12eb99AAb61d737Bd8b8951b64103647"],
                 "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09", "0x368F3Fa78357Db3DAa961D404ADD97c81a17ddf8"]},
    "arbitrum": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c", "0x713D2a6c0e5494f6c33A463Cac80A0617F8B9a58", "0x88bc5d8043195d3362262A6f35a8e416e416fa97", "0x1f741e2b12eb99AAb61d737Bd8b8951b64103647"],
                 "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09", "0x5753b99901C271Ace51ce2342F51ba701ed1cf90", "0x32C6b14776819E2b9B805A1f0774971F8B8De8e9", "0x5E00202fa186d22EAB8B5EFAa47a5e2A63031e69", "0x4c39844f75FaC26F085Fb8a3C44c322a4e64D04D", "0x8d464BCfe5CfAD58d1b66AcA8f92f1E359aC92c8"]},
    "base": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c", "0x713D2a6c0e5494f6c33A463Cac80A0617F8B9a58", "0x88bc5d8043195d3362262A6f35a8e416e416fa97"],
             "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09", "0x32C6b14776819E2b9B805A1f0774971F8B8De8e9", "0x5E00202fa186d22EAB8B5EFAa47a5e2A63031e69"]},
    "optimism": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c", "0x88bc5d8043195d3362262A6f35a8e416e416fa97"],
                 "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09", "0x5E00202fa186d22EAB8B5EFAa47a5e2A63031e69"]},
    "mantle": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c", "0x88bc5d8043195d3362262A6f35a8e416e416fa97", "0xE7A2937aC4A4e1ccaBc5af7D7B77579C36818B9e"],
               "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09", "0x5E00202fa186d22EAB8B5EFAa47a5e2A63031e69", "0xA27ba6b69a9108cFa6070C4A868bFBCe22454508", "0x5D1BD013D005124D946249615FabD77d8269138E"]},
    "hyperliquid": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c"], "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09"]},
    "xlayer": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c"], "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09"]},
    "polygon-zkevm": {"tokens": ["0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c", "0x713D2a6c0e5494f6c33A463Cac80A0617F8B9a58", "0x88bc5d8043195d3362262A6f35a8e416e416fa97"],
                      "liq": ["0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09", "0x5753b99901C271Ace51ce2342F51ba701ed1cf90", "0x32C6b14776819E2b9B805A1f0774971F8B8De8e9", "0x5E00202fa186d22EAB8B5EFAa47a5e2A63031e69"]},
}

def rpc(url, method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)

def batch(url, calls, retries=3):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        data = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.load(r)
                byid = {x["id"]: x for x in res}
                for j in range(len(chunk)):
                    x = byid.get(j, {})
                    out.append(x.get("result") if "result" in x else None)
                break
            except Exception:
                if attempt == retries - 1:
                    out.extend([None] * len(chunk))
                else:
                    time.sleep(1.5 * (attempt + 1))
        time.sleep(0.1)
    return out

def enc_uint(v): return format(v, "064x")
def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_uint(h): return int(h, 16) if h and h != "0x" else None

def main(chains, topn=6):
    for chain in chains:
        pf = os.path.join(HERE, f"live-priced-{chain}.json")
        poolsf = os.path.join(HERE, f"pools-{chain}.json")
        if not (os.path.exists(pf) and os.path.exists(poolsf)):
            print(f"[{chain}] missing files"); continue
        lv = json.load(open(pf))
        pl = json.load(open(poolsf))
        url = RPC[chain]
        pairs = {p["pair"].lower(): p for p in lv["pairs"]}
        # top pairs by USD
        top = [p for p in lv["pairs"] if p["usd"]["total"] > 0]
        top.sort(key=lambda x: x["usd"]["total"], reverse=True)
        top = top[:topn]
        # pools for those pairs
        out = {"chain": chain, "block": pl["block"], "pairs": []}
        for p in top:
            entry = {"pair": p["pair"], "tokens": {p["token0"]: p["token0_meta"], p["token1"]: p["token1_meta"]},
                     "balances": p["balances"], "usd": p["usd"], "pools": []}
            for pool in pl["pools"]:
                if pool["pair"].lower() != p["pair"].lower():
                    continue
                # option-level totals + positions of known holders
                strike = int(pool["strike"]); maturity = pool["maturity"]
                calls = []
                holders = [("pool", pool["pool"])] + [(f"tokens{i}", t) for i, t in enumerate(TOKENS[chain]["tokens"])] + [(f"liq{i}", t) for i, t in enumerate(TOKENS[chain]["liq"])]
                for pos in (0, 1, 2):
                    calls.append(("eth_call", [{"to": p["pair"], "data": SEL["totalPosition"] + enc_uint(strike) + enc_uint(maturity) + enc_uint(pos)}, "latest"]))
                for name, h in holders:
                    for pos in (0, 1, 2):
                        calls.append(("eth_call", [{"to": p["pair"], "data": SEL["positionOf"] + enc_uint(strike) + enc_uint(maturity) + enc_addr(h) + enc_uint(pos)}, "latest"]))
                res = batch(url, calls)
                totals = {k: str(dec_uint(res[i]) or 0) for i, k in enumerate(["totalLong0", "totalLong1", "totalShort"])}
                positions = {}
                idx = 3
                for name, h in holders:
                    positions[name] = {}
                    for pos, pname in ((0, "long0"), (1, "long1"), (2, "short")):
                        positions[name][pname] = str(dec_uint(res[idx]) or 0)
                        idx += 1
                entry["pools"].append({"pool": pool["pool"], "strike": pool["strike"], "maturity": pool["maturity"],
                                       "totalLiquidity": pool["totalLiquidity"], "protocolFees": pool["protocolFees"],
                                       "totals": totals, "positions": positions})
            out["pairs"].append(entry)
        with open(os.path.join(HERE, f"claims-{chain}.json"), "w") as f:
            json.dump(out, f, indent=1)
        print(f"[{chain}] wrote claims-{chain}.json ({len(out['pairs'])} pairs)")

if __name__ == "__main__":
    main(sys.argv[1:] or list(RPC.keys()))
