import json, cbor2
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request
client = Client(url="https://ic0.app"); agent = Agent(identity=Identity(), client=client)
def q(method, params):
    data = encode(params)
    req = {'request_type':'query','sender':agent.identity.sender().bytes,'canister_id':Principal.from_str("2ipq2-uqaaa-aaaar-qailq-cai").bytes,'method_name':method,'arg':data,'ingress_expiry':agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint("2ipq2-uqaaa-aaaar-qailq-cai", payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied': return {'_status': d.get('status'), '_err': str(d.get('reject_message'))[:150]}
    arg = d['reply'].get('arg'); return decode(arg) if arg else None
for sym in ["KONG_ICP","ICP_ckUSDT","ckBTC_ICP","ICP_KONG"]:
    print(sym, "->", json.dumps(q("pools", [{'type': Types.Opt(Types.Text), 'value': [sym]}]), default=str)[:400])
