#!/usr/bin/env python3
"""Granary Finance live-state probe. Read-only, keyless public RPCs only.

Dumps per-chain: registry -> provider -> pool/configurator/oracle/admin roles,
reserves list, and per-reserve data (config bits, indexes, aToken/debt tokens,
cash, price). Saves analysis/state-<chain>.json and analysis/state-all.json.
"""
import json, time, urllib.request, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))

CHAINS = {
    "optimism":  {"rpc": "https://mainnet.optimism.io",              "registry": "0x872b9e8aea5d65fbf29b8b05bfa4aa3fe94cc11f"},
    "metis":     {"rpc": "https://metis-rpc.publicnode.com",         "registry": "0x37133a8dca96400c249102e59b11e25b0f663ee0"},
    "arbitrum":  {"rpc": "https://arb1.arbitrum.io/rpc",             "registry": "0x512f582ffccf3c14bd872152eeae60866dcb2a1e"},
    "fantom":    {"rpc": "https://rpcapi.fantom.network",            "registry": "0x773e0277667f0c38d3ca2cf771b416bfd065da83"},
    "avalanche": {"rpc": "https://avalanche-c-chain-rpc.publicnode.com", "registry": "0xc043ba54f34c9fb3a0b45d22e2ef1f171272bc9d"},
    "bsc":       {"rpc": "https://bsc-rpc.publicnode.com",           "registry": "0x7c8e7536c5044e1b3693eb564c6de3a3ce58bbda"},
    "ethereum":  {"rpc": "https://ethereum-rpc.publicnode.com",      "registry": "0x5c93b799d31d3d6a7c977f75fdb88d069565a55b"},
    "base":      {"rpc": "https://base-rpc.publicnode.com",          "registry": "0x5c93b799d31d3d6a7c977f75fdb88d069565a55b"},
}

SIG = {
    "providers":       "0x365ccbbf",
    "lendingPool":     "0x0261bf8b",
    "configurator":    "0x85c858b1",
    "priceOracle":     "0xfca513a8",
    "poolAdmin":       "0xaecda378",
    "emergencyAdmin":  "0xddcaa9ea",
    "owner":           "0x8da5cb5b",
    "paused":          "0x5c975abb",
    "reservesList":    "0xd1946dbc",
    "reserveData":     "0x35ea6a75",
    "totalSupply":     "0x18160ddd",
    "balanceOf":       "0x70a08231",
    "underlying":      "0xb16a19de",
    "symbol":          "0x95d89b41",
    "decimals":        "0x313ce567",
    "getAssetPrice":   "0xb3596f07",
}

_id = [0]
def _post(url, payload, timeout=30):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "granary-audit/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def rpc(url, method, params, retries=3):
    for a in range(retries):
        try:
            _id[0] += 1
            res = _post(url, {"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params})
            if "result" in res:
                return res["result"]
            if "error" in res:
                return {"__err__": res["error"]}
        except Exception as e:
            if a == retries - 1:
                return {"__err__": str(e)}
            time.sleep(0.6 * (a + 1))
    return {"__err__": "retries-exhausted"}

def batch(url, calls, chunk=8, retries=2):
    """calls: list of (method, params). Returns list of results aligned."""
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = []
        for j, (m, p) in enumerate(part):
            _id[0] += 1
            payload.append({"jsonrpc": "2.0", "id": _id[0], "method": m, "params": p})
        got = None
        for a in range(retries):
            try:
                res = _post(url, payload)
                byid = {r.get("id"): r for r in res}
                got = []
                for c in payload:
                    r = byid.get(c["id"], {})
                    got.append(r.get("result", {"__err__": r.get("error", "missing")}))
                break
            except Exception as e:
                if a == retries - 1:
                    got = [{"__err__": str(e)}] * len(part)
                else:
                    time.sleep(0.8 * (a + 1))
        out.extend(got)
        time.sleep(0.1)
    return out

def w(hexstr, idx):
    s = hexstr[2:] if hexstr.startswith("0x") else hexstr
    return int(s[idx*64:(idx+1)*64], 16) if len(s) >= (idx+1)*64 else None

def addr(word):
    return "0x" + format(word, "064x")[-40:]

def dec_addresses(hexstr):
    s = hexstr[2:] if hexstr.startswith("0x") else hexstr
    if len(s) < 128: return []
    off = int(s[0:64], 16) // 32
    n = int(s[off*64:(off+1)*64], 16)
    return [addr(int(s[(off+1+i)*64:(off+2+i)*64], 16)) for i in range(n)]

def dec_string(hexstr):
    try:
        s = hexstr[2:] if hexstr.startswith("0x") else hexstr
        off = int(s[0:64], 16) // 32
        n = int(s[off*64:(off+1)*64], 16)
        b = bytes.fromhex(s[(off+1)*64:(off+1)*64 + n*2])
        return b.decode("utf-8", "replace")
    except Exception:
        return None

def dec_config(cfg):
    return {
        "ltv": cfg & 0xFFFF,
        "liq_threshold": (cfg >> 16) & 0xFFFF,
        "liq_bonus": (cfg >> 32) & 0xFFFF,
        "decimals": (cfg >> 48) & 0xFF,
        "active": (cfg >> 56) & 1,
        "frozen": (cfg >> 57) & 1,
        "borrowing": (cfg >> 58) & 1,
        "stable_borrowing": (cfg >> 59) & 1,
        "paused": (cfg >> 60) & 1,
        "flashloan": (cfg >> 63) & 1,
        "reserve_factor": (cfg >> 64) & 0xFFFF,
    }

def probe(name, c):
    url, reg = c["rpc"], c["registry"]
    r = {"chain": name, "rpc_host": url.split("//")[1].split("/")[0], "registry": reg}
    bn = rpc(url, "eth_blockNumber", [])
    r["block"] = int(bn, 16) if isinstance(bn, str) else None
    provs = rpc(url, "eth_call", [{"to": reg, "data": SIG["providers"]}, "latest"])
    r["providers"] = dec_addresses(provs) if isinstance(provs, str) else provs
    prov = r["providers"][0] if r["providers"] else None
    r["provider"] = prov
    if prov:
        calls = [
            ("eth_call", [{"to": prov, "data": SIG["lendingPool"]}, "latest"]),
            ("eth_call", [{"to": prov, "data": SIG["configurator"]}, "latest"]),
            ("eth_call", [{"to": prov, "data": SIG["priceOracle"]}, "latest"]),
            ("eth_call", [{"to": prov, "data": SIG["poolAdmin"]}, "latest"]),
            ("eth_call", [{"to": prov, "data": SIG["emergencyAdmin"]}, "latest"]),
            ("eth_call", [{"to": prov, "data": SIG["owner"]}, "latest"]),
        ]
        res = batch(url, calls)
        keys = ["pool", "configurator", "oracle", "poolAdmin", "emergencyAdmin", "owner"]
        for k, v in zip(keys, res):
            r[k] = addr(int(v, 16)) if isinstance(v, str) and len(v) >= 42 else v
        pool = r.get("pool")
        if isinstance(pool, str) and pool.startswith("0x"):
            res = batch(url, [
                ("eth_call", [{"to": pool, "data": SIG["paused"]}, "latest"]),
                ("eth_call", [{"to": pool, "data": SIG["reservesList"]}, "latest"]),
            ])
            pv = res[0]
            r["pool_paused"] = (int(pv, 16) == 1) if isinstance(pv, str) and pv != "0x" else pv
            rl = res[1]
            r["reserves"] = dec_addresses(rl) if isinstance(rl, str) else []
            # per-reserve data
            out_res = []
            for asset in r["reserves"]:
                d = {"asset": asset}
                calls = [
                    ("eth_call", [{"to": pool, "data": SIG["reserveData"] + asset[2:].rjust(64, "0")}, "latest"]),
                ]
                rd = batch(url, calls)[0]
                if isinstance(rd, str) and len(rd) >= 2 + 12*64:
                    words = [w(rd, i) for i in range(12)]
                    d["config"] = dec_config(words[0])
                    d["liquidityIndex"] = words[1]
                    d["currentLiquidityRate"] = words[2]
                    d["variableBorrowIndex"] = words[3]
                    d["currentVariableBorrowRate"] = words[4]
                    d["currentStableBorrowRate"] = words[5]
                    d["lastUpdateTimestamp"] = words[6]
                    d["aToken"] = addr(words[7])
                    d["stableDebtToken"] = addr(words[8])
                    d["variableDebtToken"] = addr(words[9])
                    d["strategy"] = addr(words[10])
                    d["reserveId"] = words[11]
                    # token reads
                    at = d["aToken"]; sd = d["stableDebtToken"]; vd = d["variableDebtToken"]
                    calls2 = [
                        ("eth_call", [{"to": at, "data": SIG["totalSupply"]}, "latest"]),
                        ("eth_call", [{"to": asset, "data": SIG["balanceOf"] + at[2:].rjust(64, "0")}, "latest"]),
                        ("eth_call", [{"to": at, "data": SIG["underlying"]}, "latest"]),
                        ("eth_call", [{"to": sd, "data": SIG["totalSupply"]}, "latest"]),
                        ("eth_call", [{"to": vd, "data": SIG["totalSupply"]}, "latest"]),
                        ("eth_call", [{"to": asset, "data": SIG["decimals"]}, "latest"]),
                        ("eth_call", [{"to": asset, "data": SIG["symbol"]}, "latest"]),
                    ]
                    if r.get("oracle", "").startswith("0x"):
                        calls2.append(("eth_call", [{"to": r["oracle"], "data": SIG["getAssetPrice"] + asset[2:].rjust(64, "0")}, "latest"]))
                    res2 = batch(url, calls2)
                    def u(x):
                        return int(x, 16) if isinstance(x, str) and x != "0x" else None
                    d["aTokenTotalSupply"] = u(res2[0])
                    d["cash"] = u(res2[1])
                    d["aTokenUnderlying"] = addr(int(res2[2], 16)) if isinstance(res2[2], str) and len(res2[2]) >= 42 else res2[2]
                    d["stableDebtTotal"] = u(res2[3])
                    d["variableDebtTotal"] = u(res2[4])
                    d["assetDecimals"] = u(res2[5])
                    d["assetSymbol"] = dec_string(res2[6]) if isinstance(res2[6], str) else res2[6]
                    if len(res2) > 7:
                        d["oraclePrice"] = u(res2[7])
                else:
                    d["error"] = str(rd)[:200]
                out_res.append(d)
            r["reserves"] = out_res
    return r

def main():
    only = sys.argv[1:] or list(CHAINS)
    all_state = {}
    for name in only:
        c = CHAINS[name]
        print(f"== probing {name} ==", flush=True)
        try:
            st = probe(name, c)
        except Exception as e:
            st = {"chain": name, "fatal": str(e)}
        all_state[name] = st
        with open(os.path.join(HERE, f"state-{name}.json"), "w") as f:
            json.dump(st, f, indent=1)
        # compact summary
        print(f"block={st.get('block')} provider={st.get('provider')} pool={st.get('pool')} paused={st.get('pool_paused')}")
        print(f"oracle={st.get('oracle')} poolAdmin={st.get('poolAdmin')} emergencyAdmin={st.get('emergencyAdmin')} owner={st.get('owner')}")
        for d in st.get("reserves", []):
            if isinstance(d, dict) and "config" in d:
                cfg = d["config"]
                print(f"  {d.get('assetSymbol')} {d['asset'][:10]} aToken={d['aToken'][:10]} supply={d.get('aTokenTotalSupply')} cash={d.get('cash')} sDebt={d.get('stableDebtTotal')} vDebt={d.get('variableDebtTotal')} price={d.get('oraclePrice')} cfg(ltv={cfg['ltv']},lt={cfg['liq_threshold']},bonus={cfg['liq_bonus']},act={cfg['active']},frz={cfg['frozen']},bor={cfg['borrowing']},pau={cfg['paused']},rf={cfg['reserve_factor']})")
            else:
                print("  RESERVE-ERR", str(d)[:160])
    with open(os.path.join(HERE, "state-all.json"), "w") as f:
        json.dump(all_state, f, indent=1)
    print("saved state-all.json")

if __name__ == "__main__":
    main()
