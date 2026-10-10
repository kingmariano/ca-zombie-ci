"""Fetch live state for every Folks app (v2: resumable, rate-limited, endpoint rotation).

Read-only. One JSON per app -> folks/raw/app_<id>.json
Plus folks/raw/folks_escrow_summary.json at the end.
"""
import base64
import json
import os
import sys
import time
import urllib.request
import urllib.error

FOLKS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(FOLKS, "raw")
UA = {"User-Agent": "zombie-research/1.0 (read-only)"}

ALGODS = [
    "https://mainnet-api.algonode.cloud/v2",
    "https://mainnet-api.4160.nodely.dev/v2",
]
INDEXERS = [
    "https://mainnet-idx.algonode.cloud/v2",
    "https://mainnet-idx.4160.nodely.dev/v2",
]

_last_call = [0.0]


def _get(urls, path, tries=4):
    last_err = None
    for t in range(tries):
        for i, base in enumerate(urls):
            url = base + path
            # global rate limit ~4/s
            dt = time.time() - _last_call[0]
            if dt < 0.22:
                time.sleep(0.22 - dt)
            try:
                req = urllib.request.Request(url, headers=UA)
                with urllib.request.urlopen(req, timeout=30) as r:
                    _last_call[0] = time.time()
                    return json.loads(r.read())
            except urllib.error.HTTPError as e:
                last_err = e
                if e.code == 404:
                    raise
                time.sleep(0.6 * (t + 1))
            except Exception as e:  # noqa: BLE001
                last_err = e
                time.sleep(0.6 * (t + 1))
    raise RuntimeError(str(last_err)[:200])


def get_app(aid):
    return _get(ALGODS, f"/applications/{aid}")


def get_account(addr):
    return _get(ALGODS, f"/accounts/{addr}")


def get_indexer_app(aid):
    return _get(INDEXERS, f"/applications/{aid}")


def app_address(app_id: int) -> str:
    import hashlib
    h = hashlib.new("sha512_256", b"appID" + app_id.to_bytes(8, "big")).digest()
    chk = hashlib.new("sha512_256", h).digest()[-4:]
    return base64.b32encode(h + chk).decode().rstrip("=")


def decode_global_state(gs):
    out = {}
    for e in gs or []:
        k = base64.b64decode(e["key"]).decode("utf-8", "replace")
        v = e["value"]
        out[k] = v["uint"] if v["type"] == 2 else v.get("bytes", "")
    return out


force = "--force" in sys.argv
app_list = json.load(open(os.path.join(RAW, "folks_app_list.json")))
round_now = _get(ALGODS, "/status")["last-round"]
print("round:", round_now, flush=True)

summary = {"fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "algod_round": round_now, "apps": []}

done = 0
for aid_s, label in sorted(app_list.items(), key=lambda kv: int(kv[0])):
    aid = int(aid_s)
    outfile = os.path.join(RAW, f"app_{aid}.json")
    if os.path.exists(outfile) and not force:
        summary["apps"].append(json.load(open(outfile)))
        done += 1
        continue
    rec = {"id": aid, "label": label}
    try:
        d = get_app(aid)
        p = d["params"]
        rec["creator"] = p.get("creator")
        rec["extra_program_pages"] = p.get("extra-program-pages", 0)
        rec["global_state"] = decode_global_state(p.get("global-state", []))
        rec["approval_b64"] = p.get("approval-program")
        rec["clear_b64"] = p.get("clear-state-program")
        rec["global_schema"] = p.get("global-state-schema")
        rec["local_schema"] = p.get("local-state-schema")
    except Exception as e:  # noqa: BLE001
        rec["app_error"] = str(e)[:300]
    try:
        ix = get_indexer_app(aid)
        app_ix = ix.get("application", {})
        rec["created_at_round"] = app_ix.get("created-at-round")
        rec["deleted"] = app_ix.get("deleted")
    except Exception as e:  # noqa: BLE001
        rec["indexer_error"] = str(e)[:200]
    try:
        addr = app_address(aid)
        rec["escrow_address"] = addr
        acc = get_account(addr)
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
    with open(outfile, "w") as f:
        json.dump(rec, f, indent=1)
    summary["apps"].append(rec)
    done += 1
    if done % 10 == 0:
        print(f"[{done}/{len(app_list)}] app {aid} {label}", flush=True)

with open(os.path.join(RAW, "folks_escrow_summary.json"), "w") as f:
    json.dump(summary, f, indent=1)
print("wrote", len(summary["apps"]), "app records at round", round_now)
