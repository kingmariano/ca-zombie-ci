#!/usr/bin/env python3
"""CI job: read Hemi MerkleBox live state (HEMI/token balances, holdings 15/16, group count).
Output: ci-out/hemi_state.json. Env: HEMI_RPC_URL (fallback public).
"""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
RPC = os.environ.get("HEMI_RPC_URL", "https://rpc.hemi.network/rpc")
UA = {"User-Agent": "zombie-hunt/read-only", "Content-Type": "application/json"}
MB1 = "0x9Ab3660ceE733332785cEa09D1a4Ff222F31aE54"
MB2 = "0x112de51b708c77C628532120Ffe2c0200f067399"
HEMI = "0x99e3dE3817F6081B2568208337ef83295b7f591D"
TT = "0x80625E7555F78bd71EBaD96c0000cec6c457bd7b"

def call(to, data):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": to, "data": data}, "latest"]}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    for i in range(5):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.load(r)
            if "result" in d:
                return d["result"]
        except Exception:
            time.sleep(1 + i)
    return None

def bal(token, who):
    r = call(token, "0x70a08231" + "0" * 24 + who[2:].lower())
    return int(r, 16) if r and r != "0x" else None

def main():
    out = {"rpc": RPC, "mb1": MB1, "mb2": MB2, "hemi": HEMI, "tt": TT}
    out["hemi_mb1"] = bal(HEMI, MB1)
    out["hemi_mb2"] = bal(HEMI, MB2)
    out["tt_mb1"] = bal(TT, MB1)
    out["mb1_eth"] = None
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_getBalance", "params": [MB1, "latest"]}).encode()
    try:
        req = urllib.request.Request(RPC, data=body, headers=UA)
        with urllib.request.urlopen(req, timeout=45) as r:
            out["mb1_eth"] = int(json.load(r)["result"], 16)
    except Exception:
        pass
    # claimGroupCount
    r = call(MB1, "0xaedefb80")  # claimGroupCount()
    out["claim_group_count"] = int(r, 16) if r and r != "0x" else None
    # holdings 15/16: third word (balance) of the static tuple
    for g in (15, 16):
        r = call(MB1, "0xaf503309" + g.to_bytes(32, "big").hex())  # holdings(uint256)
        out[f"holding_{g}"] = None
        if r and len(r) >= 2 + 64 * 3:
            out[f"holding_{g}"] = {"owner": "0x" + r[2 + 24:2 + 64],
                                   "erc20": "0x" + r[2 + 64 + 24:2 + 128],
                                   "balance": int(r[2 + 128:2 + 192], 16)}
    json.dump(out, open(os.path.join(OUT, "hemi_state.json"), "w"), indent=1)
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
