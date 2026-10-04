import json
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request
import cbor2

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
CAN = "2ipq2-uqaaa-aaaar-qailq-cai"

def raw_call(method, params):
    data = encode(params)
    req = {
        'request_type': 'query',
        'sender': agent.identity.sender().bytes,
        'canister_id': Principal.from_str(CAN).bytes,
        'method_name': method,
        'arg': data,
        'ingress_expiry': agent.get_expiry_date(),
    }
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(CAN, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    return d

for m, params in [("user_balances", [{'type': Types.Text, 'value': "2ipq2-uqaaa-aaaar-qailq-cai"}]),
                  ("claims", [{'type': Types.Text, 'value': "2ipq2-uqaaa-aaaar-qailq-cai"}])]:
    d = raw_call(m, params)
    print("==", m, "status:", d.get('status'))
    rep = d.get('reply', {})
    arg = rep.get('arg') if hasattr(rep,'get') else None
    if arg:
        print("raw reply len:", len(arg))
        open(f"raw_{m}.bin","wb").write(arg)
        try:
            val = decode(arg)
            print(json.dumps(val, default=str)[:2500])
        except Exception as e:
            print("decode err:", e)
