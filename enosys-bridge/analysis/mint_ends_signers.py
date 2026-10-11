#!/usr/bin/env python3
"""Enosys Bridge — signer-set reconstruction on the Songbird/Flare mint ends.

Read-only. Rebuilds AddSigner/RemoveSigner history via the public Blockscout
explorer APIs (the public Flare RPCs cap eth_getLogs at 30 blocks), then reads
validatorInfo() live for every discovered signer.
"""
import json
import time
import urllib.request

RPC = {
    "songbird": ["https://songbird-api.flare.network/ext/C/rpc"],
    "flare": ["https://flare-api.flare.network/ext/C/rpc"],
}
EXPLORER = {
    "songbird": "https://songbird-explorer.flare.network/api",
    "flare": "https://flare-explorer.flare.network/api",
}
ENDS = [
    ("songbird", "0x8936761f2903ed1af2b269e6fa3a79ebb0162c51", "Songbird exUSDT/exETH"),
    ("songbird", "0xcb71dc7b30205eb7ce27b2cb36b24ba331ecd42a", "Songbird exXDC"),
    ("flare", "0x37aca97a99d1b4260a5e9821d0ef14947fb68970", "Flare eUSDT/eETH/eQNT"),
]
ADD = "0x986fcaacc4ec3bd003cca4a358313c174dbc682df73d495e8af308dc55b027a1"
REMOVE = "0x1803740ef72fc16e647c10fe2d31cf61a1578081960c2e3fb7f5aa957e82f550"
SEL_VI = "0x4f1811dd"
STATUS = {0: "Uninitialized", 1: "Removed", 2: "FirstCommittee", 3: "SecondCommittee"}


def rpc(chain, method, params, tries=3, tmo=25):
    last = None
    for url in RPC[chain]:
        for _ in range(tries):
            try:
                body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
                req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                r = json.load(urllib.request.urlopen(req, timeout=tmo))
                if "result" in r:
                    return r["result"]
                last = r.get("error")
            except Exception as e:  # noqa: BLE001
                last = f"ERR:{e}"
            time.sleep(0.7)
    return last


def explorer_logs(chain, addr, topic0):
    url = (
        f"{EXPLORER[chain]}?module=logs&action=getLogs&fromBlock=0&toBlock=latest"
        f"&address={addr}&topic0={topic0}"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    r = json.load(urllib.request.urlopen(req, timeout=30))
    if r.get("status") == "1" and isinstance(r.get("result"), list):
        return r["result"]
    return []


def num(x):
    try:
        return int(x, 16)
    except Exception:  # noqa: BLE001
        return None


out = {}
for chain, addr, label in ENDS:
    adds = explorer_logs(chain, addr, ADD)
    rems = explorer_logs(chain, addr, REMOVE)
    signers = {}
    for lg in adds:
        s = "0x" + lg["topics"][1][2 + 24 :]
        c1 = int(lg["topics"][2], 16) == 1
        signers[s] = {"committee": 1 if c1 else 2, "added_block": int(lg["blockNumber"], 16)}
    for lg in rems:
        s = "0x" + lg["topics"][1][2 + 24 :]
        signers.setdefault(s, {})["removed_block"] = int(lg["blockNumber"], 16)
    live = {}
    for s in signers:
        r = rpc(chain, "eth_call", [{"to": addr, "data": SEL_VI + s[2:].zfill(64)}, "latest"])
        st = num(r[2 : 2 + 64]) if isinstance(r, str) and len(r) >= 130 else None
        idx = num(r[2 + 64 : 2 + 128]) if isinstance(r, str) and len(r) >= 130 else None
        live[s] = {"status": STATUS.get(st, st), "index": idx}
    out[addr] = {"chain": chain, "label": label, "add_events": len(adds), "remove_events": len(rems), "events": signers, "live": live}
    active = {s: v for s, v in live.items() if v["status"] in ("FirstCommittee", "SecondCommittee")}
    print(f"[{chain}] {label}: {len(adds)} adds / {len(rems)} removes; ACTIVE now ({len(active)}): {json.dumps(active)}", flush=True)

with open("analysis/mint_ends_signers.json", "w") as f:
    json.dump(out, f, indent=2)
print("written analysis/mint_ends_signers.json")
