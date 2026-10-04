#!/usr/bin/env python3
"""Fetch and measure all known Serum v3 markets + vault balances.
Read-only; mainnet-beta RPC for non-gPA calls."""
import base64, json, sys, time, os
sys.path.insert(0, "/home/heisenberg/CA/serum/analysis")
from rpc import rpc, bytes_to_b58

EP = ["https://api.mainnet-beta.solana.com"]
PROG = "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin"
OUT = os.path.dirname(os.path.abspath(__file__))

def b58(b):
    return bytes_to_b58(b)

def parse_market(b):
    if len(b) != 388 or b[:5] != b"serum":
        return None
    m = {
        "flags": int.from_bytes(b[5:13], "little"),
        "own_address": b58(b[13:45]),
        "vault_signer_nonce": int.from_bytes(b[45:53], "little"),
        "coin_mint": b58(b[53:85]),
        "pc_mint": b58(b[85:117]),
        "coin_vault": b58(b[117:149]),
        "coin_deposits_total": int.from_bytes(b[149:157], "little"),
        "coin_fees_accrued": int.from_bytes(b[157:165], "little"),
        "pc_vault": b58(b[165:197]),
        "pc_deposits_total": int.from_bytes(b[197:205], "little"),
        "pc_fees_accrued": int.from_bytes(b[205:213], "little"),
        "pc_dust_threshold": int.from_bytes(b[213:221], "little"),
        "req_q": b58(b[221:253]),
        "event_q": b58(b[253:285]),
        "bids": b58(b[285:317]),
        "asks": b58(b[317:349]),
        "coin_lot_size": int.from_bytes(b[349:357], "little"),
        "pc_lot_size": int.from_bytes(b[357:365], "little"),
        "fee_rate_bps": int.from_bytes(b[365:373], "little"),
        "referrer_rebates_accrued": int.from_bytes(b[373:381], "little"),
    }
    return m

def multi(keys, encoding="base64", chunk=100, tries=5):
    out = []
    for i in range(0, len(keys), chunk):
        part = keys[i:i+chunk]
        for attempt in range(tries):
            try:
                r = rpc("getMultipleAccounts", [part, {"encoding": encoding}], endpoints=EP)
                vals = r.get("value", [])
                if len(vals) != len(part):
                    raise RuntimeError(f"len mismatch {len(vals)} != {len(part)}")
                out += vals
                break
            except Exception as e:
                if attempt == tries - 1:
                    raise
                time.sleep(2 * (attempt + 1))
        time.sleep(0.15)
    return out

def main():
    # 1. market registry: npm @project-serum/serum + solana-labs tokenlist serumV3 fields
    reg = json.load(open("/tmp/opencode/serum_npm_markets.json"))
    v3 = [m for m in reg if m.get("programId") == PROG]
    seen = {m["address"] for m in v3}
    tl = json.load(open("/tmp/opencode/solana_tokenlist.json"))
    added = 0
    for t in tl.get("tokens", []):
        ext = t.get("extensions") or {}
        sym = t.get("symbol") or "?"
        for k, q in (("serumV3Usdc", "USDC"), ("serumV3Usdt", "USDT")):
            a = ext.get(k)
            if a and a not in seen:
                seen.add(a)
                v3.append({"address": a, "name": f"{sym}/{q}", "source": "solana-labs tokenlist"})
                added += 1
    print(f"tokenlist new markets: {added}", flush=True)
    # also allow a supplemental file if present
    supp_path = os.path.join(OUT, "extra_markets.json")
    if os.path.exists(supp_path):
        for a in json.load(open(supp_path)):
            if a not in seen:
                seen.add(a)
                v3.append({"address": a, "name": "extra", "source": "supplemental"})
    addrs = [m["address"] for m in v3]
    print(f"registry markets total: {len(addrs)}", flush=True)

    # 2. fetch market accounts
    accts = multi(addrs)
    slot = rpc("getSlot", [{"commitment": "finalized"}], endpoints=EP)
    epoch = rpc("getEpochInfo", [{"commitment": "finalized"}], endpoints=EP)
    print("slot", slot, "epoch", epoch.get("epoch"), flush=True)

    markets = []
    for meta, acc in zip(v3, accts):
        if acc is None:
            markets.append({**meta, "closed": True})
            continue
        raw = acc["data"][0] if isinstance(acc["data"], list) else acc["data"]
        b = base64.b64decode(raw)
        p = parse_market(b)
        if p is None:
            markets.append({**meta, "parse_error": True, "len": len(b)})
            continue
        p.update({k: meta.get(k) for k in ("name", "deprecated") if k in meta})
        p["address"] = meta["address"]
        p["market_lamports"] = acc["lamports"]
        p["owner"] = acc["owner"]
        markets.append(p)

    # 3. vaults
    vault_keys = []
    for m in markets:
        if m.get("closed") or m.get("parse_error"):
            continue
        vault_keys += [m["coin_vault"], m["pc_vault"]]
    print("vault accounts to fetch:", len(vault_keys), flush=True)
    vacts = multi(vault_keys, encoding="jsonParsed")
    for i, m in enumerate([m for m in markets if not (m.get("closed") or m.get("parse_error"))]):
        cv = vacts[2*i]; pv = vacts[2*i+1]
        for tag, va in (("coin_vault", cv), ("pc_vault", pv)):
            if va is None:
                m[tag + "_closed"] = True
                continue
            d = va.get("data")
            if isinstance(d, dict) and d.get("parsed"):
                info = d["parsed"]["info"]
                m[tag + "_mint"] = info.get("mint")
                m[tag + "_owner"] = info.get("owner")
                m[tag + "_amount"] = int(info["tokenAmount"]["amount"])
                m[tag + "_decimals"] = info["tokenAmount"]["decimals"]
                m[tag + "_lamports"] = va["lamports"]
            else:
                m[tag + "_nonparsed"] = True
                m[tag + "_lamports"] = va["lamports"]

    # 4. program + authorities
    extra_keys = [PROG,
                  "DeqYsmBd9BnrbgUwQjVH4sQWK71dEgE6eoZFw3Rp4ftE",
                  "5ZVJgwWxMsqXxRMYHXqMwH2hd4myX5Ef4Au2iUsuNQ7V",
                  "6XvcBmETaz5ZNRhwiz1ochXitHG771d6rmK4Ug3NVr1g"]
    extra = multi(extra_keys, encoding="base64")
    extras = {}
    for k, acc in zip(extra_keys, extra):
        if acc is None:
            extras[k] = {"exists": False}
        else:
            extras[k] = {"exists": True, "owner": acc["owner"], "lamports": acc["lamports"],
                         "executable": acc.get("executable"), "len": len(base64.b64decode(acc["data"][0])) if acc.get("data") else None}

    result = {
        "fetched_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "slot": slot,
        "epoch": epoch.get("epoch"),
        "program": PROG,
        "registry": {"source": "npm @project-serum/serum markets.json", "count": len(addrs)},
        "markets": markets,
        "extras": extras,
    }
    with open(os.path.join(OUT, "serum_v3_markets_raw.json"), "w") as f:
        json.dump(result, f, indent=1)

    # 5. summary
    init = [m for m in markets if m.get("flags") is not None and (m["flags"] & 3) == 3]
    disabled = [m for m in markets if m.get("flags") is not None and (m["flags"] & 128)]
    print(f"initialized (flags&3==3): {len(init)}; disabled: {len(disabled)}; closed/missing: {sum(1 for m in markets if m.get('closed'))}")
    totals = {}
    for m in init:
        for side, dec in (("coin", m.get("coin_vault_decimals")), ("pc", m.get("pc_vault_decimals"))):
            amt = m.get(f"{side}_vault_amount")
            mint = m.get(f"{side}_vault_mint")
            if amt is None:
                continue
            tot = totals.setdefault(mint, {"vault_amount": 0, "deposits_total": 0, "fees_accrued": 0, "decimals": dec})
            tot["vault_amount"] += amt
            tot["deposits_total"] += m.get(f"{side}_deposits_total", 0)
            tot["fees_accrued"] += m.get(f"{side}_fees_accrued", 0)
    print("top mints by vault amount (raw base units):")
    for mint, t in sorted(totals.items(), key=lambda kv: -kv[1]["vault_amount"])[:25]:
        print(" ", mint, "dec", t["decimals"], "vault", t["vault_amount"], "deposits", t["deposits_total"], "fees", t["fees_accrued"])
    print("total markets with deposits/fees:", sum(1 for m in init if (m.get("coin_deposits_total", 0) or m.get("pc_deposits_total", 0) or m.get("coin_fees_accrued", 0) or m.get("pc_fees_accrued", 0))))

if __name__ == "__main__":
    main()
