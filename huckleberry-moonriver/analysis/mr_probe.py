#!/usr/bin/env python3
"""Moonriver liveness probe (read-only, public endpoints).

Writes analysis/liveness_<tag>.json and prints a summary.
No secrets: only public endpoints / env var name referenced, values never printed.
"""
import json, sys, time, urllib.request, urllib.error, os, datetime

UA = "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt-research/1.0"

RPC_ENDPOINTS = [
    "https://moonriver.api.onfinality.io/public",
    "https://moonriver.drpc.org",
    "https://rpc.api.moonriver.moonbeam.network",
    "https://moonriver.public.blastapi.io",
    "https://moonriver-rpc.publicnode.com",
]

EXPLORER_ENDPOINTS = [
    # Moonscan (Etherscan-family) blocknumber without key
    ("moonscan_blocknumber", "https://api-moonriver.moonscan.io/api?module=block&action=eth_blockNumber"),
    # Blockscout v2
    ("blockscout_v2_blocks", "https://moonriver.blockscout.com/api/v2/blocks?type=block"),
    # Blockscout v1 (legacy) eth_blockNumber
    ("blockscout_v1_blocknumber", "https://moonriver.blockscout.com/api?module=block&action=eth_blockNumber"),
]


def http_get(url, timeout=25, headers=None):
    req = urllib.request.Request(url, headers=headers or {"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode("utf-8", "replace")
            return {"ok": True, "status": r.status, "body": body}
    except urllib.error.HTTPError as e:
        try:
            body = e.read().decode("utf-8", "replace")
        except Exception:
            body = ""
        return {"ok": False, "status": e.code, "body": body[:500], "error": str(e)}
    except Exception as e:
        return {"ok": False, "status": None, "error": str(e)}


def rpc_call(url, method, params):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=payload,
                                 headers={"Content-Type": "application/json", "User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}", "body": e.read().decode("utf-8", "replace")[:300]}
    except Exception as e:
        return {"error": str(e)}


def ts_to_utc(hex_ts):
    try:
        return datetime.datetime.fromtimestamp(int(hex_ts, 16), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except Exception:
        return None


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else "p"
    out = {
        "tag": tag,
        "probe_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rpc": [],
        "explorer": [],
    }
    for url in RPC_ENDPOINTS:
        entry = {"endpoint": url}
        bn = rpc_call(url, "eth_blockNumber", [])
        entry["blockNumber_raw"] = bn.get("result")
        blk = rpc_call(url, "eth_getBlockByNumber", ["latest", False])
        res = blk.get("result") or {}
        entry["head_number"] = res.get("number")
        entry["head_hash"] = res.get("hash")
        entry["head_timestamp"] = res.get("timestamp")
        entry["head_utc"] = ts_to_utc(res.get("timestamp", "0x0")) if res.get("timestamp") else None
        entry["parent_hash"] = res.get("parentHash")
        syncing = rpc_call(url, "eth_syncing", [])
        entry["eth_syncing"] = syncing.get("result", syncing.get("error"))
        if entry.get("blockNumber_raw") and not entry.get("head_number"):
            entry["error"] = "blockNumber ok but getBlock failed"
        if not entry.get("blockNumber_raw"):
            entry["error"] = bn.get("error") or "no result"
        out["rpc"].append(entry)

    for name, url in EXPLORER_ENDPOINTS:
        r = http_get(url)
        e = {"name": name, "endpoint": url, "ok": r["ok"], "status": r.get("status")}
        if r["ok"]:
            try:
                j = json.loads(r["body"])
                if name == "moonscan_blocknumber":
                    e["result"] = j.get("result")
                    e["message"] = j.get("message")
                    e["note"] = j.get("result", {}).get("status") if isinstance(j.get("result"), dict) else None
                elif name == "blockscout_v2_blocks":
                    items = j.get("items", [])
                    if items:
                        b = items[0]
                        e["head_number"] = b.get("height")
                        e["head_timestamp"] = b.get("timestamp")
                        e["head_hash"] = b.get("hash")
                elif name == "blockscout_v1_blocknumber":
                    e["result"] = j.get("result")
                    e["message"] = j.get("message")
            except Exception as ex:
                e["parse_error"] = str(ex)
                e["body_preview"] = r["body"][:300]
        else:
            e["error"] = r.get("error")
            e["body_preview"] = (r.get("body") or "")[:200]
        out["explorer"].append(e)

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"liveness_{tag}.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=2)
    print(json.dumps(out, indent=2))
    print(f"\nwrote {path}")


if __name__ == "__main__":
    main()
