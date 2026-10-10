#!/usr/bin/env python3
"""
C2-58 child — round 2: verify label-database / init-discovered extra candidates.

READ-ONLY, keyless RPC. Writes ../raw/extra_candidates.json
"""
import json
import sys
import time
import urllib.request
from pathlib import Path

RPC = "https://api.zilliqa.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (read-only research)"}
HERE = Path(__file__).resolve().parent.parent
RAW = HERE / "raw"
RAW.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, "/home/heisenberg/CA/zilliqa/analysis/scripts")
from zil_bech32 import zil_bech32_to_hex, hex_to_zil_bech32  # noqa: E402


def rpc(method, params, timeout=40, retries=4):
    last = None
    for i in range(retries):
        try:
            body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
            req = urllib.request.Request(RPC, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (i + 1))
    return {"error": f"rpc failed: {last}"}


def hx(a):
    return a if a.startswith("0x") else "0x" + a


CANDIDATES = [
    # bech32, role guess, source
    ("zil18r80y2g5yaazfxfjxhh0jtz2pvl8ushd7224ma", "label: 'Zilliqa Seed Node Staking Phase 1.0 Proxy Contract (Deprecated)'", "ViewBlock/cryptometa labels.json"),
    ("zil16c4aejmulkx4vnnyt7m55rgsws088f8j5dl2rq", "label: 'Zilliqa Seed Node Staking Contract'", "ViewBlock/cryptometa labels.json"),
    ("zil1ur8ehr9qeqrgkgf3qj3ruv5dyt0w8nj53drvuz", "label: 'Seed Node Staking Phase 1.1 Deployer'", "ViewBlock/cryptometa labels.json"),
    ("zil1rm988wdvdnue5we36tr2y0yyxufcfphqcxmj55", "v1.1 impl init_admin (0x1Eca73B9...)", "GetSmartContractInit of v1.1 impl"),
    ("zil1vszj220406ez4gglpf6jvlds5jkszju63kpvax", "label: 'Zilliqa Reserve Multi-Sig 1' (context)", "ViewBlock/cryptometa labels.json"),
    ("zil1cm2x24v7807w7yjvmkz0am0y37vkys8lwtxsth", "label: 'Zilliqa Reserve Multi-Sig 2' (context)", "ViewBlock/cryptometa labels.json"),
]

PROBE_FIELDS = ["contractadmin", "admin", "implementation", "paused", "verifier",
                "gziladdr", "proxyaddr", "owners", "required_signatures",
                "transactionCount", "total_supply", "minter", "stagingadmin",
                "init_implementation", "init_admin"]


def main():
    out = {"collected_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "head": None, "candidates": {}}
    bn = int(rpc("eth_blockNumber", [])["result"], 16)
    out["head"] = bn
    print("head", bn)

    for addr, role, src in CANDIDATES:
        a = hx(zil_bech32_to_hex(addr))
        rec = {"hex": a, "bech32": addr, "role_guess": role, "source": src}
        code = rpc("eth_getCode", [a, "latest"])
        bal = rpc("eth_getBalance", [a, "latest"])
        leg = rpc("GetBalance", [a[2:]])
        rec["eth_getCode_size"] = (len(code["result"]) - 2) // 2 if code.get("result") else None
        rec["eth_getCode_is_eoa"] = code.get("result") in ("0x", None)
        rec["eth_getBalance_wei"] = int(bal["result"], 16) if bal.get("result") else None
        rec["eth_getBalance_zil"] = rec["eth_getBalance_wei"] / 1e18 if rec["eth_getBalance_wei"] is not None else None
        rec["legacy_GetBalance"] = leg.get("result")
        # probe Scilla state fields if it looks like a contract
        if not rec["eth_getCode_is_eoa"]:
            st = {}
            for f in PROBE_FIELDS:
                r = rpc("GetSmartContractSubState", [a[2:].lower(), f, []])
                res = r.get("result")
                if res:  # only record non-null
                    st[f] = res
            rec["substate_nonnull"] = st
            ini = rpc("GetSmartContractInit", [a[2:].lower()])
            rec["init"] = ini.get("result")
        out["candidates"][addr] = rec
        print(f"{addr} | code {rec['eth_getCode_size']} | {rec['eth_getBalance_zil']} ZIL | {json.dumps(rec.get('substate_nonnull', {}))[:200]}")

    head2 = int(rpc("eth_blockNumber", [])["result"], 16)
    out["head_end"] = head2
    fp = RAW / "extra_candidates.json"
    fp.write_text(json.dumps(out, indent=1))
    print("wrote", fp)


if __name__ == "__main__":
    main()
