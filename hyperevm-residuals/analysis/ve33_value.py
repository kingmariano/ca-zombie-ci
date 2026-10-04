#!/usr/bin/env python3
"""Aggregate Hybra ve33 system value (non-pool) with on-chain decimals + DefiLlama prices.
Input: ve33_probe.json. Output: ve33_value.json (+ console report)."""
import json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ve33_rpc as rp

D = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(D, "ve33_probe.json")))
BLK = d["block"]
SIG = json.load(open(os.path.join(D, "sigs.json")))

MAJORS = {
    "HYBR": "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8",
    "WHYPE": "0x5555555555555555555555555555555555555555",
    "USDC": "0xb88339cb7199b77e23db6e890353e22632ba630f",
    "USDT0": "0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb",
    "kHYPE": "0xfd739d4e423301ce9385c1fb8850539d657c296d",
    "UBTC": "0x9fdbda0a5e284c32744d2f17ee5c74b284993463",
    "UETH": "0xbe6727b535545c67d5caa73dea54865b92cf7907",
}
KNOWN_DEC = {
    "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8": 18,
    "0x5555555555555555555555555555555555555555": 18,
    "0xb88339cb7199b77e23db6e890353e22632ba630f": 6,
    "0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb": 6,
    "0xfd739d4e423301ce9385c1fb8850539d657c296d": 18,
    "0x9fdbda0a5e284c32744d2f17ee5c74b284993463": 8,
    "0xbe6727b535545c67d5caa73dea54865b92cf7907": 18,
}

def du(o):
    return int(o, 16) if o and o != "0x" else None

def ds(o):
    if not o or o == "0x":
        return None
    b = bytes.fromhex(o[2:])
    try:
        off = int.from_bytes(b[0:32], "big"); ln = int.from_bytes(b[off:off + 32], "big")
        return b[off + 32:off + 32 + ln].decode(errors="replace")
    except Exception:
        try:
            return b.rstrip(b"\x00").decode(errors="replace")
        except Exception:
            return None

def main():
    # token universe
    toks = set(MAJORS.values())
    for g, info in d["gauges"].items():
        for tag, b in (info.get("balances") or {}).items():
            if b.get("token"):
                toks.add(b["token"].lower())
        cp = (info.get("clPool()") or "").lower()
        if cp in d.get("pools", {}):
            for tk in ("token0", "token1"):
                t = d["pools"][cp].get(tk)
                if t:
                    toks.add(t.lower())
    for b, info in d["bribes"].items():
        for t in (info.get("balances") or {}):
            toks.add(t.lower())
        for t in info.get("tokens", []):
            toks.add(t.lower())
    toks.discard("0x0000000000000000000000000000000000000000")
    toks = sorted(toks)
    print("unique tokens:", len(toks), flush=True)

    # decimals / symbols
    meta = {}
    calls = []
    for t in toks:
        calls.append((t, SIG["decimals()"]))
        calls.append((t, SIG["symbol()"]))
    raw = rp.batch([("eth_call", [{"to": t, "data": dd}, hex(BLK)]) for t, dd in calls], chunk=15)
    for i, t in enumerate(toks):
        dec = du(raw[2 * i]) if raw[2 * i] not in (None, "0x") else None
        sym = ds(raw[2 * i + 1])
        meta[t] = {"decimals": dec if dec is not None else KNOWN_DEC.get(t, 18), "symbol": sym or t[:10]}

    # prices
    prices = {}
    ts = list(toks)
    for i in range(0, len(ts), 45):
        part = ts[i:i + 45]
        url = "https://coins.llama.fi/prices/current/" + ",".join("hyperliquid:" + t for t in part)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            js = json.loads(urllib.request.urlopen(req, timeout=45).read())
            for k, v in js.get("coins", {}).items():
                prices[k.split(":")[1].lower()] = v.get("price")
        except Exception as e:
            print("price error", e, flush=True)

    def usd(tok, amount):
        p = prices.get(tok.lower())
        if p is None:
            return None
        return amount / (10 ** meta.get(tok.lower(), {}).get("decimals", 18)) * p

    def agg_rows(items):
        """items: dict token->amount; returns rows sorted by usd desc + totals"""
        rows = []
        tu = 0.0; unk = 0
        for t, amt in items.items():
            if not amt:
                continue
            u = usd(t, amt)
            sym = meta.get(t.lower(), {}).get("symbol", t)
            rows.append({"token": t, "symbol": sym, "amount_raw": str(amt),
                         "amount": amt / 10 ** meta.get(t.lower(), {}).get("decimals", 18),
                         "price": prices.get(t.lower()), "usd": round(u, 2) if u is not None else None})
            if u is not None:
                tu += u
            else:
                unk += 1
        rows.sort(key=lambda r: (r["usd"] is None, -(r["usd"] or 0)))
        return {"rows": rows, "total_usd": round(tu, 2), "unpriced_rows": unk}

    out = {"block": BLK, "meta": meta, "prices_at": "DefiLlama current at run time"}

    # gauges aggregate
    g_tot = {}; gf_tot = {}; positions = 0
    for g, info in d["gauges"].items():
        positions += info.get("nfpm_position_count") or 0
        for tag, b in (info.get("balances") or {}).items():
            t = (b.get("token") or "").lower()
            if t:
                g_tot[t] = g_tot.get(t, 0) + b.get("amount", 0)
        cp = (info.get("clPool()") or "").lower()
        gf = info.get("gaugeFees") or [0, 0]
        if cp in d.get("pools", {}):
            for i, tk in enumerate(("token0", "token1")):
                t = d["pools"][cp].get(tk)
                if t:
                    gf_tot[t.lower()] = gf_tot.get(t.lower(), 0) + (gf[i] if i < len(gf) else 0)
    out["gauges"] = agg_rows(g_tot)
    out["gauges"]["staked_position_count"] = positions
    out["gaugeFees_in_pools"] = agg_rows(gf_tot)

    # bribes aggregate
    b_tot = {}
    for b, info in d["bribes"].items():
        for t, amt in (info.get("balances") or {}).items():
            b_tot[t.lower()] = b_tot.get(t.lower(), 0) + amt
    out["bribes"] = agg_rows(b_tot)

    # system addresses (majors only measured)
    s_tot = {}
    per_addr = {}
    for name, bals in d["systemBalances"].items():
        if name.startswith(("gauge:", "bribe:")):
            continue
        per_addr[name] = {}
        for sym, b in bals.items():
            t = (b.get("token") or "").lower()
            amt = b.get("amount", 0)
            s_tot[t] = s_tot.get(t, 0) + amt
            if amt:
                per_addr[name][sym] = {"amount_raw": str(amt),
                                       "amount": amt / 10 ** meta.get(t, {}).get("decimals", 18),
                                       "usd": round(usd(t, amt), 2) if usd(t, amt) is not None else None}
    out["system_addresses_majors"] = agg_rows(s_tot)
    out["system_addresses_detail"] = per_addr

    # HYBR accounting
    HY = MAJORS["HYBR"].lower()
    hybr_total = d["hybr"]["totalSupply()"]
    ve_supply = d["core"]["votingEscrow"]["supply()"]
    ve_total = d["core"]["votingEscrow"]["totalSupply()"]
    held = {
        "votingEscrow_locked(-balanceOf)": d["systemBalances"]["votingEscrow"]["HYBR"]["amount"],
        "rewardsDistributor": d["systemBalances"]["rewardsDistributor"]["HYBR"]["amount"],
        "minterTeam(Safe)": d["systemBalances"]["minterTeam"]["HYBR"]["amount"],
        "gHYBR_balance": d["systemBalances"]["gHYBR"]["HYBR"]["amount"],
        "gauges": g_tot.get(HY, 0),
        "bribes": b_tot.get(HY, 0),
        "gaugeManager": d["systemBalances"]["gaugeManager"]["HYBR"]["amount"],
        "voter": d["systemBalances"]["voter"]["HYBR"]["amount"],
        "minter": d["systemBalances"]["minter"]["HYBR"]["amount"],
    }
    out["hybr"] = {
        "totalSupply": str(hybr_total),
        "totalSupply_human": hybr_total / 1e18,
        "price_usd": prices.get(HY),
        "ve_supply_locked_uint": str(ve_supply),
        "ve_totalSupply_votingpower": str(ve_total),
        "held": {k: {"raw": str(v), "human": v / 1e18, "usd": round(usd(HY, v), 2) if usd(HY, v) is not None else None} for k, v in held.items()},
        "held_sum": str(sum(held.values())),
        "held_sum_human": sum(held.values()) / 1e18,
        "held_sum_usd": round(usd(HY, sum(held.values())), 2) if usd(HY, sum(held.values())) is not None else None,
    }

    # gHYBR / rHYBR
    gh = d.get("gHYBR", {})
    out["gHYBR"] = {
        "totalSupply_gHYBR": gh.get("totalSupply()"),
        "totalSupply_human": gh.get("totalSupply()", 0) / 1e18,
        "veNFT_tokenId": gh.get("veNFT", {}).get("tokenId"),
        "veNFT_locked_HYBR_human": gh.get("veNFT", {}).get("locked_amount", 0) / 1e18,
        "veNFT_locked_HYBR_usd": round(usd(HY, gh.get("veNFT", {}).get("locked_amount", 0)), 2) if prices.get(HY) else None,
        "veNFT_balanceOfNFT_human": gh.get("veNFT", {}).get("balanceOfNFT", 0) / 1e18,
        "HYBR_on_balance_human": d["systemBalances"]["gHYBR"]["HYBR"]["amount"] / 1e18,
        "owner": gh.get("owner()"),
    }
    rh = d.get("phase3", {}).get("rHYBR", {})
    out["rHYBR"] = {
        "address": rh.get("address"),
        "totalSupply": rh.get("totalSupply()"),
        "symbol": rh.get("symbol()"),
        "HYBR_backing_balance_human": None,
        "note": "rHYBR totalSupply==0 at block; no outstanding reward token",
    }

    json.dump(out, open(os.path.join(D, "ve33_value.json"), "w"), indent=1)

    # console
    print("== GAUGES total USD", out["gauges"]["total_usd"], "positions", positions)
    for r in out["gauges"]["rows"][:12]:
        print(f"  {r['symbol']:>12s} {r['amount']:>22,.4f} ${(r['usd'] or 0):>12,.2f}")
    print("== GAUGE FEES pending in pools USD", out["gaugeFees_in_pools"]["total_usd"])
    for r in out["gaugeFees_in_pools"]["rows"][:12]:
        print(f"  {r['symbol']:>12s} {r['amount']:>22,.4f} ${(r['usd'] or 0):>12,.2f}")
    print("== BRIBES total USD", out["bribes"]["total_usd"])
    for r in out["bribes"]["rows"][:15]:
        print(f"  {r['symbol']:>12s} {r['amount']:>22,.4f} ${(r['usd'] or 0):>12,.2f}")
    print("== SYSTEM (majors) total USD", out["system_addresses_majors"]["total_usd"])
    for r in out["system_addresses_majors"]["rows"]:
        print(f"  {r['symbol']:>12s} {r['amount']:>22,.4f} ${(r['usd'] or 0):>12,.2f}")
    print("== HYBR held sum:", out["hybr"]["held_sum_human"], "USD", out["hybr"]["held_sum_usd"])
    print("== gHYBR:", json.dumps(out["gHYBR"], indent=1))

if __name__ == "__main__":
    main()
