#!/usr/bin/env python3
"""Try simulateTransaction encodings for a MoveCall with a shared object input."""
import json, sys, urllib.request

GQL = "https://graphql.mainnet.sui.io/graphql"
SENDER = "0x0feb54a725aa357ff2f5bc6bb023c05b310285bd861275a30521f339a434ebb3"
DI = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
DI_SHARED_V = "1587827"
VLT = "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7"
VMID = "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f"

QUERY = """query Sim($tx: JSON!, $checks: Boolean, $gasSelect: Boolean) {
  simulateTransaction(transaction: $tx, checksEnabled: $checks, doGasSelection: $gasSelect) {
    effects { status executionError { message identifier abortCode constant module { name } function { name } } }
  }
}"""

def sim(tx):
    body = {"query": QUERY, "variables": {"tx": tx, "checks": False, "gasSelect": True}, "operationName": "Sim"}
    req = urllib.request.Request(GQL, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "bluemove-phase2-code-audit/0.1"})
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.loads(r.read())
    if d.get("errors"):
        return {"gql_errors": d["errors"]}
    st = d.get("data", {}).get("simulateTransaction") or {}
    return st.get("effects") or {}

def call(package, fn, arg_enc, input_enc, type_args=None):
    return {
        "sender": SENDER,
        "kind": {"kind": "PROGRAMMABLE_TRANSACTION", "programmableTransaction": {
            "inputs": [input_enc],
            "commands": [{"moveCall": {"package": package, "module": "swap", "function": fn,
                                       "typeArguments": type_args or [],
                                       "arguments": [arg_enc]}}]}}}

inputs = {
    "shared_snake": {"object": {"SharedObject": {"objectId": DI, "initialSharedVersion": DI_SHARED_V, "mutable": False}}},
    "shared_camel": {"Object": {"SharedObject": {"objectId": DI, "initialSharedVersion": DI_SHARED_V, "mutable": False}}},
}
argses = {"input_snake": {"input": 0}, "Input_camel": {"Input": 0}, "nested": {"NestedResult": [0, 0]}, "result": {"Result": 0}}

for iname, ienc in inputs.items():
    for aname, aenc in argses.items():
        for pkg, pname in ((VLT, "VLT(0x35f3)"), (VMID, "VMID(0x08cd)")):
            try:
                eff = sim(call(pkg, "assert_version_contract", aenc, ienc))
            except Exception as e:
                print(f"[{iname}/{aname}/{pname}] EXC {str(e)[:120]}")
                continue
            if "gql_errors" in eff:
                print(f"[{iname}/{aname}/{pname}] GQL-ERR {json.dumps(eff['gql_errors'])[:220]}")
            else:
                err = eff.get("executionError")
                print(f"[{iname}/{aname}/{pname}] status={eff.get('status')} err={json.dumps(err)[:220] if err else None}")
