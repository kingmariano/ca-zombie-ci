#!/usr/bin/env python3
"""C-25: probe live proxy behavior for key selectors (read-only eth_call)."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/c-25/analysis")
from rpc import rpc_batch

PROXY = "0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756"
WETH  = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
USDT  = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
USDC  = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
WBTC  = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"
DAI   = "0x6B175474E89094C44Da98b954EedeAC495271d0F"

def pad(a): return a[2:].lower().rjust(64, "0")

calls, labels = [], []
def add(label, data, to=PROXY):
    labels.append(label)
    calls.append(("eth_call", [{"to": to, "data": data}, "latest"]))

add("proxy.owner()", "0x8da5cb5b")
add("proxy.maxExpiry()", "0x94be834d")
for name, tok in [("WETH", WETH), ("USDT", USDT), ("USDC", USDC), ("WBTC", WBTC), ("DAI", DAI)]:
    add(f"proxy.isSupportedToken({name})", "0x240028e8" + pad(tok))
add("proxy.getOrderStatus(0,0)", "0x5df4fd38" + "00" * 32 + "00" * 32)
add("proxy.0x4112e1c2-empty", "0x4112e1c2")
add("proxy.0xea7faa61-empty", "0xea7faa61")
for sel in ["0x637fec51", "0x7179a12c", "0x9227b794", "0xb9e7bce6", "0xcbfd8657",
            "0xdcbbc8d4", "0x01e480ab", "0x06c1f431", "0x5d4d8fe7", "0x3fabe5a3"]:
    add(f"proxy.{sel}-empty", sel)
add("proxy.0x12345678-unknown", "0x12345678")
add("proxy.0x9db64a40-rollback-test", "0x9db64a40" + "01e480ab".rjust(64, "0") + pad("0x" + "00" * 20))

res = rpc_batch(calls)
out = {}
for lab, r in zip(labels, res):
    out[lab] = r
print(json.dumps(out, indent=2))
with open("/home/heisenberg/CA/c-25/analysis/probe_calls.json", "w") as f:
    json.dump(out, f, indent=2)
