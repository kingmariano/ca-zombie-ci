#!/usr/bin/env python3
"""Post-process ci-out/results.json -> final per-protocol classification + markdown table."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "ci-out/results.json")))
meta = json.load(open(os.path.join(ROOT, "analysis/llama_meta.json")))
plan = json.load(open(os.path.join(ROOT, "ci/plan.json")))
rpcs = plan["rpcs"]

# --- pre-processing: avoid double counting in Pendle-style SYs (direct balance + claim value) ---
def fix_splice(pr):
    for t in pr["targets"]:
        if t.get("kind") != "splice" or not t.get("ok"):
            continue
        direct = {}
        claim = {}
        other = 0.0
        for a in t.get("assets", []):
            src = a.get("src", "")
            m = None
            if "SY 0x" in src and src.endswith("direct"):
                m = src.split("SY ")[1].split(" direct")[0]
                direct[m] = direct.get(m, 0) + a["usd"]
            elif "SY 0x" in src and "claim" in src:
                m = src.split("SY ")[1].split(" claim")[0]
                claim[m] = claim.get(m, 0) + a["usd"]
            else:
                other += a["usd"]
        total = other
        for sy in set(list(direct.keys()) + list(claim.keys())):
            total += max(direct.get(sy, 0), claim.get(sy, 0))
        t["usd"] = round(total, 2)
        t["note"] = (t.get("note", "") + " (splice: max(direct,claim) per SY)").strip()

for pr in res["protocols"]:
    fix_splice(pr)

rows = []
for pr in res["protocols"]:
    slug = pr["slug"]
    m = meta.get(slug, {})
    targets = pr["targets"]
    ok_t = [t for t in targets if t.get("ok")]
    fail_t = [t for t in targets if not t.get("ok")]
    onchain = round(sum((t.get("usd") or 0) for t in ok_t), 2)
    dl = m.get("current_tvl") or 0
    dl_date = m.get("last_tvl_date")
    dl_fresh = (dl_date or "") >= "2026-10-01"
    chains = sorted({t["chain"] for t in targets})
    blocks = {t["chain"]: t.get("block") for t in targets if t.get("block")}
    kinds = {t["kind"] for t in targets}
    if not ok_t:
        status = "UNREACHABLE"
    elif kinds == {"probe"} and onchain < 1000:
        status = "UNREACHABLE (addresses unresolved)"
    elif onchain >= 1000:
        status = "LIVE-FUNDED"
    else:
        status = "DRAINED"
    if ok_t and fail_t:
        status += " (partial)"
    # per-chain live
    per_chain = {}
    for t in ok_t:
        per_chain[t["chain"]] = round(per_chain.get(t["chain"], 0) + (t.get("usd") or 0), 2)
    # top contracts
    contracts = []
    for t in ok_t:
        c = {"label": t["label"], "chain": t["chain"], "usd": t.get("usd") or 0}
        if t.get("pair_count") is not None:
            c["pairs"] = t.get("pair_count")
        if t.get("pool_count") is not None:
            c["pools"] = t.get("pool_count")
        if t.get("markets"):
            c["markets"] = len(t["markets"])
        if t.get("pairs") is not None and t["kind"] == "cog":
            c["pairs"] = len(t["pairs"])
        if t.get("note"):
            c["note"] = t["note"]
        c["top_assets"] = sorted([a for a in (t.get("assets") or []) if a.get("usd", 0) > 0],
                                 key=lambda x: -x["usd"])[:4]
        contracts.append(c)
    # confidence heuristic
    conf = "high"
    if status.startswith("UNREACHABLE"):
        conf = "low"
    else:
        notes = " ".join(str(t.get("note", "")) for t in targets)
        if "partial" in status or "capped" in notes or "partial" in notes:
            conf = "medium"
        if dl and onchain:
            ratio = dl / max(onchain, 1)
            if ratio > 1.5 or ratio < 0.6:
                conf = "medium"
        if onchain < 1000:
            conf = "medium"
    rows.append({
        "slug": slug, "name": pr["name"], "status": status, "confidence": conf,
        "chains": chains, "onchain_usd": onchain, "defillama_usd": dl,
        "defillama_fresh": dl_fresh, "defillama_last_date": dl_date,
        "per_chain_live": per_chain, "blocks": blocks,
        "targets": contracts,
        "errors": [{"label": t["label"], "chain": t["chain"], "error": t.get("error")} for t in fail_t],
        "url": m.get("url"), "audits": m.get("audits"),
    })

rows.sort(key=lambda r: -r["onchain_usd"])
json.dump(rows, open(os.path.join(ROOT, "analysis/final_table.json"), "w"), indent=1)

print(f"{'protocol':26s} {'status':22s} {'onchain$':>10s} {'llama$':>10s} fresh chains")
for r in rows:
    print(f"{r['name'][:26]:26s} {r['status']:22s} {r['onchain_usd']:>10,.0f} {r['defillama_usd']:>10,.0f} "
          f"{'Y' if r['defillama_fresh'] else 'n':5s} {','.join(r['chains'])}")

tot_live = sum(r["onchain_usd"] for r in rows if r["status"].startswith("LIVE"))
print(f"\nLIVE total on-chain: ${tot_live:,.0f}")
print("funded:", sum(1 for r in rows if r["status"].startswith("LIVE")),
      "drained:", sum(1 for r in rows if r["status"].startswith("DRAINED")),
      "unreachable:", sum(1 for r in rows if r["status"].startswith("UNREACHABLE")))
