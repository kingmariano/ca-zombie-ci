"""Fetch live state for every Folks app: global state + escrow balance.

Read-only. Saves one JSON per app into folks/raw/app_<id>.json
and a summary folks/raw/folks_escrow_summary.json.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts"))
import algo_lib as A  # noqa: E402

FOLKS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(FOLKS, "raw")

app_list = json.load(open(os.path.join(RAW, "folks_app_list.json")))

status = A.algod_get("/status")
round_now = status["last-round"]
print("round:", round_now)

summary = {
    "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "algod_round": round_now,
    "apps": [],
}

for i, (aid_s, label) in enumerate(sorted(app_list.items(), key=lambda kv: int(kv[0]))):
    aid = int(aid_s)
    rec = {"id": aid, "label": label}
    try:
        d = A.get_app(aid)
        p = d["params"]
        rec["creator"] = p.get("creator")
        rec["extra_program_pages"] = p.get("extra-program-pages", 0)
        rec["global_state"] = A.decode_global_state(p.get("global-state", []))
        rec["approval_b64"] = p.get("approval-program")
        rec["clear_b64"] = p.get("clear-state-program")
        rec["global_schema"] = p.get("global-state-schema")
        rec["local_schema"] = p.get("local-state-schema")
    except Exception as e:  # noqa: BLE001
        rec["app_error"] = str(e)[:300]
    try:
        ix = A.get_indexer_app(aid)
        app_ix = ix.get("application", {})
        rec["created_at_round"] = app_ix.get("created-at-round")
        rec["deleted"] = app_ix.get("deleted")
    except Exception as e:  # noqa: BLE001
        rec["indexer_error"] = str(e)[:200]
    try:
        addr = A.app_address(aid)
        rec["escrow_address"] = addr
        acc = A.get_account(addr)
        rec["escrow_microalgos"] = acc["amount"]
        rec["escrow_assets"] = [
            {"asset_id": a["asset-id"], "amount": a["amount"], "is_frozen": a.get("is-frozen", False)}
            for a in acc.get("assets", [])
        ]
        rec["escrow_total_assets"] = acc.get("total-assets-opted-in")
        rec["escrow_created_round"] = acc.get("created-at-round")
        rec["escrow_auth_addr"] = acc.get("auth-addr")
    except Exception as e:  # noqa: BLE001
        rec["escrow_error"] = str(e)[:200]
    summary["apps"].append(rec)
    with open(os.path.join(RAW, f"app_{aid}.json"), "w") as f:
        json.dump(rec, f, indent=1)
    if i % 20 == 0:
        print(f"[{i}/{len(app_list)}] app {aid} {label} done")
    time.sleep(0.12)

with open(os.path.join(RAW, "folks_escrow_summary.json"), "w") as f:
    json.dump(summary, f, indent=1)
print("wrote", len(summary["apps"]), "app records at round", round_now)
