"""Query ICPSwap pool canisters on-chain: getState / getPoolMetadata (read-only queries)."""
import json, cbor2
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)

def call_query(canister, method, params=None):
    data = encode(params if params is not None else [])
    req = {'request_type': 'query', 'sender': agent.identity.sender().bytes,
           'canister_id': Principal.from_str(canister).bytes, 'method_name': method,
           'arg': data, 'ingress_expiry': agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(canister, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied':
        return {"_status": d.get('status'), "_err": str(d.get('reject_message', d))[:250]}
    arg = d['reply'].get('arg')
    return decode(arg) if arg else None

pools = {
    "KONG/ICP": "ye4fx-gqaaa-aaaag-qnara-cai",
    "KONG/MAPTF": "tzap2-xaaaa-aaaar-qbm5q-cai",
    "KONG/ckETH": "xm6pw-uaaaa-aaaag-qnbwa-cai",
    "BOB/KONG": "nemoc-diaaa-aaaag-qndbq-cai",
    "ICS/KONG": "y7qyo-piaaa-aaaar-qaq5a-cai",
    "KONG/EXE": "ppk5w-5qaaa-aaaar-qbr3a-cai",
    "nanas/KONG": "yw2so-kaaaa-aaaag-qnasa-cai",
    "pICP/KONG": "3icu4-6qaaa-aaaar-qaqvq-cai",
    "OGY/KONG": "szp7t-2aaaa-aaaar-qargq-cai",
}
out = {}
for name, can in pools.items():
    rec = {}
    for method in ("getPoolMetadata", "getState"):
        try:
            rec[method] = call_query(can, method)
        except Exception as e:
            rec[method] = {"_exception": str(e)[:200]}
    out[name] = {"canister": can, "data": rec}
    print("=" * 20, name, can)
    print(json.dumps(rec, default=str)[:1500])
json.dump(out, open("icpswap_pool_states.json", "w"), default=str, indent=1)
print("saved icpswap_pool_states.json")
