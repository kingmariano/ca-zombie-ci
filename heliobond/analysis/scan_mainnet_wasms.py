#!/usr/bin/env python3
"""Scan all mainnet contract WASMs for Heliobond fingerprints.

Inputs:
  mainnet_contracts_all.json  (from enumerate_all_mainnet_contracts.py)
  optional: ci-out/*_hashes.txt (sha256 of locally built vuln/fixed WASMs)

Strategy:
  * take every contract created >= 2026-06-01 (Heliobond org exists since 2026-06-12)
  * group by wasm hash; download hashes with <= MAX_INSTANCES instances network-wide
    (a project vault build is rare; factories are shared by thousands)
  * grep each binary for Heliobond markers, and exact-match against local build hashes
  * also emit the full hash -> instances table for the report

Read-only. Writes analysis/mainnet_wasm_scan.json and prints a report.
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ALL = os.path.join(HERE, "mainnet_contracts_all.json")
OUT_JSON = os.path.join(HERE, "mainnet_wasm_scan.json")
WASM_DIR = os.path.join(HERE, "wasm_mainnet")
UA = "Mozilla/5.0 (X11; Linux x86_64) heliobond-readonly-research/1.0"
CUTOFF = 1748736000  # 2026-06-01 UTC
MAX_INSTANCES = 50
MARKERS = [b"heliobond", b"Heliobond", b"HBS", b"QueuedClaim", b"fund_project",
           b"Heliobond Shares", b"InvestmentVault", b"VaultError"]


def get(url, retries=8):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 15 + 10 * i
                print(f"429; sleep {wait}s", flush=True)
                time.sleep(wait)
                continue
            if e.code == 404:
                return None
            if i == retries - 1:
                raise
            time.sleep(2 * (i + 1))
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(2 * (i + 1))


def load_local_hashes():
    out = {}
    ci_out = os.path.join(HERE, "..", "ci-out")
    if os.path.isdir(ci_out):
        for fn in os.listdir(ci_out):
            if fn.endswith("_hashes.txt"):
                name = fn[: -len("_hashes.txt")]
                for line in open(os.path.join(ci_out, fn)):
                    parts = line.split()
                    if len(parts) == 2 and parts[1].endswith("investment_vault.wasm"):
                        out[name] = parts[0]
    return out


def main():
    data = json.load(open(ALL))
    records = data["records"]
    print(f"contracts in dump: {len(records)} (updated {data.get('updated')})")
    counts = Counter(r.get("wasm") for r in records if r.get("wasm"))
    era = [r for r in records if (r.get("created") or 0) >= CUTOFF and r.get("wasm")]
    print(f"era contracts (>=2026-06-01) with wasm: {len(era)}; distinct hashes: {len(set(r['wasm'] for r in era))}")

    local = load_local_hashes()
    print("local build hashes:", local)

    candidates = sorted({r["wasm"] for r in era if counts[r["wasm"]] <= MAX_INSTANCES})
    print(f"candidate hashes (<= {MAX_INSTANCES} instances network-wide): {len(candidates)}")

    os.makedirs(WASM_DIR, exist_ok=True)
    results = {"scanned_hashes": [], "matches": [], "local_hash_hits": [], "counts": {}}
    matches = []
    for i, h in enumerate(candidates):
        path = os.path.join(WASM_DIR, h + ".wasm")
        blob = None
        if os.path.exists(path):
            blob = open(path, "rb").read()
        else:
            blob = get(f"https://api.stellar.expert/explorer/public/wasm/{h}")
            if blob is None:
                results["counts"][h] = {"error": "404"}
                continue
            if hashlib.sha256(blob).hexdigest() != h:
                print(f"WARNING sha mismatch for {h}")
            open(path, "wb").write(blob)
        found = [m.decode(errors="replace") for m in MARKERS if m in blob]
        insts = [r["contract"] for r in era if r["wasm"] == h]
        entry = {"hash": h, "instances": insts, "size": len(blob),
                 "markers": found, "network_instances": counts[h]}
        results["scanned_hashes"].append(entry)
        results["counts"][h] = counts[h]
        if found:
            matches.append(entry)
            print(f"MATCH {h} markers={found} instances={insts}")
        if h in local.values():
            for name, lh in local.items():
                if lh == h:
                    results["local_hash_hits"].append({"name": name, "hash": h, "instances": insts})
                    print(f"LOCAL HASH HIT: {name} {h} instances={insts}")
        if (i + 1) % 50 == 0:
            print(f"scanned {i+1}/{len(candidates)}", flush=True)
            json.dump(results, open(OUT_JSON, "w"))

    results["matches"] = matches
    json.dump(results, open(OUT_JSON, "w"), indent=1)
    print(f"\nDONE scanned={len(results['scanned_hashes'])} marker_matches={len(matches)} local_hits={len(results['local_hash_hits'])}")
    print("wrote", OUT_JSON)


if __name__ == "__main__":
    main()
