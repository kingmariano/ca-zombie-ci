#!/usr/bin/env python3
"""L2 Silicon bridge state + wrapped token supplies. Read-only."""
from rpc import eth_call, rpc, SILICON, block_number

BRIDGE_L2 = "0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe"
GER_L2 = "0xa40d5f56745a118d0906a34e69aec8c0db1cb8fa"
ORC = "0x37908ffdEf18aDD36518e781a9a77C2C6f4A4260"

ORIGINS = {  # originNetwork=0 (Ethereum) origin token addresses
    "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "WBTC": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "ORC":  "0x662b67d00a13faf93254714dd601f5ed49ef2f51",
    "DAI":  "0x6B175474E89094C44Da98b954EedeAC495271d0F",
}
DEC = {"USDC":6,"USDT":6,"WBTC":8,"WETH":18,"ORC":18,"DAI":18}

def u(r):
    return None if not r or r == "0x" else int(r, 16)

def call(to, data):
    return eth_call(SILICON, to, data)

if __name__ == "__main__":
    bn = block_number(SILICON)
    print("silicon block", bn)
    print("== L2 bridge state ==")
    for sig, sel in [("networkID","0xbab161bf"),("globalExitRootManager","0xd02103ca"),("depositCount","0x2dfdf0b5"),
                     ("getRoot","0x5ca1e165"),("isDepositPaused","0xf560d0b2"),("lastUpdatedDepositCount","0xbe5831c7")]:
        try:
            r = call(BRIDGE_L2, sel)
            print(f"  {sig:24}", u(r))
        except Exception as e:
            print(f"  {sig:24} ERR {str(e)[:80]}")
    print("  ETH balance:", int(rpc(SILICON,"eth_getBalance",[BRIDGE_L2,"latest"])["result"],16)/1e18)
    print("== wrapped tokens on L2 (originNetwork=0) ==")
    for name, origin in ORIGINS.items():
        data = "0x968e77ed" + "0"*64 + origin[2:].lower().rjust(64, "0")
        try:
            w = call(BRIDGE_L2, data)
            waddr = "0x" + w[-40:] if w and w != "0x" else None
        except Exception as e:
            waddr = f"ERR {str(e)[:60]}"
        sup = None
        if waddr and waddr.startswith("0x"):
            try:
                sup = u(call(waddr, "0x18160ddd"))
            except Exception as e:
                sup = f"ERR {str(e)[:60]}"
        print(f"  {name:5} origin={origin} wrapped={waddr} totalSupply={sup if not isinstance(sup,int) else sup/10**DEC[name]:,.4f}")
    print("== L2 GER manager ==")
    for sig, sel in [("lastGlobalExitRoot","0x0acd922c"),("lastLocalExitRoot","0xf8e6f226"),("lastRollupExitRoot","0x01fd9044"),("bridgeAddress","0xa3c573eb")]:
        try:
            r = call(GER_L2, sel)
            print(f"  {sig:24}", r)
        except Exception as e:
            print(f"  {sig:24} ERR {str(e)[:80]}")
