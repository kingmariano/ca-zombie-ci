#!/usr/bin/env python3
"""Final compute: build nest_value.json + nest_value.md from the raw on-chain reads.
No double counting:
  - pool token balances  = AMM custody (headline 1)
  - fee vaults           = collected protocol fees, held outside pools (additive)
  - veNEST locked NEST   = separate asset class (headline 2)
  - gauge-held LP tokens = claims on pool tokens -> informational only, NOT added
  - third-party vaults   = labelled, NOT added to protocol total
"""
import json
from collections import defaultdict

BASE = "/home/heisenberg/CA/hyperevm-residuals/analysis"
BLOCK = 47620218

raw = json.load(open(f"{BASE}/nest_value_raw.json"))
st3 = json.load(open(f"{BASE}/nest_value_stage3.json"))
native = json.load(open(f"{BASE}/nest_native.json"))
prices_raw = json.load(open(f"{BASE}/nest_prices.json"))["coins"]
api_pools = json.load(open(f"{BASE}/nest_pools_api.json"))
api = {p["id"]: p for p in api_pools}
llama = json.load(open(f"{BASE}/llama_latest.json"))
assert raw["block"] == BLOCK == st3["block"] == native["block"]

# ---------- token metadata ----------
TM = {}
for t, m in raw["token_meta"].items():
    TM[t.lower()] = {"symbol": m.get("symbol"), "decimals": m.get("decimals")}
# API fallback symbols
for p in api_pools:
    for k in ("token0", "token1"):
        t = p.get(k)
        if isinstance(t, dict) and t.get("tokenAddress"):
            a = t["tokenAddress"].lower()
            if not TM.get(a, {}).get("symbol"):
                bs = (t.get("basetoken") or {}).get("symbol") or t.get("symbol")
                TM.setdefault(a, {})["symbol"] = bs or "?"
            if TM.get(a, {}).get("decimals") is None:
                TM[a]["decimals"] = t.get("decimals") or 18
for a in TM:
    if TM[a].get("decimals") is None:
        TM[a]["decimals"] = 18
# canonical labels
LABEL = {
    "0x5555555555555555555555555555555555555555": "WHYPE",
    "0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb": "USDT0",
    "0xb88339cb7199b77e23db6e890353e22632ba630f": "USDC",
    "0x07c57e32a3c29d5659bda1d3efc2e7bf004e3035": "NEST",
    "0x9fdbda0a5e284c32744d2f17ee5c74b284993463": "UBTC",
    "0xbe6727b535545c67d5caa73dea54865b92cf7907": "UETH",
    "0xfd739d4e423301ce9385c1fb8850539d657c296d": "KHYPE",
}
def sym(a):
    s = LABEL.get(a.lower()) or TM.get(a.lower(), {}).get("symbol")
    if not s:
        s = "UNKNOWN_" + a.lower()[2:10]
    return s

def dec(a):
    return TM.get(a.lower(), {}).get("decimals", 18)

# ---------- prices ----------
P = {}  # lowercase addr -> {price, source, ts, confidence, symbol}
for k, v in prices_raw.items():
    a = k.split(":", 1)[1].lower()
    P[a] = {"price": v.get("price"), "source": "defillama", "ts": v.get("timestamp"),
            "confidence": v.get("confidence"), "symbol": v.get("symbol")}
# fallback from Nest app API snapshot
for p in api_pools:
    for k in ("token0", "token1"):
        t = p.get(k)
        if isinstance(t, dict) and t.get("tokenAddress"):
            a = t["tokenAddress"].lower()
            if a not in P and t.get("priceUSD") is not None:
                P[a] = {"price": float(t["priceUSD"]), "source": "nest_api_snapshot",
                        "ts": None, "confidence": None, "symbol": (t.get("basetoken") or {}).get("symbol")}

def px(a):
    return (P.get(a.lower()) or {}).get("price") or 0.0

# ---------- pools ----------
per_contract = []
pool_tokens = defaultdict(lambda: {"amount": 0.0, "usd": 0.0})
pool_rows_out = []
pools_usd = 0.0
for r in raw["pool_rows"]:
    a = r["pool"]
    row = {"address": a, "label": f"Nest {r['type']} pool", "type": r["type"], "tokens": {}}
    v = 0.0
    for k, tk in (("bal0", "token0"), ("bal1", "token1")):
        t = r[tk]
        if not t:
            continue
        amt = (r[k] or 0) / (10 ** dec(t))
        usd = amt * px(t)
        row["tokens"][sym(t)] = {"address": t, "amount": round(amt, 10), "usd": round(usd, 4)}
        pool_tokens[sym(t)]["amount"] += amt
        pool_tokens[sym(t)]["usd"] += usd
        v += usd
    row["tvlUSD_api"] = r["tvlUSD_api"]
    row["usd"] = round(v, 4)
    pool_rows_out.append({"pool": a, "type": r["type"], "usd": round(v, 2), "api": round(r["tvlUSD_api"], 2),
                          "gauge": (raw["gauges_map"].get(a) or [None])[0] if a in raw["gauges_map"] else None})
    per_contract.append(row)
    pools_usd += v

# ---------- fee vaults ----------
vault_usd = 0.0
vault_tokens = defaultdict(lambda: {"amount": 0.0, "usd": 0.0})
vault_rows_out = []
for vault, tv in st3["vault_balances"].items():
    row = {"address": vault, "label": "FeesVault (collected protocol fees)", "tokens": {}}
    v = 0.0
    pool_addr = raw["vaults_map"][vault][0]
    for key, amt_raw in tv.items():
        if not amt_raw:
            continue
        _, _, t = key.split(":")
        amt = amt_raw / (10 ** dec(t))
        usd = amt * px(t)
        row["tokens"][sym(t)] = {"address": t, "amount": round(amt, 10), "usd": round(usd, 6)}
        vault_tokens[sym(t)]["amount"] += amt
        vault_tokens[sym(t)]["usd"] += usd
        v += usd
    if v:
        row["pool"] = pool_addr
        row["usd"] = round(v, 4)
        per_contract.append(row)
        vault_rows_out.append({"vault": vault, "pool": pool_addr, "usd": round(v, 6)})
    vault_usd += v

# ---------- veNEST ----------
NEST = "0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035"
nest_price = px(NEST)
venest_locked = st3["core2"]["0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074"]["0x047fc9aa"] / 1e18
venest_perm = st3["core2"]["0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074"]["0x94340b05"] / 1e18
venest_vp = st3["core2"]["0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074"]["0xe1ba0c00"] / 1e18
nest_total = st3["core2"][NEST]["0x18160ddd"] / 1e18
venest_usd = venest_locked * nest_price
per_contract.append({
    "address": "0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074", "label": "veNEST (VotingEscrow proxy, locked NEST)",
    "tokens": {"NEST": {"address": NEST, "amount": venest_locked, "usd": round(venest_usd, 2)}},
    "usd": round(venest_usd, 2),
    "stats": {"locked_NEST": venest_locked, "permanent_locked_NEST": venest_perm,
              "votingPowerTotalSupply": venest_vp, "nft_count": 4043, "NEST_totalSupply": nest_total,
              "locked_share_of_supply_pct": round(100 * venest_locked / nest_total, 4)},
})

# ---------- gauge LP (informational) ----------
gauge_info = {"v2_staked_lp": None, "gauge_token_dust_usd": 0.0}
G = "0xd61e0416a3ce369fb1c328ecb84dfe8cea168219"
pair = "0x9aa281b23341ce69d4b1500367a43cfc42005538"
lp_held = st3["gauge_lp_balances"][G][f"{pair}:{pair}"]
lp_total = raw["pair_lp"][pair]["totalSupply"]
pair_val = next(r["usd"] for r in pool_rows_out if r["pool"] == pair)
share = lp_held / lp_total
gauge_info["v2_staked_lp"] = {"gauge": G, "pool": pair, "lp_held": lp_held / 1e18, "lp_total": lp_total / 1e18,
                              "share_pct": round(100 * share, 4), "claim_usd": round(share * pair_val, 2),
                              "note": "claim on pool tokens; NOT added to totals"}
# gauge token dust (non-LP tokens sitting in gauges)
gauge_dust = defaultdict(lambda: {"amount": 0.0, "usd": 0.0})
for g, tv in st3["gauge_token_balances"].items():
    for key, amt_raw in tv.items():
        if not amt_raw:
            continue
        _, _, t = key.split(":")
        amt = amt_raw / (10 ** dec(t))
        usd = amt * px(t)
        gauge_dust[sym(t)]["amount"] += amt
        gauge_dust[sym(t)]["usd"] += usd
        gauge_info["gauge_token_dust_usd"] += usd
if gauge_dust:
    per_contract.append({"address": "gauges (55)", "label": "Gauge token dust (non-LP)",
                         "tokens": {s: {"amount": round(v["amount"], 6), "usd": round(v["usd"], 6)} for s, v in gauge_dust.items()},
                         "usd": round(gauge_info["gauge_token_dust_usd"], 6)})

# ---------- other protocol wallets ----------
voter_nest = raw["nest_balances"]["Voter"] / 1e18
other_usd = voter_nest * nest_price
per_contract.append({"address": "0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901", "label": "Voter (NEST dust)",
                     "tokens": {"NEST": {"address": NEST, "amount": voter_nest, "usd": round(other_usd, 6)}},
                     "usd": round(other_usd, 6)})

# ---------- algebra ----------
algebra_rows = []
alg_usd = 0.0
for holder, tv in raw["algebra"].items():
    row = {"address": "0x15E408A37cE4D13218202C0054B0f485E38F5768" if holder == "AlgebraVault" else "0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3",
           "label": holder, "tokens": {}}
    v = 0.0
    for t, amt_raw in tv.items():
        if amt_raw:
            amt = amt_raw / (10 ** dec(t)); usd = amt * px(t)
            row["tokens"][sym(t)] = {"amount": round(amt, 10), "usd": round(usd, 4)}; v += usd
    row["usd"] = round(v, 4)
    algebra_rows.append(row)
    alg_usd += v
    if v:
        per_contract.append(row)

# ---------- third-party Ichi/Steer ----------
tp_rows = []
tp_usd = 0.0
tp_tokens = defaultdict(lambda: {"amount": 0.0, "usd": 0.0})
for va, tv in raw["tp_balances"].items():
    row = {"address": va, "label": "Third-party Ichi/Steer vault (informational, NOT protocol)", "tokens": {}}
    v = 0.0
    for t, amt_raw in tv.items():
        if amt_raw:
            amt = amt_raw / (10 ** dec(t)); usd = amt * px(t)
            row["tokens"][sym(t)] = {"address": t, "amount": round(amt, 10), "usd": round(usd, 4)}
            tp_tokens[sym(t)]["amount"] += amt; tp_tokens[sym(t)]["usd"] += usd
            v += usd
    row["usd"] = round(v, 4)
    tp_rows.append(row)
    tp_usd += v

# ---------- per-token totals ----------
token_rows = {}
for s, d in pool_tokens.items():
    token_rows.setdefault(s, {})["pools"] = d
for s, d in vault_tokens.items():
    token_rows.setdefault(s, {})["fee_vaults"] = d
for s, d in gauge_dust.items():
    token_rows.setdefault(s, {})["gauge_dust"] = d
token_rows["NEST"] = token_rows.get("NEST", {})
token_rows["NEST"]["veNEST_locked"] = {"amount": venest_locked, "usd": venest_usd}
token_rows["NEST"]["voter_dust"] = {"amount": voter_nest, "usd": other_usd}
out_tokens = {}
for s, cats in token_rows.items():
    addr = None
    for c in cats.values():
        if isinstance(c, dict):
            pass
    # find address/price from a representative
    taddr = None
    for p in api_pools:
        for k in ("token0", "token1"):
            t = p.get(k)
            if isinstance(t, dict) and t.get("tokenAddress") and sym(t["tokenAddress"]) == s:
                taddr = t["tokenAddress"]
    if not taddr:
        for a in TM:
            if sym(a) == s:
                taddr = a
    price = px(taddr) if taddr else 0
    total_usd = sum(c.get("usd", 0) for c in cats.values() if isinstance(c, dict))
    total_amt = sum(c.get("amount", 0) for c in cats.values() if isinstance(c, dict))
    out_tokens[s] = {"address": taddr, "price_usd": price, "price_source": (P.get((taddr or "").lower()) or {}).get("source"),
                     "by_category": {k: {"amount": round(v["amount"], 10), "usd": round(v["usd"], 4)} for k, v in cats.items() if isinstance(v, dict)},
                     "pools_amount": round(cats.get("pools", {}).get("amount", 0), 10),
                     "pools_usd": round(cats.get("pools", {}).get("usd", 0), 2),
                     "total_amount": round(total_amt, 10), "total_usd": round(total_usd, 2)}

protocol_hold_usd = pools_usd + vault_usd + other_usd + alg_usd + gauge_info["gauge_token_dust_usd"]
total_usd = protocol_hold_usd + venest_usd
v2_usd = sum(r["usd"] for r in pool_rows_out if r["type"] == "V2")
v3_usd = sum(r["usd"] for r in pool_rows_out if r["type"] == "V3")

# validation vs API + llama
val = []
for r in pool_rows_out:
    if r["api"] > 100:
        val.append({"pool": r["pool"], "onchain_usd": r["usd"], "api_usd": r["api"],
                    "diff_pct": round(100 * (r["usd"] - r["api"]) / r["api"], 2)})
val.sort(key=lambda x: -abs(x["diff_pct"]))
llama_cmp = []
for s in out_tokens:
    lt = llama["tokens"].get(s) or llama["tokens"].get(s.upper())
    if lt is not None and s not in ("NEST",):
        llama_cmp.append({"symbol": s, "llama": lt, "onchain_pools": out_tokens[s]["by_category"].get("pools", {}).get("amount", 0)})

out = {
    "block": BLOCK,
    "block_timestamp": 1791096164,
    "block_time_utc": "2026-10-04T06:42:44Z",
    "measured_at": "2026-10-04",
    "chain": "hyperevm (chainid 999)",
    "prices": {a: P[a] for a in P},
    "categories": {
        "pools": {"usd": round(pools_usd, 2), "n_pools": len(raw["pool_rows"]),
                  "v3_usd": round(v3_usd, 2), "v2_usd": round(v2_usd, 2),
                  "note": "sum of on-chain balanceOf(pool) for token0/token1 across all 69 V3 + 3 V2 pools"},
        "gauges": {"usd": None, "note": "gauge-held LP are claims on pool tokens; NOT added (see gauge_lp_staked)",
                   "gauge_lp_staked": gauge_info["v2_staked_lp"], "gauge_token_dust_usd": round(gauge_info["gauge_token_dust_usd"], 6)},
        "veNEST": {"usd": round(venest_usd, 2), "locked_NEST": venest_locked, "note": "separate asset class: user-locked NEST held by the veNEST voting escrow"},
        "fee_vaults": {"usd": round(vault_usd, 2), "n_vaults": len(raw["vaults_map"]),
                       "note": "collected protocol fees sitting in per-pool FeesVaults; additive, outside pools"},
        "algebra_vault": {"usd": round(alg_usd, 2), "note": "Algebra community vault + factory: zero balances on all 43 measured tokens"},
        "other": {"usd": round(other_usd + gauge_info["gauge_token_dust_usd"], 6), "voter_nest_usd": round(other_usd, 6),
                  "gauge_dust_usd": round(gauge_info["gauge_token_dust_usd"], 6)},
    },
    "headline": {
        "pool_token_balances_usd": round(pools_usd, 2),
        "fee_vaults_usd": round(vault_usd, 2),
        "protocol_hold_usd_excl_venest": round(protocol_hold_usd, 2),
        "veNEST_locked_nest_usd": round(venest_usd, 2),
        "total_measured_usd": round(total_usd, 2),
    },
    "total_usd": round(total_usd, 2),
    "gauge_lp_staked": gauge_info["v2_staked_lp"],
    "third_party_vaults": {"usd": round(tp_usd, 2), "n_vaults": len(raw["tp_vaults"]),
                           "tokens": {s: {"amount": round(v["amount"], 6), "usd": round(v["usd"], 2)} for s, v in tp_tokens.items()},
                           "note": "Ichi/Steer automated vaults (third-party, user funds) — informational only"},
    "per_token_totals": out_tokens,
    "per_contract": per_contract,
    "validation": {"pool_vs_api_top_diffs": val[:15],
                   "llama_vs_onchain": llama_cmp,
                   "llama_snapshot_date": llama["date"], "llama_total_usd": round(sum(llama["usd"].values()), 2)},
    "price_timestamps": {a: P[a]["ts"] for a in P},
    "gaps": [],
}
json.dump(out, open(f"{BASE}/nest_value.json", "w"), indent=1)

print(f"BLOCK {BLOCK}")
print(f"pools USD               = ${pools_usd:,.2f}")
print(f"fee vaults USD          = ${vault_usd:,.4f}")
print(f"gauge token dust USD    = ${gauge_info['gauge_token_dust_usd']:,.4f}")
print(f"voter NEST dust USD     = ${other_usd:,.4f}")
print(f"algebra USD             = ${alg_usd:,.4f}")
print(f"veNEST locked NEST USD  = ${venest_usd:,.2f}  ({venest_locked:,.2f} NEST @ ${nest_price})")
print(f"protocol hold (excl ve) = ${protocol_hold_usd:,.2f}")
print(f"TOTAL measured USD      = ${total_usd:,.2f}")
print(f"gauge V2 stake share    = {gauge_info['v2_staked_lp']['share_pct']}% claim ${gauge_info['v2_staked_lp']['claim_usd']:,.2f}")
print(f"third-party vaults USD  = ${tp_usd:,.2f}")
print("\ntop pool diffs vs API:")
for v in val[:8]:
    print(" ", v)
print("\nllama total:", out["validation"]["llama_total_usd"])
