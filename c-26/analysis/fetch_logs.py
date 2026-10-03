#!/usr/bin/env python3
"""Fetch all EnabledModule/DisabledModule logs (topic1 = module) + module ActionExecuted logs.
Etherscan V2, read-only. Saves JSON pages to analysis/logs/."""
import json, os, sys, time, urllib.request, urllib.parse

ANALYSIS = "/home/heisenberg/CA/c-26/analysis"
os.makedirs(os.path.join(ANALYSIS, "logs"), exist_ok=True)
KEY = os.environ["ETHERSCANV2_API_KEY"]
MODULE = "0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca"
T_ENABLED = "0xecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f8440"
T_DISABLED = "0xaab4fa2b463f581b2b32cb3b7e3b704b9ce37cc209b5fb4d77e593ace4054276"
T_ACTION = "0xbbff709987512d10ea510d6fa17f8f95acd959892646194d0122df240b18a512"


def fetch_logs(params, name):
    all_rows = []
    page = 1
    while True:
        q = dict(params)
        q.update({"chainid": "1", "module": "logs", "action": "getLogs",
                  "page": str(page), "offset": "1000", "apikey": KEY})
        url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(q)
        for attempt in range(5):
            try:
                with urllib.request.urlopen(url, timeout=60) as r:
                    d = json.loads(r.read().decode())
                break
            except Exception as e:
                print("retry", name, page, e, file=sys.stderr)
                time.sleep(2 + attempt * 2)
        else:
            raise SystemExit("fetch failed " + name)
        if d.get("status") != "1":
            if d.get("message") == "No records found":
                break
            print("status", d.get("status"), d.get("message"), d.get("result"), file=sys.stderr)
            break
        rows = d.get("result", [])
        if not isinstance(rows, list) or not rows:
            break
        all_rows += rows
        print(f"{name} page {page}: +{len(rows)} total {len(all_rows)}")
        if len(rows) < 1000:
            break
        page += 1
        time.sleep(0.25)
    json.dump(all_rows, open(os.path.join(ANALYSIS, "logs", name + ".json"), "w"), indent=1)
    return all_rows


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "enabled"):
        rows = fetch_logs({"fromBlock": "0", "toBlock": "latest", "topic0": T_ENABLED,
                           "topic1": "0x" + MODULE[2:].lower().rjust(64, "0")}, "enabled_module")
        print("enabled events:", len(rows))
    if which in ("all", "disabled"):
        rows = fetch_logs({"fromBlock": "0", "toBlock": "latest", "topic0": T_DISABLED,
                           "topic1": "0x" + MODULE[2:].lower().rjust(64, "0")}, "disabled_module")
        print("disabled events:", len(rows))
    if which in ("all", "actions"):
        rows = fetch_logs({"fromBlock": "0", "toBlock": "latest",
                           "address": MODULE, "topic0": T_ACTION}, "module_actions")
        print("action events:", len(rows))
