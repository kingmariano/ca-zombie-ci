#!/usr/bin/env python3
"""Measure L1 Silicon bridge (PolygonZkEVMBridgeV2) balances + state. Read-only."""
from rpc import eth_call, rpc, block_number

ETH = "https://ethereum-rpc.publicnode.com"
BRIDGE_L1 = "0x2a3dd3eb832af982ec71669e178424b10dca2ede"
GER_L1 = "0x580bda1e7a0cfae92fa7f6c20a3794f169ce3cfb"
ROLLUP_MGR = "0x5132A183E9F3CB7C848b0AAC5Ae0c4f0491B7aB2"
VALIDIUM = "0x419dcd0f72ebafd3524b65a97ac96699c7fbebdb"

TOKENS = {
    "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
    "WBTC": ("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", 8),
    "WETH": ("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18),
    "ORC":  ("0x662b67d00a13faf93254714dd601f5ed49ef2f51", 18),
    "DAI":  ("0x6B175474E89094C44Da98b954EedeAC495271d0F", 18),
}

def bal(token, holder):
    data = "0x70a08231" + holder[2:].lower().rjust(64, "0")
    return int(eth_call(ETH, token, data), 16)

if __name__ == "__main__":
    bn = block_number(ETH)
    print("ethereum block", bn)
    for name, (addr, dec) in TOKENS.items():
        try:
            b = bal(addr, BRIDGE_L1)
            print(f"L1 bridge {name:5} {b/10**dec:,.6f}")
        except Exception as e:
            print(f"L1 bridge {name:5} ERR {e}")
    # native ETH
    b = int(rpc(ETH, "eth_getBalance", [BRIDGE_L1, "latest"])["result"], 16)
    print(f"L1 bridge ETH   {b/1e18:,.6f}")
    print("== bridge state ==")
    for sig, sel in [("isDepositPaused","0xf560d0b2"),("networkID","0xbab161bf"),("globalExitRootManager","0xd02103ca"),
                     ("polygonRollupManager","0x8ed7e3f2"),("bridgeAddress","0xa3c573eb")]:
        try:
            r = eth_call(ETH, BRIDGE_L1, sel)
            print(f"  {sig:22}", int(r,16) if len(r) <= 66 else r)
        except Exception as e:
            print(f"  {sig:22} ERR {e}")
    print("== L1 GER manager ==")
    for sig, sel in [("lastGlobalExitRoot","0x0acd922c"),("lastLocalExitRoot","0xf8e6f226"),("lastRollupExitRoot","0x01fd9044"),("bridgeAddress","0xa3c573eb")]:
        try:
            r = eth_call(ETH, GER_L1, sel)
            print(f"  {sig:22}", r)
        except Exception as e:
            print(f"  {sig:22} ERR {e}")
