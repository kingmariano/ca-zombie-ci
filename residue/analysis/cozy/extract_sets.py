#!/usr/bin/env python3
"""Extract all Cozy Set clone addresses from manager creation txs (read-only)."""
import json
import subprocess
import sys

EXPL = "https://explorer.optimism.io"
FAC2 = "0xdebe19b57e8b7eb6ea6ebea67b12153e011e6447"  # Gen-2 factory (clone deployer)
MGR1 = "0xa81ebc382a5d591bc07ffeebdc404eca487c00e7"  # Gen-1 manager


def curl_json(url):
    out = subprocess.run(["curl", "-s", "-m", "90", url, "-H", "User-Agent: Mozilla/5.0"],
                         capture_output=True, text=True, timeout=120)
    return json.loads(out.stdout)


def internals(tx):
    d = curl_json(f"{EXPL}/api/v2/transactions/{tx}/internal-transactions")
    return d.get("items", [])


def find_created(tx, factory):
    items = internals(tx)
    for i, it in enumerate(items):
        if it.get("type") in ("create", "create2") and it.get("created", {}).get("hash"):
            return it["created"]["hash"]
        if it.get("type") in ("create", "create2"):
            # the created address is the target of a following call from the factory
            for j in range(i + 1, min(i + 4, len(items))):
                to = items[j].get("to")
                if to and to["hash"].lower() == factory:
                    continue
                if items[j].get("from", {}).get("hash", "").lower() == factory and to:
                    return to["hash"]
    # fallback: any call from factory to non-factory
    for it in items:
        if it.get("type") == "call" and it.get("from", {}).get("hash", "").lower() == factory:
            to = it.get("to")
            if to and to["hash"].lower() != factory:
                return to["hash"]
    return None


def main():
    mgr2 = curl_json(f"{EXPL}/api/v2/addresses/0x7eDfAd1b566657a236C8422bA6997536BC647a29/transactions")
    txs2 = [it["hash"] for it in mgr2["items"] if it.get("method") == "0x3a5ccd70"]
    print(f"Gen-2 create txs: {len(txs2)}", file=sys.stderr)
    sets = {}
    for tx in txs2:
        a = find_created(tx, FAC2)
        print(f"  {tx[:18]} -> {a}", file=sys.stderr)
        if a:
            sets.setdefault(a, set()).add("gen2")

    mgr1 = curl_json(f"{EXPL}/api/v2/addresses/{MGR1}/transactions")
    # creation-ish methods on gen-1 manager (c771bd28 = createSet, dd1abe55/3929bea9 = others)
    txs1 = [it["hash"] for it in mgr1["items"] if it.get("method") in ("0xc771bd28", "0xdd1abe55", "0x3929bea9")]
    print(f"Gen-1 candidate txs: {len(txs1)}", file=sys.stderr)
    for tx in txs1:
        a = find_created(tx, MGR1)
        print(f"  {tx[:18]} -> {a}", file=sys.stderr)
        if a:
            sets.setdefault(a, set()).add("gen1")

    out = {a: sorted(v) for a, v in sets.items()}
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
