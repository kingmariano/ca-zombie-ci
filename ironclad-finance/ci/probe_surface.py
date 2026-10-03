#!/usr/bin/env python3
"""Exhaustive unprivileged attack-surface prober for the Ironclad Finance (Mode) deployment.

Read-only: every function of every live Ironclad contract is invoked with dummy
arguments via `eth_call` from an unprivileged address.  A call that does NOT
revert is a candidate value path (or a harmless no-op) and is reported for manual
review.  Nothing is signed or broadcast.

Output: ci-out/probe_results.json (+ human-readable stdout).
"""
import json
import os
import sys
import time

import requests
from eth_abi import encode as abi_encode
from eth_utils import keccak

RPC = os.environ.get("MODE_RPC_URL", "https://mainnet.mode.network")
FROM = "0x0000000000000000000000000000000000c0ffee"
DUMMY = "0x0000000000000000000000000000000000c0ffee"

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ANALYSIS = os.path.join(ROOT, "analysis")

CONTRACTS = [
    ("LendingPool(proxy)",      "0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3", "pool_impl.json"),
    ("PoolConfigurator(proxy)", "0xc534f577c0e6c46B27fdcA6D27D132c543b0D61c", "configurator_impl.json"),
    ("LendingPoolProxy",        "0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3", "pool_contract.json"),
    ("aUSDC(proxy)",            "0xe7334ad0e325139329e747cf2fc24538dd564987", "atoken_impl.json"),
    ("aUSDCProxy",              "0xe7334ad0e325139329e747cf2fc24538dd564987", "atoken_proxy.json"),
    ("vUSDC",                   "0xe5415fa763489c813694d7a79d133f0a7363310c", "vdebt_impl.json"),
    ("Oracle",                  "0xE4F4F36FcBb2D53c0bAB95F5D117489579553CaA", "oracle_contract.json"),
    ("Registry",                "0x5C93B799D31d3d6a7C977f75FDB88d069565A55b", "registry_contract.json"),
    ("Provider",                "0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC", "provider_contract.json"),
    ("Timelock",                "0x96bCFB86F1bFf315c13E00D850e2FAeA93CcD3e7", "owner_contract.json"),
    ("Treasury",                "0xd93E25A8B1D645b15f8c736E1419b4819Ff9e6EF", "treasury_contract.json"),
    ("CollateralManager",       "0x025D9d36C616946530Ff8eA32d912aBf73170947", "collmgr.json"),
    ("M-BTC token",             "0x59889b7021243dB5B1e065385F918316cD90D46c", "mbtc_token.json"),
]

VIEW = {"view", "pure"}


def dummy_value(t):
    if t.endswith("[]"):
        inner = dummy_value(t[:-2])
        return [] if inner is None else [inner]
    if t == "address":
        return DUMMY
    if t == "bool":
        return False
    if t == "string":
        return ""
    if t == "bytes":
        return b""
    if t.startswith("bytes") and t[5:].isdigit():
        return b"\x00" * int(t[5:])
    if t.startswith("uint") or t.startswith("int"):
        return 1
    return None  # tuples / unsupported


def decode_revert(data):
    if not data or data == "0x":
        return "revert(no data)"
    raw = bytes.fromhex(data[2:])
    if raw[:4] == bytes.fromhex("08c379a0"):  # Error(string)
        try:
            from eth_abi import decode as abi_decode
            (s,) = abi_decode(["string"], raw[4:])
            return "revert: " + s
        except Exception:
            pass
    return "revert: 0x" + data[2:][:80]


def call(to, data):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
               "params": [{"from": FROM, "to": to.lower(), "input": data}, "latest"]}
    for attempt in range(3):
        try:
            r = requests.post(RPC, json=payload, timeout=30)
            j = r.json()
            if "result" in j:
                return {"status": "success", "result": j["result"]}
            err = j.get("error", {})
            return {"status": "revert", "reason": decode_revert(err.get("data") or ""),
                    "raw_error": str(err.get("message"))[:120]}
        except Exception as e:
            if attempt == 2:
                return {"status": "rpc_error", "reason": str(e)[:120]}
            time.sleep(1)
    return {"status": "rpc_error", "reason": "unreachable"}


def main():
    results = []
    for name, addr, abi_file in CONTRACTS:
        path = os.path.join(ANALYSIS, abi_file)
        if not os.path.exists(path):
            results.append({"contract": name, "address": addr, "abi": abi_file, "error": "abi missing"})
            continue
        abi = json.load(open(path)).get("abi") or []
        for item in abi:
            if item.get("type") != "function":
                continue
            fn = item.get("name")
            mut = item.get("stateMutability", "nonpayable")
            ins = item.get("inputs") or []
            types = [i["type"] for i in ins]
            vals = [dummy_value(t) for t in types]
            if any(v is None for v in vals):
                results.append({"contract": name, "address": addr, "function": fn,
                                "stateMutability": mut, "status": "skipped(struct/unsupported args)"})
                continue
            try:
                data = "0x" + keccak(text=fn + "(" + ",".join(types) + ")")[:4].hex()
                if types:
                    data += abi_encode(types, vals).hex()
            except Exception as e:
                results.append({"contract": name, "function": fn, "status": "skipped(encode)",
                                "reason": str(e)[:80]})
                continue
            out = call(addr, data)
            out.update({"contract": name, "address": addr, "function": fn,
                        "stateMutability": mut, "kind": "view" if mut in VIEW else "state-changing",
                        "sig": fn + "(" + ",".join(types) + ")"})
            results.append(out)
            time.sleep(0.12)

    os.makedirs(os.path.join(ROOT, "ci-out"), exist_ok=True)
    with open(os.path.join(ROOT, "ci-out", "probe_results.json"), "w") as f:
        json.dump(results, f, indent=1)

    state = [r for r in results if r.get("kind") == "state-changing"]
    succ = [r for r in state if r.get("status") == "success"]
    skipped = [r for r in results if str(r.get("status", "")).startswith("skipped")]
    print(f"# probed {len(results)} functions; state-changing: {len(state)}; skipped: {len(skipped)}")
    if not state:
        print("FATAL: no state-changing functions were probed (missing eth-hash backend?)")
        sys.exit(2)
    print(f"# state-changing calls that did NOT revert (review): {len(succ)}")
    for r in succ:
        print(f"  NO-REVERT {r['contract']}.{r.get('sig')} -> {str(r.get('result'))[:80]}")
    print("\n# state-changing revert reasons (grouped)")
    groups = {}
    for r in state:
        key = (r["contract"], r.get("reason") or r.get("status"))
        groups[key] = groups.get(key, 0) + 1
    for (c, reason), n in sorted(groups.items()):
        print(f"  {c:26} {str(reason)[:60]:60} x{n}")


if __name__ == "__main__":
    main()
