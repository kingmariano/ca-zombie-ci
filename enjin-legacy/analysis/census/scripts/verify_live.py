#!/usr/bin/env python3
"""Full scan of Envoy Badge (61 items) + independent verification of live triples.

Writes envoy_full_scan.json and live_verification.json (all at one pinned block).
"""
import json, os

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BURN = "0x0000deaddeaddeaddeaddeaddeaddeaddead0000"
ZERO = "0x0000000000000000000000000000000000000000"
DEAD = "0x000000000000000000000000000000000000dead"
SENT = {BURN, ZERO, DEAD}
PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
ENVOY = {"shell": "0x0f1f62c38fa21da98bdcfb2f06e8a20dba979791",
         "baseType": "43648189888285219791758562213502959110711528811875759294532057304950080798720"}

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_shells.py")).read().split("def main")[0])

def main():
    [pinned] = [int(rpc_batch([("eth_blockNumber", [])])[0], 16)]
    shell = ENVOY["shell"]; base = int(ENVOY["baseType"])
    # full scan 1..61
    ids = [base | i for i in range(1, 62)]
    calls = [("eth_call", [{"to": shell, "data": "0x6352211e" + format(i, "064x")}, hex(pinned)]) for i in ids]
    res = []
    for i in range(0, len(calls), 10):
        res.extend(rpc_batch(calls[i:i + 10]))
    scan = []
    for iid, r in zip(ids, res):
        owner = None if isinstance(r, dict) else "0x" + r[-40:]
        cls = "nonexistent" if owner is None else ("melt-burn" if owner == BURN else ("legacy-burn" if owner == DEAD else ("zero" if owner == ZERO else "live")))
        scan.append({"id": str(iid), "idx": iid & ((1 << 64) - 1), "owner": owner, "class": cls})
    with open(os.path.join(CENSUS, "envoy_full_scan.json"), "w") as f:
        json.dump({"block": pinned, "shell": shell, "baseType": ENVOY["baseType"], "items": scan}, f, indent=1)
    nlive = sum(1 for s in scan if s["class"] == "live")
    print(f"Envoy full scan at {pinned}: {nlive}/61 live")

    # verify EVERY live triple with shell.ownerOf + PA.ownerOf + PA.balanceOf + getCode
    live = [s for s in scan if s["class"] == "live"]
    ver = []
    for s in live:
        iid = int(s["id"]); owner = s["owner"]
        calls = [
            ("eth_call", [{"to": shell, "data": "0x6352211e" + format(iid, "064x")}, hex(pinned)]),
            ("eth_call", [{"to": PA, "data": "0x6352211e" + format(iid, "064x")}, hex(pinned)]),
            ("eth_call", [{"to": PA, "data": "0x00fdd58e" + "0" * 24 + owner[2:] + format(iid, "064x")}, hex(pinned)]),
            ("eth_getCode", [owner, hex(pinned)]),
        ]
        r = rpc_batch(calls)
        shell_o = None if isinstance(r[0], dict) else "0x" + r[0][-40:]
        pa_o = None if isinstance(r[1], dict) else "0x" + r[1][-40:]
        bal = None if isinstance(r[2], dict) else int(r[2], 16)
        code = r[3]
        ver.append({"shell": shell, "baseType": ENVOY["baseType"], "instanceId": s["id"], "idx": s["idx"],
                    "owner": owner, "shell_ownerOf": shell_o, "pa_ownerOf": pa_o,
                    "pa_balanceOf": bal, "owner_is_contract": isinstance(code, str) and len(code) > 2,
                    "block": pinned,
                    "consistent": (shell_o == owner and pa_o == owner and bal == 1)})
    with open(os.path.join(CENSUS, "live_verification.json"), "w") as f:
        json.dump({"block": pinned, "count": len(ver), "allConsistent": all(v["consistent"] for v in ver), "triples": ver}, f, indent=1)
    print("live verification:", sum(1 for v in ver if v["consistent"]), "/", len(ver), "consistent")
    for v in ver[:5]:
        print("  ", v["idx"], v["owner"], "bal", v["pa_balanceOf"], "contract", v["owner_is_contract"])

if __name__ == "__main__":
    main()
