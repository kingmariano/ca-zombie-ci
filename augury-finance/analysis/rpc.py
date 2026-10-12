#!/usr/bin/env python3
"""Minimal keyless JSON-RPC helper (Polygon). No secrets. Batches <=10 calls."""
import json, urllib.request, sys, time

RPC = "https://polygon-bor-rpc.publicnode.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}

def batch(calls, rpc=RPC):
    """calls: list of (method, params). Returns list of results (or {'error':...})."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        req = urllib.request.Request(rpc, data=json.dumps(payload).encode(), headers=UA)
        for attempt in range(4):
            try:
                resp = json.loads(urllib.request.urlopen(req, timeout=30).read())
                break
            except Exception as e:
                if attempt == 3: raise
                time.sleep(1.5 * (attempt + 1))
        by_id = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            out.append(r.get("result", r.get("error")))
    return out

def eth_call(to, data, block="latest"):
    return ("eth_call", [{"to": to, "data": data}, block])

def eth_getBalance(addr, block="latest"):
    return ("eth_getBalance", [addr, block])

def block_number():
    return batch([("eth_blockNumber", [])])[0]

def hex2int(h):
    if h is None: return None
    return int(h, 16)

# --- selector helpers (no external deps) ---
def sel(sig):
    # keccak256 via eth_call trick is not possible offline; use precomputed table instead
    raise NotImplementedError

PRECOMPUTED = {
    # function sig -> 4-byte selector
    "poolLength()": "0x081e3eda",
    "poolInfo(uint256)": "0x1526fe27",
    "omen()": "0x0c9a2ad3",       # guess placeholder; will verify below
    "dividends()": "0x0bd9f2f6",
    "owner()": "0x8da5cb5b",
    "devAddress()": "0xf2b30a88",  # placeholder
    "communityAddress()": "0x8b4c0d25", # placeholder
    "startBlock()": "0x48cd4cb1",
    "omenPerBlock()": "0xce9a3f34",  # placeholder
    "maxSupply()": "0xd5abeb01",
    "totalAllocPoint()": "0x17caf6f1",
    "operators(address)": "0x13e7ab25", # placeholder
    "dividendsContractAddress()": "0x76d25865", # placeholder
    "totalSupply()": "0x18160ddd",
    "balanceOf(address)": "0x70a08231",
    "totalLpOmenStaked_d18()": "0xf4f39c88", # placeholder
    "totalNlpOmenStaked_d18()": "0x9d5f6b1a", # placeholder
    "lastFundedEpoch()": "0x27d2576e", # placeholder
    "lastClosedEpoch()": "0x67ac2f2a", # placeholder
    "dividendToken()": "0xd5a2bf59", # placeholder
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "getReserves()": "0x0902f1ac",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "name()": "0x06fdde03",
    "pendingOmen(uint256,address)": "0xf40f0f0d", # placeholder
    "userInfo(uint256,address)": "0x93f1a40b",
    "referralCommissionRate()": "0x1e75f0d6", # placeholder
    "epochDurationSeconds()": "0x4b336f1d", # placeholder
    "lastFundedAtUtcSeconds()": "0x8b9acb2c", # placeholder
    "currentEpoch()": "0xde1b0f7b", # placeholder
    "stakedUserAddresses(uint256)": "0x2861b88f", # placeholder
    "depositFeeBP": "",
}

if __name__ == "__main__":
    print("block", hex2int(block_number()))
