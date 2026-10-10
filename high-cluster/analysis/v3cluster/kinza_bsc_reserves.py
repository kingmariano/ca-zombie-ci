#!/usr/bin/env python3
"""Read Kinza (Aave v3 fork) BSC reserves live. Keyless public RPC. Read-only."""
import json, subprocess, sys

RPC = "https://bsc-rpc.publicnode.com"
POOL = "0xcB0620b181140e57D1C0D8b724cde623cA963c8C"
ORACLE = "0xec203E7676C45455BF8cb43D28F9556F014Ab461"

def call(to, sig, *args, json_out=False):
    cmd = ["cast", "call", to, sig, *[str(a) for a in args], "--rpc-url", RPC]
    if json_out: cmd.append("--json")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if r.returncode != 0: return None
    out = r.stdout.strip()
    if json_out:
        return json.loads(out)
    # strip human-readable suffix like "123 [1.23e2]" for numerics; keep strings
    if out.startswith('"'):
        return out.strip('"')
    return out.split()[0]

def main():
    assets = call(POOL, "getReservesList()(address[])", json_out=True)
    if assets and isinstance(assets[0], list): assets = assets[0]
    res = []
    for a in assets:
        d = call(POOL, "getReserveData(address)((uint256,uint128,uint128,uint128,uint128,uint128,uint40,uint16,address,address,address,address,uint128,uint128,uint128))", a, json_out=True)
        if d is None: 
            res.append({"asset": a, "error": "getReserveData failed"}); continue
        d = d[0]
        cfg = int(d[0])
        atoken = d[8]; vdebt = d[10]
        sym = call(a, "symbol()(string)") or "?"
        dec = call(a, "decimals()(uint8)") or "18"
        price = call(ORACLE, "getAssetPrice(address)(uint256)", a) or "0"
        ats = call(atoken, "totalSupply()(uint256)") or "0"
        vds = call(vdebt, "totalSupply()(uint256)") or "0"
        res.append({
            "asset": a, "symbol": sym, "decimals": int(dec),
            "ltv": cfg & 0xFFFF, "lt": (cfg >> 16) & 0xFFFF, "bonus": (cfg >> 32) & 0xFFFF,
            "active": (cfg >> 56) & 1, "frozen": (cfg >> 57) & 1,
            "borrowing": (cfg >> 58) & 1, "paused": (cfg >> 60) & 1,
            "oracle_price_1e8": price,
            "aToken": atoken, "variableDebt": vdebt,
            "aTokenSupply": ats, "variableDebtSupply": vds,
            "supplied": int(ats)/10**int(dec), "borrowed": int(vds)/10**int(dec),
            "price_usd": int(price)/1e8,
            "supplied_usd": int(ats)/10**int(dec)*int(price)/1e8,
            "borrowed_usd": int(vds)/10**int(dec)*int(price)/1e8,
        })
    out = {"chain": "bsc", "pool": POOL, "oracle": ORACLE, "block": call("0x0000000000000000000000000000000000000000","eth_blockNumber") if False else subprocess.run(["cast","block-number","--rpc-url",RPC],capture_output=True,text=True).stdout.strip(), "reserves": res}
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
