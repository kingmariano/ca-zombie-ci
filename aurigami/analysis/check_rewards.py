#!/usr/bin/env python3
"""Check reward speeds, reward token balances and claimer whitelist for Aurigami."""
import json
import urllib.request

RPC = "https://mainnet.aurora.dev"
UNIT = "0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb"
PLY = "0x09C9D464b58d96837f8d8b6f4d9fE4aD408d3A4f"
AURORA = "0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79"
PULP = "0x04Ac48711BCdc45b4d223fb021E09DA73c71095e"
MARKETS = {
    "auUSDC": "0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
    "auETH": "0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
    "auWBTC": "0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
    "auUSDT": "0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
    "auDAI": "0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
    "auWNEAR": "0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
    "auSTNEAR": "0x3195949f267702723bc614cAE037cdc8D1E94786",
    "auAURORA": "0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf",
    "auTRI": "0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca",
    "auPLY": "0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c",
    "auUSN": "0x5cCAD065400341db391FD3a4B7F50087B678D7CC",
    "auNEARX": "0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
    "auUSDCNative": "0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
    "auUSDTNative": "0xdDfd0407220026c6566979B5be6A4983d1247a3E",
}


def sig(typesig):
    # keccak via cast is not available in python; hardcode known selectors
    return None


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc_u8(v):
    return "%064x" % v


def rpc_calls(calls):
    payload = json.dumps([{"jsonrpc": "2.0", "id": i, "method": "eth_call", "params": [{"to": t, "data": d}, "latest"]}
                          for i, (t, d) in enumerate(calls)]).encode()
    req = urllib.request.Request(RPC, data=payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    out = json.load(urllib.request.urlopen(req, timeout=60))
    res = {}
    for item in out:
        res[item["id"]] = item.get("result") if "error" not in item else {"err": item["error"].get("message")}
    return [res[i] for i in range(len(calls))]


def main():
    # selectors
    SEL_REWARD_SPEEDS = "0x"  # compute below via known: rewardSpeeds(uint8,address,bool)
    import subprocess
    def sel(s):
        return subprocess.run(["cast", "sig", s], capture_output=True, text=True).stdout.strip()
    s_speeds = sel("rewardSpeeds(uint8,address,bool)")
    s_bal = "0x70a08231"
    print("selector rewardSpeeds:", s_speeds)
    calls, meta = [], []
    for rt in (0, 1):
        for name, m in MARKETS.items():
            for is_supply in (True, False):
                calls.append((UNIT, s_speeds + enc_u8(rt) + enc_addr(m) + enc_u8(1 if is_supply else 0)))
                meta.append((rt, name, is_supply))
    for tok, label in [(PLY, "PLY"), (AURORA, "AURORA")]:
        for who, who_l in [(UNIT, "unitroller"), (PULP, "pulp")]:
            calls.append((tok, s_bal + enc_addr(who)))
            meta.append((label, who_l))
    res = rpc_calls(calls)
    nz = []
    for (meta_i, r) in zip(meta, res):
        if isinstance(r, str) and len(r) >= 66 and int(r[2:66], 16) != 0:
            nz.append((meta_i, int(r[2:66], 16)))
    print("nonzero entries:")
    for m, v in nz:
        print("  ", m, v)
    print("balances:")
    for (meta_i, r) in zip(meta, res):
        if isinstance(meta_i, tuple) and 0 in (0,) and False:
            pass
    for i, (m, r) in enumerate(zip(meta, res)):
        if isinstance(m, tuple) and isinstance(m[0], str):
            print("  ", m, r)
    # whitelist check: isWhitelisted(address)
    s_wl = sel("isWhitelisted(address)")
    for a in ["0x1111111111111111111111111111111111111111", "0x2D05FfFE70CE64c5954710D4C308dB31C8dBd8dE"]:
        r = rpc_calls([(UNIT, s_wl + enc_addr(a))])[0]
        print("isWhitelisted", a, r)


if __name__ == "__main__":
    main()
