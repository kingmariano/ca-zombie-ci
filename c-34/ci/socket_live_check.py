#!/usr/bin/env python3
"""CI heavy job: from socket_approvals_raw.json, compute the latest approval per (token,owner)
and read live allowance(owner->gateway) + balanceOf(owner) in batched eth_calls.
Output: ci-out/socket_live_approvals.json + printed summary.
Env: RPC_URL (required), MAX_CHECKS (optional, default 30000).
"""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
def pick_rpc():
    for u in [os.environ.get("FORK_RPC_URL"), os.environ.get("NODEREAL_ETH_RPC_URL"),
              os.environ.get("RPC_URL"), "https://ethereum-rpc.publicnode.com"]:
        if not u:
            continue
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
        try:
            req = urllib.request.Request(u, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=20) as r:
                if "result" in json.load(r):
                    return u
        except Exception:
            continue
    return "https://ethereum-rpc.publicnode.com"

RPC = pick_rpc()
UA = {"User-Agent": "zombie-hunt/read-only", "Content-Type": "application/json"}
GW = "0x3a23F943181408EAC424116Af7b7790c94Cb97a5"
MAX = int(os.environ.get("MAX_CHECKS", "1500"))

def rpc_batch(batch):
    req = urllib.request.Request(RPC, data=json.dumps(batch).encode(), headers=UA)
    for i in range(6):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                out = json.load(r)
            res = out if isinstance(out, list) else [out]
            # Individual call errors (non-ERC20 contracts etc.) are mapped to None, not fatal.
            return {v["id"]: (None if "error" in v else v.get("result")) for v in res}
        except Exception:
            time.sleep(1.5 * (i + 1))
    return {}

def enc_allowance(owner):
    return "0xdd62ed3e" + "0" * 24 + owner[2:].lower() + "0" * 24 + GW[2:].lower()

def enc_balance(owner):
    return "0x70a08231" + "0" * 24 + owner[2:].lower()

def main():
    rawp = os.path.join(OUT, "socket_approvals_raw.json")
    try:
        raw = json.load(open(rawp))
    except FileNotFoundError:
        raw = {"events": []}
    if not raw.get("events"):
        fb = os.path.join(HERE, "..", "analysis", "socket_approvals_raw.json")
        if os.path.exists(fb):
            print("ci-out census empty; falling back to", fb)
            raw = json.load(open(fb))
    if not raw.get("events"):
        sf = os.path.join(HERE, "..", "analysis", "socket_approvals_sample.json")
        if os.path.exists(sf):
            print("census empty; using committed sample", sf)
            rows = json.load(open(sf))
            raw = {"events": [{"block": e["b"], "token": e["t"], "owner": e["o"],
                               "tx": "sample", "logIndex": i, "value": int(e["v"])}
                              for i, e in enumerate(rows)]}
    if not raw.get("events"):
        # Secondary fallback: the 129 victims parsed from the 2024 attack raw trace (USDC).
        vf = os.path.join(HERE, "..", "analysis", "socket_2024_victims.json")
        if os.path.exists(vf):
            print("census empty; falling back to 2024 attack victims", vf)
            victims = json.load(open(vf))
            raw = {"events": [{"block": 19_021_454, "token": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                               "owner": v["victim"], "tx": "0xattack", "logIndex": i, "value": v["amount"]}
                              for i, v in enumerate(victims)]}
    events = raw["events"]
    print("approval events:", len(events))
    latest = {}
    for e in events:
        latest[(e["token"], e["owner"])] = e  # ascending order -> last wins
    pairs = sorted(latest.values(), key=lambda e: e["block"], reverse=True)
    print("unique (token,owner) pairs:", len(pairs))
    check = pairs[:MAX]
    # Always include the older 2024-victim cohort (most likely to still hold approvals).
    seen = {(e["token"], e["owner"]) for e in check}
    for e in pairs:
        if e["block"] < 20_000_000 and (e["token"], e["owner"]) not in seen:
            check.append(e)
            seen.add((e["token"], e["owner"]))
    print("checking live allowance+balance for", len(check), "pairs", flush=True)

    results = {"checked": 0, "allowance_nonzero": 0, "allowance_nonzero_and_balance": 0,
               "by_token": {}, "live": []}
    batch, metas = [], []
    for e in check:
        pi = len(batch) // 2  # pair index within the batch
        batch.append({"jsonrpc": "2.0", "id": pi * 2 + 1, "method": "eth_call",
                      "params": [{"to": e["token"], "data": enc_allowance(e["owner"])}, "latest"]})
        batch.append({"jsonrpc": "2.0", "id": pi * 2 + 2, "method": "eth_call",
                      "params": [{"to": e["token"], "data": enc_balance(e["owner"])}, "latest"]})
        metas.append(e)
        if len(batch) >= 30:  # 15 pairs per batch (public RPCs reject larger batches)
            _process(batch, metas, results)
            batch, metas = [], []
            time.sleep(0.2)
            if results["checked"] and results["checked"] % 1000 < 15:
                print("checked", results["checked"], "allowance!=0:", results["allowance_nonzero"],
                      "with balance:", results["allowance_nonzero_and_balance"], flush=True)
    if batch:
        _process(batch, metas, results)

    json.dump(results, open(os.path.join(OUT, "socket_live_approvals.json"), "w"), indent=1)
    print("== SUMMARY ==")
    print("pairs checked:", results["checked"])
    print("live allowance > 0:", results["allowance_nonzero"])
    print("live allowance > 0 AND owner balance > 0:", results["allowance_nonzero_and_balance"])
    print("top tokens among live approvals:", sorted(results["by_token"].items(), key=lambda x: -x[1])[:15])

def _process(batch, metas, results):
    m = rpc_batch(batch)
    for i, e in enumerate(metas):
        al = m.get(i * 2 + 1)
        ba = m.get(i * 2 + 2)
        if al is None or ba is None:
            continue
        alv = int(al, 16) if al != "0x" else 0
        bav = int(ba, 16) if ba != "0x" else 0
        results["checked"] += 1
        if alv > 0:
            results["allowance_nonzero"] += 1
            results["by_token"][e["token"]] = results["by_token"].get(e["token"], 0) + 1
            if bav > 0:
                results["allowance_nonzero_and_balance"] += 1
                results["live"].append({"token": e["token"], "owner": e["owner"],
                                        "allowance": str(alv), "balance": str(bav),
                                        "last_approval_block": e["block"]})

if __name__ == "__main__":
    main()
