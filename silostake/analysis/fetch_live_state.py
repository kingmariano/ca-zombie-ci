#!/usr/bin/env python3
"""Fetch SiloStake (Sei CosmWasm hub) live state from PUBLIC endpoints only.

Outputs: analysis/live-state.json  (all reads with the block context they were taken at)
No secrets, no keyed RPC URLs. Read-only.
"""
import json, urllib.request, urllib.parse, base64, subprocess, datetime, os, sys

HUB = "sei1e3gttzq5e5k49f9f5gzvrl0rltlav65xu6p9xc0aj7e84lantdjqp7cncc"
OWNER = "sei1wg3jpdr4zl59mqh2ptwv678tefjvqfjl32mf4y"   # owner == admin == operator
CREATOR = "sei1efpl63nwegea0j2a69hhapx0a7khmvaacxd67c"
FEE = "sei1uk7ulcdtnj885862ue658cuxwgjdp4dcfdemfg"      # protocol_fee_contract
LCD = "https://rest.sei-apis.com"
EVM_RPC = "https://sei-evm-rpc.publicnode.com"
ISEI_POINTER = "0x5cf6826140c1c56ff49c808a1a75407cd1df9423"
UA = {"User-Agent": "Mozilla/5.0"}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "live-state.json")

def get(url):
    req = urllib.request.Request(url, headers=UA)
    return json.loads(urllib.request.urlopen(req, timeout=40).read().decode())

def smart(msg):
    b = base64.b64encode(json.dumps(msg).encode()).decode()
    return get(f"{LCD}/cosmwasm/wasm/v1/contract/{HUB}/smart/{b}")["data"]

def cast(*args):
    try:
        return subprocess.run(["cast", *args], capture_output=True, text=True, timeout=40).stdout.strip()
    except Exception as e:
        return f"ERR: {e}"

out = {"fetched_at_utc": datetime.datetime.utcnow().isoformat() + "Z"}
out["sei_latest_block"] = get(f"{LCD}/cosmos/base/tendermint/v1beta1/blocks/latest")["block"]["header"]["height"]
out["sei_latest_block_time"] = get(f"{LCD}/cosmos/base/tendermint/v1beta1/blocks/latest")["block"]["header"]["time"]
out["hub"] = HUB
out["contract_info"] = get(f"{LCD}/cosmwasm/wasm/v1/contract/{HUB}")["contract_info"]
out["contract_history"] = get(f"{LCD}/cosmwasm/wasm/v1/contract/{HUB}/history")["entries"]
out["code_info_4485"] = get(f"{LCD}/cosmwasm/wasm/v1/code/4485")["code_info"]

out["state"] = smart({"state": {}})
out["config"] = smart({"config": {}})
out["pending_batch"] = smart({"pending_batch": {}})

# delegations
out["delegations"] = get(f"{LCD}/cosmos/staking/v1beta1/delegations/{HUB}")["delegation_responses"]
out["delegations_total_usei"] = sum(int(d["balance"]["amount"]) for d in out["delegations"])
# unbonding
ub = get(f"{LCD}/cosmos/staking/v1beta1/delegators/{HUB}/unbonding_delegations")["unbonding_responses"]
entries = []
for r in ub:
    for e in r["entries"]:
        entries.append({"validator": r["validator_address"], "creation_height": e["creation_height"],
                        "completion_time": e["completion_time"], "balance": e["balance"]})
out["unbonding_entries"] = entries
out["unbonding_total_usei"] = sum(int(e["balance"]) for e in entries)

# balances
out["balances"] = get(f"{LCD}/cosmos/bank/v1beta1/balances/{HUB}")["balances"]
out["fee_contract_balances"] = get(f"{LCD}/cosmos/bank/v1beta1/balances/{FEE}")["balances"]
out["owner_balances"] = get(f"{LCD}/cosmos/bank/v1beta1/balances/{OWNER}")["balances"]

# previous batches (paginate)
batches = []
start = None
while True:
    d = smart({"previous_batches": {"start_after": start, "limit": 30}})
    if not d:
        break
    batches.extend(d)
    start = d[-1]["id"]
    if len(d) < 30:
        break
out["previous_batches"] = batches
out["previous_batches_sum"] = {
    "count": len(batches),
    "total_shares_remaining": sum(int(b["total_shares"]) for b in batches),
    "utoken_unclaimed_total": sum(int(b["utoken_unclaimed"]) for b in batches),
    "utoken_unclaimed_reconciled": sum(int(b["utoken_unclaimed"]) for b in batches if b["reconciled"]),
    "utoken_unclaimed_unreconciled": sum(int(b["utoken_unclaimed"]) for b in batches if not b["reconciled"]),
}

# iSEI supply via EVM pointer (6 decimals)
out["isei_evm_block"] = cast("block-number", "--rpc-url", EVM_RPC)
out["isei_total_supply_6dec"] = cast("call", "--rpc-url", EVM_RPC, ISEI_POINTER, "totalSupply()(uint256)")
out["isei_name"] = cast("call", "--rpc-url", EVM_RPC, ISEI_POINTER, "name()(string)")

# price (DefiLlama, public)
try:
    out["prices"] = get("https://coins.llama.fi/prices/current/coingecko:sei-network,coingecko:silo-staked-sei")
except Exception as e:
    out["prices"] = {"error": str(e)}

json.dump(out, open(OUT, "w"), indent=1)
print("wrote", OUT)

# derived summary
u = out["state"]
print("state:", json.dumps(u))
print("delegations total SEI:", out["delegations_total_usei"] / 1e6)
print("unbonding total SEI:", out["unbonding_total_usei"] / 1e6)
print("bank:", out["balances"])
print("batches:", json.dumps(out["previous_batches_sum"]))
