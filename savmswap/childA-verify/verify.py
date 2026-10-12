#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
childA-verify: independent, from-scratch recomputation of savmSwap holdings
(abandoned Uniswap V2 fork, Prom chain, EVM id 227).

READ-ONLY: only eth_chainId / eth_blockNumber / eth_getBlockByNumber /
eth_getCode / eth_call against the public RPC https://rpc.prom.io.
No transactions, no keys, no secrets. Python 3 stdlib only.
JSON-RPC batches of at most 10 calls per HTTP request.

Steps:
  1. Factory allPairsLength() and every allPairs(i).
  2. Per pair: token0(), token1(), getReserves(), balanceOf(pair) for both tokens.
  3. Totals of WPROM (18dec) and USDT (6dec) held across all pairs + USD at the
     current DefiLlama PROM price.
  4. Excess check: balanceOf(pair) vs getReserves() per token.
  5. Top 10 pairs by WPROM held.
  6. Main pair LP totalSupply() and shares of 4 addresses.

Output: verify-results.json (next to this script).
"""

import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from decimal import Decimal, getcontext

getcontext().prec = 60

# ---------------------------------------------------------------------------
# constants given by the parent task
# ---------------------------------------------------------------------------
RPC_URL = "https://rpc.prom.io"
FACTORY = "0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9"
WPROM = "0x04a21a38d5e275d6023b27504beb3095dc43b0c0"
USDT = "0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed"
MAIN_PAIR = "0x1ddbf7113e3711ae9918f2dc14efb6b302b1e0d2"
LP_HOLDERS = [
    "0x2bA8968C1AE5984f049F28085f50D7Df4aD1a01e",
    "0x55594E57F80b2deCd63608A4F2802F8003633aD2",
    "0x000000000000000000000000000000000000dEaD",
    "0x0000000000000000000000000000000000000000",
]
PRICE_URL = "https://coins.llama.fi/prices/current/coingecko:prometeus"
USDT_PRICE_URL = "https://coins.llama.fi/prices/current/coingecko:tether"

PARENT_CLAIM = {
    "pair_count": 90,
    "total_usd": 234906.0,
    "wprom_price": 5.2549,
    "main_pair_wprom": 14630.8,
    "main_pair_usdt": 76134.7,
    "main_pair_lp_share_pct": 99.85,
    "no_excess": True,
}

# Uniswap V2 selectors
SEL_ALL_PAIRS_LENGTH = "0x574f2ba3"
SEL_ALL_PAIRS        = "0x1e3dd18b"
SEL_TOKEN0           = "0x0dfe1681"
SEL_TOKEN1           = "0xd21220a7"
SEL_GET_RESERVES     = "0x0902f1ac"
SEL_BALANCE_OF       = "0x70a08231"
SEL_SYMBOL           = "0x95d89b41"
SEL_DECIMALS         = "0x313ce567"
SEL_TOTAL_SUPPLY     = "0x18160ddd"

CHUNK = 10            # max JSON-RPC calls per HTTP request
SLEEP_BETWEEN = 0.12  # polite pause between HTTP requests
MASK160 = (1 << 160) - 1

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS_PATH = os.path.join(HERE, "verify-results.json")


def log(msg):
    print(msg, flush=True)


# ---------------------------------------------------------------------------
# JSON-RPC plumbing
# ---------------------------------------------------------------------------
def _http_post_json(payload, timeout=45):
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        RPC_URL,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "savmswap-childA-verify/1.0 (read-only, python-stdlib)",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", "replace"))


def rpc_batch(method_calls, stage=""):
    """method_calls: list of {"method": ..., "params": [...]}
    Returns list aligned with input, each element (ok: bool, value_or_error).
    Chunks requests to CHUNK calls; retries transport errors with backoff;
    on persistent batch failure, splits the chunk to isolate bad calls."""
    results = [None] * len(method_calls)
    queue = []
    for start in range(0, len(method_calls), CHUNK):
        queue.append((start, method_calls[start:start + CHUNK]))
    while queue:
        start, part = queue.pop(0)
        payload = [
            {"jsonrpc": "2.0", "id": j, "method": c["method"], "params": c["params"]}
            for j, c in enumerate(part)
        ]
        success = False
        last_err = None
        attempts = 5 if len(part) == 1 else 4
        for attempt in range(attempts):
            try:
                resp = _http_post_json(payload)
                if isinstance(resp, dict):
                    if "error" in resp and "result" not in resp:
                        raise RuntimeError("rpc error: %s" % resp["error"])
                    resp = [resp]
                if not isinstance(resp, list):
                    raise RuntimeError("unexpected response type %r" % type(resp))
                by_id = {}
                for r in resp:
                    if isinstance(r, dict) and "id" in r:
                        by_id[r["id"]] = r
                chunk_res = []
                for j in range(len(part)):
                    r = by_id.get(j)
                    if r is None:
                        chunk_res.append((False, "missing from batch response"))
                    elif "error" in r and "result" not in r:
                        chunk_res.append((False, str(r["error"])))
                    else:
                        chunk_res.append((True, r.get("result")))
                for k, item in enumerate(chunk_res):
                    results[start + k] = item
                success = True
                break
            except Exception as exc:  # transport or protocol failure
                last_err = exc
                time.sleep(min(1.5 * (attempt + 1), 8.0))
        if success:
            time.sleep(SLEEP_BETWEEN)
        elif len(part) > 1:
            mid = len(part) // 2
            queue.insert(0, (start + mid, part[mid:]))
            queue.insert(0, (start, part[:mid]))
            time.sleep(0.5)
        else:
            raise RuntimeError("RPC call failed (stage=%s start=%d): %s" % (stage, start, last_err))
    return results


def eth_calls(items, block_tag, stage=""):
    """items: list of (to_addr, data_hex). Returns aligned (ok, hex-or-error).
    If pinned block_tag fails per item, retries that item at 'latest'."""
    calls = [
        {"method": "eth_call", "params": [{"to": to, "data": data}, block_tag]}
        for (to, data) in items
    ]
    res = rpc_batch(calls, stage=stage)
    if block_tag != "latest":
        for i, (ok, _v) in enumerate(res):
            if not ok:
                one = rpc_batch(
                    [{"method": "eth_call",
                      "params": [{"to": items[i][0], "data": items[i][1]}, "latest"]}],
                    stage=stage + "-fallback",
                )
                if one[0][0]:
                    res[i] = one[0]
    return res


def fetch_json(url, tries=5):
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(
                url, headers={"Accept": "application/json",
                              "User-Agent": "savmswap-childA-verify/1.0"}
            )
            with urllib.request.urlopen(req, timeout=45) as resp:
                return json.loads(resp.read().decode("utf-8", "replace"))
        except Exception as exc:
            last = exc
            time.sleep(1.0 * (attempt + 1))
    log("WARN: could not fetch %s (%s)" % (url, last))
    return None


# ---------------------------------------------------------------------------
# decoding helpers
# ---------------------------------------------------------------------------
def words(hexstr):
    """Split ABI return data into 32-byte words (ints). None if malformed."""
    if not isinstance(hexstr, str) or not hexstr.startswith("0x"):
        return None
    h = hexstr[2:]
    if not h or len(h) % 64 != 0:
        return None
    try:
        return [int(h[i:i + 64], 16) for i in range(0, len(h), 64)]
    except ValueError:
        return None


def as_addr(word):
    return "0x%040x" % (word & MASK160)


def dec_string(hexstr):
    """Decode ABI string return: offset word, length word, bytes (bytes32 ok)."""
    if not isinstance(hexstr, str) or not hexstr.startswith("0x"):
        return None
    h = hexstr[2:]
    if not h:
        return ""
    try:
        raw = bytes.fromhex(h)
    except ValueError:
        return None
    if len(raw) == 32:  # bytes32-style symbol
        return raw.rstrip(b"\x00").decode("utf-8", "replace")
    if len(raw) < 64:
        return None
    off = int.from_bytes(raw[0:32], "big")  # offset word
    if 32 <= off <= len(raw) - 32:
        ln = int.from_bytes(raw[off:off + 32], "big")  # length word
        if 0 <= ln <= len(raw) - off - 32:
            txt = raw[off + 32:off + 32 + ln].decode("utf-8", "replace").strip("\x00")
            if txt:
                return txt
    # fallback: first word treated as length (non-standard)
    ln = int.from_bytes(raw[0:32], "big")
    if 0 < ln <= len(raw) - 32:
        return raw[32:32 + ln].decode("utf-8", "replace").strip("\x00")
    return None


def encode_uint256(x):
    return "%064x" % x


def encode_address(addr):
    a = addr.lower()
    if a.startswith("0x"):
        a = a[2:]
    return a.rjust(64, "0")


def human(raw, decimals):
    """Exact decimal string (or None)."""
    if raw is None or decimals is None:
        return None
    q = Decimal(raw) / (Decimal(10) ** decimals)
    return format(q.normalize(), "f")


def pct(num, den):
    if num is None or den is None or den == 0:
        return None
    q = (Decimal(num) / Decimal(den)) * 100
    return format(q.quantize(Decimal("0.000001")), "f")


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    t_start = time.time()
    notes = []

    # ---- 0. head, chain, block header, factory code ------------------------
    head = rpc_batch([
        {"method": "eth_chainId", "params": []},
        {"method": "eth_blockNumber", "params": []},
    ], stage="head")
    chain_id = int(head[0][1], 16) if head[0][0] else None
    block_hex = head[1][1] if head[1][0] else "latest"
    block_num = int(block_hex, 16) if isinstance(block_hex, str) and block_hex.startswith("0x") else None
    log("[head] chain_id=%s block=%s (%s)" % (chain_id, block_num, block_hex))

    meta = rpc_batch([
        {"method": "eth_getBlockByNumber", "params": [block_hex, False]},
        {"method": "eth_getCode", "params": [FACTORY, "latest"]},
    ], stage="meta")
    blk = meta[0][1] if (meta[0][0] and isinstance(meta[0][1], dict)) else {}
    factory_code = meta[1][1] if meta[1][0] else "0x"
    code_size = len(factory_code) // 2 if isinstance(factory_code, str) else 0

    # pick block tag for all eth_calls (pin the fresh head; fall back to latest)
    block_tag = block_hex
    probe = rpc_batch(
        [{"method": "eth_call",
          "params": [{"to": FACTORY, "data": SEL_ALL_PAIRS_LENGTH}, block_hex]}],
        stage="probe-pinned",
    )
    if not (probe[0][0] and isinstance(probe[0][1], str)):
        block_tag = "latest"
        notes.append("eth_call with pinned block tag failed (%s); used 'latest'"
                     % (probe[0][1],))
    log("[meta] block_hash=%s ts=%s factory_code_size=%d block_tag=%s"
        % (blk.get("hash"), blk.get("timestamp"), code_size, block_tag))

    # ---- 1. allPairsLength + allPairs(i) -----------------------------------
    r = eth_calls([(FACTORY, SEL_ALL_PAIRS_LENGTH)], block_tag, stage="allPairsLength")
    w = words(r[0][1]) if r[0][0] else None
    n_pairs = w[0] if w else None
    if n_pairs is None:
        raise RuntimeError("could not read allPairsLength: %s" % (r[0],))
    log("[factory] allPairsLength = %d" % n_pairs)

    items = [(FACTORY, SEL_ALL_PAIRS + encode_uint256(i)) for i in range(n_pairs)]
    res = eth_calls(items, block_tag, stage="allPairs")
    pair_addrs = []
    for i, (ok, v) in enumerate(res):
        w = words(v) if ok else None
        pair_addrs.append(as_addr(w[0]) if w else None)
    bad = [i for i, a in enumerate(pair_addrs) if a is None]
    if bad:
        notes.append("allPairs(i) failed for indexes: %s" % bad)
    log("[factory] fetched %d pair addresses (%d failures)" % (len(pair_addrs), len(bad)))

    # ---- 2a. token0 / token1 / getReserves for every pair -------------------
    items, idx_map = [], []
    for pi, a in enumerate(pair_addrs):
        if a is None:
            continue
        for kind, sel in (("token0", SEL_TOKEN0), ("token1", SEL_TOKEN1),
                          ("reserves", SEL_GET_RESERVES)):
            items.append((a, sel))
            idx_map.append((pi, kind))
    res = eth_calls(items, block_tag, stage="pair-basics")

    pairs_raw = []
    for a in pair_addrs:
        pairs_raw.append({
            "pair": a, "token0": None, "token1": None,
            "r0": None, "r1": None, "ts": None,
            "bal0": None, "bal1": None,
            "bal_wprom_x": None, "bal_usdt_x": None,
        })
    for (pi, kind), (ok, v) in zip(idx_map, res):
        if not ok:
            continue
        w = words(v)
        if w is None:
            continue
        pr = pairs_raw[pi]
        if kind == "token0":
            pr["token0"] = as_addr(w[0])
        elif kind == "token1":
            pr["token1"] = as_addr(w[0])
        elif kind == "reserves" and len(w) >= 2:
            pr["r0"], pr["r1"] = w[0], w[1]
            pr["ts"] = w[2] if len(w) >= 3 else None
    log("[pairs] token0/token1/getReserves done")

    # ---- 2b. balanceOf(pair) per token (+ cross-check WPROM/USDT everywhere) -
    items, idx_map = [], []
    for pi, pr in enumerate(pairs_raw):
        a = pr["pair"]
        if a is None:
            continue
        seen = set()
        for kind, tok in (("bal0", pr["token0"]), ("bal1", pr["token1"])):
            if tok and tok not in seen:
                items.append((tok, SEL_BALANCE_OF + encode_address(a)))
                idx_map.append((pi, kind))
                seen.add(tok)
        if WPROM not in (pr["token0"], pr["token1"]):
            items.append((WPROM, SEL_BALANCE_OF + encode_address(a)))
            idx_map.append((pi, "bal_wprom_x"))
        if USDT not in (pr["token0"], pr["token1"]):
            items.append((USDT, SEL_BALANCE_OF + encode_address(a)))
            idx_map.append((pi, "bal_usdt_x"))
    res = eth_calls(items, block_tag, stage="balances")
    for (pi, kind), (ok, v) in zip(idx_map, res):
        w = words(v) if ok else None
        if w is not None:
            pairs_raw[pi][kind] = w[0]
    log("[pairs] balanceOf done")

    # ---- 2c. symbol()/decimals() for every unique token ---------------------
    tok_set = set()
    for pr in pairs_raw:
        for t in (pr["token0"], pr["token1"]):
            if t:
                tok_set.add(t)
    tok_set.add(WPROM)
    tok_set.add(USDT)
    tok_list = sorted(tok_set)
    items = []
    for t in tok_list:
        items.append((t, SEL_SYMBOL))
        items.append((t, SEL_DECIMALS))
    res = eth_calls(items, block_tag, stage="token-meta")
    tok_meta = {}
    for i, t in enumerate(tok_list):
        ok_s, v_s = res[2 * i]
        ok_d, v_d = res[2 * i + 1]
        sym = dec_string(v_s) if ok_s else None
        w = words(v_d) if ok_d else None
        dec = w[0] if (w and w[0] <= 36) else None
        tok_meta[t] = {"symbol": sym, "decimals": dec}
    log("[tokens] metadata for %d unique tokens" % len(tok_list))

    # ---- 3/4. totals + excess checks ---------------------------------------
    tot_wprom = 0
    tot_usdt = 0
    tot_wprom_res = 0
    tot_usdt_res = 0
    n_pairs_wprom = 0
    n_pairs_usdt = 0
    excess = []
    pairs_out = []

    for pi, pr in enumerate(pairs_raw):
        a = pr["pair"]
        t0, t1 = pr["token0"], pr["token1"]
        r0, r1 = pr["r0"], pr["r1"]
        b0 = pr["bal0"]
        b1 = pr["bal1"]
        if t0 is not None and t0 == t1:
            b1 = b0  # degenerate duplicate-token pair; single call suffices
        m0 = tok_meta.get(t0, {})
        m1 = tok_meta.get(t1, {})
        d0, d1 = m0.get("decimals"), m1.get("decimals")

        # WPROM / USDT held by this pair
        if t0 == WPROM:
            wprom_hold, wprom_side = b0, "token0"
        elif t1 == WPROM:
            wprom_hold, wprom_side = b1, "token1"
        else:
            wprom_hold, wprom_side = pr["bal_wprom_x"], "external"
        if t0 == USDT:
            usdt_hold, usdt_side = b0, "token0"
        elif t1 == USDT:
            usdt_hold, usdt_side = b1, "token1"
        else:
            usdt_hold, usdt_side = pr["bal_usdt_x"], "external"

        if a is not None:
            if wprom_hold:
                tot_wprom += wprom_hold
            if usdt_hold:
                tot_usdt += usdt_hold
            if t0 == WPROM and r0 is not None:
                tot_wprom_res += r0
            if t1 == WPROM and r1 is not None:
                tot_wprom_res += r1
            if t0 == USDT and r0 is not None:
                tot_usdt_res += r0
            if t1 == USDT and r1 is not None:
                tot_usdt_res += r1
            if WPROM in (t0, t1):
                n_pairs_wprom += 1
            if USDT in (t0, t1):
                n_pairs_usdt += 1

            # excess vs reserves (per side)
            for side, tok, resv, bal in (("token0", t0, r0, b0), ("token1", t1, r1, b1)):
                if tok is None or resv is None or bal is None:
                    continue
                if bal != resv:
                    excess.append({
                        "pair": a, "pair_index": pi, "side": side, "token": tok,
                        "symbol": (tok_meta.get(tok) or {}).get("symbol"),
                        "balanceOf_pair_raw": bal, "getReserves_raw": resv,
                        "delta_raw": bal - resv,
                        "excess_skimable": bal > resv,
                    })

        pairs_out.append({
            "index": pi,
            "pair": a,
            "token0": {
                "address": t0,
                "symbol": m0.get("symbol"),
                "decimals": d0,
                "reserve_raw": r0,
                "reserve_human": human(r0, d0),
                "balanceOf_pair_raw": b0,
                "balanceOf_pair_human": human(b0, d0),
            },
            "token1": {
                "address": t1,
                "symbol": m1.get("symbol"),
                "decimals": d1,
                "reserve_raw": r1,
                "reserve_human": human(r1, d1),
                "balanceOf_pair_raw": b1,
                "balanceOf_pair_human": human(b1, d1),
            },
            "getReserves_blockTimestampLast": pr["ts"],
            "wprom_held_raw": wprom_hold,
            "wprom_hold_side": wprom_side if wprom_hold is not None else None,
            "usdt_held_raw": usdt_hold,
        })

    tot_wprom_h = human(tot_wprom, 18)
    tot_usdt_h = human(tot_usdt, 6)
    log("[totals] WPROM=%s (raw %d)  USDT=%s (raw %d)"
        % (tot_wprom_h, tot_wprom, tot_usdt_h, tot_usdt))
    log("[excess] pairs with balanceOf != getReserves: %d" % len(excess))

    # ---- 5. top 10 pairs by WPROM amount ------------------------------------
    holders = [
        p for p in pairs_out
        if p["wprom_held_raw"] is not None and p["wprom_held_raw"] > 0
    ]
    holders.sort(key=lambda p: p["wprom_held_raw"], reverse=True)
    top10 = []
    for p in holders[:10]:
        d0 = p["token0"]["decimals"]
        d1 = p["token1"]["decimals"]
        top10.append({
            "pair": p["pair"],
            "token0_symbol": p["token0"]["symbol"],
            "token1_symbol": p["token1"]["symbol"],
            "wprom_held_human": human(p["wprom_held_raw"], 18),
            "wprom_hold_side": p["wprom_hold_side"],
            "reserve0_human": p["token0"]["reserve_human"],
            "reserve1_human": p["token1"]["reserve_human"],
            "reserve0_raw": p["token0"]["reserve_raw"],
            "reserve1_raw": p["token1"]["reserve_raw"],
        })
    log("[top10] computed")

    # ---- 6. main pair LP shares ---------------------------------------------
    items = [(MAIN_PAIR, SEL_TOTAL_SUPPLY)]
    for h in LP_HOLDERS:
        items.append((MAIN_PAIR, SEL_BALANCE_OF + encode_address(h)))
    res = eth_calls(items, block_tag, stage="main-pair-lp")
    w = words(res[0][1]) if res[0][0] else None
    lp_total_supply = w[0] if w else None
    lp_balances = []
    for i, h in enumerate(LP_HOLDERS):
        ok, v = res[1 + i]
        w = words(v) if ok else None
        lp_balances.append(w[0] if w else None)

    main_pair_rec = next(
        (p for p in pairs_out if p["pair"] and p["pair"].lower() == MAIN_PAIR.lower()),
        None,
    )
    lp_holders_out = []
    for h, bal in zip(LP_HOLDERS, lp_balances):
        lp_holders_out.append({
            "address": h,
            "balanceOf_raw": bal,
            "share_pct": pct(bal, lp_total_supply),
        })
    main_pair_out = {
        "address": MAIN_PAIR,
        "in_factory": main_pair_rec is not None,
        "record": main_pair_rec,
        "totalSupply_raw": lp_total_supply,
        "lp_holders": lp_holders_out,
    }
    log("[main-pair] totalSupply=%s shares=%s"
        % (lp_total_supply, [x["share_pct"] for x in lp_holders_out]))

    # ---- 7. price + USD totals ----------------------------------------------
    price_json = fetch_json(PRICE_URL)
    price_coin = (price_json or {}).get("coins", {}).get("coingecko:prometeus")
    prom_price = price_coin.get("price") if price_coin else None
    usdt_price_json = fetch_json(USDT_PRICE_URL)
    usdt_coin = (usdt_price_json or {}).get("coins", {}).get("coingecko:tether")
    usdt_price = usdt_coin.get("price") if usdt_coin else None

    total_usd = None
    total_usd_usdt1 = None
    if prom_price is not None:
        wprom_usd = Decimal(tot_wprom) / (Decimal(10) ** 18) * Decimal(str(prom_price))
        usdt_usd = Decimal(tot_usdt) / (Decimal(10) ** 6) * Decimal(str(usdt_price if usdt_price else 1))
        wprom_usd1 = Decimal(tot_wprom) / (Decimal(10) ** 18) * Decimal(str(prom_price))
        usdt_usd1 = Decimal(tot_usdt) / (Decimal(10) ** 6)
        total_usd = float(wprom_usd + usdt_usd)               # USDT at DefiLlama price
        total_usd_usdt1 = float(wprom_usd1 + usdt_usd1)       # USDT at $1
    log("[price] PROM=$%s USDT=$%s -> total $%s (USDT@1: $%s)"
        % (prom_price, usdt_price, total_usd, total_usd_usdt1))

    # ---- 8. compare with parent claims --------------------------------------
    main_wprom = main_pair_rec["token0"] if (main_pair_rec and main_pair_rec["token0"]["address"] == WPROM) else (
        main_pair_rec["token1"] if main_pair_rec else None)
    main_usdt = main_pair_rec["token0"] if (main_pair_rec and main_pair_rec["token0"]["address"] == USDT) else (
        main_pair_rec["token1"] if main_pair_rec else None)
    main_wprom_h = main_wprom["reserve_human"] if main_wprom else None
    main_usdt_h = main_usdt["reserve_human"] if main_usdt else None

    def rel_diff(mine, parent):
        try:
            return float((Decimal(str(mine)) - Decimal(str(parent))) / Decimal(str(parent)) * 100)
        except Exception:
            return None

    comparison = {
        "parent_claim": PARENT_CLAIM,
        "computed": {
            "pair_count": n_pairs,
            "total_wprom": tot_wprom_h,
            "total_usdt": tot_usdt_h,
            "prom_price_usd": prom_price,
            "usdt_price_usd": usdt_price,
            "total_usd": total_usd,
            "total_usd_if_usdt_eq_1": total_usd_usdt1,
            "excess_count": len(excess),
            "main_pair_wprom_reserve": main_wprom_h,
            "main_pair_usdt_reserve": main_usdt_h,
            "main_pair_lp_share_pct_first": lp_holders_out[0]["share_pct"] if lp_holders_out else None,
        },
        "diffs": {
            "total_usd_pct_vs_parent": rel_diff(total_usd, PARENT_CLAIM["total_usd"]) if total_usd is not None else None,
            "pair_count_vs_parent": (n_pairs - PARENT_CLAIM["pair_count"]) if n_pairs is not None else None,
            "main_pair_wprom_pct_vs_parent": rel_diff(main_wprom_h, PARENT_CLAIM["main_pair_wprom"]) if main_wprom_h else None,
            "main_pair_usdt_pct_vs_parent": rel_diff(main_usdt_h, PARENT_CLAIM["main_pair_usdt"]) if main_usdt_h else None,
        },
    }

    # ---- token_totals (informational: all tokens summed across pairs) --------
    token_totals = {}
    for p in pairs_out:
        for side in ("token0", "token1"):
            t = p[side]
            if not t["address"]:
                continue
            rec = token_totals.setdefault(t["address"], {
                "address": t["address"], "symbol": t["symbol"],
                "decimals": t["decimals"], "total_raw": 0, "pairs": 0,
            })
            if t["balanceOf_pair_raw"] is not None:
                rec["total_raw"] += t["balanceOf_pair_raw"]
                rec["pairs"] += 1
    for rec in token_totals.values():
        rec["total_human"] = human(rec["total_raw"], rec["decimals"])
    token_totals_list = sorted(token_totals.values(), key=lambda r: r["total_raw"], reverse=True)

    # ---- write results --------------------------------------------------------
    results = {
        "meta": {
            "description": "childA independent verification of savmSwap (Prom chain) holdings",
            "rpc_url": RPC_URL,
            "chain_id": chain_id,
            "block_number": block_num,
            "block_hash": blk.get("hash"),
            "block_timestamp": int(blk["timestamp"], 16) if blk.get("timestamp") else None,
            "block_tag_used_for_eth_calls": block_tag,
            "factory": FACTORY,
            "factory_code_size_bytes": code_size,
            "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "elapsed_seconds": round(time.time() - t_start, 1),
            "notes": notes,
        },
        "summary": {
            "pair_count": n_pairs,
            "pairs_containing_wprom": n_pairs_wprom,
            "pairs_containing_usdt": n_pairs_usdt,
            "total_wprom_raw": tot_wprom,
            "total_wprom": tot_wprom_h,
            "total_usdt_raw": tot_usdt,
            "total_usdt": tot_usdt_h,
            "total_wprom_reserves_only_raw": tot_wprom_res,
            "total_usdt_reserves_only_raw": tot_usdt_res,
            "prom_price_usd": prom_price,
            "prom_price_source": PRICE_URL,
            "usdt_price_usd": usdt_price,
            "usdt_price_source": USDT_PRICE_URL,
            "total_usd": total_usd,
            "total_usd_if_usdt_eq_1": total_usd_usdt1,
            "excess_pair_count": len(excess),
            "main_pair_lp_first_holder_share_pct": lp_holders_out[0]["share_pct"] if lp_holders_out else None,
        },
        "pairs": pairs_out,
        "excess": excess,
        "top10_by_wprom": top10,
        "main_pair": main_pair_out,
        "token_totals": token_totals_list,
        "parent_claim_comparison": comparison,
    }
    with open(RESULTS_PATH, "w") as f:
        json.dump(results, f, indent=2)
    log("[done] wrote %s in %.1fs" % (RESULTS_PATH, time.time() - t_start))

    # concise stdout recap
    log("")
    log("==== childA-verify recap (block %s) ====" % block_num)
    log("pairs: %s | WPROM total: %s | USDT total: %s" % (n_pairs, tot_wprom_h, tot_usdt_h))
    log("PROM price: %s | total USD: %s" % (prom_price, total_usd))
    log("excess (balanceOf != getReserves): %d" % len(excess))
    log("main pair WPROM/USDT: %s / %s" % (main_wprom_h, main_usdt_h))
    log("main pair LP shares: %s" % [x["share_pct"] for x in lp_holders_out])


if __name__ == "__main__":
    main()
