#!/usr/bin/env python3
"""Independent verification (childA) of Kinetic-on-Flare claims. READ-ONLY.

Uses raw JSON-RPC + hand-rolled ABI encode/decode so every call and result is
explicit. Records the pinned block number.
"""
import json, sys, time
import requests
from web3 import Web3

RPC = "https://14.rpc.thirdweb.com"
OUT = "/home/heisenberg/CA/kinetic/analysis/childA-state.json"

C = {
    "C1": "0x15F69897E6aEBE0463401345543C26d1Fd994abB",
    "C2": "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8",
    "C3": "0xDcce91d46Ecb209645A26B5885500127819BeAdd",
    "C4": "0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f",
}
VERIFIER_ARG = "0x00000000000000000000000000000000DeaDBeef"
FTSoV2_CLAIM = "0x7BDE3Df0624114eDB3A67dFe6753e62f4e7c1d20"
FEEDS = {
    "FLR/USD": "0x01464c522f55534400000000000000000000000000",
    "USDT/USD": "0x01555344542f555344000000000000000000000000",
    "ETH/USD": "0x014554482f55534400000000000000000000000000",
}
SNATIVE = "0x7e0182d284c39a0b4db0e870c59dcf5cdb6f65cc"
SETH = "0x1347192f6ce9ee6c6ff4ac899ef5ca7379892d94"

def sel(sig):
    return "0x" + Web3.keccak(text=sig)[:4].hex().replace("0x", "")

def e_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def e_uint(i):
    return hex(i)[2:].rjust(64, "0")

def e_bytes_left(h):
    return h.lower().replace("0x", "").ljust(64, "0")

def e_call(to, sig, args=b""):
    return {"to": to, "data": sel(sig) + args}

class RPCClient:
    def __init__(self, url):
        self.url = url
        self.id = 0
        self.s = requests.Session()
        self.s.headers["Content-Type"] = "application/json"

    def batch(self, calls, block):
        """calls: list of (to,data). returns list of string results ('0x' on revert)."""
        out = []
        for i in range(0, len(calls), 10):
            chunk = calls[i:i+10]
            payload = []
            for to, data in chunk:
                self.id += 1
                payload.append({"jsonrpc": "2.0", "id": self.id, "method": "eth_call",
                                "params": [{"to": to, "data": data}, block]})
            for attempt in range(4):
                try:
                    r = self.s.post(self.url, json=payload, timeout=40)
                    r.raise_for_status()
                    j = r.json()
                    by_id = {x["id"]: x for x in j}
                    for p in payload:
                        x = by_id.get(p["id"], {})
                        out.append(x.get("result", "0x"))
                    break
                except Exception as ex:
                    if attempt == 3:
                        print("BATCH FAIL", ex, file=sys.stderr)
                        out.extend(["0x"] * len(chunk))
                    else:
                        time.sleep(1.5 * (attempt + 1))
        return out

    def single(self, to, data, block):
        self.id += 1
        p = {"jsonrpc": "2.0", "id": self.id, "method": "eth_call",
             "params": [{"to": to, "data": data}, block]}
        for attempt in range(3):
            try:
                r = self.s.post(self.url, json=p, timeout=30).json()
                return r.get("result", "0x")
            except Exception:
                time.sleep(1)
        return "0x"

    def rpc(self, method, params):
        self.id += 1
        p = {"jsonrpc": "2.0", "id": self.id, "method": method, "params": params}
        return self.s.post(self.url, json=p, timeout=30).json().get("result")


def words(h):
    h = h[2:]
    return [h[i:i+64] for i in range(0, len(h), 64)]

def d_uint(res, i=0):
    ws = words(res)
    if len(ws) <= i: return None
    return int(ws[i], 16)

def d_int8(res, i=1):
    v = d_uint(res, i)
    if v is None: return None
    return v - 256 if v >= 128 else v

def d_bool(res, i=0):
    v = d_uint(res, i)
    return None if v is None else (v != 0)

def d_addr(res, i=0):
    ws = words(res)
    if len(ws) <= i: return None
    return "0x" + ws[i][24:]

def d_bytes21(res, i=1):
    ws = words(res)
    if len(ws) <= i: return None
    return "0x" + ws[i][:42]

def d_addr_array(res):
    h = res[2:]
    if not h: return None
    off = int(h[:64], 16)          # byte offset to array
    p = off * 2                    # hex chars
    n = int(h[p:p+64], 16)
    items = []
    for k in range(n):
        w = h[p + 64 + k*64: p + 128 + k*64]
        if len(w) < 64: break
        items.append("0x" + w[24:])
    return items

def d_string(res):
    h = res[2:]
    if not h: return None
    off = int(h[:64], 16)
    p = off * 2
    ln = int(h[p:p+64], 16)
    return bytes.fromhex(h[p+64:p+64+ln*2]).decode("utf-8", "replace")

def ok(res):
    return res not in (None, "0x", "")

def main():
    cli = RPCClient(RPC)
    start_block = int(cli.rpc("eth_blockNumber", []), 16)
    blkhex = hex(start_block)
    blkh = cli.rpc("eth_getBlockByNumber", [blkhex, False])
    block_ts = int(blkh["timestamp"], 16)
    print(f"# RPC {RPC}")
    print(f"# pinned block {start_block} ts {block_ts} ({time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime(block_ts))})")

    R = {"rpc": RPC, "block": start_block, "block_timestamp": block_ts, "comptrollers": {}}

    # ---------- 1. enumerate markets ----------
    calls = []
    for k, a in C.items():
        calls.append((a, sel("getAllMarkets()")))
        calls.append((a, sel("oracle()")))
        calls.append((a, sel("comptrollerImplementation()")))
        calls.append((a, sel("admin()")))
        calls.append((a, sel("liquidatorsWhitelistVerifier()")))
        calls.append((a, sel("_mintGuardianPaused()")))
        calls.append((a, sel("_borrowGuardianPaused()")))
    res = cli.batch(calls, blkhex)
    idx = 0
    for k, a in C.items():
        mk = d_addr_array(res[idx]); idx += 1
        oracle = d_addr(res[idx]); idx += 1
        impl = d_addr(res[idx]); idx += 1
        admin = d_addr(res[idx]); idx += 1
        lwv = d_addr(res[idx]); idx += 1
        gm = d_bool(res[idx]); idx += 1
        gb = d_bool(res[idx]); idx += 1
        R["comptrollers"][k] = {
            "address": a, "markets": mk, "oracle": oracle,
            "impl": impl, "admin": admin,
            "liquidatorsWhitelistVerifier_raw": res[idx-5] if False else None,
            "liquidatorsWhitelistVerifier": lwv,
            "global_mintGuardianPaused": gm,
            "global_borrowGuardianPaused": gb,
        }
        print(f"{k} {a}: {len(mk) if mk else mk} markets oracle={oracle} impl={impl} lwv={lwv}")

    # save raw results for the comptroller-level calls (for audit)
    R["comptroller_raw"] = {}
    idx = 0
    for k, a in C.items():
        R["comptroller_raw"][k] = {
            "getAllMarkets": res[idx], "oracle": res[idx+1],
            "comptrollerImplementation": res[idx+2], "admin": res[idx+3],
            "liquidatorsWhitelistVerifier": res[idx+4],
            "_mintGuardianPaused": res[idx+5], "_borrowGuardianPaused": res[idx+6],
        }
        idx += 7

    # ---------- 2. per-market state ----------
    market_info = {}
    for k, a in C.items():
        for m in (R["comptrollers"][k]["markets"] or []):
            market_info.setdefault(m.lower(), {"comptrollers": []})["comptrollers"].append(k)

    calls = []
    for m in market_info:
        calls.append((m, sel("symbol()")))
        calls.append((m, sel("underlying()")))
        calls.append((m, sel("totalSupply()")))
        calls.append((m, sel("getCash()")))
        calls.append((m, sel("totalBorrows()")))
        calls.append((m, sel("totalReserves()")))
        calls.append((m, sel("exchangeRateStored()")))
        calls.append((m, sel("comptroller()")))
        calls.append((m, sel("decimals()")))
    res = cli.batch(calls, blkhex)
    per = len(res) // len(market_info)
    for i, m in enumerate(market_info):
        base = i * per
        info = market_info[m]
        info["symbol"] = d_string(res[base+0])
        info["underlying"] = d_addr(res[base+1]) if ok(res[base+1]) else None
        info["totalSupply"] = d_uint(res[base+2])
        info["getCash"] = d_uint(res[base+3])
        info["totalBorrows"] = d_uint(res[base+4])
        info["totalReserves"] = d_uint(res[base+5])
        info["exchangeRateStored"] = d_uint(res[base+6])
        info["comptroller_of_market"] = d_addr(res[base+7])
        info["decimals"] = d_uint(res[base+8])
        info["_raw"] = {
            "symbol": res[base+0], "underlying": res[base+1],
            "totalSupply": res[base+2], "getCash": res[base+3],
            "exchangeRateStored": res[base+6], "comptroller": res[base+7],
        }
    R["markets"] = market_info

    # ---------- 3. comptroller-level per-market flags ----------
    flags = {}
    calls = []
    keymap = []
    for k, a in C.items():
        for m in (R["comptrollers"][k]["markets"] or []):
            keymap.append((k, m))
            calls.append((a, sel("markets(address)") + e_addr(m)))
            calls.append((a, sel("mintGuardianPaused(address)") + e_addr(m)))
            calls.append((a, sel("borrowGuardianPaused(address)") + e_addr(m)))
            calls.append((a, sel("borrowCaps(address)") + e_addr(m)))
            calls.append((a, sel("supplyCaps(address)") + e_addr(m)))
    res = cli.batch(calls, blkhex)
    per = len(res) // len(keymap)
    for i, (k, m) in enumerate(keymap):
        base = i * per
        raw_markets = res[base+0]
        f = {
            "markets_raw": raw_markets,
            "markets_words": len(words(raw_markets)) if raw_markets not in (None, "0x") else 0,
            "isListed": d_bool(raw_markets, 0),
            "collateralFactorMantissa": d_uint(raw_markets, 1),
            "mintGuardianPaused": d_bool(res[base+1]),
            "borrowGuardianPaused": d_bool(res[base+2]),
            "borrowCaps": d_uint(res[base+3]),
            "supplyCaps": d_uint(res[base+4]) if res[base+4] not in (None, "0x") else None,
        }
        flags[(k, m.lower())] = f
    R["flags"] = {f"{k}|{m.lower()}": v for (k, m), v in flags.items()}

    # ---------- 4. permissions ----------
    perms = {}
    for k, a in C.items():
        perms[a.lower()] = {
            "liquidatorsWhitelistVerifier": R["comptrollers"][k]["liquidatorsWhitelistVerifier"],
        }
    R["permissions"] = perms

    # C1/C2/C3 verifier allowed() checks
    verif_out = {}
    vs = set()
    for k in ("C1", "C2", "C3"):
        v = R["comptrollers"][k]["liquidatorsWhitelistVerifier"]
        if v and v != "0x" + "0"*40:
            vs.add(v.lower())
    calls = []
    vkeys = []
    for v in sorted(vs):
        vkeys.append((v, VERIFIER_ARG))
        calls.append((v, sel("allowed(address)") + e_addr(VERIFIER_ARG)))
        vkeys.append((v, "0x" + "0"*40))
        calls.append((v, sel("allowed(address)") + e_addr("0x" + "0"*40)))
    res = cli.batch(calls, blkhex)
    for i, (v, arg) in enumerate(vkeys):
        verif_out[f"{v}|{arg}"] = d_bool(res[i])
        if res[i] in (None, "0x", ""):
            verif_out[f"{v}|{arg}_raw"] = res[i]
    R["verifier_allowed"] = verif_out

    # C4 alternative gate functions
    c4 = C["C4"].lower()
    c4_gate = {}
    tests = [
        ("liquidatorsWhitelistVerifier()", sel("liquidatorsWhitelistVerifier()")),
        ("liquidatorWhiteList(address)", sel("liquidatorWhiteList(address)") + e_addr(VERIFIER_ARG)),
        ("isInLiquidateWhiteList(address)", sel("isInLiquidateWhiteList(address)") + e_addr(VERIFIER_ARG)),
    ]
    for name, data in tests:
        r1 = cli.single(C["C4"], data, blkhex)
        c4_gate[name] = {"raw": r1, "exists": ok(r1),
                         "value": d_bool(r1) if ok(r1) and len(r1) == 66 else (d_addr(r1) if ok(r1) else None)}
    R["c4_gate"] = c4_gate

    # ---------- 5. oracle: assetPrices / tokenConfigs / getUnderlyingPrice ----------
    oracle_calls = []
    okeys = []
    for k in ("C1", "C2", "C3", "C4"):
        oc = R["comptrollers"][k]["oracle"]
        for m in (R["comptrollers"][k]["markets"] or []):
            u = market_info[m.lower()].get("underlying")
            # getUnderlyingPrice for every market on its comptroller oracle
            okeys.append(("up", k, m, oc))
            oracle_calls.append((oc, sel("getUnderlyingPrice(address)") + e_addr(m)))
            if u:
                okeys.append(("ap", k, m, oc))
                oracle_calls.append((oc, sel("assetPrices(address)") + e_addr(u)))
                okeys.append(("tc", k, m, oc))
                oracle_calls.append((oc, sel("tokenConfigs(address)") + e_addr(u)))
            if u is None:
                # native market: zero-address token config
                okeys.append(("ap0", k, m, oc))
                oracle_calls.append((oc, sel("assetPrices(address)") + e_addr("0x" + "0"*40)))
                okeys.append(("tc0", k, m, oc))
                oracle_calls.append((oc, sel("tokenConfigs(address)") + e_addr("0x" + "0"*40)))
    res = cli.batch(oracle_calls, blkhex)
    orc = R.setdefault("oracle", {})
    for i, (kind, k, m, oc) in enumerate(okeys):
        r = res[i]
        key = f"{k}|{m.lower()}"
        d = orc.setdefault(key, {"oracle": oc})
        if kind == "up":
            d["getUnderlyingPrice"] = d_uint(r) if ok(r) else None
            d["getUnderlyingPrice_raw"] = r
        elif kind == "ap":
            d["assetPrices"] = d_uint(r) if ok(r) else None
            d["assetPrices_raw"] = r
        elif kind == "ap0":
            d["assetPrices_native"] = d_uint(r) if ok(r) else None
        elif kind == "tc":
            if ok(r) and len(words(r)) >= 4:
                d["tokenConfigs"] = {
                    "asset": d_addr(r, 0), "ftsoV2FeedId": d_bytes21(r, 1),
                    "maxStalePeriod": d_uint(r, 2), "exchangeAsset": d_addr(r, 3),
                }
            else:
                d["tokenConfigs"] = None
            d["tokenConfigs_raw"] = r
        elif kind == "tc0":
            if ok(r) and len(words(r)) >= 4:
                d["tokenConfigs_native"] = {
                    "asset": d_addr(r, 0), "ftsoV2FeedId": d_bytes21(r, 1),
                    "maxStalePeriod": d_uint(r, 2), "exchangeAsset": d_addr(r, 3),
                }
            d["tokenConfigs_native_raw"] = r

    # oracle ftsoV2() address per oracle
    ocs = sorted({R["comptrollers"][k]["oracle"].lower() for k in C if R["comptrollers"][k]["oracle"]})
    calls = [(oc, sel("ftsoV2()")) for oc in ocs]
    res = cli.batch(calls, blkhex)
    R["oracle_ftsoV2"] = {oc: (d_addr(res[i]) if ok(res[i]) else None) for i, oc in enumerate(ocs)}
    R["oracle_ftsoV2_raw"] = {oc: res[i] for i, oc in enumerate(ocs)}

    # ---------- 6. FTSO feeds ----------
    ftso_targets = {FTSoV2_CLAIM.lower()}
    for oc, f in R["oracle_ftsoV2"].items():
        if f: ftso_targets.add(f.lower())
    feed_calls = []
    fkeys = []
    for ft in sorted(ftso_targets):
        for name, fid in FEEDS.items():
            fkeys.append((ft, name, fid))
            feed_calls.append((ft, sel("getFeedById(bytes21)") + e_bytes_left(fid)))
        # also every feed used in tokenConfigs
        for key, d in orc.items():
            tc = d.get("tokenConfigs")
            if tc and tc.get("ftsoV2FeedId"):
                fkeys.append((ft, "cfg:" + key, tc["ftsoV2FeedId"]))
                feed_calls.append((ft, sel("getFeedById(bytes21)") + e_bytes_left(tc["ftsoV2FeedId"])))
            tcn = d.get("tokenConfigs_native")
            if tcn and tcn.get("ftsoV2FeedId"):
                fkeys.append((ft, "cfgn:" + key, tcn["ftsoV2FeedId"]))
                feed_calls.append((ft, sel("getFeedById(bytes21)") + e_bytes_left(tcn["ftsoV2FeedId"])))
    res = cli.batch(feed_calls, blkhex)
    feeds = {}
    for i, (ft, name, fid) in enumerate(fkeys):
        r = res[i]
        feeds[f"{ft}|{name}|{fid}"] = {
            "value": d_uint(r, 0) if ok(r) else None,
            "decimals": d_int8(r, 1) if ok(r) else None,
            "timestamp": d_uint(r, 2) if ok(r) else None,
            "age_s": (block_ts - d_uint(r, 2)) if ok(r) and d_uint(r, 2) else None,
            "raw": r,
        }
    R["ftso_feeds"] = feeds

    # ---------- 7. exchange assets ----------
    ex_calls = []
    ex_keys = []
    for name, a in [("sNative", SNATIVE), ("sETH", SETH)]:
        ex_keys.append((name, "getExchangeRate")); ex_calls.append((a, sel("getExchangeRate()")))
        ex_keys.append((name, "decimals")); ex_calls.append((a, sel("decimals()")))
        ex_keys.append((name, "symbol")); ex_calls.append((a, sel("symbol()")))
    res = cli.batch(ex_calls, blkhex)
    R["exchange_assets"] = {}
    for i, (name, fn) in enumerate(ex_keys):
        d = R["exchange_assets"].setdefault(name, {"address": SNATIVE if name == "sNative" else SETH})
        if fn == "symbol":
            d[fn] = d_string(res[i])
        elif fn == "decimals":
            d[fn] = d_uint(res[i])
        else:
            d[fn] = d_uint(res[i])
        d[fn + "_raw"] = res[i]

    end_block = int(cli.rpc("eth_blockNumber", []), 16)
    R["end_block"] = end_block
    print(f"# end block {end_block}")

    with open(OUT, "w") as f:
        json.dump(R, f, indent=1, sort_keys=True)
    print(f"# wrote {OUT}")

if __name__ == "__main__":
    main()
