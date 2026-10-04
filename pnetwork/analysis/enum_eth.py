#!/usr/bin/env python3
"""Enumerate pNetwork-related contracts on Ethereum via Blockscout v2 and dump balances."""
import json, sys, time, urllib.request, urllib.parse, urllib.error

HOST = "eth.blockscout.com"
UA = {"User-Agent": "Mozilla/5.0 (research; read-only)"}

def get(path, params=None, tries=3):
    url = f"https://{HOST}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception as e:
            if i == tries - 1:
                return {"__error__": str(e)}
            time.sleep(1 + i)

def search_all(q, max_pages=8):
    items, params = [], None
    for _ in range(max_pages):
        j = get("/api/v2/search", {"q": q, **(params or {})})
        if "__error__" in j: return items
        items += j.get("items", [])
        params = j.get("next_page_params")
        if not params: break
    return items

def token_balances(addr):
    out, params = [], None
    for _ in range(6):
        j = get(f"/api/v2/addresses/{addr}/token-balances", params)
        if "__error__" in j or not isinstance(j, list): break
        out += j
        # token-balances endpoint is not paginated; single page
        break
    return out

def main():
    terms = sys.argv[1:] or ["Erc20Vault", "EthVault", "PNetworkHub", "PFactory", "PRegistry", "Slasher", "EpochsManager", "PToken"]
    seen = {}
    for t in terms:
        for it in search_all(t):
            name = it.get("name") or (it.get("metadata") or {}).get("name") or ""
            addr = (it.get("address_hash") or "").lower()
            if not addr: continue
            if addr not in seen or (name and not seen[addr]["name"]):
                seen[addr] = {"addr": addr, "name": name, "type": it.get("type"), "term": t}
        print(f"search {t}: total unique so far {len(seen)}", file=sys.stderr)
    # filter: keep contracts whose name contains any term (case-insensitive) OR any
    res = []
    for addr, info in seen.items():
        nm = (info["name"] or "")
        if any(t.lower() in nm.lower() for t in terms) or info["type"] in ("contract",):
            a = get(f"/api/v2/addresses/{addr}")
            if "__error__" in a: a = {}
            tb = token_balances(addr)
            res.append({
                **info,
                "is_contract": a.get("is_contract"),
                "native_balance_wei": a.get("coin_balance"),
                "creator": (a.get("creator_address_hash") or ""),
                "verified": a.get("is_verified"),
                "token_balances": [
                    {"token": (b.get("token") or {}).get("address_hash", b.get("token", {}).get("address", "")),
                     "symbol": (b.get("token") or {}).get("symbol"),
                     "name": (b.get("token") or {}).get("name"),
                     "value": b.get("value"),
                     "decimals": (b.get("token") or {}).get("decimals")}
                    for b in tb
                ],
            })
            time.sleep(0.15)
    json.dump(res, open("analysis/eth_contracts.json", "w"), indent=1)
    # summary
    for r in sorted(res, key=lambda x: -int(x.get("native_balance_wei") or 0)):
        nb = int(r.get("native_balance_wei") or 0)/1e18
        toks = ", ".join(f"{t['symbol']}:{t['value']}" for t in r["token_balances"][:6])
        print(f"{r['addr']} {r['name'][:32]:32s} native={nb:.4f} tokens=[{toks}] creator={r['creator'][:12]}")

if __name__ == "__main__":
    main()
