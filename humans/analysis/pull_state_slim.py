#!/usr/bin/env python3
"""Slim live-state pull for C2-30 (fast). Saves analysis/raw/state.json."""
import base64, json, os, subprocess, time, hashlib

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
UA = "Mozilla/5.0 (X11; Linux x86_64) research"
LCD = "https://api.humans.nodestake.org"
RPC = "https://humans-rpc.noders.services"

def curl(url, timeout=20, post=None):
    cmd = ["curl", "-s", "--max-time", str(timeout), "-A", UA]
    if post:
        cmd += ["-X", "POST", "-H", "Content-Type: application/json", "-d", json.dumps(post)]
    cmd.append(url)
    for _ in range(2):
        out = subprocess.run(cmd, capture_output=True, text=True).stdout
        if out.strip():
            return out
        time.sleep(1)
    return out

def jget(path, base=LCD):
    try:
        return json.loads(curl(base + path))
    except Exception:
        return {"_error": True, "_path": path}

def abci(path, data_hex=""):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "abci_query",
               "params": {"path": path, "data": data_hex, "prove": False}}
    try:
        return json.loads(curl(RPC, post=payload))["result"]["response"]
    except Exception:
        return {"_error": True}

st = {}
b = jget("/cosmos/base/tendermint/v1beta1/blocks/latest")
st["height"] = int(b["block"]["header"]["height"]); st["time"] = b["block"]["header"]["time"]
st["staking_pool"] = jget("/cosmos/staking/v1beta1/pool").get("pool")
st["staking_params"] = jget("/cosmos/staking/v1beta1/params").get("params")
st["distribution_params"] = jget("/cosmos/distribution/v1beta1/params").get("params")
st["mint_params"] = jget("/cosmos/mint/v1beta1/params").get("params")
st["mint_inflation"] = jget("/cosmos/mint/v1beta1/inflation")
st["annual_provisions"] = jget("/cosmos/mint/v1beta1/annual_provisions")
st["slashing_params"] = jget("/cosmos/slashing/v1beta1/params").get("params")
st["supply_all"] = jget("/cosmos/bank/v1beta1/supply?pagination.limit=200").get("supply")
st["community_pool"] = jget("/cosmos/distribution/v1beta1/community_pool").get("pool")
st["community_pool_noders"] = jget("/cosmos/distribution/v1beta1/community_pool", "https://humans-api.noders.services").get("pool")
st["validators_bonded"] = jget("/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=300").get("validators")
st["validators_unbonding"] = jget("/cosmos/staking/v1beta1/validators?status=BOND_STATUS_UNBONDING&pagination.limit=300").get("validators")
st["validators_unbonded"] = jget("/cosmos/staking/v1beta1/validators?status=BOND_STATUS_UNBONDED&pagination.limit=300").get("validators")
# gov params via ABCI
for pt in ["tallying", "voting", "deposit"]:
    data = "0a" + format(len(pt), "02x") + pt.encode().hex()
    r = abci("/cosmos.gov.v1beta1.Query/Params", data)
    st["gov_abci_" + pt] = {"code": r.get("code"), "height": r.get("height"), "hex": base64.b64decode(r["value"]).hex() if r.get("value") else None}
st["proposals"] = jget("/cosmos/gov/v1beta1/proposals?pagination.limit=200").get("proposals")
st["tally_1"] = jget("/cosmos/gov/v1beta1/proposals/1/tally").get("tally")
st["tally_2"] = jget("/cosmos/gov/v1beta1/proposals/2/tally").get("tally")
st["votes_1"] = jget("/cosmos/gov/v1/proposals/1/votes?pagination.limit=400").get("votes")
st["votes_2"] = jget("/cosmos/gov/v1/proposals/2/votes?pagination.limit=400").get("votes")
st["ibc_channels"] = jget("/ibc/core/channel/v1/channels?pagination.limit=500").get("channels")
st["ibc_connections"] = jget("/ibc/core/connection/v1/connections?pagination.limit=500").get("connections")
st["ica_host_params"] = jget("/ibc/apps/interchain_accounts/host/v1/params")
st["wasm_codes"] = jget("/cosmwasm/wasm/v1/codes?pagination.limit=10")
st["upgrade_plan"] = jget("/cosmos/upgrade/v1beta1/current_plan")
st["module_accounts"] = jget("/cosmos/auth/v1beta1/module_accounts?pagination.limit=200").get("accounts")
# gov-module-owned ICA
gov_addr = "human10d07y265gmmuvt4z0w9aw880jnsr700jcdatdv"
st["gov_ica_connections"] = jget(f"/ibc/apps/interchain_accounts/controller/v1/owners/{gov_addr}/connections")
with open(os.path.join(RAW, "state.json"), "w") as f:
    json.dump(st, f, indent=1)
print("height", st["height"], st["time"])
print("bonded", st["staking_pool"])
print("cp", st["community_pool"])
print("cp_noders", st["community_pool_noders"])
print("wasm", str(st["wasm_codes"])[:120])
print("upgrade", str(st["upgrade_plan"])[:200])
print("gov_ica", str(st["gov_ica_connections"])[:200])
