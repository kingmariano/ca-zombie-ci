#!/usr/bin/env python3
"""Apply all pending scanner patches idempotently + verify."""
import re, sys

P = "scan.py"
src = open(P).read()
applied, missing = [], []

def rep(tag, old, new):
    global src
    if new in src:
        applied.append(tag + " (already)")
        return
    if old not in src:
        missing.append(tag)
        return
    src = src.replace(old, new, 1)
    applied.append(tag)

# --- 1. sol_mint_decimals helper ---
rep("sol_mint_decimals",
'''def spl_amount(data_b64):
    b = base64.b64decode(data_b64)
    return int.from_bytes(b[64:72], "little")''',
'''def spl_amount(data_b64):
    b = base64.b64decode(data_b64)
    return int.from_bytes(b[64:72], "little")

def sol_mint_decimals(mints, top=60, raw_amounts=None):
    mints = list(mints)
    if raw_amounts:
        mints = sorted(mints, key=lambda m: -(raw_amounts.get(m, 0)))[:top]
    decs = {}
    for i in range(0, len(mints), 100):
        chunk = mints[i:i + 100]
        try:
            r = sol_rpc("getMultipleAccounts", [chunk, {"encoding": "jsonParsed"}], timeout=60)
            for j, acct in enumerate(r.get("value", []) if isinstance(r, dict) else (r or [])):
                try:
                    decs[chunk[j]] = int(acct["data"]["parsed"]["info"]["decimals"])
                except Exception:
                    pass
        except Exception:
            pass
    return decs''')

# --- 2. wire mint decimals: jet / 01 / armada ---
rep("jet decimals",
'''    row["tokens"] = tokens
    decs = sol_mint_decimals(list(tokens.keys()), raw_amounts=tokens)
    row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
    row["evidence"]["debt_tokens_note"]''',
'''    row["tokens"] = tokens
    decs = sol_mint_decimals(list(tokens.keys()), raw_amounts=tokens)
    row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
    row["evidence"]["debt_tokens_note"]''')
if "sol_mint_decimals(list(tokens.keys())" not in src:
    rep("jet decimals2",
'''    row["tokens"] = tokens
    row["evidence"]["debt_tokens_note"] = "debt mints''',
'''    row["tokens"] = tokens
    decs = sol_mint_decimals(list(tokens.keys()), raw_amounts=tokens)
    row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
    row["evidence"]["debt_tokens_note"] = "debt mints''')

rep("01 decimals",
'''    row["tokens"] = tokens
    row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else ("DRAINED" if row.get("evidence", {}).get("accounts") is not None else "UNREACHABLE")''',
'''    row["tokens"] = tokens
    decs = sol_mint_decimals(list(tokens.keys()), raw_amounts=tokens)
    row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
    row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else ("DRAINED" if row.get("evidence", {}).get("accounts") is not None else "UNREACHABLE")''')

rep("armada decimals",
'''        row["tokens"] = tokens
        row["evidence"]["whirlpool_positions_note"]''',
'''        row["tokens"] = tokens
        decs = sol_mint_decimals(list(tokens.keys()), raw_amounts=tokens)
        row["token_decimals"] = {f"solana:{m}": d for m, d in decs.items()}
        row["evidence"]["whirlpool_positions_note"]''')

# --- 3. dojoswap CW20 token_info ---
rep("dojoswap decimals",
'''        row["tokens"] = tokens
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 8. ErgoDEX (Ergo) ----------''',
'''        row["tokens"] = tokens
        decs = {"injective:inj": 18}
        for t in list(tokens.keys()):
            addr = t.split(":", 1)[1]
            if addr.startswith("inj1"):
                try:
                    ti = cosmos_lcd_smart(lcds[0], addr, {"token_info": {}})
                    if ti.get("decimals") is not None:
                        decs[t] = int(ti["decimals"])
                except Exception:
                    pass
        row["token_decimals"] = decs
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "high"
    except Exception as e:
        row["errors"].append(redact(e)); row["status"] = "UNREACHABLE"

# ---------- 8. ErgoDEX (Ergo) ----------''')

# --- 4. margined denom decimals ---
rep("margined decimals",
'''    row["tokens"] = tokens
    row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else ("DRAINED" if tokens else "UNREACHABLE")
    row["confidence"] = "medium"''',
'''    row["tokens"] = tokens
    decs = {}
    for t in tokens:
        d = t.split(":", 1)[1]
        if d in ("uosmo", "untrn"):
            decs[t] = 6
        elif d.startswith(("ibc/", "factory/", "gamm/")):
            decs[t] = 6
        elif d.startswith("u") and len(d) <= 6:
            decs[t] = 6
    row["token_decimals"] = decs
    row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else ("DRAINED" if tokens else "UNREACHABLE")
    row["confidence"] = "medium"''')

# --- 5. caviar LSU redemption ---
rep("caviar redemption",
'''        resources = []
        for f in fung:
            resources.append({"resource": f["resource_address"], "amount": f["amount"]})
        row["evidence"]["fungibles"] = resources
        row["tokens"] = {f"radix:{x['resource']}": float(x["amount"]) for x in resources}
        row["status"] = "LIVE-FUNDED" if resources else "DRAINED"
        row["confidence"] = "high"''',
'''        resources = []
        for f in fung:
            resources.append({"resource": f["resource_address"], "amount": f["amount"]})
        row["evidence"]["fungibles"] = resources
        lsu_res = [x["resource"] for x in resources if x["resource"].startswith("resource_")]
        redemption = {}
        try:
            if lsu_res:
                rd = http("https://mainnet.radixdlt.com/state/entity/details",
                          {"addresses": lsu_res, "aggregation_level": "Vault",
                           "explicit_metadata": ["validator"]}, timeout=40)
                validators = []
                for it in rd.get("items", []):
                    meta = {m["key"]: m for m in (it.get("metadata", {}) or {}).get("items", [])}
                    val = meta.get("validator", {}).get("value", {}).get("typed", {}).get("value")
                    if val and val.startswith("validator_"):
                        redemption[it["address"]] = {"validator": val,
                                                     "total_supply": it.get("details", {}).get("total_supply")}
                        validators.append(val)
                if validators:
                    vd = http("https://mainnet.radixdlt.com/state/entity/details",
                              {"addresses": validators, "aggregation_level": "Vault"}, timeout=40)
                    for v in vd.get("items", []):
                        st = (v.get("details", {}).get("state", {}) or {})
                        su = st.get("stake_unit_resource_address")
                        stake_xrd_vault = (st.get("stake_xrd_vault", {}) or {}).get("entity_address")
                        xrd_res = [x for x in (v.get("fungible_resources", {}) or {}).get("items", [])
                                   if x["resource_address"].endswith("radxrdxxxxxxxxx009923554798xxxxxxxxxradxrd")]
                        xrd_bal = None
                        for x in xrd_res:
                            for vault in (x.get("vaults", {}) or {}).get("items", []):
                                if vault.get("vault_address") == stake_xrd_vault:
                                    xrd_bal = float(vault.get("amount"))
                        if su in redemption and xrd_bal and redemption[su].get("total_supply"):
                            try:
                                redemption[su]["xrd_redemption"] = xrd_bal / float(redemption[su]["total_supply"])
                            except Exception:
                                pass
        except Exception as e:
            row["errors"].append("lsu redemption: " + redact(e))
        row["evidence"]["lsu_redemption"] = redemption
        tokens = {}
        for x in resources:
            r_ = x["resource"]; amt = float(x["amount"])
            if r_ in redemption and redemption[r_].get("xrd_redemption"):
                tokens["native:xrd"] = tokens.get("native:xrd", 0) + amt * redemption[r_]["xrd_redemption"]
            elif r_.endswith("radxrdxxxxxxxxx009923554798xxxxxxxxxradxrd"):
                tokens["native:xrd"] = tokens.get("native:xrd", 0) + amt
            else:
                tokens[f"radix:{r_}"] = amt
        row["tokens"] = tokens
        row["status"] = "LIVE-FUNDED" if any(v > 0 for v in tokens.values()) else "DRAINED"
        row["confidence"] = "high"''')

# --- 6. fountain underlying decimals ---
rep("fountain decimals",
'''                    key = f"oasis:{und_a}" if und_a else f"oasis:{m}"
                    tokens[key] = tokens.get(key, 0) + cash_v + bor_v''',
'''                    key = f"oasis:{und_a}" if und_a else f"oasis:{m}"
                    tokens[key] = tokens.get(key, 0) + cash_v + bor_v
                    if und_a:
                        try:
                            dec = evm_rpc(url, "eth_call", [{"to": und_a, "data": EV["decimals()"]}, "latest"])
                            if dec and dec != "0x":
                                row["token_decimals"][key] = int(dec, 16)
                        except Exception:
                            pass''')
rep("decimals selector",
'''    "getReserves()": "0x0902f1ac",
}''',
'''    "getReserves()": "0x0902f1ac",
    "decimals()": "0x313ce567",
}''')

# --- 7. taiga per-cid decimals ---
rep("taiga decimals",
'''        toks = substrate_tokens_of(url, acct, None)
        row["evidence"]["orml_tokens_by_currency_hex"] = toks
        tokens = {}
        # 0002 = Token(2) DOT (10 dec); 0003 = Token(3) LDOT (10 dec)
        if "0002" in toks: tokens["native:dot"] = toks["0002"]
        if "0003" in toks: tokens["native:ldot"] = toks["0003"]
        # any other currencies
        for k, v in toks.items():
            if k not in ("0002", "0003"):
                tokens[f"acala:{k}"] = v''',
'''        toks_raw = substrate_tokens_of(url, acct, None, decimals=0)
        CID_DEC = {"0000": 12, "0001": 12, "0002": 10, "0003": 10, "0004": 12}
        toks = {k: v / (10 ** CID_DEC.get(k, 12)) for k, v in toks_raw.items()}
        row["evidence"]["orml_tokens_by_currency_hex"] = toks_raw
        row["evidence"]["orml_tokens_scaled"] = toks
        tokens = {}
        if "0002" in toks: tokens["native:dot"] = toks["0002"]
        if "0003" in toks: tokens["native:ldot"] = toks["0003"]
        for k, v in toks.items():
            if k not in ("0002", "0003"):
                tokens[f"acala:{k}"] = v''')

# --- 8. bluemove top-30 metadata ---
rep("bluemove top30",
'''        decs = {}
        for t in list(tokens.keys()):
            try:
                md = sui_rpc("suix_getCoinMetadata", [t])''',
'''        decs = {}
        top_tokens = sorted(tokens.keys(), key=lambda t: -tokens[t])[:30]
        for t in top_tokens:
            try:
                md = sui_rpc("suix_getCoinMetadata", [t])''')

# --- 9. valuate rewrite ---
rep("valuate",
'''        for t, amt in (r.get("tokens") or {}).items():
            pk = price_key_for(t)
            p = prices.get(pk)
            dec = KNOWN_DECIMALS.get(t)
            if dec is None:
                # infer decimals: sui addr types 9, solana mints 6 or 9 unknown, others assume 0 (amounts already scaled)
                if t.startswith("sui:"):
                    dec = 9 if t == "sui:0x2::sui::SUI" else None
                dec = dec if dec is not None else None
            if p is None:
                unknown.append(t)
                continue
            val = amt
            if dec is not None and t.startswith(("sui:", "solana:")):
                val = amt / (10 ** dec)
            usd += val * p
            breakdown[t] = {"amount": amt, "price": p, "usd": round(val * p, 2)}
        r["price_breakdown"] = breakdown
        r["unpriced_tokens"] = unknown[:30]''',
'''        decs = r.get("token_decimals") or {}
        for t, amt in (r.get("tokens") or {}).items():
            pk = price_key_for(t)
            p = prices.get(pk)
            if p is None and t == "native:ldot":
                p = prices.get("coingecko:polkadot")
                if p:
                    r["notes"].append("LDOT valued at DOT parity (no direct price feed)")
            dec = decs.get(t, 0)
            if p is None:
                unknown.append(t)
                continue
            val = amt / (10 ** dec) if dec else amt
            usd += val * p
            breakdown[t] = {"amount": amt, "decimals": dec, "price": p, "usd": round(val * p, 2)}
        r["price_breakdown"] = breakdown
        r["unpriced_tokens"] = unknown[:40]''')
rep("polkadot key",
'''    prices = price_of(None, all_keys)
    for r in RESULTS:
        usd = 0.0''',
'''    all_keys.add("coingecko:polkadot")
    prices = price_of(None, all_keys)
    for r in RESULTS:
        usd = 0.0''')

# --- 10. moria rewrite ---
old_moria = None
if "blockchain.address.get_balance" not in src:
    old_moria = '''    utxos = None
    for host, port in [("bch.imaginary.cash", 50002), ("fulcrum.greyh.at", 50002),
                       ("bch.cyberbits.eu", 50002), ("electrum.imaginary.cash", 50002),
                       ("electroncash.dk", 50002)]:
        for proto in ["1.4.3", "1.4"]:
            try:
                r = fulcrum_call(host, port, "token.address.listunspent", [MORIA_ADDR, None, MUSD], proto)
                if isinstance(r, dict) and "result" in r:
                    utxos = r["result"]
                    row["evidence"]["source"] = f"{host}:{port} proto {proto}"
                    break
                if isinstance(r, dict) and "error" in r:
                    row["errors"].append(f"{host}: {r['error']}")
            except Exception as e:
                row["errors"].append(f"{host}: {redact(e)}")
        if utxos is not None:
            break
    if utxos is None:
        try:
            r = moria_ws_call("token.address.listunspent", [MORIA_ADDR, None, MUSD])
            utxos = r.get("result")
            row["evidence"]["source"] = "wss://rostrum.moria.money:443"
        except Exception as e:
            row["errors"].append("rostrum ws: " + redact(e))
    if utxos is not None:
        unspent = utxos.get("unspent", utxos) if isinstance(utxos, dict) else utxos
        loan = [u for u in (unspent or []) if u.get("commitment")]
        sats = sum(int(u.get("value", 0)) for u in loan)
        row["evidence"]["utxos_total"] = len(unspent or [])
        row["evidence"]["utxos_with_commitment"] = len(loan)
        row["evidence"]["collateral_sats"] = sats
        row["tokens"] = {"native:bitcoincash": sats / 1e8}
        row["status"] = "LIVE-FUNDED" if sats > 0 else "DRAINED"
        row["confidence"] = "high"
    else:
        row["status"] = "UNREACHABLE"; row["confidence"] = "low"'''
    new_moria = '''    hosts = [("bch.imaginary.cash", 50002), ("fulcrum.greyh.at", 50002),
             ("bch.cyberbits.eu", 50002), ("electrum.imaginary.cash", 50002),
             ("electroncash.dk", 50002), ("bch.loping.net", 50002)]
    got_any = False
    for host, port in hosts:
        try:
            r = fulcrum_call(host, port, "blockchain.address.get_balance", [MORIA_ADDR])
            bal = r.get("result")
            if isinstance(bal, dict):
                conf = int(bal.get("confirmed", 0) or 0)
                row["evidence"]["balance_source"] = f"{host}:{port}"
                row["evidence"]["confirmed_sats"] = conf
                got_any = True
                r2 = fulcrum_call(host, port, "blockchain.address.get_history", [MORIA_ADDR])
                h = r2.get("result")
                row["evidence"]["history_entries"] = len(h) if isinstance(h, list) else None
                try:
                    r3 = fulcrum_call(host, port, "token.address.listunspent", [MORIA_ADDR, None, MUSD], "1.6")
                    if isinstance(r3, dict) and "result" in r3:
                        unspent = r3["result"]
                        unspent = unspent.get("unspent", unspent) if isinstance(unspent, dict) else unspent
                        loan = [u for u in (unspent or []) if u.get("commitment")]
                        sats = sum(int(u.get("value", 0)) for u in loan)
                        row["evidence"]["token_utxos"] = len(unspent or [])
                        row["evidence"]["token_utxos_with_commitment"] = len(loan)
                        row["evidence"]["collateral_sats"] = sats
                        row["tokens"] = {"native:bitcoincash": sats / 1e8}
                        row["status"] = "LIVE-FUNDED" if sats > 0 else "DRAINED"
                        row["confidence"] = "high"
                        break
                    elif isinstance(r3, dict) and "error" in r3:
                        row["errors"].append(f"token RPC {host}: {str(r3['error'])[:80]}")
                except Exception as e:
                    row["errors"].append(f"token RPC {host}: {redact(e)}")
                sats = conf
                row["tokens"] = {"native:bitcoincash": sats / 1e8}
                row["status"] = "LIVE-FUNDED" if sats > 0 else "DRAINED"
                row["confidence"] = "medium"
                row["notes"].append("plain blockchain.address.* used (Fulcrum 2.x token.address.* unsupported on public servers)")
                break
        except Exception as e:
            row["errors"].append(f"{host}: {redact(e)}")
    if not got_any:
        try:
            r = moria_ws_call("token.address.listunspent", [MORIA_ADDR, None, MUSD])
            unspent = r.get("result")
            unspent = unspent.get("unspent", unspent) if isinstance(unspent, dict) else unspent
            loan = [u for u in (unspent or []) if u.get("commitment")]
            sats = sum(int(u.get("value", 0)) for u in loan)
            row["evidence"]["source"] = "wss://rostrum.moria.money:443"
            row["evidence"]["collateral_sats"] = sats
            row["tokens"] = {"native:bitcoincash": sats / 1e8}
            row["status"] = "LIVE-FUNDED" if sats > 0 else "DRAINED"
            row["confidence"] = "high"
        except Exception as e:
            row["errors"].append("rostrum ws: " + redact(e))
            row["status"] = "UNREACHABLE"; row["confidence"] = "low"'''
    rep("moria", old_moria, new_moria)

# --- 11. lenfi decimals (koios) ---
rep("lenfi decimals",
'''                for a in assets:
                    unit = (a.get("policy_id") or "") + (a.get("asset_name") or "")
                    qty = int(a.get("quantity") or 0)
                    if qty:
                        tokens[f"cardano:{unit}"] = tokens.get(f"cardano:{unit}", 0) + qty''',
'''                decs = {}
                for a in assets:
                    unit = (a.get("policy_id") or "") + (a.get("asset_name") or "")
                    qty = int(a.get("quantity") or 0)
                    if qty:
                        tokens[f"cardano:{unit}"] = tokens.get(f"cardano:{unit}", 0) + qty
                        decs[f"cardano:{unit}"] = int(a.get("decimals") or 0)
                row["token_decimals"] = decs''')

open(P, "w").write(src)
print("APPLIED:", applied)
if missing:
    print("MISSING:", missing)
    sys.exit(2)
