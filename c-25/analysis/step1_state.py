#!/usr/bin/env python3
"""C-25 step 1: live state of TrustedVolumes proxy + impl (read-only)."""
import json, sys, urllib.request
sys.path.insert(0, "/home/heisenberg/CA/c-25/analysis")
from rpc import rpc_batch, call, slot

PROXY = "0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756"
IMPL = "0x88eb28009351Fb414A5746F5d8CA91cdc02760d8"
TOKENS = {
    "WETH": ("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18),
    "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
    "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "WBTC": ("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", 8),
    "DAI":  ("0x6B175474E89094C44Da98b954EedeAC495271d0F", 18),
}
RPC = sys.argv[1] if len(sys.argv) > 1 else "https://ethereum-rpc.publicnode.com"

def balance_of(token, who):
    return call(token, "0x70a08231" + who[2:].rjust(64, "0").lower())

calls = [
    ("eth_blockNumber", []),
    ("eth_getCode", [PROXY, "latest"]),
    ("eth_getCode", [IMPL, "latest"]),
    slot(PROXY, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"),
    slot(PROXY, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"),
    slot(PROXY, "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"),
    slot(PROXY, "0x0"),
    ("eth_getBalance", [PROXY, "latest"]),
    ("eth_getBalance", [IMPL, "latest"]),
]
keys = ["block", "proxy_code", "impl_code", "impl_slot", "admin_slot", "beacon_slot", "slot0",
        "proxy_eth", "impl_eth"]
for name, (addr, dec) in TOKENS.items():
    calls.append(balance_of(addr, PROXY)); keys.append(f"proxy_{name}")
    calls.append(balance_of(addr, IMPL)); keys.append(f"impl_{name}")

res = rpc_batch(calls, RPC)
out = {}
for k, v in zip(keys, res):
    out[k] = v

# decode helpers
def to_int(h):
    if h is None: return None
    if isinstance(h, int): return h
    return int(h, 16) if h not in ("0x", "") else 0

def to_addr(h):
    if not h or len(h) < 42: return h
    return "0x" + h[-40:]

s = {}
s["block"] = to_int(out["block"])
s["proxy_code_size"] = len(out["proxy_code"] or "0x") // 2 - 1
s["impl_code_size"] = len(out["impl_code"] or "0x") // 2 - 1
s["eip1967_impl"] = to_addr(out["impl_slot"])
s["eip1967_admin"] = to_addr(out["admin_slot"])
s["eip1967_beacon"] = to_addr(out["beacon_slot"])
s["slot0_raw"] = out["slot0"]
s["proxy_eth_wei"] = to_int(out["proxy_eth"])
s["impl_eth_wei"] = to_int(out["impl_eth"])
for name, (addr, dec) in TOKENS.items():
    s[f"proxy_{name}_raw"] = to_int(out[f"proxy_{name}"])
    s[f"proxy_{name}"] = to_int(out[f"proxy_{name}"]) / 10**dec
    s[f"impl_{name}_raw"] = to_int(out[f"impl_{name}"])
    s[f"impl_{name}"] = to_int(out[f"impl_{name}"]) / 10**dec

print(json.dumps(s, indent=2))
with open("/home/heisenberg/CA/c-25/analysis/state.json", "w") as f:
    json.dump(s, f, indent=2)
