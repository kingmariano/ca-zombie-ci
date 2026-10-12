#!/usr/bin/env python3
"""Decisive read-only simulations: which package version actually passes the version gate.
Uses the sui.rpc.v2 proto-JSON format (kind/input/result fields), simulateTransaction only."""
import json, sys, urllib.request

GQL = "https://graphql.mainnet.sui.io/graphql"
SENDER = "0x0feb54a725aa357ff2f5bc6bb023c05b310285bd861275a30521f339a434ebb3"
DI = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
DI_SHARED_V = 1587827
SUI = "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
PAULY = "0xe7131700f8b336a011ff2d0e3403eb719ae9d5c15fc71bf371e4990eccf013a7::pauly::PAULY"
V1 = "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9"
VMID = "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f"
VLT = "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7"

QUERY = """query Sim($tx: JSON!) {
  simulateTransaction(transaction: $tx, checksEnabled: false, doGasSelection: true) {
    effects { status executionError { message identifier abortCode constant module { name } function { name } } }
  }
}"""

def sim(tx, label):
    body = {"query": QUERY, "variables": {"tx": tx}, "operationName": "Sim"}
    req = urllib.request.Request(GQL, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "bluemove-phase2-code-audit/0.1"})
    with urllib.request.urlopen(req, timeout=150) as r:
        d = json.loads(r.read())
    if d.get("errors"):
        print(f"[{label}] GQL-ERR {json.dumps(d['errors'])[:400]}")
        return None
    eff = (d["data"].get("simulateTransaction") or {}).get("effects") or {}
    print(f"[{label}] status={eff.get('status')} err={json.dumps(eff.get('executionError'))[:300]}")
    return eff

def tx_shared_call(pkg, module, fn, mutable, type_args=None, extra_inputs=None):
    return {
        "sender": SENDER,
        "kind": {"kind": "PROGRAMMABLE_TRANSACTION", "programmable_transaction": {
            "inputs": [{"kind": "SHARED", "object_id": DI, "version": DI_SHARED_V, "mutable": mutable}] + (extra_inputs or []),
            "commands": [{"move_call": {"package": pkg, "module": module, "function": fn,
                                        "type_arguments": type_args or [],
                                        "arguments": [{"kind": "INPUT", "input": 0}]}}]}}}

# 1) version-gate probes on assert_version_contract (public non-entry, read-only)
sim(tx_shared_call(VLT, "swap", "assert_version_contract", False), "VLT assert_version_contract")
sim(tx_shared_call(VMID, "swap", "assert_version_contract", False), "VMID assert_version_contract")
sim(tx_shared_call(V1, "swap", "assert_version_contract", False), "V1 assert_version_contract(should fail: no such fn?)")

# 2) sync_pool on pool that only has EscownCoins (V-mid escrow) -> expect escrow lookup abort
sim(tx_shared_call(VLT, "swap", "sync_pool", True, [SUI, PAULY]), "VLT sync_pool<SUI,PAULY> mutable Dex_Info")

# 3) control: V1 token_reserves is public non-entry but needs &Pool; try mint entry? use V1 create_new_pool_admin (gated but proof of callability)
sim(tx_shared_call(V1, "swap", "create_new_pool_admin", True, [SUI, PAULY]), "V1 create_new_pool_admin<SUI,PAULY> (dev-gated)")

# 4) VMID withdraw_fee_direct public non-entry (u64, &mut Dex_Info, ctx) - probe alive/dead
def tx_shared_call2(pkg, module, fn, mutable, type_args=None):
    return {
        "sender": SENDER,
        "kind": {"kind": "PROGRAMMABLE_TRANSACTION", "programmable_transaction": {
            "inputs": [{"kind": "SHARED", "object_id": DI, "version": DI_SHARED_V, "mutable": mutable},
                       {"kind": "PURE", "pure": "AAAAAAAAAAA="}],  # placeholder pure u64
            "commands": [{"move_call": {"package": pkg, "module": module, "function": fn,
                                        "type_arguments": type_args or [],
                                        "arguments": [{"kind": "INPUT", "input": 1}, {"kind": "INPUT", "input": 0}]}}]}}}
sim(tx_shared_call2(VMID, "swap", "withdraw_fee_direct", True, [SUI, PAULY]), "VMID withdraw_fee_direct(0, Dex_Info)")

# 5) VLT skim_pool probe (u64, &mut Dex_Info)
sim(tx_shared_call2(VLT, "swap", "skim_pool", True, [SUI, PAULY]), "VLT skim_pool(0, Dex_Info)")
