#!/usr/bin/env python3
"""
C-32 Moonwell oracle/parameter scanner (dependency-free).

Reads, per chain:
  comptroller -> markets -> {oracle price, feed, override, CF, caps, pauses, cash, borrows}
and compares each oracle price against external reference prices (DefiLlama + GeckoTerminal).

Outputs one JSON file per chain into $OUTDIR (default ./out).
Usage: python3 scan.py [chain ...]
"""
import json, os, sys, time, urllib.request, urllib.parse, urllib.error

OUTDIR = os.environ.get("SCAN_OUTDIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"))
os.makedirs(OUTDIR, exist_ok=True)

SEL = {
 "getAllMarkets()": "0xb0772d0b",
 "oracle()": "0x7dc0d1d0",
 "closeFactorMantissa()": "0xe8755446",
 "liquidationIncentiveMantissa()": "0x4ada90af",
 "markets(address)": "0x8e8f294b",
 "borrowCaps(address)": "0x4a584432",
 "supplyCaps(address)": "0x02c3bcbb",
 "mintGuardianPaused(address)": "0x731f0c2b",
 "borrowGuardianPaused(address)": "0x6d154ea5",
 "transferGuardianPaused(address)": "0xa3690086",
 "seizeGuardianPaused(address)": "0x934356cc",
 "pauseGuardian()": "0x24a3d622",
 "admin()": "0xf851a440",
 "symbol()": "0x95d89b41",
 "underlying()": "0x6f307dc3",
 "decimals()": "0x313ce567",
 "totalSupply()": "0x18160ddd",
 "totalBorrows()": "0x47bd3718",
 "totalReserves()": "0x8f840ddd",
 "getCash()": "0x3b1d21a2",
 "exchangeRateStored()": "0x182df0f5",
 "reserveFactorMantissa()": "0x173b9904",
 "getUnderlyingPrice(address)": "0xfc57d4df",
 "assetPrices(address)": "0x5e9a523c",
 "getFeed(string)": "0x3b39a51c",
 "latestRoundData()": "0xfeaf968c",
 "description()": "0x7284e416",
 "balanceOf(address)": "0x70a08231",
 "borrowIndex()": "0xaa5af0fd",
 "accrualBlockNumber()": "0x6c540baf",
 "isListed(address)": "0xf794062e",
 "liquidationBlocked(address)": "0xa9cd720d",
}

CHAINS = {
  "base": {
    "chainId": 8453,
    "rpc_env": "BASE_RPC_URL",
    "rpc_fallback": "https://base-rpc.publicnode.com",
    "llama": "base",
    "comptroller": "0xfBb21d0380beE3312B33c4353c8936a0F13EF26C",
    "oracle": "0xEC942bE8A8114bFD0396A5052c36027f2cA6a9d0",
  },
  "optimism": {
    "chainId": 10,
    "rpc_env": "OP_RPC_URL",
    "rpc_fallback": "https://optimism-rpc.publicnode.com",
    "llama": "optimism",
    "comptroller": "0xCa889f40aae37FFf165BccF69aeF1E82b5C511B9",
    "oracle": "0x2f1490bD6aD10C9CE42a2829afa13EAc0b746dcf",
  },
  "moonbeam": {
    "chainId": 1284,
    "rpc_env": "MOONBEAM_RPC_URL",
    "rpc_fallback": "https://moonbeam.api.onfinality.io/public",
    "llama": "moonbeam",
    "comptroller": "0x8E00D5e02E65A19337Cdba98bbA9F84d4186a180",
    "oracle": "0xED301cd3EB27217BDB05C4E9B820a8A3c8B665f9",
  },
  "moonriver": {
    "chainId": 1285,
    "rpc_env": "MOONRIVER_RPC_URL",
    "rpc_fallback": "https://moonriver.api.onfinality.io/public",
    "llama": "moonriver",
    "comptroller": "0x0b7a0EAA884849c6Af7a129e899536dDDcA4905E",
    "oracle": "0x892bE716Dcf0A6199677F355f45ba8CC123BAF60",
  },
  "ethereum": {
    "chainId": 1,
    "rpc_env": "RPC_URL",
    "rpc_fallback": "https://ethereum-rpc.publicnode.com",
    "llama": "ethereum",
    "comptroller": "0xdec80bB934397575594E91970b37baf65f5b21bE",
    "oracle": "0x599A01297fc181558BdFa1737caFeE513694B654",
  },
}

ZERO = "0x" + "0" * 40


class Rpc:
    def __init__(self, url, name):
        self.url = url
        self.name = name
        self.id = 0

    def call(self, calls):
        """calls: list of (to, data). Returns list of raw result hex or None."""
        payload = []
        for to, data in calls:
            self.id += 1
            payload.append({"jsonrpc": "2.0", "id": self.id, "method": "eth_call",
                            "params": [{"to": to, "data": data}, "latest"]})
        out = None
        for attempt in range(4):
            try:
                req = urllib.request.Request(self.url, data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 c32-scan"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    out = json.loads(r.read().decode())
                break
            except Exception as e:
                if attempt == 3:
                    raise RuntimeError(f"{self.name}: batched call failed: {e}")
                time.sleep(1.5 * (attempt + 1))
        res = {x["id"]: x.get("result") for x in out}
        ordered = []
        for i in range(len(payload)):
            ordered.append(res.get(payload[i]["id"]))
        return ordered


def enc_address(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc_uint(v):
    return hex(v)[2:].rjust(64, "0")


def enc_string(s):
    b = s.encode()
    ln = len(b)
    padded = b.hex().ljust(((ln + 31) // 32) * 64, "0")
    return "0000000000000000000000000000000000000000000000000000000000000020" + \
           enc_uint(ln) + padded


def dec_uint(hexstr):
    if hexstr is None or hexstr == "0x":
        return None
    return int(hexstr, 16)


def dec_int(hexstr):
    v = dec_uint(hexstr)
    if v is None:
        return None
    if v >= 2 ** 255:
        v -= 2 ** 256
    return v


def dec_address(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    return "0x" + hexstr[-40:]


def dec_bool(hexstr):
    v = dec_uint(hexstr)
    return bool(v)


def dec_string(hexstr):
    if not hexstr or len(hexstr) < 130:
        return None
    raw = bytes.fromhex(hexstr[2:])
    try:
        ln = int.from_bytes(raw[32:64], "big")
        return raw[64:64 + ln].decode(errors="replace")
    except Exception:
        return None


def dec_words(hexstr, n):
    if not hexstr or hexstr == "0x":
        return [None] * n
    raw = hexstr[2:]
    return [raw[i * 64:(i + 1) * 64] for i in range(n)]


def http_json(url, timeout=40):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 c32-scan"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def scan_chain(name):
    cfg = CHAINS[name]
    rpc_url = os.environ.get(cfg["rpc_env"]) or cfg["rpc_fallback"]
    rpc = Rpc(rpc_url, name)
    comp = cfg["comptroller"]
    result = {"chain": name, "chain_id": cfg["chainId"], "rpc": rpc_url,
              "comptroller": comp, "scanned_at": int(time.time()), "markets": []}

    markets_hex = rpc.call([(comp, SEL["getAllMarkets()"])])[0]
    if not markets_hex or markets_hex == "0x":
        raise RuntimeError(f"{name}: getAllMarkets failed")
    words = dec_words(markets_hex, (len(markets_hex) - 2) // 64)
    n = int(words[1], 16) if len(words) > 1 else 0
    markets = []
    for i in range(n):
        off = 2 + i
        if off < len(words):
            markets.append(dec_address(words[off]))
    result["markets_count"] = len(markets)

    # global reads
    g = rpc.call([
        (comp, SEL["oracle()"]),
        (comp, SEL["closeFactorMantissa()"]),
        (comp, SEL["liquidationIncentiveMantissa()"]),
        (comp, SEL["pauseGuardian()"]),
        (comp, SEL["admin()"]),
    ])
    result["oracle"] = dec_address(g[0])
    result["close_factor"] = dec_uint(g[1]) / 1e18 if g[1] else None
    result["liq_incentive"] = dec_uint(g[2]) / 1e18 if g[2] else None
    result["pause_guardian"] = dec_address(g[3])
    result["admin"] = dec_address(g[4])
    result["oracle_matches_docs"] = (result["oracle"] or "").lower() == cfg["oracle"].lower()
    oracle = result["oracle"] or cfg["oracle"]

    # per-market call plan
    plan = []
    for m in markets:
        plan += [
            (m, SEL["symbol()"]),
            (m, SEL["underlying()"]),
            (comp, SEL["markets(address)"] + enc_address(m)),
            (comp, SEL["borrowCaps(address)"] + enc_address(m)),
            (comp, SEL["supplyCaps(address)"] + enc_address(m)),
            (comp, SEL["mintGuardianPaused(address)"] + enc_address(m)),
            (comp, SEL["borrowGuardianPaused(address)"] + enc_address(m)),
            (comp, SEL["transferGuardianPaused(address)"] + enc_address(m)),
            (comp, SEL["seizeGuardianPaused(address)"] + enc_address(m)),
            (comp, SEL["liquidationBlocked(address)"] + enc_address(m)),
            (m, SEL["getCash()"]),
            (m, SEL["totalBorrows()"]),
            (m, SEL["totalReserves()"]),
            (m, SEL["totalSupply()"]),
            (m, SEL["exchangeRateStored()"]),
            (oracle, SEL["getUnderlyingPrice(address)"] + enc_address(m)),
        ]
    raw = []
    B = 10
    for i in range(0, len(plan), B):
        raw += rpc.call(plan[i:i + B])

    per = 16
    underlyings = []
    for idx, m in enumerate(markets):
        c = raw[idx * per:(idx + 1) * per]
        sym = dec_string(c[0])
        token = dec_address(c[1])
        mk = dec_words(c[2], 3)
        entry = {
            "market": m, "symbol": sym, "underlying": token,
            "is_listed": dec_bool(mk[0]) if mk[0] else None,
            "collateral_factor": dec_uint(mk[1]) / 1e18 if mk[1] else None,
            "borrow_cap": dec_uint(c[3]),
            "supply_cap": dec_uint(c[4]),
            "mint_paused": dec_bool(c[5]),
            "borrow_paused": dec_bool(c[6]),
            "transfer_paused": dec_bool(c[7]),
            "seize_paused": dec_bool(c[8]),
            "liquidation_blocked": dec_bool(c[9]) if c[9] and c[9] != "0x" else None,
            "cash": dec_uint(c[10]),
            "total_borrows": dec_uint(c[11]),
            "total_reserves": dec_uint(c[12]),
            "total_supply_mtokens": dec_uint(c[13]),
            "exchange_rate": dec_uint(c[14]),
            "oracle_price_raw": dec_uint(c[15]),
        }
        result["markets"].append(entry)
        underlyings.append((idx, token))

    # token metadata + feed/override reads
    plan2 = []
    native_idx = []
    for idx, token in underlyings:
        if token:
            plan2 += [(token, SEL["symbol()"]), (token, SEL["decimals()"])]
        else:
            native_idx.append(idx)
            plan2 += [(ZERO, SEL["symbol()"]), (ZERO, SEL["decimals()"])]
    raw2 = []
    for i in range(0, len(plan2), B):
        raw2 += rpc.call(plan2[i:i + B])
    for j, (idx, token) in enumerate(underlyings):
        if token:
            result["markets"][idx]["underlying_symbol"] = dec_string(raw2[j * 2])
            result["markets"][idx]["underlying_decimals"] = dec_uint(raw2[j * 2 + 1])
        else:
            mt = result["markets"][idx].get("symbol") or "m"
            result["markets"][idx]["underlying_symbol"] = mt[1:] if mt.startswith("m") else mt
            result["markets"][idx]["underlying_decimals"] = 18

    plan3 = []
    for idx, token in underlyings:
        s = result["markets"][idx].get("underlying_symbol") or ""
        if token:
            plan3 += [
                (oracle, SEL["assetPrices(address)"] + enc_address(token)),
                (oracle, SEL["getFeed(string)"] + enc_string(s)),
            ]
        else:
            # native market: oracle keys on mToken symbol; try both raw and stripped
            mt = result["markets"][idx].get("symbol") or ""
            plan3 += [
                ("__native__", mt),
                ("__native__", mt[1:] if mt.startswith("m") else mt),
            ]
    # split native probes out of the batch (they are not raw calls)
    exec_calls = [(to, data) for (to, data) in plan3 if to != "__native__"]
    mapping = [i for i, (to, d) in enumerate(plan3) if to != "__native__"]
    raw_exec = []
    for i in range(0, len(exec_calls), B):
        raw_exec += rpc.call(exec_calls[i:i + B])
    raw3 = [None] * len(plan3)
    for k, val in zip(mapping, raw_exec):
        raw3[k] = val
    for j, (idx, token) in enumerate(underlyings):
        if token:
            result["markets"][idx]["asset_price_override"] = dec_uint(raw3[j * 2])
            feed = dec_address(raw3[j * 2 + 1])
        else:
            result["markets"][idx]["asset_price_override"] = None
            feed = None
            mt = result["markets"][idx].get("symbol") or ""
            for probe in (mt, mt[1:] if mt.startswith("m") else mt):
                h = rpc.call([(oracle, SEL["getFeed(string)"] + enc_string(probe))])[0]
                if h and h != "0x" and dec_address(h) != ZERO:
                    feed = dec_address(h)
                    break
        if feed in (None, ZERO):
            feed = None
        result["markets"][idx]["feed"] = feed

    # feed metadata
    feeds = sorted({mk["feed"] for mk in result["markets"] if mk.get("feed")})
    plan4 = []
    for f in feeds:
        plan4 += [(f, SEL["latestRoundData()"]), (f, SEL["decimals()"]), (f, SEL["description()"])]
    raw4 = []
    for i in range(0, len(plan4), B):
        raw4 += rpc.call(plan4[i:i + B])
    feedinfo = {}
    for j, f in enumerate(feeds):
        w = dec_words(raw4[j * 3], 5)
        feedinfo[f] = {
            "round_id": dec_uint(w[0]),
            "answer": dec_int(w[1]),
            "started_at": dec_uint(w[2]),
            "updated_at": dec_uint(w[3]),
            "answered_in_round": dec_uint(w[4]),
            "decimals": dec_uint(raw4[j * 3 + 1]),
            "description": dec_string(raw4[j * 3 + 2]),
        }
        feedinfo[f]["age_sec"] = int(time.time()) - (feedinfo[f]["updated_at"] or 0)
    for mk in result["markets"]:
        mk["feed_info"] = feedinfo.get(mk.get("feed"))

    # normalize protocol price to USD/whole-token
    for mk in result["markets"]:
        dec = mk.get("underlying_decimals")
        rawp = mk.get("oracle_price_raw")
        if rawp is not None and isinstance(dec, int):
            mk["oracle_price_usd"] = rawp / (10 ** (36 - dec))
        else:
            mk["oracle_price_usd"] = None
        ov = mk.get("asset_price_override")
        if ov:
            mk["oracle_source"] = "override"
        elif mk.get("feed"):
            mk["oracle_source"] = "chainlink_feed"
        else:
            mk["oracle_source"] = "none"

    # external prices (DefiLlama)
    llama_ids = []
    idmap = {}
    for mk in result["markets"]:
        if mk.get("underlying") and mk.get("underlying_decimals") is not None:
            lid = f"{cfg['llama']}:{mk['underlying']}"
            llama_ids.append(lid)
            idmap[lid] = mk
    try:
        prices = http_json("https://coins.llama.fi/prices/current/" + ",".join(llama_ids))
        coins = prices.get("coins", {})
    except Exception as e:
        coins = {}
        result["llama_error"] = str(e)
    for lid, mk in idmap.items():
        c = coins.get(lid)
        if c:
            mk["external_price_usd"] = c.get("price")
            mk["external_price_ts"] = c.get("timestamp")
            mk["external_price_source"] = "defillama"
            if mk.get("oracle_price_usd"):
                mk["divergence_pct"] = (mk["oracle_price_usd"] / c["price"] - 1) * 100
        else:
            mk.setdefault("external_price_usd", None)

    # native-token markets via coingecko ids (GLMR/MOVR)
    nat_ids = []
    natmap = {}
    for mk in result["markets"]:
        if mk.get("underlying") is None and mk.get("underlying_symbol"):
            cid = "coingecko:" + mk["underlying_symbol"].lower()
            nat_ids.append(cid)
            natmap[cid] = mk
    if nat_ids:
        try:
            prices = http_json("https://coins.llama.fi/prices/current/" + ",".join(nat_ids))
            ncoins = prices.get("coins", {})
            for cid, mk in natmap.items():
                c = ncoins.get(cid)
                if c:
                    mk["external_price_usd"] = c.get("price")
                    mk["external_price_ts"] = c.get("timestamp")
                    mk["external_price_source"] = "defillama_native"
                    if mk.get("oracle_price_usd"):
                        mk["divergence_pct"] = (mk["oracle_price_usd"] / c["price"] - 1) * 100
        except Exception as e:
            result["llama_native_error"] = str(e)

    # GeckoTerminal fallback (token price) for unresolved underlyings
    net = cfg["llama"]
    for mk in result["markets"]:
        if mk.get("external_price_usd") is None and mk.get("underlying"):
            try:
                url = f"https://api.geckoterminal.com/api/v2/simple/networks/{net}/token_price/{mk['underlying']}"
                gt = http_json(url)
                attrs = gt["data"]["attributes"]
                p = attrs.get("token_prices", {}).get(mk["underlying"].lower())
                if p:
                    mk["external_price_usd"] = float(p)
                    mk["external_price_source"] = "geckoterminal"
                    if mk.get("oracle_price_usd"):
                        mk["divergence_pct"] = (mk["oracle_price_usd"] / float(p) - 1) * 100
            except Exception:
                pass
            time.sleep(0.7)

    # quick exploitability heuristics
    for mk in result["markets"]:
        cf = mk.get("collateral_factor") or 0
        ext = mk.get("external_price_usd")
        op = mk.get("oracle_price_usd")
        mk["borrow_exploit"] = None
        mk["liq_exploit"] = None
        if op and ext and ext > 0 and cf > 0 and mk.get("is_listed") and not mk.get("borrow_paused"):
            ratio = op / ext
            # borrow path: profit_factor = cf*ratio - 1  (>0 => supply+borrow extracts)
            mk["borrow_exploit"] = round(cf * ratio - 1, 6)
        if op and ext and mk.get("is_listed"):
            f = op / ext
            li = result.get("liq_incentive") or 0.08
            # liquidating a healthy book at wrong-low price: repay 1 unit debt, seize (1+li)/f real
            mk["liq_exploit"] = round((1 + li) / f - 1, 6) if f > 0 else None
    return result


def main():
    which = sys.argv[1:] or list(CHAINS.keys())
    for name in which:
        print(f"=== scanning {name} ===", flush=True)
        try:
            r = scan_chain(name)
            path = os.path.join(OUTDIR, f"{name}.json")
            with open(path, "w") as f:
                json.dump(r, f, indent=1)
            print(f"[ok] {name}: {r['markets_count']} markets -> {path}")
            for mk in r["markets"]:
                d = mk.get("divergence_pct")
                print(f"  {mk.get('symbol'):>12} {mk.get('underlying_symbol')} "
                      f"oracle=${mk.get('oracle_price_usd')}  ext=${mk.get('external_price_usd')} "
                      f"div={round(d,3) if d is not None else None}%  "
                      f"cf={mk.get('collateral_factor')} cash={mk.get('cash')} "
                      f"feed={mk.get('feed')} age={mk.get('feed_info',{}).get('age_sec') if mk.get('feed_info') else None}")
        except Exception as e:
            print(f"[ERR] {name}: {e}")


if __name__ == "__main__":
    main()
