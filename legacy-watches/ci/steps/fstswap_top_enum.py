#!/usr/bin/env python3
"""
fstswap_top_enum.py — H2-09 legacy-watches / fstswap-top-pairs (READ-ONLY).

Full enumeration of ALL FstSwap (BSC) factory pairs, focused on blue-chip custody:
  - all pairs from factory 0x9A272d734c5a0d7d84E0a892e891a553e8066dce
  - token0/token1/getReserves via multicall3
  - for pairs holding a blue-chip token (USDT/USDC/BUSD/WBNB/BTCB/ETH/DAI/FDUSD):
    balanceOf(pair) on the blue-chip side + excess = balance - reserve
  - USD via DefiLlama coins API (keyless); FIST fallback = implied from its USDT pair
  - outputs: top pairs by USD, all blue-chip pairs, block number

Public RPCs only; no API keys, no secrets. Env knobs: OUT (default ./fstswap_top_enum.json),
RPC1/RPC2 overrides (URLs only, never logged).
"""
import json, os, sys, time, urllib.request
from pathlib import Path

try:
    sys.set_int_max_str_digits(100000)
except Exception:
    pass

OUT = Path(os.environ.get("OUT", "ci-out/fstswap_top_enum.json"))
FACTORY = "0x9A272d734c5a0d7d84E0a892e891a553e8066dce"
MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
RPCS = [os.environ.get("RPC1"), os.environ.get("RPC2"),
        "https://bsc.publicnode.com", "https://bsc-dataseed.binance.org"] 
RPCS = [r for r in RPCS if r and r.startswith("http")]

BLUE = {
    "0x55d398326f99059ff775485246999027b3197955": "USDT",
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d": "USDC",
    "0xe9e7cea3dedca5984780bafc599bd69add087d56": "BUSD",
    "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c": "WBNB",
    "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c": "BTCB",
    "0x2170ed0880ac9a755fd29b2688956bd959f933f8": "ETH",
    "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3": "DAI",
    "0xc5f0f7b66764f6ec8c8dff7ba683102295e16409": "FDUSD",
}
FIST = "0xc9882def23bc42d53895b8361d0b1edc7570bc6a"

SEL = {"allPairsLength": "0x574f2ba3", "allPairs": "0x1e3dd18b",
       "token0": "0x0dfe1681", "token1": "0xd21220a7", "getReserves": "0x0902f1ac",
       "balanceOf": "0x70a08231", "decimals": "0x313ce567", "symbol": "0x95d89b41"}

def pad(v): return f"{v:064x}"
def enc(sel, *args):
    d = sel
    for a in args:
        d += pad(a) if isinstance(a, int) else a.lower().replace("0x", "").rjust(64, "0")
    return d
def dec_u(res):
    if not isinstance(res, str) or res in ("0x", ""): return None
    h = res[2:] if res.startswith("0x") else res
    return int(h, 16) if 0 < len(h) <= 66 else None
def dec_addr(res):
    if not isinstance(res, str): return None
    h = res[2:] if res.startswith("0x") else res
    return "0x" + h[-40:] if len(h) == 64 else None

class Rpc:
    def __init__(self):
        self.good = None; self.calls = 0; self.errors = 0
    def _post(self, url, payload, timeout=60):
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "h2-09-recon/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read())
    def rpc(self, method, params):
        order = ([self.good] if self.good else []) + [r for r in RPCS if r != self.good]
        last = None
        for url in order:
            try:
                d = self._post(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
                if "error" in d: raise RuntimeError(d["error"])
                self.good = url; return d.get("result")
            except Exception as e:
                last = e
        self.errors += 1
        raise RuntimeError(f"rpc failed: {last}")
    def call(self, to, data, block="latest"):
        self.calls += 1
        return self.rpc("eth_call", [{"to": to, "data": data}, block])
    def multicall(self, calls, block):
        results = [None] * len(calls); idx = list(range(len(calls))); batch = 150; i = 0
        code = self.rpc("eth_getCode", [MULTICALL3, block])
        has_mc = code and code not in ("0x", "0x0")
        while i < len(idx):
            part = idx[i:i + batch]
            if has_mc:
                data = self._enc_tryagg([calls[k] for k in part])
                ok = False
                for attempt in range(3):
                    try:
                        outs = self._dec_tryagg(self.call(MULTICALL3, data, block))
                        if len(outs) != len(part): raise RuntimeError("len")
                        for k, o in zip(part, outs): results[k] = o
                        ok = True; break
                    except Exception:
                        time.sleep(0.4 * (attempt + 1))
                if ok: i += len(part); time.sleep(0.15); continue
                elif batch > 1: batch = max(1, batch // 3); continue
                else: results[part[0]] = None; i += 1; continue
            else:
                payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                            "params": [{"to": t, "data": d}, block]} for j, (t, d) in enumerate(part)]
                res = None
                for url in ([self.good] if self.good else []) + [r for r in RPCS if r != self.good]:
                    try: res = self._post(url, payload); self.good = url; break
                    except Exception: continue
                if res:
                    by_id = {x.get("id"): x for x in res}
                    for j in range(len(part)):
                        x = by_id.get(j) or {}
                        results[part[j]] = x.get("result") if "error" not in x else None
                    self.calls += len(part)
                i += len(part); time.sleep(0.2)
        return results
    @staticmethod
    def _enc_tryagg(calls):
        # tryAggregate(bool requireSuccess, (address,bytes)[]) = 0xbce38bd7
        # offsets relative to the slot right after the array length word (multicall3 convention, empirically verified)
        n = len(calls); offs = ""; bodies = ""; off = 0x20 * n
        for a, d in calls:
            db = bytes.fromhex(d[2:]); padded = db + b"\x00" * ((32 - len(db) % 32) % 32)
            offs += pad(off); bodies += pad(int(a, 16)) + pad(0x40) + pad(len(db)) + padded.hex()
            off += 0x60 + len(padded)
        return "0xbce38bd7" + pad(0) + pad(0x40) + pad(n) + offs + bodies
    @staticmethod
    def _dec_tryagg(res):
        # returns [(success, data_hex or None), ...]
        # layout: word0 = offset to array (chars 64); at X: length; offsets relative to X+64 (after length word)
        h = res[2:]
        X = int(h[0:64], 16) * 2
        n = int(h[X:X + 64], 16)
        C = X + 64
        out = []
        for i in range(n):
            eo = int(h[C + i * 64:C + i * 64 + 64], 16)
            T = C + eo * 2
            succ = int(h[T:T + 64], 16)
            bo = int(h[T + 64:T + 128], 16)
            sp = T + bo * 2
            ln = int(h[sp:sp + 64], 16)
            data = h[sp + 64:sp + 64 + ln * 2] if ln else ""
            out.append(data if succ else None)
        return out

    @staticmethod
    def _enc_agg(calls):
        n = len(calls); offs = ""; bodies = ""; off = 0x20 * n
        for a, d in calls:
            db = bytes.fromhex(d[2:]); padded = db + b"\x00" * ((32 - len(db) % 32) % 32)
            offs += pad(off); bodies += pad(int(a, 16)) + pad(0x40) + pad(len(db)) + padded.hex()
            off += 0x60 + len(padded)
        return "0x252dba42" + pad(0x20) + pad(n) + offs + bodies
    @staticmethod
    def _dec_agg(res):
        h = res[2:]; A = int(h[64:128], 16); la = A * 2; cnt = int(h[la:la + 64], 16); C = la + 64; out = []
        for i in range(cnt):
            eo = int(h[C + i * 64:C + i * 64 + 64], 16); sp = C + eo * 2
            ln = int(h[sp:sp + 64], 16); out.append(h[sp + 64:sp + 64 + ln * 2])
        return out

def fetch_prices(tokens):
    out = {}
    toks = sorted({t.lower() for t in tokens})
    for i in range(0, len(toks), 25):
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"bsc:{t}" for t in toks[i:i + 25])
        for attempt in range(3):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "h2-09-recon"}), timeout=45) as r:
                    d = json.loads(r.read())
                for k, v in (d.get("coins") or {}).items():
                    out[k.split(":", 1)[1].lower()] = v.get("price")
                break
            except Exception:
                time.sleep(0.6 * (attempt + 1))
        time.sleep(0.1)
    return out

def main():
    rpc = Rpc()
    blk = int(rpc.rpc("eth_blockNumber", []), 16)
    block = "latest"  # public RPCs prune old states (~128 blocks); pin only for records
    n = dec_u(rpc.call(FACTORY, SEL["allPairsLength"], block))
    print(f"[fstswap] block={blk} pairs={n}", flush=True)
    pairs = [dec_addr(r) for r in rpc.multicall([(FACTORY, enc(SEL["allPairs"], i)) for i in range(n)], block)]
    pairs = [p for p in pairs if p]
    print(f"[fstswap] enumerated {len(pairs)} pairs; reading token0/token1/reserves", flush=True)
    calls = []
    for p in pairs:
        calls += [(p, SEL["token0"]), (p, SEL["token1"]), (p, SEL["getReserves"])]
    res = rpc.multicall(calls, block)
    structs = []
    for j, p in enumerate(pairs):
        t0 = dec_addr(res[j * 3]); t1 = dec_addr(res[j * 3 + 1]); rr = res[j * 3 + 2]
        r0 = r1 = None
        if isinstance(rr, str):
            h = rr[2:] if rr.startswith("0x") else rr
            if len(h) >= 128:
                r0 = int(h[0:64], 16); r1 = int(h[64:128], 16)
        structs.append({"pair": p, "token0": t0, "token1": t1, "r0": r0, "r1": r1})
    # decimals for all unique tokens
    toks = sorted({t.lower() for s in structs for t in (s["token0"], s["token1"]) if t})
    dec = {}
    for i in range(0, len(toks), 100):
        part = toks[i:i + 100]
        for t, r in zip(part, rpc.multicall([(t, SEL["decimals"]) for t in part], block)):
            d = dec_u(r)
            dec[t] = d if isinstance(d, int) and d <= 36 else None
    print(f"[fstswap] decimals for {len(dec)} tokens", flush=True)
    # balances on blue-chip sides
    blue_calls = []
    for s in structs:
        for side in ("0", "1"):
            t = s["token" + side]
            if t and t.lower() in BLUE:
                blue_calls.append((s["pair"], side, t.lower()))
    bres = rpc.multicall([(t, enc(SEL["balanceOf"], p)) for (p, side, t) in blue_calls], block)
    for (p, side, t), r in zip(blue_calls, bres):
        for s in structs:
            if s["pair"] == p:
                s["b" + side] = dec_u(r)
    # prices: DefiLlama for everything; fallback FIST implied
    prices = fetch_prices(toks)
    # implied FIST price from the top USDT pair (raw ratios, both decimals known)
    fist_implied = None
    for s in structs:
        t0 = (s["token0"] or "").lower(); t1 = (s["token1"] or "").lower()
        if FIST in (t0, t1) and s["r0"] and s["r1"]:
            if t0 in BLUE and t0 != FIST and dec.get(t0) is not None and dec.get(FIST) is not None:
                usd_side = s["r0"] / 10 ** dec[t0]; fist_side = s["r1"] / 10 ** dec[FIST]
                if fist_side > 0 and usd_side > 1000:
                    fist_implied = (usd_side / fist_side) if t1 == FIST else (s["r1"] / 10 ** dec[t1]) / (s["r0"] / 10 ** dec[t0])
                    break
    if fist_implied:
        prices[FIST] = fist_implied
    print(f"[fstswap] prices: {len(prices)} tokens; FIST implied={fist_implied}", flush=True)

    def human(tok, raw):
        if raw is None or not tok: return None
        d = dec.get(tok.lower())
        return raw / 10 ** d if isinstance(d, int) else None

    rows = []
    for s in structs:
        if not s["token0"] or not s["token1"] or s["r0"] is None or s["r1"] is None:
            continue
        t0 = s["token0"].lower(); t1 = s["token1"].lower()
        v0 = human(t0, s["r0"]); v1 = human(t1, s["r1"])
        p0 = prices.get(t0); p1 = prices.get(t1)
        usd0 = v0 * p0 if (v0 is not None and p0) else None
        usd1 = v1 * p1 if (v1 is not None and p1) else None
        tvl = (usd0 or 0) + (usd1 or 0) if (usd0 is not None or usd1 is not None) else None
        blue_sides = []
        for side, t in (("0", t0), ("1", t1)):
            if t in BLUE:
                bal = s.get("b" + side)
                r = s["r" + side]
                blue_sides.append({"side": side, "symbol": BLUE[t], "token": t,
                                   "reserve_raw": str(r), "balance_raw": str(bal) if bal is not None else None,
                                   "excess_raw": str(bal - r) if bal is not None else None,
                                   "reserve_human": human(t, r),
                                   "reserve_usd": (human(t, r) * prices.get(t)) if (human(t, r) is not None and prices.get(t)) else None})
        row = {"pair": s["pair"], "token0": t0, "token1": t1,
               "reserve0_human": v0, "reserve1_human": v1,
               "price0_usd": p0, "price1_usd": p1, "tvl_usd_est": round(tvl, 2) if tvl is not None else None,
               "blue_sides": blue_sides,
               "blue_usd": round(sum(b["reserve_usd"] for b in blue_sides if b["reserve_usd"]), 2) if any(b["reserve_usd"] for b in blue_sides) else None}
        rows.append(row)
    rows.sort(key=lambda x: (x["tvl_usd_est"] or 0), reverse=True)
    blue_rows = [r for r in rows if r["blue_sides"]]
    blue_rows.sort(key=lambda x: (x["blue_usd"] or 0), reverse=True)
    blk_end = int(rpc.rpc("eth_blockNumber", []), 16)
    out = {"factory": FACTORY, "block_start": blk, "block": blk_end, "pairs_total": n, "pairs_scanned": len(structs),
           "tokens": len(toks), "fist_implied_price": fist_implied,
           "blue_pairs_count": len(blue_rows),
           "blue_usd_total": round(sum(r["blue_usd"] or 0 for r in blue_rows), 2),
           "top_pairs_by_usd": rows[:40],
           "blue_pairs": blue_rows,
           "rpc_calls": rpc.calls, "rpc_errors": rpc.errors}
    OUT.write_text(json.dumps(out, indent=1))
    print(f"[fstswap] wrote {OUT} blue_pairs={len(blue_rows)} blue_usd_total={out['blue_usd_total']} "
          f"top_tvl={rows[0]['tvl_usd_est'] if rows else None} rpc_calls={rpc.calls}", flush=True)

if __name__ == "__main__":
    main()
