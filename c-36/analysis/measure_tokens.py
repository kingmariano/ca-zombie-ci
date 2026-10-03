#!/usr/bin/env python3
"""Measure ERC-20 balances (WETH/USDC/USDT/DAI/WBTC/stETH/wstETH/SAI) for all 295 contracts
plus a curated child/backing list. Read-only. Writes analysis/token_balances.json."""
import json, time
import requests
from concurrent.futures import ThreadPoolExecutor

RPC = "https://ethereum-rpc.publicnode.com"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

TOKENS = {
    "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "DAI":  "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "WBTC": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    "stETH": "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
    "wstETH": "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0",
    "SAI": "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359",
}

# curated backing/child contracts
CHILDREN = [
    "0xbf4ed7b27f1d666546e30d74d50d173d20bca754",  # The DAO WithdrawDAO
    "0x78988d377227c8801905e517c042e61d85601a75",  # DigixDAO refund
    "0xa2f987a546d4cd1c607ee8141276876c26b72bdf",  # Lido AnchorVault
    "0xb1e4675f0dbe360ba90447a7e58c62c762ad62d4",  # Neufund LockedAccount v1
    "0x0b7dc5a43ce121b4eaaa41b0f4f43bba47bb8951",  # Neufund v2 EtherToken (listed)
    "0x3dfd23a6c5e8bbcfc9581d2e864a68feb6a076d3",  # Aave v1 core
    "0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e",  # dYdX Solo
    "0x5b67871c3a857de81a1ca0f9f7945e5670d986dc",  # Set vault
    "0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e",  # YFI (sanity)
]

def rpc_batch(calls, retries=4):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    for i in range(retries):
        try:
            r = requests.post(RPC, json=payload, headers=UA, timeout=60)
            j = r.json()
            out = [None]*len(calls)
            if isinstance(j, list):
                for item in j:
                    idx = item.get("id")
                    if "result" in item: out[idx] = item["result"]
                    elif "error" in item: out[idx] = item["__error__"] if False else {"__error__": item["error"]}
                return out
        except Exception:
            pass
        time.sleep(0.5*(i+1))
    return [None]*len(calls)

def enc_balance_of(addr):
    return "0x70a08231" + addr.lower().replace("0x", "").rjust(64, "0")

def main():
    rows = json.load(open("/home/heisenberg/CA/c-36/analysis/index_full_live.json"))
    addrs = [r["contract"] for r in rows] + [a for a in CHILDREN if a.lower() not in {r["contract"].lower() for r in rows}]
    addrs = list(dict.fromkeys(addrs))
    block = int(requests.post(RPC, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, headers=UA, timeout=20).json()["result"], 16)
    print("block", block, "addrs", len(addrs))
    out = {}
    # build calls
    calls = []
    meta = []
    for a in addrs:
        for sym, tok in TOKENS.items():
            calls.append(("eth_call", [{"to": tok, "data": enc_balance_of(a)}, hex(block)]))
            meta.append((a, sym))
    # also ETH balances for children
    for a in addrs:
        calls.append(("eth_getBalance", [a, hex(block)]))
        meta.append((a, "ETH"))
    for i in range(0, len(calls), 20):
        res = rpc_batch(calls[i:i+20])
        for (a, sym), v in zip(meta[i:i+20], res):
            out.setdefault(a, {})[sym] = v
    json.dump({"block": block, "balances": out}, open("/home/heisenberg/CA/c-36/analysis/token_balances.json", "w"))
    # summary: nonzero WETH/stable entries
    DEC = {"WETH":18,"USDC":6,"USDT":6,"DAI":18,"WBTC":8,"stETH":18,"wstETH":18,"SAI":18,"ETH":18}
    for r in rows:
        a = r["contract"]; b = out.get(a, {})
        row = []
        for sym in ["ETH"]+list(TOKENS):
            v = b.get(sym)
            if isinstance(v, str):
                try:
                    amt = int(v, 16)/10**DEC[sym]
                    if amt > 0.001: row.append(f"{sym}={amt:.3f}")
                except: pass
        if row: print(f"{str(r.get('name'))[:36]:38s} {a} {' '.join(row)}")

if __name__ == "__main__":
    main()
