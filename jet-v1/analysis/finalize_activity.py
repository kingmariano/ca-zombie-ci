#!/usr/bin/env python3
"""Finalize the activity census: read activity_signatures.json + activity_census2.json
(partial results are fine), aggregate, and write activity_census.json + activity_census.md.
"""
import collections, json, os, time

HERE = os.path.dirname(os.path.abspath(__file__))
BOT_PROGRAM = "C3MPbLBQbREEJ56ku8SNHrHMh5q3iYKUkAYFQdvmcWP8"
BOT_WALLET = "4VnBfBpwUyQjvB8QBPYdtoeiLT3dH9zeErWS3qDjqMZx"
KEEPER_WALLET = "AZgsUBQpMa9DHuX5jpQKDNxNJ7BHgJHpkTaeAqr59cDB"

sigs = json.load(open(os.path.join(HERE, "activity_signatures.json")))["signatures"]
d = json.load(open(os.path.join(HERE, "activity_census2.json")))
results = d["txs"]

total = len(sigs)
ok = [s for s in sigs if results.get(s["signature"]) and not results[s["signature"]].get("error")]
missing = [s for s in sigs if not results.get(s["signature"]) or results[s["signature"]].get("error")]

ix_counts = collections.Counter()
ix_by_signer = collections.defaultdict(collections.Counter)
signer_counts = collections.Counter()
fp_counts = collections.Counter()
jet_txs = 0
by_day_sigs = collections.Counter()
by_day_classified = collections.Counter()
touching = {"solBTC": [], "solETH": []}
nonbot_bd = []
borrow_like = []
tx_rows = {}

for s in sigs:
    sig = s["signature"]
    bt = s.get("blockTime")
    if bt:
        by_day_sigs[time.strftime("%Y-%m-%d", time.gmtime(bt))] += 1
    r = results.get(sig)
    if not r or r.get("error"):
        continue
    if bt is None:
        bt = r.get("blockTime")
    if bt:
        by_day_classified[time.strftime("%Y-%m-%d", time.gmtime(bt))] += 1
    names = [h["name"] for h in r.get("jetIx", [])]
    if names:
        jet_txs += 1
    for n in names:
        ix_counts[n] += 1
        for sn in r.get("signers", []):
            ix_by_signer[n][sn] += 1
    for sn in r.get("signers", []):
        signer_counts[sn] += 1
    fp = r.get("feePayer")
    if fp:
        fp_counts[fp] += 1
    bot_involved = BOT_PROGRAM in (r.get("programs") or [])
    row = {"sig": sig, "slot": s.get("slot"), "blockTime": bt, "err": r.get("err"),
           "feePayer": fp, "signers": r.get("signers"), "jetIx": names,
           "programs": r.get("programs"), "botProgram": bot_involved}
    tx_rows[sig] = row
    if {"borrow", "deposit", "depositCollateral"} & set(names):
        borrow_like.append(row)
        if not bot_involved and fp not in (BOT_WALLET, KEEPER_WALLET):
            nonbot_bd.append(row)
    if r.get("touches_solBTC_reserve"):
        touching["solBTC"].append({k: row[k] for k in ("sig", "blockTime", "jetIx", "feePayer", "err")})
    if r.get("touches_solETH_reserve"):
        touching["solETH"].append({k: row[k] for k in ("sig", "blockTime", "jetIx", "feePayer", "err")})

summary = {
    "signatures": {
        "total_listed": total,
        "newest_iso": time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(sigs[0]["blockTime"])) if sigs[0].get("blockTime") else None,
        "oldest_iso": time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(sigs[-1]["blockTime"])) if sigs[-1].get("blockTime") else None,
        "per_day": dict(sorted(by_day_sigs.items())),
    },
    "fetched": {"txs_ok": len(ok), "txs_missing": len(missing),
                "date_range_classified": [min([r["blockTime"] for r in tx_rows.values() if r["blockTime"]], default=None),
                                          max([r["blockTime"] for r in tx_rows.values() if r["blockTime"]], default=None)]},
    "jet_txs_classified": jet_txs,
    "instruction_counts": dict(ix_counts.most_common()),
    "instruction_counts_by_signer": {k: dict(v) for k, v in ix_by_signer.items()},
    "distinct_fee_payers": dict(fp_counts.most_common()),
    "distinct_signers": dict(signer_counts.most_common()),
    "borrow_deposit_like_txs": borrow_like,
    "nonbot_borrow_deposit_like_txs": nonbot_bd,
    "touching_solBTC_reserve": touching["solBTC"],
    "touching_solETH_reserve": touching["solETH"],
    "method_caveat": "public RPC history is pruned; the archival source (Tatum public gateway) is limited to ~4.5 req/min, so coverage is partial and fully documented per-tx in activity_census.json",
}
json.dump({"summary": summary, "txs": tx_rows}, open(os.path.join(HERE, "activity_census.json"), "w"), indent=1)

lines = ["# Jet v1 program activity census", ""]
w = lines.append
w(f"- signature list: {total} sigs, {summary['signatures']['oldest_iso']} .. {summary['signatures']['newest_iso']}")
w(f"- classified txs: {len(ok)} ok / {len(missing)} not retrievable (pruned by public RPCs; archival fetch in progress/partial)")
w(f"- Jet txs among classified: {jet_txs}")
w("")
w("## Instruction counts (classified subset)")
w("")
w("| instruction | count |")
w("|---|---|")
for n, c in ix_counts.most_common():
    w(f"| {n} | {c} |")
w("")
w("## Distinct fee payers / signers")
for sn, c in fp_counts.most_common(20):
    w(f"- {sn}: {c}")
w("")
w(f"## Non-bot borrow/deposit-like txs: {len(nonbot_bd)}")
for t in nonbot_bd[:50]:
    w(f"- {t['sig']} {t['blockTime']} {t['jetIx']} feePayer={t['feePayer']}")
w("")
w(f"## Txs touching solBTC reserve: {len(touching['solBTC'])}; solETH reserve: {len(touching['solETH'])} (classified subset)")
for k in ("solBTC", "solETH"):
    for t in touching[k][:80]:
        w(f"- [{k}] {t['sig']} {t['blockTime']} {t['jetIx']} feePayer={t['feePayer']}")
w("")
w("## Signatures per day (all listed)")
for day, c in sorted(by_day_sigs.items()):
    w(f"- {day}: {c}")
open(os.path.join(HERE, "activity_census.md"), "w").write("\n".join(lines) + "\n")
print(json.dumps({k: v for k, v in summary.items() if k not in ("touching_solBTC_reserve", "touching_solETH_reserve")}, indent=1)[:2500])
