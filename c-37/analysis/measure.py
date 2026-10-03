#!/usr/bin/env python3
"""Local measurement helper for C-37 native protocols (light reads only)."""
import json, sys, urllib.request, time, concurrent.futures as cf

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://eth.drpc.org"

def rpc(method, params):
    req = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    for a in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(RPC, json.dumps(req).encode(),
                                       {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}), timeout=20) as r:
                j = json.load(r)
            if "result" in j:
                return j["result"]
        except Exception:
            time.sleep(0.3 * (a + 1))
    return None

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def bal(token, who):
    r = call(token, "0x70a08231" + "0" * 24 + who[2:].lower())
    return int(r, 16) if r and r != "0x" else None

def u256(to, sel):
    r = call(to, sel)
    return int(r, 16) if r and r != "0x" else None

def eth_bal(a):
    r = rpc("eth_getBalance", [a, "latest"])
    return int(r, 16) if r else None

CORE = "0x3dfd23a6c5e8bbcfc9581d2e864a68feb6a076d3"
RESERVES = {
    "DAI": ("0x6B175474E89094C44Da98b954EedeAC495271d0F", "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d", 18),
    "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "0x9bA00D6856a4eDF4665BcA2C2309936572473B7E", 6),
    "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", "0x71fc860F7D3A592A4a98740e39dB31d25db65ae8", 6),
    "TUSD": ("0x0000000000085d4780B73119b644AE5ecd22b376", "0x4DA9b813057D04BAef4e5800E36083717b4a0341", 18),
    "SUSD": ("0x57Ab1ec28D129707052df4dF418D58a2D46d5f51", "0x625aE63000f46200499120B906716420bd059240", 18),
    "BAT":  ("0x0D8775F648430679A709E98d2b0Cb6250d2887EF", "0xE1BA0FB44CCb0D11b80F38ac6a2e471161dE0Bdf", 18),
    "KNC":  ("0xdd974D5C2e2928deA5F71b9825b8b646686BD200", "0x9D91BE44C06d373a8a226E1f3b146956083803eB", 18),
    "LEND": ("0x80fB784B7eD66730e8b1DBd9820aFD30615e2f77", "0x7D2D3688Df45Ce7C552E19c27e007673da9204B8", 18),
    "LINK": ("0x514910771AF9Ca656af840dff83E8264EcF986CA", "0xA64BD6C70Cb9051F6A9ba1F163Fdc07E0DfB5F84", 18),
    "MANA": ("0x0F5D2fB29fb7d3CFeE444a200298f468908cC942", "0x6FCE4A401B6B80ACe52baAefE4421Bd188e76F6f", 18),
    "MKR":  ("0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2", "0x7deB5e830be29F91E298ba5FF1356BB7f8146998", 18),
    "REP":  ("0x1985365e9f78359a9B6AD760e32412f4a445E862", "0x71010A9D003445aC60C4e6A700955cA0a4682be2", 18),
    "SNX":  ("0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F", "0x328C4c80fC8D0978Ff9b82AB9CAe1b6306d1C6c6", 18),
    "WBTC": ("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", "0xFC4B8ED459e00e5400be803A9BB3954234FD50e3", 8),
    "ZRX":  ("0xE41d2489571d322189246DaFA5ebDe1F4699F498", "0x6Fb0855c404E09c47C3fBCA25f08d4E41f9F062f", 18),
}

def one(name, tok, atok, dec):
    tb = bal(tok, CORE)
    ts = u256(atok, "0x18160ddd")
    return (name, tb / 10**dec if tb is not None else None, ts / 10**dec if ts is not None else None)

out = {"block": int(rpc("eth_blockNumber", []), 16), "aave_v1": {}, "aave_eth_core": eth_bal(CORE)}
with cf.ThreadPoolExecutor(max_workers=5) as ex:
    for name, tb, ts in ex.map(lambda x: one(*x), [(k, *v) for k, v in RESERVES.items()]):
        out["aave_v1"][name] = {"core_balance": tb, "aToken_supply": ts}
print(json.dumps(out, indent=1))
json.dump(out, open("/home/heisenberg/CA/c-37/analysis/aave_v1_scan.json", "w"), indent=1)
