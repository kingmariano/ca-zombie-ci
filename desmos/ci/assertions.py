#!/usr/bin/env python3
"""
C2-10 Desmos — CI assertions (turns the evidence pull into a verifiable test).
Reads ci-out/raw/*.json + ci-out/cost-model.json; exits non-zero on any failure.
"""
import json, os, sys

raw = sys.argv[1] if len(sys.argv) > 1 else "ci-out/raw"
out = sys.argv[2] if len(sys.argv) > 2 else "ci-out"

def L(name, default=None):
    try:
        with open(os.path.join(raw, name)) as f:
            return json.load(f)
    except Exception:
        return default

def LO(name, default=None):
    try:
        with open(os.path.join(out, name)) as f:
            return json.load(f)
    except Exception:
        return default

def fnum(x, d=0.0):
    try:
        return float(x)
    except Exception:
        return d

results = []
def check(name, cond, detail=""):
    results.append((name, bool(cond), detail))

# ---- versions ----
survey = L("endpoint-survey.json", []) or []
ok_survey = [e for e in survey if e.get("app_version")]
ibc_vals = sorted(set(e.get("ibc_go") for e in ok_survey if e.get("ibc_go")))
wasmvm_vals = sorted(set(e.get("wasmvm") for e in ok_survey if e.get("wasmvm")))
check("endpoint survey >= 2 nodes", len(ok_survey) >= 2, f"{len(ok_survey)} nodes: " + ", ".join(e["endpoint"] for e in ok_survey))
check("sampled nodes ibc-go == v7.4.0 only", ibc_vals == ["v7.4.0"], f"ibc-go values: {ibc_vals}")
check("sampled nodes wasmvm in 1.5.2/1.5.3 only", set(wasmvm_vals) <= {"v1.5.2", "v1.5.3"} and len(wasmvm_vals) >= 1, f"wasmvm values: {wasmvm_vals}")
patched = [e for e in ok_survey if e.get("wasmvm") not in (None, "", "v1.5.2", "v1.5.3") or e.get("ibc_go") not in (None, "", "v7.4.0")]
check("no node patched (would contradict finding)", not patched, f"patched nodes: {[e['endpoint'] for e in patched]}")

# ---- gov ----
gov = L("gov-params.json", {}) or {}
check("gov quorum == 0.334", abs(fnum(gov.get("quorum"), -1) - 0.334) < 1e-9, str(gov.get("quorum")))
check("gov threshold == 0.5", abs(fnum(gov.get("threshold"), -1) - 0.5) < 1e-9, str(gov.get("threshold")))
check("gov veto == 0.334", abs(fnum(gov.get("veto_threshold"), -1) - 0.334) < 1e-9, str(gov.get("veto_threshold")))
check("gov voting period 7d", gov.get("voting_period") == "604800000000000", str(gov.get("voting_period")))
check("gov min deposit 2000 DSM", fnum((gov.get("min_deposit") or [{}])[0].get("amount")) == 2_000_000_000, str(gov.get("min_deposit")))

# ---- wasm ----
wp = L("wasm-params.json", {}) or {}
acc = ((wp.get("params") or {}).get("codeUploadAccess") or {}).get("permission")
check("wasm code upload = EVERYBODY", acc == "ACCESS_TYPE_EVERYBODY", str(acc))
wc = L("wasm-codes.json", {}) or {}
codes = wc.get("codeInfos") or wc.get("code_infos") or []
check("wasm codes exist (module in use)", len(codes) >= 1, f"{len(codes)} codes")
wcs = L("wasm-contracts-summary.json", {}) or {}
check("wasm contracts instantiated", fnum(wcs.get("n_contracts")) >= 1, f"{wcs.get('n_contracts')} contracts")

# ---- economics ----
pool = L("staking-pool.json", {}) or {}
bonded = fnum(pool.get("bonded_tokens")) / 1e6
cpraw = L("community-pool.json", {}) or {}
cp = 0.0
for b in (cpraw.get("pool") or []):
    if b.get("denom") == "udsm":
        cp = fnum(b.get("amount")) / 1e6
check("bonded ~82.9M DSM (+-2%)", abs(bonded - 82_888_768) / 82_888_768 < 0.02, f"{bonded:,.3f}")
check("community pool ~16.67M DSM (+-2%)", abs(cp - 16_666_868) / 16_666_868 < 0.02, f"{cp:,.3f}")

cm = LO("cost-model.json", {}) or {}
q = cm.get("capture") or {}
osm = cm.get("osmosis") or {}
check("quorum > on-market weighted pool DSM (infeasible)", q.get("onmarket_infeasible") is True,
      f"quorum={q.get('quorum_dsm')} weighted_pool_total={osm.get('pool_dsm_total')}")
check("observable exit liquidity < $100k", fnum(osm.get("pool_counter_total_usd")) < 100_000,
      f"${fnum(osm.get('pool_counter_total_usd')):,.2f}")
check("CP dump realizable < $50k", fnum(q.get("cp_realizable_dump_usd")) < 50_000, f"${fnum(q.get('cp_realizable_dump_usd')):,.2f}")
check("net capture at spot < -$100k", fnum(q.get("net_if_otc_at_spot_usd")) < -100_000, f"${fnum(q.get('net_if_otc_at_spot_usd')):,.2f}")

esc = L("escrows.json", {}) or {}
esc_total = 0.0
for ch, info in esc.items():
    for b in (info.get("balances") or []):
        if b.get("denom") == "udsm":
            esc_total += fnum(b.get("amount")) / 1e6
check("IBC escrow backing > 40M DSM", esc_total > 40_000_000, f"{esc_total:,.3f}")

# ---- tally (SDK v0.47.10 rules) ----
B = bonded
QUORUM, THRESHOLD, VETO = 0.334, 0.5, 0.334
TOP4 = fnum((cm.get("staking") or {}).get("top4_dsm"), 68_804_250.596394)
def outcome(a_yes, others):
    v = {"yes": a_yes, "no": 0.0, "veto": 0.0, "abstain": 0.0}
    for opt, amt in others:
        v[opt] += amt
    total = sum(v.values())
    if total < QUORUM * B: return "FAIL"
    if total - v["abstain"] <= 0: return "FAIL"
    if v["veto"] / total > VETO: return "VETOED"
    return "PASS" if v["yes"] / (total - v["abstain"]) > THRESHOLD else "FAIL"
check("tally: quorum-only attacker passes if validators silent", outcome(QUORUM * B, []) == "PASS")
check("tally: quorum-only attacker fails if top-4 vote No", outcome(QUORUM * B, [("no", TOP4)]) == "FAIL")
check("tally: 68.9M attacker vetoed by top-4 NoWithVeto", outcome(68_900_000, [("veto", TOP4)]) == "VETOED")

npass = sum(1 for _, ok, _ in results if ok)
lines = ["# C2-10 Desmos — CI assertions", "", f"**{npass}/{len(results)} PASS**", "", "| assertion | result | detail |", "|---|---|---|"]
for name, ok, detail in results:
    lines.append(f"| {name} | {'PASS' if ok else 'FAIL'} | {detail} |")
with open(os.path.join(out, "ASSERTIONS.md"), "w") as f:
    f.write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(0 if npass == len(results) else 1)
