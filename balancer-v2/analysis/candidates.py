#!/usr/bin/env python3
"""Rank live ComposableStable pools with REAL rate providers by USD value per chain.

Usage: python3 candidates.py chain-fixed.json [more.json ...]
"""
import json, sys, time, urllib.request, urllib.parse

LLAMA = {"ethereum": "ethereum", "arbitrum": "arbitrum", "polygon": "polygon", "base": "base",
         "optimism": "optimism", "gnosis": "gnosis", "avalanche": "avalanche", "mode": "mode",
         "fraxtal": "fraxtal"}
SEL_SYMBOL = "0x95d89b41"
SEL_DECIMALS = "0x313ce567"


def rpc_batch(url, calls, chunk=25):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(part)]
        body = json.dumps(payload).encode()
        for a in range(4):
            try:
                req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.load(r)
                break
            except Exception:
                time.sleep(1 + a)
        else:
            return [None] * len(part)
        by = {x.get("id"): x for x in res}
        for j in range(len(part)):
            x = by.get(j, {})
            out.append(x.get("result") if "result" in x else None)
    return out


def dec_str(h):
    if not h or h == "0x":
        return None
    h = h[2:]
    try:
        if len(h) >= 128:
            off = int(h[0:64], 16) * 2
            ln = int(h[off:off + 64], 16)
            return bytes.fromhex(h[off + 64:off + 64 + ln * 2]).decode("utf-8", "replace")
        return bytes.fromhex(h[:64]).decode("utf-8", "replace").strip("\x00")
    except Exception:
        return None


def main():
    for path in sys.argv[1:]:
        d = json.load(open(path))
        chain = d["chain"]
        rpc = {
            "ethereum": "https://ethereum-rpc.publicnode.com",
            "arbitrum": "https://arbitrum-one-rpc.publicnode.com",
            "base": "https://base-rpc.publicnode.com",
            "optimism": "https://optimism-rpc.publicnode.com",
            "mode": "https://mainnet.mode.network",
            "fraxtal": "https://rpc.frax.com",
        }.get(chain)
        pools = []
        toks = set()
        for p in d["pools"]:
            if p.get("type") != "ComposableStable":
                continue
            pr = p.get("probe") or {}
            rp = pr.get("rateProviders_fixed") or []
            real = [r for r in rp if r != "0x0000000000000000000000000000000000000000"]
            if not real:
                continue
            paused = (pr.get("poolPausedState") or {}).get("paused")
            if paused:
                continue
            nz = [(t, b) for t, b in zip(p["tokens"], p["balances"]) if t.lower() != p["address"].lower() and b > 0]
            if not nz:
                continue
            pools.append((p, real, nz))
            for t, _ in nz:
                toks.add(t)
        toks = sorted(toks)
        calls = []
        for t in toks:
            calls.append(("eth_call", [{"to": t, "data": SEL_SYMBOL}, "latest"]))
            calls.append(("eth_call", [{"to": t, "data": SEL_DECIMALS}, "latest"]))
        res = rpc_batch(rpc, calls, chunk=50) if toks else []
        meta = {}
        for i, t in enumerate(toks):
            meta[t] = {"symbol": dec_str(res[2 * i]),
                       "decimals": int(res[2 * i + 1], 16) if res[2 * i + 1] and res[2 * i + 1] != "0x" else None}
        prices = {}
        llama = LLAMA.get(chain, chain)
        addrs = [t for t in toks]
        for i in range(0, len(addrs), 40):
            batch = addrs[i:i + 40]
            key = ",".join(f"{llama}:{a}" for a in batch)
            url = "https://coins.llama.fi/prices/current/" + urllib.parse.quote(key, safe=":,")
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=45) as r:
                    pd = json.load(r)
                for k, v in pd.get("coins", {}).items():
                    prices[k.split(":")[-1].lower()] = v.get("price")
            except Exception:
                pass
            time.sleep(0.2)
        rows = []
        for p, real, nz in pools:
            usd = 0.0
            detail = []
            for t, b in nz:
                m = meta.get(t, {})
                dec = m.get("decimals")
                px = prices.get(t.lower())
                v = (b / 10 ** dec) * px if dec is not None and px else 0.0
                usd += v
                detail.append((m.get("symbol"), b, dec, px, v))
            rows.append((usd, p["address"], (p["probe"].get("version") or "")[:60], p["probe"].get("recovery_fixed"), detail))
        rows.sort(key=lambda r: -r[0])
        print(f"===== {chain} (block {d.get('block')}): CSP+rates, not paused: {len(rows)} =====")
        for usd, addr, ver, rec, detail in rows[:12]:
            print(f"  ${usd:>14,.2f} {addr} rec={rec} {ver[:45]}")
            for sym, b, dec, px, v in detail:
                print(f"       {sym!r:14s} raw={b} dec={dec} px={px} usd={v:,.2f}")


if __name__ == "__main__":
    main()
