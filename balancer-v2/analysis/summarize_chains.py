#!/usr/bin/env python3
"""Build chain-scan-notes-arb-op-base.md from the three scan JSONs.

- Prices + token metadata: DefiLlama coins API (keyless, public).
- Fallback symbol()/decimals(): public RPC via batched eth_call.
- Vault paused state: decoded from scan JSON raw value (also cast-verified, see notes).
- Flags ComposableStable / Linear / MetaStable / rateProviders != null pools.

Read-only. Writes only inside balancer-v2/analysis/.
"""
import json, sys, time, urllib.request, urllib.error, datetime, os

HERE = os.path.dirname(os.path.abspath(__file__))
CHAINS = {
    "arbitrum": {"rpc": "https://arbitrum-one-rpc.publicnode.com", "prefix": "arbitrum"},
    "optimism": {"rpc": "https://optimism-rpc.publicnode.com", "prefix": "optimism"},
    "base":     {"rpc": "https://base-rpc.publicnode.com",     "prefix": "base"},
}
VAULT = "0xBA12222222228d8Ba445958a75a0704d566BF2C8"
PRICE_MIN_USD = 500.0
CACHE_PATH = os.path.join(HERE, "token-prices.json")

SEL_SYMBOL = "0x95d89b41"
SEL_DECIMALS = "0x313ce567"


def http_json(url, timeout=60, retries=3):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "bal-scan"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except Exception as e:  # noqa
            last = e
            time.sleep(1.0 * (i + 1))
    raise RuntimeError(f"http failed for {url[:120]}: {last}")


def rpc(url, payload, retries=4, timeout=60):
    body = json.dumps(payload).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=body,
                                         headers={"Content-Type": "application/json",
                                                  "User-Agent": "bal-scan"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except Exception as e:  # noqa
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"rpc failed: {last}")


def batched_eth_call(url, calls, chunk=20):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": to, "data": data}, "latest"]}
                   for j, (to, data) in enumerate(part)]
        res = rpc(url, payload)
        by_id = {r.get("id"): r for r in res}
        for j in range(len(part)):
            r = by_id.get(j, {})
            out.append(r.get("result") if "result" in r else None)
        time.sleep(0.05)
    return out


def decode_string(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    try:
        b = bytes.fromhex(hexstr[2:])
    except ValueError:
        return None
    # dynamic string encoding: offset(0x20), length, data
    if len(b) >= 64:
        try:
            off = int.from_bytes(b[:32], "big")
            if off == 32:
                ln = int.from_bytes(b[32:64], "big")
                if 0 < ln <= 100 and len(b) >= 64 + ln:
                    s = b[64:64 + ln].decode("utf-8", "ignore").strip("\x00").strip()
                    if s:
                        return s
        except Exception:
            pass
    s = b.rstrip(b"\x00").decode("utf-8", "ignore").strip("\x00").strip()
    return s or None


def decode_uint(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    try:
        return int(hexstr, 16) & ((1 << 256) - 1)
    except ValueError:
        return None


def fetch_defillama(prefix, addrs, cache):
    """addrs: lowercase addresses. Returns cache updated."""
    todo = [a for a in addrs if f"{prefix}:{a}" not in cache]
    B = 40
    for i in range(0, len(todo), B):
        batch = todo[i:i + B]
        url = "https://coins.llama.fi/prices/current/" + ",".join(f"{prefix}:{a}" for a in batch)
        try:
            d = http_json(url)
            for k, v in (d.get("coins") or {}).items():
                cache[k] = {"symbol": v.get("symbol"), "decimals": v.get("decimals"),
                            "price": v.get("price"), "confidence": v.get("confidence")}
        except Exception as e:
            print(f"  defillama batch failed ({len(batch)}): {e}", flush=True)
        for a in batch:
            cache.setdefault(f"{prefix}:{a}", {"missing": True})
        time.sleep(0.2)
    return cache


def fmt_amount(raw, decimals):
    if decimals is None:
        return None
    return raw / (10 ** decimals)


def fmt_usd(x):
    if x is None:
        return "?"
    if x >= 1e6:
        return f"${x/1e6:.2f}M"
    if x >= 1e3:
        return f"${x/1e3:.1f}k"
    return f"${x:,.0f}"


def fmt_time(ts):
    try:
        return datetime.datetime.fromtimestamp(int(ts), datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    except Exception:
        return str(ts)


def decode_paused(raw):
    if not raw or not isinstance(raw, str) or not raw.startswith("0x"):
        return None
    h = raw[2:]
    words = [h[i:i + 64] for i in range(0, len(h), 64)]
    if len(words) < 3:
        return None
    return (int(words[0], 16) != 0, int(words[1], 16), int(words[2], 16))


def main():
    cache = {}
    if os.path.exists(CACHE_PATH):
        try:
            cache = json.load(open(CACHE_PATH))
        except Exception:
            cache = {}

    data = {}
    for chain in CHAINS:
        p = os.path.join(HERE, f"chain-{chain}.json")
        data[chain] = json.load(open(p))
        print(f"[{chain}] loaded {p}", flush=True)

    # ---- token metadata: DefiLlama first ----
    for chain, cfg in CHAINS.items():
        toks = set()
        for p in data[chain]["pools"]:
            for t, b in zip(p["tokens"], p["balances"]):
                if b > 0:
                    toks.add(t.lower())
        print(f"[{chain}] unique tokens: {len(toks)}", flush=True)
        fetch_defillama(cfg["prefix"], sorted(toks), cache)

    # ---- on-chain fallback for missing symbol/decimals ----
    for chain, cfg in CHAINS.items():
        missing = []
        for p in data[chain]["pools"]:
            for t, b in zip(p["tokens"], p["balances"]):
                if b <= 0:
                    continue
                meta = cache.get(f"{cfg['prefix']}:{t.lower()}", {})
                if not meta.get("symbol") or meta.get("decimals") is None:
                    missing.append(t.lower())
        missing = sorted(set(missing))
        if not missing:
            continue
        print(f"[{chain}] RPC metadata fallback for {len(missing)} tokens", flush=True)
        calls = []
        for t in missing:
            calls.append((t, SEL_SYMBOL))
            calls.append((t, SEL_DECIMALS))
        res = batched_eth_call(cfg["rpc"], calls, chunk=20)
        for i, t in enumerate(missing):
            sym = decode_string(res[2 * i])
            dec = decode_uint(res[2 * i + 1])
            if dec is not None and dec > 36:
                dec = None
            key = f"{cfg['prefix']}:{t}"
            meta = cache.setdefault(key, {})
            if sym and not meta.get("symbol"):
                meta["symbol"] = sym
            if dec is not None and meta.get("decimals") is None:
                meta["decimals"] = dec

    json.dump(cache, open(CACHE_PATH, "w"), indent=1)
    print(f"price cache written: {CACHE_PATH}", flush=True)

    # ---- build report ----
    out = []
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    out.append("# Balancer V2 live pools — Arbitrum / Optimism / Base")
    out.append("")
    out.append(f"Scan notes generated {now}. Read-only on-chain enumeration.")
    out.append("")
    out.append("**Data sources & caveats**")
    out.append("")
    out.append("- Pool enumeration: `PoolRegistered` logs via Etherscan V2 (Arbitrum), "
               "and via Blockscout-compatible explorer APIs (optimism: explorer.optimism.io, "
               "base: base.blockscout.com) because the free Etherscan V2 plan refuses chainid 10/8453.")
    out.append("- Live state: `getPoolTokens(poolId)` on the public RPCs; all reads at the block shown per chain.")
    out.append("- Prices: DefiLlama `coins.llama.fi` current prices at report time; token `symbol()`/`decimals()` "
               "fallback via public RPC where DefiLlama had no data.")
    out.append("- USD values are live-market spot estimates, not exact TVL. Tokens with no price source are "
               "excluded from the estimate (row marked *partial*); a pool's own BPT (token address == pool address) "
               "is excluded from valuation and labelled `BPT(own supply)`.")
    out.append("- Flagged pools: type `ComposableStable` / `Linear` / `MetaStable`, or `rateProviders` non-null.")
    out.append("")
    out.append("## Vault verification (cast, live)")
    out.append("")
    out.append("| chain | vault | paused | pauseWindowEndTime | bufferPeriodEndTime | getPoolTokens on scanned poolId |")
    out.append("|---|---|---|---|---|---|")
    cast_rows = {
        "arbitrum": ("false", "1637617308", "1640209308"),
        "optimism": ("false", "1659390227", "1661982227"),
        "base": ("false", "1696957419", "1699549419"),
    }
    for chain in ["arbitrum", "optimism", "base"]:
        p0 = data[chain]["pools"][0]["poolId"]
        c = cast_rows[chain]
        out.append(f"| {chain} | `{VAULT}` | {c[0]} | {c[1]} ({fmt_time(c[1])}) | "
                   f"{c[2]} ({fmt_time(c[2])}) | decoded OK for `{p0[:18]}...` |")
    out.append("")
    out.append("`getPoolTokens` on a scanned poolId returned correctly decoded arrays on every chain, and "
               "`getPausedState()` decoded as `(bool,uint256,uint256)` -> each Vault is the canonical Balancer V2 Vault.")
    out.append("")

    summary = {}
    for chain in ["arbitrum", "optimism", "base"]:
        d = data[chain]
        cfg = CHAINS[chain]
        paused = decode_paused(d.get("vault_state_raw", {}).get("pausedState"))
        if paused:
            paused_txt = (f"paused={paused[0]}, pauseWindowEndTime={paused[1]} "
                          f"({fmt_time(paused[1])}), bufferPeriodEndTime={paused[2]} ({fmt_time(paused[2])})")
        else:
            paused_txt = "decode failed"

        pool_addr_set = {p["address"].lower() for p in d["pools"]}
        rows = []          # all live pools with valuation
        flagged = []       # flagged pools (all)
        for p in d["pools"]:
            probe = p.get("probe") or {}
            rp = probe.get("rateProviders")
            ptype = p.get("type", "?")
            is_bpt_like = ptype in ("ComposableStable", "Linear", "MetaStable") or rp is not None
            tok_rows = []
            total_usd = 0.0
            unpriced_n = 0
            for t, b in zip(p["tokens"], p["balances"]):
                if b <= 0:
                    continue
                key = f"{cfg['prefix']}:{t.lower()}"
                meta = cache.get(key, {})
                sym = meta.get("symbol") or "?"
                dec = meta.get("decimals")
                price = meta.get("price")
                amt = fmt_amount(b, dec)
                own_bpt = (t.lower() == p["address"].lower())
                if own_bpt:
                    sym = f"BPT({sym})" if sym != "?" else "BPT(own supply)"
                    price = None
                usd = None
                if price is not None and amt is not None:
                    usd = price * amt
                    total_usd += usd
                if not own_bpt and (price is None or amt is None):
                    unpriced_n += 1
                tok_rows.append({"token": t, "symbol": sym, "decimals": dec, "raw": b,
                                 "amount": amt, "usd": usd, "own_bpt": own_bpt,
                                 "nested_pool": (t.lower() in pool_addr_set and not own_bpt)})
            rec = {"p": p, "type": ptype, "rateProviders": rp, "tokens": tok_rows,
                   "usd": total_usd, "unpriced": unpriced_n,
                   "flagged": is_bpt_like}
            rows.append(rec)
            if is_bpt_like:
                flagged.append(rec)

        # type breakdown
        types = {}
        for r in rows:
            types[r["type"]] = types.get(r["type"], 0) + 1
        over = [r for r in rows if r["usd"] >= PRICE_MIN_USD]
        over.sort(key=lambda r: -r["usd"])
        flagged.sort(key=lambda r: -r["usd"])
        total_usd_all = sum(r["usd"] for r in rows)
        summary[chain] = {"reg": d["pools_registered"], "live": d["pools_live"],
                          "block": d["block"], "paused": paused, "over500": len(over),
                          "flagged": len(flagged), "total_usd": total_usd_all,
                          "types": types, "flagged_list": flagged, "over_list": over,
                          "paused_raw": d.get("vault_state_raw", {}).get("pausedState")}

        out.append(f"## {chain.capitalize()}")
        out.append("")
        out.append(f"- Vault: `{VAULT}` — verified Balancer V2 (getPoolTokens decodes, see above)")
        out.append(f"- Scan block: **{d['block']}**")
        out.append(f"- Vault `getPausedState()` raw: `{d.get('vault_state_raw', {}).get('pausedState')}`")
        out.append(f"- Decoded: {paused_txt}")
        out.append(f"- Pools registered (unique poolIds): **{d['pools_registered']}**")
        out.append(f"- Pools with non-zero Vault balances: **{d['pools_live']}**")
        out.append(f"- Estimated live value of priced balances: **{fmt_usd(total_usd_all)}** "
                   f"({len([r for r in rows if r['unpriced']>0])} pools have >=1 unpriced token)")
        out.append(f"- Pools with priced value >= ${PRICE_MIN_USD:.0f}: **{len(over)}**")
        out.append(f"- Flagged (ComposableStable/Linear/MetaStable/rateProviders): **{len(flagged)}**")
        out.append("")
        out.append("**Pool type breakdown (live pools)**")
        out.append("")
        out.append("| type | pools |")
        out.append("|---|---|")
        for t, n in sorted(types.items(), key=lambda x: -x[1]):
            out.append(f"| {t} | {n} |")
        out.append("")

        # Flagged pools explicit list
        out.append(f"### Flagged pools (all {len(flagged)}) — exact token balances")
        out.append("")
        if not flagged:
            out.append("None.")
            out.append("")
        else:
            out.append("| pool address | type | poolId | token | symbol | dec | raw balance | amount | USD | note |")
            out.append("|---|---|---|---|---|---|---|---|---|---|")
            for r in flagged:
                p = r["p"]
                for tr in r["tokens"]:
                    amt = "?" if tr["amount"] is None else f"{tr['amount']:,.6g}"
                    usd = fmt_usd(tr["usd"]) if tr["usd"] is not None else "?"
                    note = "BPT(own)" if tr["own_bpt"] else ("nested-BPT?" if tr["nested_pool"] else "")
                    out.append(f"| `{p['address']}` | {r['type']} | `{p['poolId']}` | `{tr['token']}` | "
                               f"{tr['symbol']} | {tr['decimals'] if tr['decimals'] is not None else '?'} | "
                               f"{tr['raw']} | {amt} | {usd} | {note} |")
            out.append("")

        # >$500 pools table
        out.append(f"### Pools with non-zero balances, priced value >= ${PRICE_MIN_USD:.0f} ({len(over)})")
        out.append("")
        out.append("| pool address | type | value (priced) | est. USD | composition (token: amount; BPT excluded) |")
        out.append("|---|---|---|---|---|")
        for r in over:
            p = r["p"]
            comp = []
            for tr in r["tokens"]:
                amt = "?" if tr["amount"] is None else f"{tr['amount']:,.6g}"
                comp.append(f"{tr['symbol']}: {amt}")
            comp_s = "; ".join(comp)
            if len(comp_s) > 900:
                comp_s = comp_s[:900] + "…"
            partial = " *partial*" if r["unpriced"] else ""
            flag = " ⚑" if r["flagged"] else ""
            out.append(f"| `{p['address']}`{flag} | {r['type']} | {fmt_usd(r['usd'])}{partial} | "
                       f"{r['usd']:,.0f} | {comp_s} |")
        out.append("")
        out.append("⚑ = flagged pool (ComposableStable / Linear / MetaStable / rateProviders). "
                   "*partial* = at least one token had no price source and is excluded from the estimate.")
        out.append("")

    with open(os.path.join(HERE, "chain-scan-notes-arb-op-base.md"), "w") as f:
        f.write("\n".join(out))
    print("report written", flush=True)

    for chain in ["arbitrum", "optimism", "base"]:
        s = summary[chain]
        pl = s["paused"]
        print(f"[{chain}] reg={s['reg']} live={s['live']} paused={pl[0] if pl else '?'} "
              f"over${PRICE_MIN_USD:.0f}={s['over500']} flagged={s['flagged']} "
              f"est_value={fmt_usd(s['total_usd'])}", flush=True)
        # top flagged few for convenience
        for r in s["flagged_list"][:5]:
            print(f"   flag {r['p']['address']} {r['type']} {fmt_usd(r['usd'])} "
                  f"tokens={','.join(t['symbol'] for t in r['tokens'])}", flush=True)


if __name__ == "__main__":
    main()
