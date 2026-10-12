#!/usr/bin/env python3
"""
cog (Scroll) oracle decoder — read-only, keyless public RPC.
For each oracle used by live pairs: classify (ChainlinkOracle vs LayerZeroOracle vs other),
decode getDataParameter(), read the underlying feed (Chainlink aggregator or LayerZero xF33d hash),
and compare the pair's stored exchange_rate with the feed-implied rate and the market.

Outputs ci-out/oracles_decoded.json
"""
import json, os, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
RPCS = ["https://rpc.scroll.io", "https://scroll-rpc.publicnode.com", "https://scroll.drpc.org"]
_rr = [0]

def rpc(method, params, tries=3, timeout=25):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(tries):
        u = RPCS[_rr[0] % len(RPCS)]; _rr[0] += 1
        try:
            req = urllib.request.Request(u, data=body, headers={"Content-Type": "application/json",
                                                                "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d: return d["result"]
            last = str(d.get("error"))
        except Exception as e:
            last = str(e)
        time.sleep(0.2 + 0.3 * i)
    raise RuntimeError(f"rpc failed {method}: {last}")

def words(h):
    h = h[2:] if h.startswith("0x") else h
    return [h[i:i+64] for i in range(0, len(h) - 63, 64)]

def uint(w): return int(w, 16)
def addr(w): return "0x" + w[-40:]

def sel(sig):
    from Crypto.Hash import keccak
    k = keccak.new(digest_bits=256); k.update(sig.encode())
    return "0x" + k.hexdigest()[:8]

S = {s: sel(s) for s in ["getDataParameter()", "latestRoundData()", "latestRoundData(bytes32)",
                          "decimals()", "name()", "description()", "peek()", "get()"]}

def call(to, selector, extra=""):
    try:
        return rpc("eth_call", [{"to": to, "data": selector + extra}, "latest"])
    except Exception as e:
        return "ERR:" + str(e)[:90]

LZ_FEED = "0x3dd5c2acd2f41947e73b384ef52c049bac0b65d0"

def decode_gdp(o):
    r = call(o, S["getDataParameter()"])
    if not isinstance(r, str) or r.startswith("ERR") or len(r) < 2 + 64*8:
        return {"err": str(r)[:80]}
    w = words(r)
    # dynamic bytes: [0]=offset(0x20), [1]=len, [2..]=data
    ln = uint(w[1])
    dat = w[2:2 + (ln + 31)//32]
    out = {"abi_words": len(dat)}
    if len(dat) >= 3:
        a, b, c = dat[0], dat[1], dat[2]
        au, bu = uint(a), uint(b)
        # addresses have top 24 hex chars zero
        a_is_addr = a[:24] == "0"*24
        b_is_addr = b[:24] == "0"*24
        out["w0"], out["w1"], out["dec"] = "0x"+a, "0x"+b, uint(c)
        out["type"] = "chainlink" if (a_is_addr and b_is_addr) else "layerzero"
    return out

def chainlink_feed(feed):
    r = call(feed, S["latestRoundData()"])
    if not isinstance(r, str) or r.startswith("ERR") or len(r) < 2+64*5:
        return {"err": str(r)[:80]}
    w = words(r)
    return {"roundId": uint(w[0]), "answer": uint(w[1]) if uint(w[1]) < 2**255 else uint(w[1]) - 2**256,
            "startedAt": uint(w[2]), "updatedAt": uint(w[3]), "answeredInRound": uint(w[4]),
            "decimals": uint(call(feed, S["decimals()"])[:66]) if call(feed, S["decimals()"]).startswith("0x") else None}

def lz_feed(h):
    r = call(LZ_FEED, S["latestRoundData(bytes32)"], h)
    if not isinstance(r, str) or r.startswith("ERR") or len(r) < 2+64*5:
        return {"err": str(r)[:80]}
    w = words(r)
    return {"roundId": uint(w[0]), "answer": uint(w[1]) if uint(w[1]) < 2**255 else uint(w[1]) - 2**256,
            "startedAt": uint(w[2]), "updatedAt": uint(w[3]), "answeredInRound": uint(w[4])}

def main():
    d = json.load(open(os.path.join(OUT, "state_latest.json")))
    oracles = sorted(d["oracles"].keys())
    now = int(time.time())
    out = {}
    res = {}
    def one(o):
        r = {"oracle": o}
        r.update(decode_gdp(o))
        r["code_len"] = len(rpc("eth_getCode", [o, "latest"]))
        if r.get("type") == "chainlink":
            r["feed_mul"] = chainlink_feed(r["w0"])
            r["feed_div"] = chainlink_feed(r["w1"])
        elif r.get("type") == "layerzero":
            r["lz_mul"] = lz_feed(r["w0"])
            r["lz_div"] = lz_feed(r["w1"])
        p = call(o, S["peek()"])
        if isinstance(p, str) and not p.startswith("ERR") and len(p) >= 130:
            w = words(p)
            r["peek"] = {"updated": uint(w[0]), "rate": uint(w[1])}
        return r
    def one2(o):
        return o, one(o)
    with ThreadPoolExecutor(max_workers=5) as ex:
        for o, r in ex.map(one2, oracles):
            res[o] = r
    res["_meta"] = {"now": now, "lz_feed": LZ_FEED, "source_block": d["block"]}
    json.dump(res, open(os.path.join(OUT, "oracles_decoded.json"), "w"), indent=1)
    print("wrote ci-out/oracles_decoded.json", len(res) - 1, "oracles")

if __name__ == "__main__":
    main()
