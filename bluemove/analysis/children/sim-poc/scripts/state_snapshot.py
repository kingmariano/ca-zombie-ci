#!/usr/bin/env python3
"""Capture the exact reviewed on-chain state (read-only) into evidence/state_snapshot.json.

Covers: Dex_Info, the test pool, its escrow dynamic object field, VersionManage field,
package version constants for the three known packages, pool-name convention,
and the currently used router in recent Dex_Info transactions.
"""
import json
import pathlib
import urllib.request

GQL = "https://graphql.mainnet.sui.io/graphql"
EVID = pathlib.Path(__file__).resolve().parent.parent / "evidence"
HEADERS = {"Content-Type": "application/json", "User-Agent": "bluemove-sim-poc/0.1"}

DEX = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
POOL = "0x32999bec61de990fe4cb931c98221677e91042048b0db773554eb7288a414368"
V1 = "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9"
VMID = "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f"
VLATEST = "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7"


def gql(q, v=None):
    req = urllib.request.Request(GQL, data=json.dumps({"query": q, "variables": v or {}}).encode(),
                                 headers=HEADERS)
    with urllib.request.urlopen(req, timeout=90) as r:
        d = json.loads(r.read())
    if d.get("errors"):
        raise RuntimeError(json.dumps(d["errors"])[:400])
    return d["data"]


OBJ = """query($a: SuiAddress!){ object(address:$a){ address version digest
  owner { __typename ... on Shared { initialSharedVersion } }
  asMoveObject { contents { type { repr } json } }
  dynamicFields(first: 5) { nodes { name { type { repr } json }
    value { __typename ... on MoveObject { address version digest contents { type { repr } json } } } } }
} }"""

FN = """query($a: SuiAddress!){ object(address:$a){ asMovePackage { module(name:"router"){
  a: function(name:"add_liquidity_returns"){ name visibility isEntry }
  b: function(name:"swap_exact_input_"){ name visibility isEntry }
  c: function(name:"swap_exact_input"){ name visibility isEntry }
  d: function(name:"remove_liquidity"){ name visibility isEntry }
} } } }"""

snap = {"endpoint": GQL}
for name, addr in (("dex_info", DEX), ("pool", POOL)):
    snap[name] = gql(OBJ, {"a": addr})["object"]

# VersionManage dynamic object field on Dex_Info (key = Dex_Info id, type 0x2::object::ID)
import base64
bcs_id = base64.b64encode(bytes.fromhex(DEX[2:])).decode()
VQ = """query($a: SuiAddress!, $n: DynamicFieldName!){ object(address:$a){
  dynamicObjectField(name: $n) { value { __typename ... on MoveObject { address version digest contents { type { repr } json } } } }
} }"""
snap["version_manage"] = gql(VQ, {"a": DEX, "n": {
    "type": "0x0000000000000000000000000000000000000000000000000000000000000002::object::ID", "bcs": bcs_id}})["object"]

for name, addr in (("v1", V1), ("vmid", VMID), ("vlatest_0x35f3", VLATEST)):
    snap[f"router_functions_{name}"] = gql(FN, {"a": addr})["object"]["asMovePackage"]["module"]

# recent Dex_Info traffic: which packages are actually called
CALLQ = """query($f: TransactionFilter){ transactions(last: 25, filter: $f){ nodes {
  digest effects { status } transactionJson } } }"""
nodes = gql(CALLQ, {"f": {"affectedObject": DEX}})["transactions"]["nodes"]
calls = {}
for n in nodes:
    tj = n.get("transactionJson") or {}
    cmds = (((tj.get("kind") or {}).get("programmableTransaction") or {}).get("commands")) or []
    for c in cmds:
        mc = c.get("moveCall")
        if mc and mc.get("package") != "0x0000000000000000000000000000000000000000000000000000000000000002":
            key = f"{mc.get('package')}::{mc.get('module')}::{mc.get('function')}"
            calls[key] = calls.get(key, 0) + 1
snap["recent_dex_info_tx_calls"] = calls
snap["recent_dex_info_tx_statuses"] = [(n.get("digest"),
                                        ((n.get("effects") or {}).get("status")))
                                       for n in nodes]

(EVID / "state_snapshot.json").write_text(json.dumps(snap, indent=1))
print("saved", EVID / "state_snapshot.json")
print("version_manage:", json.dumps(snap["version_manage"])[:400])
print("recent calls:", json.dumps(calls, indent=1))
