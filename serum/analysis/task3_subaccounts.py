#!/usr/bin/env python3
"""Task 3: sample sub-accounts + vault balances for top/zero markets.
Streaming selection (low memory). Verifies deposits_total vs token vault
balances, vault ownership by the vault-signer PDA, measures rent/market."""
import gzip, hashlib, heapq, json, os, random, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rpc import bytes_to_b58, b58_to_bytes

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"
PROGRAM_B = b58_to_bytes(PROGRAM)
RPC = "https://api.mainnet-beta.solana.com"
MARKETS = os.path.join(HERE, "openbook_markets.jsonl.gz")
OUT = os.path.join(HERE, "subaccount_sample.json")

# ---------- ed25519 / PDA ----------
P = 2**255 - 19
D = (-121665 * pow(121666, P - 2, P)) % P

def is_on_curve(b):
    y = int.from_bytes(b, "little") & ((1 << 255) - 1)
    if y >= P:
        return False
    sign = b[31] >> 7
    y2 = (y * y) % P
    num = (y2 - 1) % P
    den = (D * y2 + 1) % P
    x2 = (num * pow(den, P - 2, P)) % P
    if x2 == 0:
        return sign == 0
    x = pow(x2, (P + 3) // 8, P)
    if (x * x - x2) % P != 0:
        x = (x * pow(2, (P - 1) // 4, P)) % P
    if (x * x - x2) % P != 0:
        return False
    return True

def create_program_address(seeds, program_id):
    h = hashlib.sha256(b"".join(seeds) + program_id + b"ProgramDerivedAddress").digest()
    if is_on_curve(h):
        raise ValueError("on curve")
    return h

def vault_signer(market_pubkey, nonce):
    return create_program_address([b58_to_bytes(market_pubkey), nonce.to_bytes(8, "little")], PROGRAM_B)

# ---------- RPC ----------
def rpc(method, params, timeout=120, tries=5):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                j = json.loads(r.read())
            if "error" in j:
                raise RuntimeError(str(j["error"])[:200])
            return j["result"]
        except Exception as e:
            last = e
            time.sleep(2 * (a + 1))
    raise RuntimeError(str(last))

def get_multiple(pubkeys, encoding="base64", extra=None):
    cfg = {"encoding": encoding, "commitment": "finalized"}
    if extra:
        cfg.update(extra)
    return rpc("getMultipleAccounts", [pubkeys, cfg])["value"]

# ---------- prices ----------
def load_prices():
    prices = {}
    for pf in ("mint_prices.json", "openbook_mint_prices.json"):
        p = os.path.join(HERE, pf)
        if not os.path.exists(p):
            continue
        try:
            d = json.load(open(p))
        except Exception:
            continue
        for k, v in d.items():
            if isinstance(v, dict) and v.get("price") is not None and v.get("decimals") is not None:
                prices[k] = (v["price"], v["decimals"])
    return prices

def usd_of(r, prices):
    tot = 0.0
    for side in ("coin", "pc"):
        amt = r[f"{side}_dep"]
        if not amt:
            continue
        p = prices.get(r[f"{side}_mint"])
        if p:
            tot += (amt / (10 ** p[1])) * p[0]
    return tot

# ---------- streaming selection ----------
def select_sample(top_raw_n=30, top_usd_n=15, zero_n=20):
    prices = load_prices()
    if not os.path.exists(MARKETS):
        return select_sample_fallback(prices, top_raw_n, top_usd_n, zero_n)
    top_raw = []   # heap (sum, seq, rec)
    top_usd = []   # heap (usd, seq, rec)
    zero_res = []
    n_zero = 0
    seq = 0
    rng = random.Random(42)
    n_total = 0
    with gzip.open(MARKETS, "rt") as f:
        for line in f:
            r = json.loads(line)
            n_total += 1
            s = r["coin_dep"] + r["pc_dep"]
            seq += 1
            if s > 0:
                if len(top_raw) < top_raw_n:
                    heapq.heappush(top_raw, (s, seq, r))
                elif s > top_raw[0][0]:
                    heapq.heapreplace(top_raw, (s, seq, r))
                u = usd_of(r, prices)
                if u > 0:
                    if len(top_usd) < top_usd_n:
                        heapq.heappush(top_usd, (u, seq, r))
                    elif u > top_usd[0][0]:
                        heapq.heapreplace(top_usd, (u, seq, r))
            else:
                n_zero += 1
                if len(zero_res) < zero_n:
                    zero_res.append(r)
                else:
                    j = rng.randrange(n_zero)
                    if j < zero_n:
                        zero_res[j] = r
    print(f"scanned {n_total} markets; zero-deposit seen {n_zero}; prices known for {len(prices)} mints")
    top_raw = [r for _, _, r in sorted(top_raw, reverse=True)]
    top_usd = [r for _, _, r in sorted(top_usd, reverse=True)]
    raw_keys = {r["pubkey"] for r in top_raw}
    top_usd_extra = [r for r in top_usd if r["pubkey"] not in raw_keys]
    sample = ([("top", r) for r in top_raw] + [("usd_top", r) for r in top_usd_extra]
              + [("zero", r) for r in zero_res])
    info = {"top_raw": [(r["pubkey"][:10], r["coin_dep"] + r["pc_dep"]) for r in top_raw[:5]],
            "top_usd": [(r["pubkey"][:10], round(usd_of(r, prices), 2)) for r in top_usd[:5]],
            "zero_n": len(zero_res)}
    return sample, prices, info

def select_sample_fallback(prices, top_raw_n, top_usd_n, zero_n):
    """When the full merged file is absent: use aggregates top100 + 20k sample."""
    agg = json.load(open(os.path.join(HERE, "openbook_aggregates.json")))
    top100 = agg["top100_markets_by_deposits"]
    top_raw = top100[:top_raw_n]
    raw_keys = {r["pubkey"] for r in top_raw}
    by_usd = sorted(top100, key=lambda r: usd_of(r, prices), reverse=True)
    top_usd = [r for r in by_usd if r["pubkey"] not in raw_keys][:top_usd_n]
    zero_res = []
    rng = random.Random(42)
    n_zero = 0
    sample_f = os.path.join(HERE, "openbook_markets_sample20k.jsonl.gz")
    if os.path.exists(sample_f):
        with gzip.open(sample_f, "rt") as f:
            for line in f:
                r = json.loads(line)
                if r["coin_dep"] == 0 and r["pc_dep"] == 0:
                    n_zero += 1
                    if len(zero_res) < zero_n:
                        zero_res.append(r)
                    else:
                        j = rng.randrange(n_zero)
                        if j < zero_n:
                            zero_res[j] = r
    print(f"FALLBACK selection from aggregates+sample20k; zero candidates {n_zero}; prices {len(prices)}")
    sample = ([("top", r) for r in top_raw] + [("usd_top", r) for r in top_usd]
              + [("zero", r) for r in zero_res])
    info = {"selection": "fallback", "top_raw": [(r["pubkey"][:10], r["coin_dep"] + r["pc_dep"]) for r in top_raw[:5]],
            "top_usd": [(r["pubkey"][:10], round(usd_of(r, prices), 2)) for r in top_usd[:5]],
            "zero_n": len(zero_res)}
    return sample, prices, info

def main():
    t0 = time.time()
    sample, prices, info = select_sample()
    print("selection:", json.dumps(info))
    print(f"sample size: {len(sample)}  ({time.time()-t0:.0f}s)")

    sub_results = {}
    todo = []
    for tag, r in sample:
        for kind, key in (("market", r["pubkey"]), ("req_q", r["req_q"]),
                          ("event_q", r["event_q"]), ("bids", r["bids"]), ("asks", r["asks"])):
            todo.append((r["pubkey"], kind, key))
    print(f"fetching {len(todo)} sub-accounts in {-(-len(todo)//100)} calls", flush=True)
    for i in range(0, len(todo), 100):
        batch = todo[i:i + 100]
        vals = get_multiple([k for _, _, k in batch])
        for (mk, kind, key), v in zip(batch, vals):
            sub_results.setdefault(mk, {})[kind] = v
        time.sleep(0.3)

    vault_todo = []
    for tag, r in sample:
        vault_todo.append((r["pubkey"], "coin_vault", r["coin_vault"]))
        vault_todo.append((r["pubkey"], "pc_vault", r["pc_vault"]))
    print(f"fetching {len(vault_todo)} vaults (jsonParsed)", flush=True)
    vault_results = {}
    for i in range(0, len(vault_todo), 100):
        batch = vault_todo[i:i + 100]
        vals = get_multiple([k for _, _, k in batch], encoding="jsonParsed")
        for (mk, kind, key), v in zip(batch, vals):
            vault_results.setdefault(mk, {})[kind] = v
        time.sleep(0.3)

    out = {"slot_fetched": rpc("getSlot", []), "samples": []}
    for tag, r in sample:
        mk = r["pubkey"]
        rec = {"tag": tag, "market": r, "subs": {}, "vaults": {}}
        total_lamports = 0
        for kind in ("market", "req_q", "event_q", "bids", "asks"):
            v = sub_results[mk].get(kind)
            if v is None:
                rec["subs"][kind] = None
                continue
            rec["subs"][kind] = {"lamports": v["lamports"], "space": v["space"], "owner": v["owner"]}
            total_lamports += v["lamports"]
        for kind in ("coin_vault", "pc_vault"):
            v = vault_results[mk].get(kind)
            if v is None:
                rec["vaults"][kind] = None
                continue
            parsed = v["data"]["parsed"]["info"]
            rec["vaults"][kind] = {
                "lamports": v["lamports"], "space": v["space"], "owner": v["owner"],
                "mint": parsed["mint"], "token_owner": parsed["owner"],
                "amount": int(parsed["tokenAmount"]["amount"]),
                "decimals": parsed["tokenAmount"]["decimals"],
                "ui": parsed["tokenAmount"]["uiAmountString"],
            }
            total_lamports += v["lamports"]
        rec["total_lamports"] = total_lamports
        rec["usd_est"] = round(usd_of(r, prices), 2)

        def check(side):
            key = f"{side}_vault"
            dep = r[f"{side}_dep"]
            fees = r[f"{side}_fees"]
            reb = r["referrer_rebates"]
            v = rec["vaults"].get(key)
            if v is None:
                return {"dep": dep, "fees": fees, "vault": "closed/missing",
                        "match_dep": dep == 0, "match_dep_fees": (dep == 0 and fees == 0),
                        "match_dep_fees_reb": (dep == 0 and fees == 0 and reb == 0)}
            amt = v["amount"]
            return {"dep": dep, "fees": fees, "reb": reb, "vault": amt,
                    "match_dep": dep == amt,
                    "match_dep_fees": dep + fees == amt,
                    "match_dep_fees_reb": dep + fees + reb == amt}
        rec["check_coin"] = check("coin")
        rec["check_pc"] = check("pc")
        try:
            expected = bytes_to_b58(vault_signer(mk, r["nonce"]))
        except Exception:
            expected = None
        rec["vault_signer_expected"] = expected
        for key in ("coin_vault", "pc_vault"):
            v = rec["vaults"].get(key)
            if v:
                v["owner_is_signer"] = (v["token_owner"] == expected)
        out["samples"].append(rec)
        print(f"  {tag} {mk[:10]} usd={rec['usd_est']} rent={total_lamports} "
              f"coin match_dep_fees={rec['check_coin'].get('match_dep_fees')} "
              f"pc match_dep_fees={rec['check_pc'].get('match_dep_fees')}", flush=True)

    full = [s for s in out["samples"] if s["total_lamports"] > 0]
    rents = sorted(s["total_lamports"] for s in full)
    n = len(rents)
    out["rent_stats"] = {
        "n": n,
        "min": rents[0] if n else 0, "median": rents[n // 2] if n else 0,
        "mean": sum(rents) / n if n else 0, "max": rents[-1] if n else 0,
        "theoretical_full_market_rent": 297430560,
    }
    top_all = [s for s in out["samples"] if s["tag"] in ("top", "usd_top")]
    out["summary"] = {
        "top_checked": len(top_all),
        "top_vault_match_dep": sum(1 for s in top_all if s["check_coin"]["match_dep"] and s["check_pc"]["match_dep"]),
        "top_vault_match_dep_fees": sum(1 for s in top_all if s["check_coin"]["match_dep_fees"] and s["check_pc"]["match_dep_fees"]),
        "top_vault_match_dep_fees_reb": sum(1 for s in top_all if s["check_coin"]["match_dep_fees_reb"] and s["check_pc"]["match_dep_fees_reb"]),
        "closed_vaults_in_sample": sum(1 for s in out["samples"] for k in ("coin_vault", "pc_vault") if s["vaults"].get(k) is None),
        "owner_is_signer_all": all((s["vaults"].get(k) or {}).get("owner_is_signer", True)
                                   for s in out["samples"] for k in ("coin_vault", "pc_vault")),
        "usd_estimates": {s["market"]["pubkey"][:10]: s["usd_est"] for s in sorted(out["samples"], key=lambda x: -x["usd_est"])[:10]},
    }
    with open(OUT, "w") as f:
        json.dump(out, f, indent=1)
    print(json.dumps(out["rent_stats"], indent=1))
    print(json.dumps(out["summary"], indent=1))
    print(f"written {OUT} in {time.time()-t0:.1f}s")

if __name__ == "__main__":
    main()
