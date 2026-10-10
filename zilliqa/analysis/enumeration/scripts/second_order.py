#!/usr/bin/env python3
"""
C2-58 child — round 3: second-order addresses discovered from round-2 state.
READ-ONLY. Writes ../raw/second_order.json
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
sys.path.insert(0, "/home/heisenberg/CA/zilliqa/analysis/scripts")
from zil_bech32 import hex_to_zil_bech32  # noqa: E402


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


# hex targets (already resolved), role, source
TARGETS = [
    ("0xd62bdccb7cfd8d564e645fb74a0d10741e73a4f2", "impl of zil18r80 proxy (label 'Phase 1.0 Proxy (Deprecated)')", "v1.0-proxy#2 state 'implementation'"),
    ("0x6074c76195392541a2f9e61379cc721deec025bb", "admin of zil18r80 proxy", "zil18r80 state 'admin'"),
    ("0x9611ec4c9388865fc21042677c268511afbc37f6", "contractadmin of zil16c4aej ('Zilliqa Seed Node Staking Contract')", "zil16c4aej state 'contractadmin'"),
]
PROBE = ["contractadmin", "admin", "implementation", "stagingadmin", "paused",
         "verifier", "verifier_receiving_addr", "gziladdr", "proxyaddr",
         "owners", "required_signatures", "transactionCount",
         "minstake", "maxstake", "contractmaxstake", "totalstakeddeposit",
         "totalstakeamount", "lastrewardblocknum", "lastrewardcycle"]


def main():
    out = {"collected_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "head": int(rpc("eth_blockNumber", [])["result"], 16), "targets": {}}
    print("head", out["head"])
    for a, role, src in TARGETS:
        rec = {"hex": a, "bech32": hex_to_zil_bech32(a), "role_guess": role, "source": src}
        code = rpc("eth_getCode", [a, "latest"])
        bal = rpc("eth_getBalance", [a, "latest"])
        leg = rpc("GetBalance", [a[2:]])
        rec["eth_getCode_size"] = (len(code["result"]) - 2) // 2 if code.get("result") else None
        rec["eth_getBalance_wei"] = int(bal["result"], 16) if bal.get("result") else None
        rec["eth_getBalance_zil"] = rec["eth_getBalance_wei"] / 1e18 if rec["eth_getBalance_wei"] is not None else None
        rec["legacy_GetBalance"] = leg.get("result")
        st = {}
        for f in PROBE:
            r = rpc("GetSmartContractSubState", [a[2:].lower(), f, []])
            if r.get("result"):
                st[f] = r["result"]
        rec["substate"] = st
        rec["init"] = rpc("GetSmartContractInit", [a[2:].lower()]).get("result")
        out["targets"][a] = rec
        print(f"{a} ({rec['bech32']}) code={rec['eth_getCode_size']} bal={rec['eth_getBalance_zil']}ZIL keys={list(st.keys())}")

    # full state of the small label-only contracts (identification + hidden-value scan)
    for bech, nick in [("zil16c4aejmulkx4vnnyt7m55rgsws088f8j5dl2rq", "stage0-ssnlist"),
                       ("zil18r80y2g5yaazfxfjxhh0jtz2pvl8ushd7224ma", "stage0-proxy")]:
        h = None
        # convert via public helper
        import subprocess  # noqa: S404
        h = "0x" + subprocess.check_output(
            ["python3", "/home/heisenberg/CA/zilliqa/analysis/scripts/zil_bech32.py", bech]
        ).decode().split("->")[-1].strip().replace("0x", "")
        r = rpc("GetSmartContractState", [h[2:].lower()])
        out[f"full_state_{nick}"] = {"hex": h, "bech32": bech, "result": r.get("result"), "error": r.get("error")}
        print("full state", nick, "bytes:", len(json.dumps(r.get("result"))))
    out["head_end"] = int(rpc("eth_blockNumber", [])["result"], 16)
    fp = RAW / "second_order.json"
    fp.write_text(json.dumps(out, indent=1))
    print("wrote", fp)


if __name__ == "__main__":
    main()
