import sys, json, base64
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
CAN = "2ipq2-uqaaa-aaaar-qailq-cai"

# Get raw reply bytes for user_balances/claims, then decode with permissive types.
def raw_call(method, params):
    data = encode(params)
    # use query_endpoint to get raw response
    import cbor2
    from ic.agent import sign_request
    req = {
        'request_type': 'query',
        'sender': agent.identity.sender().bytes,
        'canister_id': __import__('ic.principal', fromlist=['Principal']).Principal.from_str(CAN).bytes,
        'method_name': method,
        'arg': data,
        'ingress_expiry': agent.get_expiry_date(),
    }
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(CAN, payload)
    d = cbor2.loads(ret)
    return d

for m, params in [("user_balances", [{'type': Types.Text, 'value': "2ipq2-uqaaa-aaaar-qailq-cai"}]),
                  ("claims", [{'type': Types.Text, 'value': "2ipq2-uqaaa-aaaar-qailq-cai"}])]:
    d = raw_call(m, params)
    print("==", m, "status:", d.get('status'))
    rep = d.get('reply', {})
    arg = rep.get('arg') if isinstance(rep, dict) else None
    if arg:
        print("raw reply len:", len(arg))
        open(f"raw_{m}.bin","wb").write(arg)
        try:
            val = decode(arg)
            print(json.dumps(val, default=str)[:2000])
        except Exception as e:
            print("decode err:", e)
