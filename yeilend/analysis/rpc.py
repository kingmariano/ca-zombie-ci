#!/usr/bin/env python3
"""Minimal JSON-RPC helper for read-only Sei mainnet state reads."""
import json, time, urllib.request, sys

RPCS = ["https://evm-rpc.sei-apis.com", "https://sei-evm-rpc.publicnode.com"]

def rpc(method, params, rpc_url=None, _retries=3):
    urls = [rpc_url] if rpc_url else RPCS
    last = None
    for attempt in range(_retries):
        for u in urls:
            try:
                req = urllib.request.Request(
                    u,
                    data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 zombie-research"},
                )
                with urllib.request.urlopen(req, timeout=30) as r:
                    j = json.loads(r.read())
                if "error" in j:
                    last = RuntimeError(f"{method} {params}: {j['error']}")
                    continue
                return j["result"]
            except Exception as e:
                last = e
        time.sleep(0.4)
    raise last

BLOCK = None
def block_number():
    global BLOCK
    if BLOCK is None:
        BLOCK = int(rpc("eth_blockNumber", []), 16)
    return BLOCK

def eth_call(to, data, block=None):
    if block is None:
        block = block_number()
    if isinstance(block, int):
        block = hex(block)
    return rpc("eth_call", [{"to": to, "data": data}, block])

def raw_call(to, selector, block=None):
    return eth_call(to, selector, block)

# ---- ABI decoding helpers (static types only) ----
def words(hexstr):
    h = hexstr[2:] if hexstr.startswith("0x") else hexstr
    if h == "":
        return []
    return [h[i:i+64] for i in range(0, len(h), 64)]

def dec_uint(w): return int(w, 16)
def dec_addr(w): return "0x" + w[24:]
def dec_u40(w): return int(w, 16)

def dec_string(hexstr):
    h = hexstr[2:]
    if len(h) < 128:
        return None
    off = int(h[:64], 16) * 2
    ln = int(h[off:off+64], 16)
    return bytes.fromhex(h[off+64:off+64+ln*2]).decode("utf-8", "replace")

def dec_string_array(hexstr):
    h = hexstr[2:]
    off = int(h[:64], 16) * 2
    n = int(h[off:off+64], 16)
    out = []
    for i in range(n):
        p = off + 64 + i*64
        soff = int(h[p:p+64], 16) * 2
        ln = int(h[soff:soff+64], 16)
        out.append(bytes.fromhex(h[soff+64:soff+64+ln*2]).decode("utf-8", "replace"))
    return out

# selectors
SEL = {
    "getReservesList()": "d1946dbc",
    "getReserveData(address)": "35ea6a75",
    "getConfiguration(address)": "c44b11f7",
    "getAssetPrice(address)": "b3596f07",
    "getSourceOfAsset(address)": "92bf2be0",
    "symbol()": "95d89b41",
    "decimals()": "313ce567",
    "totalSupply()": "18160ddd",
    "scaledTotalSupply()": "b1bf962d",
    "balanceOf(address)": "70a08231",
    "getFallbackOracle()": "ac5cb4d2",  # AaveOracle fallback getter is getFallbackOracle()? verify below
    "paused()": "5c975abb",
    "getUserAccountData(address)": "bf92857c",
    "ADDRESSES_PROVIDER()": "0542975c",
    "owner()": "8da5cb5b",
    "getPool()": "026b1d5f",
    "getACLAdmin()": "a99d68f6",   # verify
    "getACLManager()": "0e6718e7", # verify
    "getPriceOracle()": "9ce4fbb4",# verify
    "getLiquidationGracePeriod(address)": "5404c71c",
    "MAX_STALE_PERIOD()": "d9a4dbc1",
    "stalePeriod(address)": "f5c0f9a2",  # custom oracle hints
}

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "block":
        print(block_number())
    elif cmd == "call":
        to, data = sys.argv[2], sys.argv[3]
        print(eth_call(to, data))
