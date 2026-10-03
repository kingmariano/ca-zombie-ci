#!/usr/bin/env python3
"""Read-only state dump of Ironclad Finance (Aave v2 fork) on Mode.
Uses JSON-RPC batch calls only. No transactions.
"""
import json, sys, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

RPC = "https://mainnet.mode.network"
RPC_FALLBACKS = [
    "https://mode.drpc.org",
    "https://rpc-mode-mainnet-0.t.conduit.xyz",
]
import os
if os.environ.get("ALCHEMY_API_KEY") and os.environ.get("USE_ALCHEMY"):
    RPC_FALLBACKS.insert(0, f"https://mode-mainnet.g.alchemy.com/v2/{os.environ['ALCHEMY_API_KEY']}")
POOL = "0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3"
PROVIDER = "0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC"
ORACLE = "0xE4F4F36FcBb2D53c0bAB95F5D117489579553CaA"

def sel(sig):
    # canonical signature only (strip return type if present, e.g. "foo()(uint256)" -> "foo()")
    if ")" in sig and sig.count("(") > 1:
        sig = sig.split(")")[0] + ")"
    return "0x" + keccak(text=sig)[:4].hex()

def rpc_batch(calls):
    """calls: list of (to, data) -> list of results (hex or dict error on failure)"""
    out = [None]*len(calls)
    CHUNK = 10
    urls = [RPC] + RPC_FALLBACKS
    for start in range(0, len(calls), CHUNK):
        chunk = calls[start:start+CHUNK]
        payload = []
        for i, (to, data) in enumerate(chunk):
            # Mode RPC requires lowercase addresses, otherwise returns "execution reverted"
            payload.append({"jsonrpc":"2.0","id":i,"method":"eth_call","params":[{"to":to.lower(),"input":data},"latest"]})
        got = [None]*len(chunk)
        for attempt in range(3):
            url = urls[attempt % len(urls)]
            try:
                r = requests.post(url, json=payload, timeout=60)
                r.raise_for_status()
                items = r.json()
                if isinstance(items, dict): items = [items]
                got = [None]*len(chunk)
                for item in items:
                    got[item["id"]] = item.get("result") if "result" in item else {"error": item.get("error")}
                if not any(isinstance(g, dict) for g in got):
                    break
            except Exception:
                pass
            time.sleep(0.5)
        # retry errored calls individually once on the fallback urls
        for i, g in enumerate(got):
            if isinstance(g, dict):
                to, data = chunk[i]
                p = {"jsonrpc":"2.0","id":0,"method":"eth_call","params":[{"to":to.lower(),"input":data},"latest"]}
                for url in urls:
                    try:
                        r = requests.post(url, json=p, timeout=30)
                        j = r.json()
                        if isinstance(j, dict) and "result" in j:
                            got[i] = j["result"]; break
                    except Exception:
                        pass
        out[start:start+CHUNK] = got
    return out

def dec(types, data):
    if data is None: return None
    if isinstance(data, dict):
        print(f"# WARN rpc error: {data.get('error')}", flush=True)
        return None
    if data == "0x": return None
    return abi_decode(types, bytes.fromhex(data[2:]))

def call1(to, sig, args=()):
    data = sel(sig) + (abi_encode([t for t,_ in args], [v for _,v in args]).hex() if args else "")
    return rpc_batch([(to, data)])[0]

def main():
    block = requests.post(RPC, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, timeout=30).json()["result"]
    block_n = int(block, 16)
    print(f"# block {block_n} ({block})")

    # reserves list (retry on transient rpc errors)
    for attempt in range(8):
        res = call1(POOL, "getReservesList()(address[])")
        if isinstance(res, str) and res.startswith("0x") and len(res) > 2:
            break
        time.sleep(1)
    reserves = dec(["address[]"], res)
    reserves = reserves[0] if reserves else []
    print(f"# reserves: {len(reserves)}", flush=True)

    calls = []
    meta = []
    for a in reserves:
        calls.append((a, sel("symbol()"))); meta.append(("symbol", a))
        calls.append((a, sel("decimals()"))); meta.append(("decimals", a))
        calls.append((a, sel("name()"))); meta.append(("name", a))
        calls.append((POOL, sel("getReserveData(address)") + abi_encode(["address"],[a]).hex())); meta.append(("rdata", a))
        calls.append((POOL, sel("getConfiguration(address)") + abi_encode(["address"],[a]).hex())); meta.append(("rcfg", a))
        calls.append((ORACLE, sel("getAssetPrice(address)") + abi_encode(["address"],[a]).hex())); meta.append(("price", a))
        calls.append((ORACLE, sel("getSourceOfAsset(address)") + abi_encode(["address"],[a]).hex())); meta.append(("osrc", a))
    print("# phase1 calls...", flush=True)
    results = rpc_batch(calls)
    print("# phase1 done", flush=True)

    out = {"block": block_n, "pool": POOL, "provider": PROVIDER, "oracle": ORACLE, "reserves": {}}
    tmp = {}
    for (kind, a), r in zip(meta, results):
        tmp.setdefault(a, {})[kind] = r

    # now per-reserve dependent calls
    calls2, meta2 = [], []
    for a, t in tmp.items():
        rdata = t.get("rdata")
        try:
            rd = dec(["uint256","uint128","uint128","uint128","uint128","uint128","uint40","address","address","address","address","uint8"], rdata)
        except Exception as e:
            rd = None
        t["rd"] = rd
        if rd:
            at, sd, vd, strat = rd[7], rd[8], rd[9], rd[10]
            t["aToken"], t["stableDebt"], t["variableDebt"], t["strategy"] = at, sd, vd, strat
            for tok, label in ((at,"aTok"),(sd,"sDebt"),(vd,"vDebt")):
                if tok and tok != "0x0000000000000000000000000000000000000000":
                    calls2.append((tok, sel("totalSupply()"))); meta2.append((label+"_ts", a))
                    calls2.append((tok, sel("balanceOf(address)") + abi_encode(["address"],[POOL]).hex())); meta2.append((label+"_pool", a))
                    calls2.append((tok, sel("decimals()"))); meta2.append((label+"_dec", a))
            calls2.append((a, sel("balanceOf(address)") + abi_encode(["address"],[POOL]).hex())); meta2.append(("u_pool", a))
            calls2.append((a, sel("balanceOf(address)") + abi_encode(["address"],[at]).hex())); meta2.append(("u_atok", a))
    print("# phase2 calls...", flush=True)
    results2 = rpc_batch(calls2)
    print("# phase2 done", flush=True)
    for (kind, a), r in zip(meta2, results2):
        tmp[a][kind] = r

    for a, t in tmp.items():
        sym = dec(["string"], t.get("symbol"))
        try: sym = sym[0] if sym else "?"
        except Exception: sym = "?"
        dec_ = dec(["uint8"], t.get("decimals"))
        dec_ = dec_[0] if dec_ else 0
        rd = t.get("rd")
        cfg_raw = dec(["uint256"], t.get("rcfg"))
        cfg = None
        if cfg_raw:
            data = cfg_raw[0]
            cfg = (data & 0xFFFF, (data >> 16) & 0xFFFF, (data >> 32) & 0xFFFF, (data >> 48) & 0xFF,
                   (data >> 64) & 0xFFFF, bool((data >> 56) & 1), bool((data >> 57) & 1),
                   bool((data >> 58) & 1), bool((data >> 59) & 1))
        price = dec(["uint256"], t.get("price"))
        price = price[0] if price else None
        osrc = dec(["address"], t.get("osrc"))
        osrc = osrc[0] if osrc else None
        entry = {
            "asset": a, "symbol": sym, "decimals": dec_,
            "aToken": t.get("aToken"), "stableDebt": t.get("stableDebt"), "variableDebt": t.get("variableDebt"),
            "strategy": t.get("strategy"),
            "oraclePrice": price, "oracleSource": osrc,
            "liquidityIndex": str(rd[1]) if rd else None,
            "variableBorrowIndex": str(rd[2]) if rd else None,
            "currentLiquidityRate": str(rd[3]) if rd else None,
            "currentVariableBorrowRate": str(rd[4]) if rd else None,
            "currentStableBorrowRate": str(rd[5]) if rd else None,
            "lastUpdateTimestamp": rd[6] if rd else None,
            "cfg": None,
            "aTokenTotalSupply": None, "variableDebtTotalSupply": None, "stableDebtTotalSupply": None,
            "poolUnderlyingBalance": None, "aTokenUnderlyingBalance": None,
        }
        if cfg:
            entry["cfg"] = {"decimals": cfg[3], "ltv": cfg[0], "liqThreshold": cfg[1], "liqBonus": cfg[2],
                            "reserveFactor": cfg[4], "usageAsCollateral": cfg[0] > 0, "borrowing": cfg[7],
                            "stableEnabled": cfg[8], "active": cfg[5], "frozen": cfg[6]}
        for label, key in (("aTok_ts","aTokenTotalSupply"),("vDebt_ts","variableDebtTotalSupply"),("sDebt_ts","stableDebtTotalSupply"),
                           ("u_pool","poolUnderlyingBalance"),("u_atok","aTokenUnderlyingBalance")):
            v = t.get(label)
            try:
                vv = dec(["uint256"], v)
                entry[key] = str(vv[0]) if vv else None
            except Exception:
                entry[key] = None
        out["reserves"][a] = entry

    # pool-level
    p = call1(POOL, "paused()(bool)")
    out["paused"] = dec(["bool"], p)[0]
    p = call1(POOL, "FLASHLOAN_PREMIUM_TOTAL()(uint256)")
    out["flashloanPremiumTotal"] = str(dec(["uint256"], p)[0])
    p = call1(POOL, "LENDINGPOOL_REVISION()(uint256)")
    out["revision"] = dec(["uint256"], p)[0]
    p = call1(POOL, "MAX_NUMBER_RESERVES()(uint256)")
    out["maxReserves"] = dec(["uint256"], p)[0]

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "state_dump.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(json.dumps({k: out[k] for k in ("block","paused","flashloanPremiumTotal","revision")}, indent=1))
    for a, e in out["reserves"].items():
        print(f'{e["symbol"]:>10} {a} active={e["cfg"]["active"] if e["cfg"] else "?"} frozen={e["cfg"]["frozen"] if e["cfg"] else "?"} '
              f'supply={e["aTokenTotalSupply"]} vDebt={e["variableDebtTotalSupply"]} poolBal={e["poolUnderlyingBalance"]} price={e["oraclePrice"]}')

if __name__ == "__main__":
    main()
