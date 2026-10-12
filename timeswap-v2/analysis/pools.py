#!/usr/bin/env python3
"""Timeswap V2 — read pool-level state for every option pair found by enumerate.py.
For each chain: map option factory -> candidate pool factories (all versions), query
poolFactory.get(optionPair), then read numberOfPools/getByIndex/totalLiquidity/protocolFeesEarned.
Read-only. Keyless public RPCs.
"""
import json, sys, time, urllib.request, os

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
    "inevm": "https://mainnet.rpc.inevm.com/http",
}

# option factory -> pool factories (all versions that could own pools for that option factory)
POOLFACT = {
    "ethereum": {
        "0xcf0aca5c5b7e1bf63514d362243b6c50d5761fe8": ["0x8E3fcda01FCA533989C3CeABdcF2A6E0A776585F"],
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "arbitrum": {
        "0xcf0aca5c5b7e1bf63514d362243b6c50d5761fe8": ["0x976607554d56A46FBa855093be198cB4796e15f0"],
        "0x406d3dfcbe20b642c2262b29b960822975371502": ["0x9660c75ADd5bc600608861b7Cd32700B79b50f7f", "0x47ffFCc12b1731e543e79640EBc151E958f56f4D", "0x1EE933d5a94797f8F6aA66baeCB3F4E764427E9A"],
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "base": {
        "0x406d3dfcbe20b642c2262b29b960822975371502": ["0x47ffFCc12b1731e543e79640EBc151E958f56f4D", "0x1EE933d5a94797f8F6aA66baeCB3F4E764427E9A"],
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "optimism": {
        "0x406d3dfcbe20b642c2262b29b960822975371502": ["0x1EE933d5a94797f8F6aA66baeCB3F4E764427E9A"],
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "polygon": {
        "0xcab2e5ba8b3a8d8bf8b50f0eec12884d0255fb4a": ["0xD5c23BFd453fb1AF499BB7D813b34d48f395A279"],
        "0xcf0aca5c5b7e1bf63514d362243b6c50d5761fe8": ["0x979eC553484E0EEA2801893F1EA1C024142a58BA"],
        "0x406d3dfcbe20b642c2262b29b960822975371502": ["0x9660c75ADd5bc600608861b7Cd32700B79b50f7f", "0x47ffFCc12b1731e543e79640EBc151E958f56f4D", "0x1EE933d5a94797f8F6aA66baeCB3F4E764427E9A"],
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "mantle": {
        "0xf8f5e4b7825d484fbdfdc36fc915e79f30b02f9e": ["0xdc3462339885A7aD459a0F6f3C5b011391354732", "0x6C9e7EDe169168fb573cc95BF3558cfe936338f6"],
        "0x406d3dfcbe20b642c2262b29b960822975371502": ["0x1EE933d5a94797f8F6aA66baeCB3F4E764427E9A"],
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "hyperliquid": {
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "xlayer": {
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "polygon-zkevm": {
        "0x406d3dfcbe20b642c2262b29b960822975371502": ["0x9660c75ADd5bc600608861b7Cd32700B79b50f7f", "0x47ffFCc12b1731e543e79640EBc151E958f56f4D", "0x1EE933d5a94797f8F6aA66baeCB3F4E764427E9A"],
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
    "inevm": {
        "0x17385e95cb74a20150e4fa092aa72d57330896c4": ["0x97509c65Ff29C268F0D283A41201Be6b4090354c"],
    },
}

SEL = {
    "get1": "0xc2bc2efc",        # get(address)
    "numberOfPools": "0x6f682a53",
    "getByIndex": "0x2d883a73",
    "totalLiquidity": "0xb15044ac",   # totalLiquidity(uint256,uint256)
    "protocolFeesEarned": "0x72f8f85c",  # protocolFeesEarned(uint256,uint256)
    "owner": "0x8da5cb5b",
    "optionFactory": "0xb3461c87",
    "transactionFee": "0x9ed3edf0",
    "protocolFee": "0xb0e21e8a",
    "totalPosition": "0xb7fb542d",   # totalPosition(uint256,uint256,uint8)
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
def dec_addr(h): return "0x" + h[-40:] if h and len(h) >= 42 else None

def run(chain):
    url = RPC[chain]
    lf = os.path.join(HERE, f"live-{chain}.json")
    if not os.path.exists(lf):
        print(f"[{chain}] no live-{chain}.json, skip")
        return
    d = json.load(open(lf))
    bn = dec_uint(rpc(url, "eth_blockNumber", [])["result"])
    out = {"chain": chain, "block": bn, "poolFactories": {}, "pools": []}
    fac_pairs = d["factories"]
    # 1. map each option pair to (poolFactory, pool)
    mapping = {}
    calls = []
    keys = []
    for ofac, info in fac_pairs.items():
        pfs = POOLFACT[chain].get(ofac.lower(), [])
        for pf in pfs:
            for pair in info.get("pairs", []):
                calls.append(("eth_call", [{"to": pf, "data": SEL["get1"] + enc_addr(pair)}, "latest"]))
                keys.append((pair.lower(), pf))
    res = batch(url, calls)
    for (pair, pf), r in zip(keys, res):
        p = dec_addr(r) if r else None
        if p and int(p, 16) != 0:
            mapping.setdefault(pair, []).append((pf, p))
    # 2. read pools per pair
    calls = []
    for pair, lst in mapping.items():
        for pf, pool in lst:
            calls.append(("eth_call", [{"to": pool, "data": SEL["numberOfPools"]}, "latest"]))
    res = batch(url, calls)
    npools = {}
    i = 0
    for pair, lst in mapping.items():
        for pf, pool in lst:
            n = dec_uint(res[i]); i += 1
            npools[pool] = n or 0
    # 3. read strike/maturity list per pool
    calls = []
    order = []
    for pair, lst in mapping.items():
        for pf, pool in lst:
            for k in range(npools.get(pool, 0)):
                calls.append(("eth_call", [{"to": pool, "data": SEL["getByIndex"] + enc_uint(k)}, "latest"]))
                order.append((pair, pf, pool, k))
    res = batch(url, calls)
    sm = []
    for (pair, pf, pool, k), r in zip(order, res):
        if r and len(r) >= 130:
            strike = int(r[2:66], 16)
            maturity = int(r[66:130], 16)
            sm.append({"pair": pair, "poolFactory": pf, "pool": pool, "idx": k, "strike": str(strike), "maturity": maturity})
    # 4. read totalLiquidity + protocolFeesEarned for each (strike,maturity)
    calls = []
    for e in sm:
        calls.append(("eth_call", [{"to": e["pool"], "data": SEL["totalLiquidity"] + enc_uint(int(e["strike"])) + enc_uint(e["maturity"])}, "latest"]))
        calls.append(("eth_call", [{"to": e["pool"], "data": SEL["protocolFeesEarned"] + enc_uint(int(e["strike"])) + enc_uint(e["maturity"])}, "latest"]))
    res = batch(url, calls)
    for j, e in enumerate(sm):
        e["totalLiquidity"] = str(dec_uint(res[2*j]) if res[2*j] else 0)
        r = res[2*j+1]
        if r and len(r) >= 194:
            e["protocolFees"] = {"long0": str(int(r[2:66],16)), "long1": str(int(r[66:130],16)), "short": str(int(r[130:194],16))}
        else:
            e["protocolFees"] = {"long0": "0", "long1": "0", "short": "0"}
    # 5. pool factory owners + fees
    allpfs = sorted({pf for ofac in fac_pairs for pf in POOLFACT[chain].get(ofac.lower(), [])})
    calls = []
    for pf in allpfs:
        calls.append(("eth_call", [{"to": pf, "data": SEL["owner"]}, "latest"]))
        calls.append(("eth_call", [{"to": pf, "data": SEL["optionFactory"]}, "latest"]))
    res = batch(url, calls)
    for j, pf in enumerate(allpfs):
        out["poolFactories"][pf] = {"owner": dec_addr(res[2*j]) if res[2*j] else None,
                                    "optionFactory": dec_addr(res[2*j+1]) if res[2*j+1] else None}
    out["pools"] = sm
    with open(os.path.join(HERE, f"pools-{chain}.json"), "w") as f:
        json.dump(out, f, indent=1)
    active = [e for e in sm if int(e["totalLiquidity"]) > 0]
    print(f"[{chain}] block {bn}: {len(sm)} (strike,maturity) pools across {len(mapping)} option pairs; {len(active)} with liquidity>0")
    for pf, v in out["poolFactories"].items():
        print(f"   poolFactory {pf} owner={v['owner']}")

if __name__ == "__main__":
    chains = sys.argv[1:] or list(RPC.keys())
    for c in chains:
        if c in RPC:
            try:
                run(c)
            except Exception as e:
                print(f"[{c}] ERROR {e}")
