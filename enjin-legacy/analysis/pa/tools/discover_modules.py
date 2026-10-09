#!/usr/bin/env python3
"""Iterative module discovery for the Enjin legacy CryptoItems PA.

Start from a seed set of selectors (observed in real txs + admin + selectors of
known modules). For each selector read PA.delegates(selector) slot from storage.
Whenever a non-zero module address is found that we haven't inspected yet,
fetch its code, extract its selectors with evmole, and enqueue them.
Repeat until closure (fixed point).

RPC URL from env ETH_RPC (never written to disk). Saves only public data.
Outputs:
  analysis/pa/raw/module_discovery.json   (modules + routed selectors)
  analysis/pa/code/<addr>.hex             (new module bytecode)
"""
import json, os, urllib.request
from eth_hash.auto import keccak
import evmole

BASE = "/home/heisenberg/CA/enjin-legacy/analysis/pa"
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
DELEGATES_SLOT = 2


def delegates_key(selector_hex: str) -> str:
    sel = bytes.fromhex(selector_hex[2:])
    return "0x" + keccak(sel + b"\x00" * 28 + DELEGATES_SLOT.to_bytes(32, "big")).hex()


def rpc(url, method, params):
    req = urllib.request.Request(
        url,
        data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r)
    if "result" not in d:
        raise RuntimeError(d)
    return d["result"]


def rpc_batch(url, calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.load(r)
    by_id = {d["id"]: d for d in data}
    return [by_id[i].get("result") if "result" in by_id[i] else by_id[i].get("error") for i in range(len(calls))]


def read_storage_batch(url, slot_map):
    """slot_map: {selector: slot_hex} -> {selector: address or None}"""
    sels = list(slot_map)
    calls = [("eth_getStorageAt", [PA, slot_map[s], "latest"]) for s in sels]
    vals = rpc_batch(url, calls)
    out = {}
    for s, v in zip(sels, vals):
        if isinstance(v, str) and len(v) == 66 and int(v, 16) != 0:
            out[s] = "0x" + v[-40:]
        else:
            out[s] = None
    return out


def extract_selectors(addr, url):
    path = f"{BASE}/code/{addr}.hex"
    if not os.path.exists(path):
        code = rpc(url, "eth_getCode", [addr, "latest"])
        open(path, "w").write(code)
    raw = open(path).read().strip()
    if raw.startswith("0x"):
        raw = raw[2:]
    if raw in ("", "0x"):
        return []
    info = evmole.contract_info(bytes.fromhex(raw), selectors=True)
    out = []
    for f in info.functions:
        sel = f.selector
        if not sel.startswith("0x"):
            sel = "0x" + sel
        out.append(sel)
    return out


def main():
    url = os.environ["ETH_RPC"]
    seeds = set()
    # admin selectors
    seeds |= {"0x48ff15b3", "0x7457bbf7", "0x8d0a3a08", "0xa0a2daf0", "0xba0e930a", "0xd5009584"}
    # observed selectors from tx samples
    import glob
    for fn in glob.glob(f"{BASE}/raw/bs_pa_tx_p*.json") + [f"{BASE}/raw/etherscan_pa_txlist_p1.json"]:
        p = fn
        if not os.path.exists(p):
            continue
        d = json.load(open(p))
        items = d.get("result") if isinstance(d, dict) and isinstance(d.get("result"), list) else d.get("items", [])
        for it in items:
            raw = it.get("raw_input") or it.get("input") or ""
            if raw.startswith("0x") and len(raw) >= 10:
                seeds.add(raw[:10].lower())
    # already-known module selectors -> add via module files
    for fn in os.listdir(f"{BASE}/code"):
        if fn.endswith(".hex"):
            addr = fn[:-4]
            for sel in extract_selectors(addr, url):
                seeds.add(sel)

    inspected = {}  # module -> [selectors]
    routed = {}     # selector -> module
    queue = sorted(seeds)
    seen_queue = set(queue)
    changed = True
    while changed:
        changed = False
        slot_map = {s: delegates_key(s) for s in queue if s not in routed}
        # chunk
        chunk = 400
        keys = list(slot_map)
        for i in range(0, len(keys), chunk):
            part = {k: slot_map[k] for k in keys[i : i + chunk]}
            res = read_storage_batch(url, part)
            for sel, mod in res.items():
                routed[sel] = mod
        # find new modules
        for sel, mod in sorted(routed.items()):
            if mod and mod not in inspected:
                # check code size first
                code = rpc(url, "eth_getCode", [mod, "latest"])
                if len(code) <= 2:
                    inspected[mod] = []
                    continue
                inspected[mod] = extract_selectors(mod, url)
                for s in inspected[mod]:
                    if s not in routed and s not in seen_queue:
                        queue.append(s)
                        seen_queue.add(s)
                        changed = True
                changed = True
        if not changed:
            break

    # any seed selector that maps to a module we still haven't extracted?
    out = {
        "pa": PA,
        "n_selectors_checked": len(routed),
        "modules": {m: {"n_selectors": len(sels), "selectors": sels} for m, sels in sorted(inspected.items())},
        "routed": {s: routed[s] for s in sorted(routed) if routed[s]},
        "not_routed": [s for s in sorted(routed) if not routed[s]],
    }
    os.makedirs(f"{BASE}/raw", exist_ok=True)
    json.dump(out, open(f"{BASE}/raw/module_discovery.json", "w"), indent=2)

    print(f"checked {len(routed)} selectors; modules found: {len(inspected)}")
    for m, sels in sorted(inspected.items()):
        rs = [s for s in sels if routed.get(s) == m]
        print(f"  module {m}: {len(sels)} selectors, {len(rs)} routed: {rs}")


if __name__ == "__main__":
    main()
