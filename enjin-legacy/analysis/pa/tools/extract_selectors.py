#!/usr/bin/env python3
"""Extract function selectors from module bytecode (evmole) and resolve
PA.delegates(bytes4) storage slots on-chain (batched JSON-RPC).

RPC URL is read from env ETH_RPC. No secrets are written to disk.
Output: analysis/pa/raw/module_selectors.json
"""
import json, os, sys, urllib.request
from eth_hash.auto import keccak
import evmole

BASE = "/home/heisenberg/CA/enjin-legacy/analysis/pa"
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
DELEGATES_SLOT = 2

MODULES = {
    "0x684811e54a58fed4b813e8bb8685b511966b0ba4": "module_A(684811e5)",
    "0x68ee930ea6ad962205f1e29ae79bcc3dfa07c837": "module_B(68ee930e:CryptoItemsAdapters)",
    "0x1b73f45892d528379397922e8bf160b8710ee997": "module_C(1b73f458:CryptoItemsUsers)",
    "0x553f1e2211fa375ed81c61e25bedecc46b83b25b": "module_D(553f1e22)",
    "0x9a67aef2fd5669e2add4cbf87e310c29d9800252": "module_E(9a67aef2)",
    "0xc6bc3e5fbb5cbf277dfa6aae132af6db39e849e5": "module_F(c6bc3e5f)",
    "0xd257ea244160b2177fbc27b04e600e28cb9efdef": "module_G(d257ea24)",
    "0x4e643a25a64952895f553f20252861258727174e": "Adapter(4e643a25)",
}

ADMIN_SELECTORS = {
    "0x48ff15b3": "acceptManager()",
    "0x7457bbf7": "pendingManager() [inferred]",
    "0x8d0a3a08": "removeManager()",
    "0xa0a2daf0": "delegates(bytes4)",
    "0xba0e930a": "transferManager(address)",
    "0xd5009584": "getManager()",
}


def delegates_slot(selector_hex: str) -> bytes:
    """mapping(bytes4=>address) at slot 2, key = selector left-aligned in 32 bytes."""
    sel = bytes.fromhex(selector_hex[2:])
    key = sel + b"\x00" * 28
    return keccak(key + (DELEGATES_SLOT).to_bytes(32, "big"))


def rpc_batch(url, calls):
    """calls: list of (method, params). returns list of results/errors."""
    payload = [
        {"jsonrpc": "2.0", "id": i, "method": m, "params": p}
        for i, (m, p) in enumerate(calls)
    ]
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)
    by_id = {d["id"]: d for d in data}
    out = []
    for i in range(len(calls)):
        d = by_id.get(i, {})
        out.append(d.get("result") if "result" in d else {"error": d.get("error")})
    return out


def main():
    url = os.environ["ETH_RPC"]
    results = {"pa": PA, "admin_selectors": ADMIN_SELECTORS, "modules": {}}
    sel_rows = []  # (module, selector, sig_hint, slot_hex)

    for addr, name in MODULES.items():
        raw = open(f"{BASE}/code/{addr}.hex").read().strip()
        if raw.startswith("0x"):
            raw = raw[2:]
        code = bytes.fromhex(raw)
        info = evmole.contract_info(code, selectors=True, state_mutability=True, arguments=True)
        funcs = []
        for f in info.functions:
            sel = f.selector if isinstance(f.selector, str) else "0x" + f.selector.hex()
            if not sel.startswith("0x"):
                sel = "0x" + sel
            funcs.append(
                {
                    "selector": sel,
                    "state_mutability": str(f.state_mutability),
                    "arguments": str(f.arguments),
                }
            )
            sel_rows.append((addr, sel, str(f.arguments), str(f.state_mutability)))
        results["modules"][addr] = {"name": name, "n_functions": len(funcs), "functions": funcs}

    # add admin selectors to the delegation check
    for sel, sig in ADMIN_SELECTORS.items():
        sel_rows.append(("PA-admin", sel, sig, ""))

    # batch storage reads for each selector's delegates() slot on PA
    calls = []
    for addr, sel, args, mut in sel_rows:
        slot = "0x" + delegates_slot(sel).hex()
        calls.append(("eth_getStorageAt", [PA, slot, "latest"]))
    vals = rpc_batch(url, calls)

    resolved = {}
    for (addr, sel, args, mut), slot_call, val in zip(sel_rows, calls, vals):
        slot_hex = slot_call[1][1]
        val_addr = ""
        if isinstance(val, str) and len(val) == 66:
            if int(val, 16) != 0:
                val_addr = "0x" + val[-40:]
        key = f"{addr}|{sel}"
        resolved[key] = {
            "module_declared": addr,
            "selector": sel,
            "args": args,
            "state_mutability": mut,
            "delegates_slot": slot_hex,
            "delegates_value": val if isinstance(val, str) else val,
            "points_to": val_addr,
        }
    results["delegation"] = resolved
    os.makedirs(f"{BASE}/raw", exist_ok=True)
    with open(f"{BASE}/raw/module_selectors.json", "w") as f:
        json.dump(results, f, indent=2)

    # summary to stdout
    for key, r in resolved.items():
        if r["points_to"]:
            print(f"REGISTERED {r['selector']} -> {r['points_to']}  (declared in {r['module_declared']})")
    print("---not registered (selector not routed by PA)---")
    for key, r in resolved.items():
        if not r["points_to"]:
            print(f"unrouted   {r['selector']} (declared in {r['module_declared']})")


if __name__ == "__main__":
    main()
