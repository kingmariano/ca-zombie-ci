#!/usr/bin/env python3
"""Read-only Ethereum recon for Orbit Bridge (Ozys). No writes, no signing."""
import json, urllib.request, sys

ETH = "https://ethereum-rpc.publicnode.com"
_id = [0]

def rpc(method, params, url=ETH, timeout=30):
    _id[0] += 1
    payload = json.dumps({"jsonrpc":"2.0","id":_id[0],"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=payload, headers={"Content-Type":"application/json",
        "User-Agent":"Mozilla/5.0 (X11; Linux x86_64) research-readonly/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.load(r)
    if "error" in d:
        raise RuntimeError(d["error"])
    return d["result"]

def code(addr):
    return rpc("eth_getCode", [addr, "latest"])

def balance(addr):
    return int(rpc("eth_getBalance", [addr, "latest"]), 16)

def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])

def erc20_balance(token, holder):
    d = "0x70a08231" + holder[2:].lower().rjust(64, "0")
    r = call(token, d)
    return None if r == "0x" else int(r, 16)

def erc20_decimals(token):
    r = call(token, "0x313ce567")
    return int(r, 16) if r != "0x" else None

def u(h, default=None):
    return default if not h or h == "0x" else int(h, 16)

def a(h):
    return None if not h or h == "0x" else "0x" + h[-40:]

CONTRACTS = {
    "ETH Vault (0x1bf68a...)":      "0x1Bf68A9d1EaEe7826b3593C20a0Ca93293cb489a",
    "Orbit Hub (0xb5680a...)":      "0xb5680a55d627c52de992e3ea52a86f19da475399",
    "Orbit Hub impl (0x8eb2ab...)": "0x8eb2abafc23483afb6bed2885bfeddfeaef2a30c",
    "ETH Bridge (0x78d80c...)":     "0x78d80c33f23a3395c52b3a8c0d0b12253771b9f7",
    "ORC token (0x662b67...)":      "0x662b67d00a13faf93254714dd601f5ed49ef2f51",
    "ORBIT Minter (0x1b57Ce...)":   "0x1b57Ce997Ca6a009ce54bB2d37DEbEBadFDbBb06",
    "KLAYTN Minter (0x60070F...)":  "0x60070F5D2e1C1001400A04F152E7ABD43410F7B9",
    "Common Minter (0x6BD8E3...)":  "0x6BD8E3beEC87176BA9c705c9507Aa5e6F0E6706f",
    "Hub ProxyAdmin?":              "0x8eb2abafc23483afb6bed2885bfeddfeaef2a30c",
}

TOKENS = {
    "ORC":  ("0x662b67d00a13faf93254714dd601f5ed49ef2f51", 18),
    "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
    "WBTC": ("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", 8),
    "WETH": ("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18),
    "DAI":  ("0x6B175474E89094C44Da98b954EedeAC495271d0F", 18),
    "oKLAY?": ("0x60070F5D2e1C1001400A04F152E7ABD43410F7B9", 18),
}

IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"

def slot(addr, s):
    return rpc("eth_getStorageAt", [addr, s, "latest"])

if __name__ == "__main__":
    bn = int(rpc("eth_blockNumber", []), 16)
    print(f"# Ethereum block {bn}")
    print("\n== code presence / size ==")
    for name, addr in CONTRACTS.items():
        c = code(addr)
        print(f"{name:34} {addr} codelen={len(c)//2-1} ETH={balance(addr)/1e18:.6f}")
        if addr in ("0x1Bf68A9d1EaEe7826b3593C20a0Ca93293cb489a",
                    "0xb5680a55d627c52de992e3ea52a86f19da475399",
                    "0x662b67d00a13faf93254714dd601f5ed49ef2f51",
                    "0x78d80c33f23a3395c52b3a8c0d0b12253771b9f7"):
            print(f"    impl={a(slot(addr, IMPL_SLOT))} admin={a(slot(addr, ADMIN_SLOT))}")
    print("\n== token balances held by ETH Vault / Hub / Bridge / Minters ==")
    holders = {
        "Vault": "0x1Bf68A9d1EaEe7826b3593C20a0Ca93293cb489a",
        "Hub":   "0xb5680a55d627c52de992e3ea52a86f19da475399",
        "Bridge":"0x78d80c33f23a3395c52b3a8c0d0b12253771b9f7",
        "ORBITMinter":"0x1b57Ce997Ca6a009ce54bB2d37DEbEBadFDbBb06",
        "KLAYTNMinter":"0x60070F5D2e1C1001400A04F152E7ABD43410F7B9",
    }
    for tn, (ta, dec) in TOKENS.items():
        if tn == "oKLAY?": continue
        for hn, ha in holders.items():
            try:
                b = erc20_balance(ta, ha)
                if b:
                    print(f"  {tn:5} in {hn:12} {b/10**dec:,.4f}")
            except Exception as e:
                print(f"  {tn:5} in {hn:12} ERR {str(e)[:60]}")
    print("\n== ORC token props ==")
    print("  totalSupply", u(call(TOKENS["ORC"][0], "0x18160ddd")))
    for sig, sel in [("owner()","0x8da5cb5b"),("minter()","0x07546172"),("bridge()","0xe78cea92"),
                     ("getOwner()","0x893d20e8"),("isMinter(address)","0xaa271e1a"),("hub()","0xa2d68f2d")]:
        try:
            r = call(TOKENS["ORC"][0], sel)
            print(f"  {sig:24} raw={r[:74]} addr={a(r)} int={u(r)}")
        except Exception as e:
            print(f"  {sig:24} ERR {str(e)[:60]}")
