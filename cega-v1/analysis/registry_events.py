#!/usr/bin/env python3
"""CegaState registry + role event timeline via Etherscan V2 (read-only)."""
import json, os, subprocess, urllib.request, urllib.parse

KEY = os.environ["ETHERSCANV2_API_KEY"]
STATE = {"1": "0x0730AA138062D8Cc54510aa939b533ba7c30f26B",
         "42161": "0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed"}
TOPICS = {
    "ProductAdded": "0x4cc39cf92556f56ba17184d656cf1bbcfd5f8e8d7b1071d0e295017b9f70f41b",
    "ProductRemoved": "0x1c40e49688e963884d475feda3ddb42c17aec5d2a82706904ba014ee7ce54a2a",
    "RoleGranted": "0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d",
    "RoleRevoked": "0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b",
    "OracleAdded": None,
}

def keccak_topic(sig):
    return subprocess.run(["cast", "sig-event", sig], capture_output=True, text=True).stdout.strip()

TOPICS["OracleAdded"] = keccak_topic("OracleAdded(string,address)")

def getlogs(chainid, address, topic0, fromblock=0):
    out = []
    page = 1
    while True:
        q = urllib.parse.urlencode({
            "chainid": chainid, "module": "logs", "action": "getLogs",
            "fromBlock": fromblock, "toBlock": "latest", "address": address,
            "topic0": topic0, "page": page, "offset": 1000, "apikey": KEY,
        })
        url = "https://api.etherscan.io/v2/api?" + q
        with urllib.request.urlopen(url, timeout=60) as r:
            d = json.load(r)
        res = d.get("result") or []
        if not isinstance(res, list) or not res:
            break
        out += res
        if len(res) < 1000:
            break
        page += 1
    return out

# role hashes
def sig_role(name):
    return subprocess.run(["cast", "keccak", name], capture_output=True, text=True).stdout.strip()

ROLES = {"DEFAULT_ADMIN_ROLE": "0x" + "00"*32,
         "OPERATOR_ADMIN_ROLE": sig_role("OPERATOR_ADMIN_ROLE"),
         "TRADER_ADMIN_ROLE": sig_role("TRADER_ADMIN_ROLE"),
         "SERVICE_ADMIN_ROLE": sig_role("SERVICE_ADMIN_ROLE")}

res = {}
for cid, state in STATE.items():
    res[cid] = {}
    for name, t0 in TOPICS.items():
        logs = getlogs(cid, state, t0)
        res[cid][name] = logs
        print(f"chain {cid} {name}: {len(logs)} logs")
    # decode role topics
    for name, rolehash in ROLES.items():
        grants = [l for l in res[cid]["RoleGranted"] if l["topics"][1].lower() == rolehash.lower()]
        revokes = [l for l in res[cid]["RoleRevoked"] if l["topics"][1].lower() == rolehash.lower()]
        print(f"  {name}: {len(grants)} grants, {len(revokes)} revokes")
        for l in grants:
            acct = "0x" + l["topics"][2][-40:]
            print(f"    grant {acct} block {int(l['blockNumber'],16)}")
        for l in revokes:
            acct = "0x" + l["topics"][2][-40:]
            print(f"    revoke {acct} block {int(l['blockNumber'],16)}")

json.dump(res, open("registry_events.json", "w"), indent=1)
print("saved registry_events.json")
