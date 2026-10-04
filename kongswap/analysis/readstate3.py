import cbor2, inspect
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.principal import Principal
from ic.cbor import sign_request

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
p = Principal.from_str("2ipq2-uqaaa-aaaar-qailq-cai")
paths = [[b"canister", p.bytes, b"module_hash"]]
req = {
    'request_type': 'read_state',
    'sender': agent.identity.sender().bytes,
    'paths': paths,
    'ingress_expiry': agent.get_expiry_date(),
}
_, data = sign_request(req, agent.identity)
ret = agent.read_state_endpoint("2ipq2-uqaaa-aaaar-qailq-cai", data)
print("raw ret type:", type(ret), "len:", len(ret))
print(ret[:400])
try:
    d = cbor2.loads(ret)
    print("decoded:", type(d))
    print(str(d)[:400])
except Exception as e:
    print("cbor error:", e)
