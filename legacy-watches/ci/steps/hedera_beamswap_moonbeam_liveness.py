#!/usr/bin/env python3
"""
hedera_beamswap_moonbeam_liveness.py -- H2-09 hedera-other-amm group.

Checks Moonbeam (chain 1284) liveness for the Beamswap V2 frozen-custody
watch. Public keyless RPCs only; optional GoldRush key read from env
(GOLD_RUSH_API_KEY) is never printed.

Exit code 0 = live (blocks advancing / recent block timestamp),
exit code 2 = halted (last block timestamp older than --max-age hours),
exit code 1 = unreachable.

Usage: python3 hedera_beamswap_moonbeam_liveness.py [--max-age-hours 6]
"""
import argparse
import json
import os
import sys
import time
import urllib.request

RPCS = [
    "https://moonbeam.drpc.org",
    "https://rpc.api.moonbeam.network",
    "https://1rpc.io/glmr",
]
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (zombie-hunt-ii; readonly)"}


def post(url, payload, tries=2):
    for t in range(tries):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read())
        except Exception:
            if t == tries - 1:
                raise
            time.sleep(1.0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-age-hours", type=float, default=6.0)
    args = ap.parse_args()

    out = {"chain": "moonbeam", "chain_id": 1284, "rpcs": {}}
    live = False
    any_reachable = False
    for url in RPCS:
        try:
            b1 = post(url, {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"]
            time.sleep(2)
            b2 = post(url, {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"]
            blk = post(url, {"jsonrpc": "2.0", "id": 1, "method": "eth_getBlockByNumber",
                             "params": [b2, False]})["result"]
            ts = int(blk["timestamp"], 16)
            age_h = (time.time() - ts) / 3600.0
            advancing = b1 != b2
            out["rpcs"][url] = {"block": int(b2, 16), "block_ts": ts,
                                "age_hours": round(age_h, 2), "advancing": advancing}
            any_reachable = True
            if age_h < args.max_age_hours or advancing:
                live = True
        except Exception as e:  # noqa: BLE001
            out["rpcs"][url] = {"error": str(e)[:120]}

    key = os.environ.get("GOLD_RUSH_API_KEY")
    if key:
        try:
            req = urllib.request.Request(
                f"https://api.covalenthq.com/v1/1284/block_v2/latest/?key={key}",
                headers={"User-Agent": UA["User-Agent"]})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read())
            it = (d.get("data") or {}).get("items") or [{}]
            out["goldrush"] = {"height": it[0].get("height"), "signed_at": it[0].get("signed_at")}
        except Exception as e:  # noqa: BLE001
            out["goldrush"] = {"error": str(e)[:120]}

    print(json.dumps(out, indent=1))
    if not any_reachable:
        sys.exit(1)
    sys.exit(0 if live else 2)


if __name__ == "__main__":
    main()
