#!/usr/bin/env python3
"""Iron Finance live-state dumper for CI.
Usage: POLYGON_RPC_URL=... FANTOM_RPC_URL=... python3 ci/dump_state.py
Writes ci-out/state.json (addresses/numbers only - no secrets)."""
import json, os, time, urllib.request

def rpc(url, method, params):
    req = urllib.request.Request(url, data=json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research; read-only)"})
    return json.load(urllib.request.urlopen(req, timeout=60))["result"]

def call(url, to, data, block="latest"):
    return rpc(url, "eth_call", [{"to": to, "data": data}, block])

def u256(url, to, sel, block="latest"):
    try:
        return int(call(url, to, sel, block), 16)
    except Exception:
        return None

def addr(url, to, sel, block="latest"):
    try:
        r = call(url, to, sel, block)
        return "0x" + r[-40:]
    except Exception:
        return None

def enc_bal(who):
    return "0x70a08231" + "0" * 24 + who[2:].lower()

def decode_uint_array(hexstr):
    b = bytes.fromhex(hexstr[2:])
    n = int.from_bytes(b[32:64], "big")
    return [int.from_bytes(b[64 + 32 * i: 96 + 32 * i], "big") for i in range(n)]

def main():
    def pick(file, envname, fallback):
        try:
            v = open(file).read().strip()
        except Exception:
            v = ""
        if not v or v == "ENV":
            return os.environ.get(envname) or fallback
        return v

    poly = pick("poc/rpc-polygon.txt", "POLYGON_RPC_URL", "https://polygon-bor-rpc.publicnode.com")
    fant = pick("poc/rpc-fantom.txt", "FANTOM_RPC_URL", "https://rpcapi.fantom.network")
    avax = os.environ.get("AVAX_RPC_URL") or "https://avalanche-c-chain-rpc.publicnode.com"

    S_PAUSED = "0x5c975abb"; S_OWNER = "0x8da5cb5b"; S_VP = "0xe25aa5fa"
    S_SUPPLY = "0x18160ddd"; S_LP = "0x8214f5a4"; S_TB = "0xa1dc9031"
    S_AB = "0x18f52ce2"; S_CASH = "0x3b1d21a2"; S_BORR = "0x47bd3718"

    out = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

    # -------- Polygon --------
    P = "0x837503e8A8753ae17fB8C8151B8e6f586defCb57"
    LP = "0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17"
    USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    USDT = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"
    DAI = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063"
    CHEF = "0x1fD1259Fa8CdC60c6E8C86cfA592CA1b8403DFaD"
    meta = {"ispusd": "0x4A783cD1b4543559eCe45dB47e07E0Cb59e55c09",
            "isxusd": "0xe440CCc13e6f273c110Cf3cF4087C23a66B8e872",
            "isiron": "0xCaEb732167aF742032D13A9e76881026f91Cd087"}
    holders = {"ironchef": CHEF,
               "ercfund2": "0x43c085b5aba4e83a7dd1a478b7458d1d472ff6b4",
               "beefy_strategy": "0x6195187d06948fb14b20fd3c639f8cb8a335c29c",
               "gnosis_safe": "0xeae55893cc8637c16cf93d43b38aa022d689fa62",
               "fee_controller": "0x66c8096Fa2F5fD21062a27C202a330e64E0ae2fc",
               "isxusd_pool": meta["isxusd"], "isiron_pool": meta["isiron"], "ispusd_pool": meta["ispusd"]}

    out["polygon"] = {
        "block": rpc(poly, "eth_blockNumber", []),
        "is3usd": {
            "pool": P, "paused": call(poly, P, S_PAUSED).endswith("1"),
            "owner": addr(poly, P, S_OWNER),
            "lp_token": addr(poly, P, S_LP),
            "lp_supply": u256(poly, LP, S_SUPPLY),
            "virtual_price": u256(poly, P, S_VP),
            "tracked_balances": decode_uint_array(call(poly, P, S_TB)),
            "admin_balances": decode_uint_array(call(poly, P, S_AB)),
            "actual_balances": {"usdc_e": u256(poly, USDC, enc_bal(P)),
                                "usdt": u256(poly, USDT, enc_bal(P)),
                                "dai": u256(poly, DAI, enc_bal(P))},
        },
        "is3usd_lp_holders": {k: u256(poly, LP, enc_bal(v)) for k, v in holders.items()},
        "meta_pools": {},
        "lending_cash": {},
    }
    for name, mp in meta.items():
        try:
            lp2 = addr(poly, mp, S_LP)
            out["polygon"]["meta_pools"][name] = {
                "pool": mp, "tracked": decode_uint_array(call(poly, mp, S_TB)),
                "admin": decode_uint_array(call(poly, mp, S_AB)),
                "lp_token": lp2, "lp_supply": u256(poly, lp2, S_SUPPLY),
                "virtual_price": u256(poly, mp, S_VP),
                "paused": call(poly, mp, S_PAUSED).endswith("1"),
                "owner": addr(poly, mp, S_OWNER)}
        except Exception as e:
            out["polygon"]["meta_pools"][name] = {"error": str(e)[:80]}
    mkts = ["0x186C4137136970739b472A8192D3D2AFc5543B61", "0xbEbAD52f3A50806b25911051BabDe6615C8e21ef",
            "0xCa0F37f73174a28a64552D426590d3eD601ecCa1", "0xEe1eb5fEBeF78A1eb1a23E79930D9c587F954E05",
            "0xad6AD29d6b8B74b4302dD829c945ca3274035c16", "0xf535B089453dfd8AE698aF6d7d5Bc9f804781b81",
            "0x09cA5d827712dD7b2570FD534305B663Ae788C17", "0x32dbCdaFA80f58FfE45C825cf1Bd04f5260FC596"]
    out["polygon"]["lending_cash"] = {m: u256(poly, m, S_CASH) for m in mkts}

    # -------- Fantom --------
    FP = "0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523"
    FLP = "0xc143a1500ca4a471eE9cc70B9AC0C739576F84bb"
    try:
        out["fantom"] = {"block": rpc(fant, "eth_blockNumber", []),
                         "pool": FP,
                         "tracked": decode_uint_array(call(fant, FP, S_TB)),
                         "admin": decode_uint_array(call(fant, FP, S_AB)),
                         "lp_supply": u256(fant, FLP, S_SUPPLY),
                         "paused": call(fant, FP, S_PAUSED).endswith("1"),
                         "lending_cash": {m: u256(fant, m, S_CASH) for m in
                            ["0xf20E5dD9bb5bA61a30Eb7E0F4568d52cCfa21412", "0xdfce3E14a8c77D32fe2455a9E56424F149E2F271",
                             "0xa52022FDda46CDD4e6305adf1842726D6983aEe7", "0xCa5427DB7aD27acbCF53F3CFA94714ef86111CA4",
                             "0xA06a706b2AD8FAABE5cB1CE01E0C705c24C4E71e"]}}
    except Exception as e:
        out["fantom"] = {"error": str(e)[:120]}

    # -------- Avalanche --------
    AP = "0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523"
    try:
        out["avalanche"] = {"block": rpc(avax, "eth_blockNumber", []), "pool": AP,
                            "tracked": decode_uint_array(call(avax, AP, S_TB)),
                            "admin": decode_uint_array(call(avax, AP, S_AB)),
                            "paused": call(avax, AP, S_PAUSED).endswith("1")}
    except Exception as e:
        out["avalanche"] = {"error": str(e)[:120]}

    os.makedirs("ci-out", exist_ok=True)
    with open("ci-out/state.json", "w") as f:
        json.dump(out, f, indent=1)
    print("wrote ci-out/state.json")

if __name__ == "__main__":
    main()
