import json, cbor2
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
CAN = "2ipq2-uqaaa-aaaar-qailq-cai"

def q(method, params):
    data = encode(params)
    req = {'request_type':'query','sender':agent.identity.sender().bytes,
           'canister_id':Principal.from_str(CAN).bytes,'method_name':method,
           'arg':data,'ingress_expiry':agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(CAN, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied':
        return {"_status": d.get('status'), "_err": str(d.get('reject_message', d))[:200]}
    arg = d['reply'].get('arg')
    if arg is None: return None
    return decode(arg)

def save(name, val):
    with open(name, 'w') as f: json.dump(val, f, default=str, indent=1)
    print(name, "saved", len(json.dumps(val, default=str)), "bytes")

print("== icrc1_name ==", q("icrc1_name", []))
save("live_tokens.json", q("tokens", [{'type': Types.Opt(Types.Text), 'value': []}]))
save("live_pools.json", q("pools", [{'type': Types.Opt(Types.Text), 'value': []}]))
save("live_check_pools.json", q("check_pools", []))
save("live_get_user.json", q("get_user", []))
r = q("requests", [{'type': Types.Opt(Types.Nat64), 'value': []}])
save("live_requests.json", r)
if isinstance(r, list) and r and isinstance(r[0], dict):
    print("requests count:", len(r[0].get('value', [])) if r[0].get('type') else len(r))
