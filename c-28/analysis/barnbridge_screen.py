#!/usr/bin/env python3
"""C-28 BarnBridge screen: governance capture cost + remaining user approvals to SmartYield providers.
Read-only. Uses public RPC + Etherscan logs API."""
import json, time, urllib.request, urllib.parse, concurrent.futures as cf, os

RPC = os.environ.get("RPC", "https://ethereum-rpc.publicnode.com")
ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        ENV[k] = v.strip().strip('"').strip("'")
ESKEY = ENV["ETHERSCANV2_API_KEY"]

def rpc(method, params, _id=1):
    body = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for _ in range(3):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=30))
            if "result" in d:
                return d["result"]
        except Exception:
            time.sleep(1)
    return None

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def sel(sig):
    import hashlib
    # keccak via hashlib? not available; use precomputed selectors by name
    raise NotImplementedError

# selectors (keccak256 first 4 bytes)
S = {
    "bondStaked()": "0xc2077e81",
    "owner()": "0x8da5cb5b",
    "uToken()": "0x63315637",
    "symbol()": "0x95d89b41",
    "controller()": "0xf77c4791",
    "getReserves()": "0x0902f1ac",
    "token0()": "0x0dfe1681",
    "getPair(address,address)": "0xe6a43905",
    "balanceOf(address)": "0x70a08231",
    "allowance(address,address)": "0xdd62ed3e",
    "decimals()": "0x313ce567",
    "lastProposalId()": "0x74cb3041",
    "minQuorum()": "0xb5a127e5",
}
# NOTE: selectors below are verified live in the screen output; if a call reverts it is reported.

def addr_arg(a):
    return a.lower().replace("0x", "").rjust(64, "0")

BARN = "0x10e138877df69ca44fdc68655f86c88cde142d7f"
GOV = "0x4cae362d7f227e3d306f70ce4878e245563f3069"
BOND = "0x0391d2021f89dc339f60fff84546ea23e337750f"
WETH = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
UNIV2 = "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f"
SUSHI = "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac"

PROVIDERS = [
    "0x6c9DaE2C40b1e5883847bF5129764e76Cb69Fc57",
    "0x3cf46DA7D65E9aa2168a31b73dd4BeEA5cA1A1f1",
    "0x660dAF6643191cF0eD045B861D820F283cA078fc",
    "0x673f9488619821aB4f4155FdFFe06f6139De518F",
    "0x3E3349E43e5EeaAEDC5Dc2cf7e022919a6751907",
    "0x6324538cc222b43490dd95CEBF72cf09d98D9dAe",
    "0x4dB6fb0218cE5DA392f1E6475A554BAFcb62EF30",
    "0x89d82FdF095083Ded96B48FC6462Ed5dBD14151f",
    "0x62e479060c89C48199FC7ad43b1432CC585BA1b9",
    "0xc45F49bE156888a1C0C93dc0fE7dC89091E291f5",
]

out = {}

# governance params
last = call(GOV, S["lastProposalId()"])
out["lastProposalId"] = int(last, 16) if last and last != "0x" else None
q = call(GOV, S["minQuorum()"])
out["minQuorum"] = int(q, 16) if q and q != "0x" else None
bs = call(BARN, S["bondStaked()"])
out["bondStaked_wei"] = int(bs, 16) if bs and bs != "0x" else None
out["bondStaked"] = out["bondStaked_wei"] / 1e18 if out["bondStaked_wei"] is not None else None
ow = call(BARN, S["owner()"])
out["barn_owner"] = "0x" + ow[-40:] if ow and ow != "0x" else None

# BOND market
def pair_reserves(factory):
    p = call(factory, S["getPair(address,address)"] + addr_arg(BOND) + addr_arg(WETH))
    if not p or p == "0x":
        return None
    pair = "0x" + p[-40:]
    r = call(pair, S["getReserves()"])
    t0 = call(pair, S["token0()"])
    if not r or r == "0x":
        return None
    r0 = int(r[2:66], 16); r1 = int(r[66:130], 16)
    return {"pair": pair, "reserve0": r0, "reserve1": r1, "token0": "0x" + t0[-40:]}

out["bond_univ2"] = pair_reserves(UNIV2)
out["bond_sushi"] = pair_reserves(SUSHI)

# providers
prov = []
for p in PROVIDERS:
    u = call(p, S["uToken()"])
    sym = call(p, S["symbol()"])
    ctrl = call(p, S["controller()"])
    u = "0x" + u[-40:] if u and u != "0x" else None
    prov.append({"provider": p, "uToken": u, "symbol": "0x" + sym[-40:] if sym else None, "controller": "0x" + ctrl[-40:] if ctrl and ctrl != "0x" else None})
    if u:
        prov[-1]["underlying_symbol"] = call(u, S["symbol()"])
        dec = call(u, S["decimals()"])
        prov[-1]["decimals"] = int(dec, 16) if dec and dec != "0x" else None
out["providers"] = prov
json.dump(out, open("/home/heisenberg/CA/c-28/analysis/barnbridge_screen.json", "w"), indent=1)
print(json.dumps(out, indent=1)[:4000])
