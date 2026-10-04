#!/usr/bin/env python3
"""Scan Summer.fi AutomationBot activeTriggers storage slots (read-only).

V2 bot: mapping(uint256 => TriggerRecord) activeTriggers at slot 1;
        record = {bytes32 triggerHash; address commandAddress; bool continuous}
V1 bot: mapping(uint256 => TriggerRecord) activeTriggers at slot 0;
        record = {bytes32 triggerHash; uint256 cdpId}
"""
import json, sys, time
from eth_hash.auto import keccak  # eth_hash may not be installed; fallback to sha3 via pysha3

try:
    from eth_hash.auto import keccak as k
    def keccak256(b): return k(b)
except Exception:
    import sha3  # pysha3
    def keccak256(b): return sha3.keccak_256(b).digest()

import urllib.request

def rpc_batch(url, calls, retries=4):
    payload = json.dumps(calls).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if i == retries - 1:
                raise
            time.sleep(2 * (i + 1))

def scan(url, bot, mapping_slot, start_id, end_id, outfile):
    active = []
    batch_size = 100
    ids = list(range(start_id, end_id + 1))
    for i in range(0, len(ids), batch_size):
        chunk = ids[i:i + batch_size]
        calls = []
        for idx, tid in enumerate(chunk):
            key = keccak256(tid.to_bytes(32, "big") + mapping_slot.to_bytes(32, "big"))
            calls.append({"jsonrpc": "2.0", "id": idx, "method": "eth_getStorageAt",
                          "params": [bot, "0x" + key.hex(), "latest"]})
        resp = rpc_batch(url, calls)
        by_id = {}
        for r in resp if isinstance(resp, list) else [resp]:
            by_id[r.get("id")] = r.get("result")
        for idx, tid in enumerate(chunk):
            val = by_id.get(idx)
            if val and int(val, 16) != 0:
                active.append(tid)
        if (i // batch_size) % 5 == 0:
            print(f"  {bot[:10]} {i+len(chunk)}/{len(ids)} active={len(active)}", file=sys.stderr)
    json.dump(active, open(outfile, "w"))
    return active

if __name__ == "__main__":
    jobs = [
        # name, url, bot, mapping_slot, first_id, last_id
        ("eth_v2", "https://ethereum-rpc.publicnode.com", "0x5743b5606e94fb534a31e1cefb3242c8a9422e5e", 1, 10000000001, 10000001119),
        ("eth_v1", "https://ethereum-rpc.publicnode.com", "0x6E87a7A0A03E51A741075fDf4D1FCce39a4Df01b", 0, 1, 3217),
        ("base_v2", "https://mainnet.base.org", "0x96D494b4544Bb7c3CB687ef7a9886Ed469e01ed8", 1, 10000000001, 10000000588),
        ("arb_v2", "https://arb1.arbitrum.io/rpc", "0xE018AeA83728a037D8B6f76cCA0E8331cDAb937a", 1, 10000000001, 10000000857),
        ("op_v2", "https://mainnet.optimism.io", "0xb2e2a088d9705cd412CE6BF94e765743Ec26b1e4", 1, 10000000001, 10000000324),
    ]
    which = sys.argv[1:] if len(sys.argv) > 1 else None
    summary = {}
    for name, url, bot, slot, first, last in jobs:
        if which and name not in which:
            continue
        print(f"SCAN {name} {bot} ids {first}..{last}", file=sys.stderr)
        try:
            active = scan(url, bot, slot, first, last, f"summerfi_{name}_active_triggers.json")
            summary[name] = len(active)
        except Exception as e:
            summary[name] = f"ERR {e}"
    print(json.dumps(summary, indent=2))
