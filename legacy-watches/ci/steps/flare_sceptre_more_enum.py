#!/usr/bin/env python3
"""
flare_sceptre_more_enum.py — re-runnable evidence collector for group flare-flow.

Protocols:
  1. Sceptre Liquid (sFLR) on Flare (chain 14)
  2. MORE Markets on Flow EVM (chain 747) — both Aave v3 fork markets

READ-ONLY. Public keyless RPCs only. Stdlib only.
Usage: python3 flare_sceptre_more_enum.py [output.json]
"""
import json, sys, time, urllib.request

FLARE_RPC = "https://flare-api.flare.network/ext/C/rpc"
FLOW_RPC = "https://mainnet.evm.nodes.onflow.org"
FLARE_RPCS = [FLARE_RPC, "https://rpc.ankr.com/flare"]

SFLR = "0x12e605bc104e93b45e1ad99f9e555f659051c2bb"
WFLR = "0x1d80c49bbbcd1c0911346656b529df9e5c2f783d"

MARKETS = {
    "market1": {
        "dp": "0x79e71e3c0EDF2B88b0aB38E9A1eF0F6a230e56bf",
        "pool": "0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d",
        "oracle": "0x7287f12c268d7Dff22AAa5c2AA242D7640041cB1",
        "acl": "0x5729Bd11b09fA80487221C32F47d22fC255B1A5D",
        "reserves": {
            "WFLOW": "0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e",
            "ankrFLOWEVM": "0x1b97100eA1D7126C4d60027e231EA4CB25314bdb",
            "USDC.e": "0x7f27352D5F83Db87a5A3E00f4B07Cc2138D8ee52",
            "cbBTC": "0xA0197b2044D28b08Be34d98b23c9312158Ea9A18",
            "USDF": "0x2aaBea2058b5aC2D339b163C6Ab6f2b6d53aabED",
            "stgUSDC": "0xF1815bd50389c46847f0Bda824eC8da914045D14",
            "WETH": "0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590",
            "WBTC": "0x717DAE2BaF7656BE9a9B01deE31d571a9d4c9579",
            "PYUSD0": "0x99aF3EeA856556646C98c8B9b2548Fe815240750",
        },
    },
    "market2": {
        "dp": "0xF580F6F3A2223Db22294c2241c7e0Cc401d20659",
        "pool": "0x23946E2fa751F0aecf655a59613beF86e20881B5",
        "oracle": "0xB84736f2864139F4e78760bD2Fa54b2de960BF5D",
        "acl": "0xc894162561228F95813aA79b92109B45F948Fe6d",
        "reserves": {
            "WFLOW": "0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e",
            "TRUMP": "0xD3378b419feae4e3A4Bb4f3349DBa43a1B511760",
            "stgUSDC": "0xF1815bd50389c46847f0Bda824eC8da914045D14",
        },
    },
}

ANKR_FLOW_FEED = "0xb9c94fc69bf20fab29c146b1efa1b2671328d5dc"
BRIDGE_ROLE = "0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278"

SEL = {
    "wrappedToken": "0x996c6cc3", "totalPooledFlr": "0xfba4fed7", "totalShares": "0x3a98ef39",
    "instantRedeemBuffer": "0xa9815430", "instantRedeemFee": "0x9f6ff78e", "cooldownPeriod": "0x04646a49",
    "redeemPeriod": "0x40a233a6", "paused": "0x5c975abb", "stakerCount": "0xdff69787",
    "rate1e18": "0x1e19e104", "balanceOf": "0x70a08231", "owner": "0x8da5cb5b",
    "getReserveConfigurationData": "0x3e150141", "getReserveCaps": "0x46fbe558",
    "getPaused": "0xb55d9904", "getReserveTokensAddresses": "0xd2493b6c", "getReserveData": "0x35ea6a75",
    "getAssetPrice": "0xb3596f07", "getSourceOfAsset": "0x92bf2be0", "hasRole": "0x91d14854",
    "getUserAccountData": "0xbf92857c", "getRatioFor": "0xa1f1d48d", "latestAnswer": "0x50d25bcd",
    "latestTimestamp": "0x8205bf6a", "totalSupply": "0x18160ddd",
}


def pad32(v):
    return hex(v)[2:].rjust(64, "0")


def rpc_batch(rpcs, calls, block="latest"):
    payload = [{"jsonrpc": "2.0", "method": m, "params": p, "id": i} for i, (m, p) in enumerate(calls)]
    last = None
    for ep in rpcs:
        for attempt in range(4):
            try:
                req = urllib.request.Request(ep, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    resp = json.loads(r.read())
                if isinstance(resp, list):
                    byid = {x["id"]: x for x in resp}
                    out = [byid.get(i, {}).get("result") for i in range(len(calls))]
                    if any(v is not None for v in out):
                        return out
                last = resp
            except Exception as e:
                last = str(e)[:120]
            time.sleep(0.8 * (attempt + 1))
    raise RuntimeError("rpc failed: %s" % last)


def words(h):
    if not h or h == "0x":
        return []
    b = h[2:]
    return [b[i:i + 64] for i in range(0, len(b), 64)]


def w2i(w):
    return int(w, 16) if w else None


def w2a(w):
    return "0x" + w[-40:] if w else None


def w2b(w):
    return w2i(w) == 1


def sceptre(rpcs):
    block = rpc_batch(rpcs, [("eth_blockNumber", [])])[0]
    calls = []
    for k in ["wrappedToken", "totalPooledFlr", "totalShares", "instantRedeemBuffer", "instantRedeemFee",
              "cooldownPeriod", "redeemPeriod", "paused", "stakerCount"]:
        calls.append(("eth_call", [{"to": SFLR, "data": SEL[k]}, block]))
    calls.append(("eth_call", [{"to": SFLR, "data": SEL["rate1e18"] + pad32(10 ** 18)}, block]))
    calls.append(("eth_call", [{"to": WFLR, "data": SEL["balanceOf"] + pad32(int(SFLR, 16))}, block]))
    res = rpc_batch(rpcs, calls)
    keys = ["wrappedToken", "totalPooledFlr", "totalShares", "instantRedeemBuffer", "instantRedeemFee",
            "cooldownPeriod", "redeemPeriod", "paused", "stakerCount"]
    out = {"block": block, "block_dec": int(block, 16)}
    for k, r in zip(keys, res):
        out[k] = w2b(r) if k == "paused" else w2i(r)
    out["wrappedToken"] = w2a(res[0])
    out["exchangeRate_1e18"] = w2i(res[9])
    out["wflrBalance"] = w2i(res[10])
    return out


def more(rpcs):
    block = rpc_batch(rpcs, [("eth_blockNumber", [])])[0]
    out = {"block": block, "block_dec": int(block, 16), "markets": {}}
    for mn, m in MARKETS.items():
        mo = {"reserves": {}, "acl_bridge": None, "ankr_oracle": None}
        calls, meta = [], []
        for sym, asset in m["reserves"].items():
            for k in ["getReserveConfigurationData", "getReserveCaps", "getPaused",
                      "getReserveTokensAddresses", "getReserveData", "getAssetPrice"]:
                calls.append(("eth_call", [{"to": m["dp"] if k != "getAssetPrice" else m["oracle"],
                                            "data": SEL[k] + (pad32(int(asset, 16)) if k != "getReserveCaps" else pad32(int(asset, 16)))},
                                           block]))
                meta.append((sym, k))
        calls.append(("eth_call", [{"to": m["acl"], "data": SEL["hasRole"] + BRIDGE_ROLE[2:] + pad32(int(m["dp"], 16))}, block]))
        meta.append(("_", "bridge_dp"))
        # ankr feed ratio + flow feed (market1 only has ankr reserve)
        if "ankrFLOWEVM" in m["reserves"]:
            calls.append(("eth_call", [{"to": ANKR_FLOW_FEED, "data": SEL["latestAnswer"]}, block]))
            meta.append(("_", "ankr_answer"))
            calls.append(("eth_call", [{"to": "0xa0f0d87c10a5dedbd79c2ee116bea1339bf5525d", "data": SEL["latestAnswer"]}, block]))
            meta.append(("_", "flow_answer"))
        res = rpc_batch(rpcs, calls)
        for (sym, k), r in zip(meta, res):
            if sym == "_":
                if k == "bridge_dp":
                    mo["acl_bridge"] = w2b(r)
                elif k == "ankr_answer":
                    mo["ankr_oracle"] = {"answer": w2i(r)}
                elif k == "flow_answer":
                    mo["ankr_oracle"]["flow_usd"] = w2i(r)
                continue
            ro = mo["reserves"].setdefault(sym, {})
            if k == "getReserveConfigurationData":
                c = words(r)
                ro["config"] = {"decimals": w2i(c[0]), "ltv": w2i(c[1]), "liquidationThreshold": w2i(c[2]),
                                "liquidationBonus": w2i(c[3]), "reserveFactor": w2i(c[4]),
                                "usageAsCollateral": w2b(c[5]), "borrowingEnabled": w2b(c[6]),
                                "isActive": w2b(c[8]), "isFrozen": w2b(c[9])} if len(c) >= 10 else c
            elif k == "getReserveCaps":
                c = words(r)
                ro["caps"] = {"borrowCap": w2i(c[0]) if c else None, "supplyCap": w2i(c[1]) if len(c) > 1 else None}
            elif k == "getPaused":
                ro["paused"] = w2b(r)
            elif k == "getReserveTokensAddresses":
                c = words(r)
                ro["aToken"] = w2a(c[0]) if c else None
            elif k == "getReserveData":
                c = words(r)
                keys = ["unbacked", "accruedToTreasuryScaled", "totalAToken", "totalStableDebt", "totalVariableDebt",
                        "liquidityRate", "variableBorrowRate", "stableBorrowRate", "averageStableBorrowRate",
                        "liquidityIndex", "variableBorrowIndex", "lastUpdateTimestamp"]
                ro["reserveData"] = dict(zip(keys, [w2i(x) for x in c])) if len(c) >= 12 else c
            elif k == "getAssetPrice":
                ro["oraclePrice"] = w2i(r)
        # underlying cash for aTokens
        cash_calls, cash_meta = [], []
        for sym, asset in m["reserves"].items():
            a = mo["reserves"][sym].get("aToken")
            if a:
                cash_calls.append(("eth_call", [{"to": asset, "data": SEL["balanceOf"] + pad32(int(a, 16))}, block]))
                cash_meta.append(sym)
        if cash_calls:
            for sym, r in zip(cash_meta, rpc_batch(rpcs, cash_calls)):
                mo["reserves"][sym]["cash"] = w2i(r)
        out["markets"][mn] = mo
    return out


def health(rpcs):
    pool = MARKETS["market1"]["pool"]
    users = ["0xCBf9a7753F9D2d0e8141ebB36d99f87AcEf98597", "0xA0C2fe72aD9b640994A9c4252F25Fb058DDb3702",
             "0xD52526d36125a9579A9Bbe89541f251Ad59265a3", "0x04f9c518129E4D6Eb380c5cCC4cb1d876913D00F"]
    calls = [("eth_call", [{"to": pool, "data": SEL["getUserAccountData"] + pad32(int(u, 16))}]) for u in users]
    res = rpc_batch(rpcs, calls)
    out = {}
    for u, r in zip(users, res):
        c = words(r)
        if len(c) >= 6:
            out[u] = {"collateralUSD": w2i(c[0]) / 1e8, "debtUSD": w2i(c[1]) / 1e8, "healthFactor": w2i(c[5]) / 1e18}
    return out


def main():
    report = {"generated_at_unix": int(time.time())}
    report["sceptre_sflr_flare"] = sceptre(FLARE_RPCS)
    report["more_markets_flow"] = more([FLOW_RPC])
    report["more_market1_health"] = health([FLOW_RPC])
    txt = json.dumps(report, indent=1)
    if len(sys.argv) > 1:
        open(sys.argv[1], "w").write(txt + "\n")
    print(txt)


if __name__ == "__main__":
    main()
