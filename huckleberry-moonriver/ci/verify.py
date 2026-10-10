#!/usr/bin/env python3
"""CI verification for C2-56 Huckleberry / Moonriver cohort.

Independent re-run on a GitHub Actions runner:
  1. Two liveness probes (>=45s apart) across the keyed env endpoint + public RPCs.
  2. Re-read the frozen-head cohort state (Moonswap 816 pairs, Huckleberry AMM 113
     pairs, Huckleberry lending 11 markets) and recompute the stuck totals.
  3. Write ci-out/moonriver_verify.json (uploaded as artifact).

Read-only. NEVER prints keyed RPC URLs (only the label). No transactions.
"""
import json, os, sys, time, urllib.request, urllib.error, datetime, re

UA = "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt-research/1.0"
HEAD_EXPECTED = "0x1093916"  # 17,381,654

PUBLIC = [
    "https://moonriver.api.onfinality.io/public",
    "https://moonriver.drpc.org",
]
KEYED = os.environ.get("MOONRIVER_RPC_URL", "").strip()

MOONSWAP_FACTORY = "0x056973f631a5533470143bb7010c9229c19c04d2"
HUCK_FACTORY = "0x017603c8f29f7f6394737628a93c57ffba1b7256"
HUCK_COMPTROLLER = "0xcffef313b69d83cb9ba35d9c0f882b027b846ddc"
HUCK_MARKETS = [
    "0x455D0c83623215095849AbCF7Cc046f78E3EDAe0",
    "0x7dcf13928EE7EfD5DD4789888d9baEf555575399",
    "0xd275c08c5C5cEDd5617ECAca5C71eC560715f49C",
    "0x0dA4B57c2BFc2AFCf6f63cDC89DAe588C943C5B6",
    "0x809eD65E30500cdFFfE4e25B8d3019DEE21230cc",
    "0x56E49Fd915a9c26B37d22A82C4A276827F31DCD5",
    "0x68c5c3F507eB76EbEd75CC28632D7C1D5B3E7E83",
    "0x12AE8068f195453f25A42f097721929F698F57fC",
    "0xd629D7ccaAE2338F13e8253B5232d5Ad4342ea22",
    "0xFBd7c66b72b9DC3F32c783548CEdCfb22F15d875",
    "0x517a37861EF1c60BA481a3D694890DDfE508e255",
]
STABLE_RE = re.compile(r"^(usdc|usdt|dai|busd|mim|frax|ust|usdd|mai|usdc\.m|usdt\.m|usdc\.e)", re.I)
FAKE_DAI = "0xe7a534f34f6ba18a03e0e09ade4a9d6628aa69da"


def _post(url, payload, timeout=45, tries=3):
    data = json.dumps(payload).encode()
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=data,
                                         headers={"Content-Type": "application/json", "User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
            time.sleep(1.0 + i)
    raise RuntimeError(str(last))


class Rpc:
    def __init__(self, endpoints):
        self.eps = endpoints
        self.i = 0

    def url(self):
        return self.eps[self.i % len(self.eps)]

    def rotate(self):
        self.i += 1

    def rpc(self, method, params):
        for _ in range(len(self.eps) + 2):
            try:
                r = _post(self.url(), {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
                if "result" in r:
                    return r["result"]
                err = r.get("error")
                # rotate only on transport-ish errors
                if err and isinstance(err, dict) and err.get("code") in (-32005, -32016):
                    self.rotate()
                    continue
                return {"__error__": err}
            except Exception:
                self.rotate()
        return {"__error__": "all endpoints failed"}

    def batch(self, calls, chunk=50):
        out = []
        for s in range(0, len(calls), chunk):
            part = calls[s:s + chunk]
            payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                        "params": [{"to": to, "data": data}, HEAD_EXPECTED]}
                       for j, (to, data) in enumerate(part)]
            res = None
            for _ in range(len(self.eps) + 2):
                try:
                    res = _post(self.url(), payload)
                    break
                except Exception:
                    self.rotate()
            if res is None:
                out.extend([None] * len(part))
                continue
            if isinstance(res, dict):
                out.extend([None] * len(part))
                continue
            byid = {r.get("id"): r for r in res if isinstance(r, dict)}
            for j in range(len(part)):
                r = byid.get(j, {})
                out.append(r.get("result") if "result" in r else None)
        return out


def addr_word(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc(sel, arg=None):
    return sel + (addr_word(arg) if arg else "")


def dec_addr(w):
    return "0x" + w[-40:].lower() if w and len(w) >= 66 else None


def dec_uint(w):
    try:
        return int(w, 16) if w and w != "0x" else None
    except Exception:
        return None


def dec_str(w):
    if not w or w == "0x":
        return None
    try:
        b = bytes.fromhex(w[2:])
        if len(b) >= 64:
            off = int.from_bytes(b[0:32], "big")
            if off == 32:
                ln = int.from_bytes(b[off:off + 32], "big")
                if 0 <= ln <= 64:
                    return b[off + 32:off + 32 + ln].decode("utf-8", "replace")
        return b.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return None


SEL = {"allPairsLength": "0x574f2ba3", "allPairs": "0x1e3dd18b", "token0": "0x0dfe1681",
       "token1": "0xd21220a7", "symbol": "0x95d89b41", "decimals": "0x313ce567",
       "balanceOf": "0x70a08231", "getCash": "0x3b1d21a2"}


def probe(rpc, label):
    bn = rpc.rpc("eth_blockNumber", [])
    blk = rpc.rpc("eth_getBlockByNumber", ["latest", False])
    syncing = rpc.rpc("eth_syncing", [])
    e = {"endpoint": label, "blockNumber_raw": bn}
    if isinstance(blk, dict):
        e["head_number"] = blk.get("number")
        e["head_hash"] = blk.get("hash")
        ts = blk.get("timestamp")
        e["head_timestamp"] = ts
        try:
            e["head_utc"] = datetime.datetime.fromtimestamp(int(ts, 16), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except Exception:
            e["head_utc"] = None
    else:
        e["error"] = blk
    e["eth_syncing"] = syncing
    return e


def enumerate_stables(rpc, factory, label):
    n = dec_uint(rpc.rpc("eth_call", [{"to": factory, "data": SEL["allPairsLength"]}, HEAD_EXPECTED]))
    if not n:
        return {"error": "allPairsLength failed", "label": label}
    pairs = []
    for s in range(0, n, 200):
        res = rpc.batch([(factory, enc(SEL["allPairs"], None) + format(i, "x").rjust(64, "0"))
                         for i in range(s, min(s + 200, n))])
        pairs.extend(dec_addr(w) for w in res)
    pairs = [p for p in pairs if p]
    t0 = rpc.batch([(p, SEL["token0"]) for p in pairs])
    t1 = rpc.batch([(p, SEL["token1"]) for p in pairs])
    uniq = sorted({dec_addr(w) for w in t0 + t1 if dec_addr(w)})
    syms = rpc.batch([(t, SEL["symbol"]) for t in uniq])
    decs = rpc.batch([(t, SEL["decimals"]) for t in uniq])
    meta = {t: {"symbol": dec_str(syms[i]), "decimals": dec_uint(decs[i])} for i, t in enumerate(uniq)}
    bal_calls, bal_map = [], []
    for i, p in enumerate(pairs):
        for tok in (dec_addr(t0[i]), dec_addr(t1[i])):
            if tok:
                bal_calls.append((tok, enc(SEL["balanceOf"], p)))
                bal_map.append((i, tok))
    bals = rpc.batch(bal_calls)
    agg = {}
    for (i, tok), w in zip(bal_map, bals):
        sym = (meta.get(tok) or {}).get("symbol") or ""
        if not STABLE_RE.match(sym.strip()) or tok.lower() == FAKE_DAI:
            continue
        d = (meta.get(tok) or {}).get("decimals") or 18
        a = agg.setdefault(tok, {"symbol": sym, "decimals": d, "raw": 0, "pairs": 0})
        a["raw"] += dec_uint(w) or 0
        if dec_uint(w):
            a["pairs"] += 1
    rows = []
    for t, a in agg.items():
        human = a["raw"] / 10 ** a["decimals"]
        rows.append({"token": t, "symbol": a["symbol"], "decimals": a["decimals"],
                     "amount": round(human, 6), "pairs": a["pairs"]})
    rows.sort(key=lambda r: -r["amount"])
    return {"label": label, "factory": factory, "pair_count": n, "stable_tokens": rows}


def main():
    eps = []
    if KEYED:
        eps.append(KEYED)
    eps += PUBLIC
    labels = (["MOONRIVER_RPC_URL (keyed env, redacted)"] if KEYED else []) + PUBLIC
    rpc = Rpc(eps)
    out = {"generated_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "head_expected": HEAD_EXPECTED, "probeA": [], "probeB": []}
    for url, label in zip(eps, labels):
        out["probeA"].append(probe(Rpc([url]), label))
    gap = int(os.environ.get("PROBE_GAP", "60"))
    print(f"probe A done; sleeping {gap}s...")
    time.sleep(gap)
    for url, label in zip(eps, labels):
        out["probeB"].append(probe(Rpc([url]), label))

    # agreement check across responding endpoints
    heads = {e.get("head_number") for e in out["probeA"] + out["probeB"] if e.get("head_number")}
    out["heads_agree"] = (len(heads) == 1)
    out["head_value"] = list(heads)[0] if len(heads) == 1 else None

    # cohort state
    out["moonswap"] = enumerate_stables(rpc, MOONSWAP_FACTORY, "moonswap")
    out["huckleberry_amm"] = enumerate_stables(rpc, HUCK_FACTORY, "huckleberry_amm")
    markets = rpc.rpc("eth_call", [{"to": HUCK_COMPTROLLER, "data": "0xb0772d0b"}, HEAD_EXPECTED])
    mkts = []
    if isinstance(markets, str) and markets.startswith("0x") and len(markets) >= 130:
        # decode address[]: offset, len, items
        try:
            b = bytes.fromhex(markets[2:])
            off = int.from_bytes(b[0:32], "big")
            ln = int.from_bytes(b[off:off + 32], "big")
            mkts = ["0x" + b[off + 32 + 32 * k + 12: off + 64 + 32 * k].hex() for k in range(ln)]
        except Exception:
            pass
    cash = rpc.batch([(m, SEL["getCash"]) for m in mkts])
    out["huckleberry_lending"] = {
        "comptroller": HUCK_COMPTROLLER,
        "market_count": len(mkts),
        "markets": [{"market": m, "getCash_raw": dec_uint(c)} for m, c in zip(mkts, cash)],
    }
    out["verdict"] = {
        "chain_frozen": out["heads_agree"] and out.get("head_value") == HEAD_EXPECTED,
        "E_U_usd": 0.0, "H_O_usd": 0.0, "P_usd": 0.0,
        "note": "all cohort assets stuck (S) while the chain head is frozen at 17,381,654; no tx can execute",
    }
    os.makedirs("ci-out", exist_ok=True)
    json.dump(out, open("ci-out/moonriver_verify.json", "w"), indent=2)
    print(json.dumps({"heads_agree": out["heads_agree"], "head": out.get("head_value"),
                      "probeA": [(e["endpoint"], e.get("head_number")) for e in out["probeA"]],
                      "probeB": [(e["endpoint"], e.get("head_number")) for e in out["probeB"]],
                      "moonswap_pairs": out["moonswap"].get("pair_count"),
                      "huck_amm_pairs": out["huckleberry_amm"].get("pair_count"),
                      "lending_markets": out["huckleberry_lending"]["market_count"]}, indent=2))
    # quick stable totals print
    for k in ("moonswap", "huckleberry_amm"):
        tot = sum(r["amount"] for r in out[k]["stable_tokens"])
        print(f"{k}: stable tokens total (nominal units) = {tot:,.2f}")
    print("wrote ci-out/moonriver_verify.json")


if __name__ == "__main__":
    main()
