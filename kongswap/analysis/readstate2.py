import cbor2
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.principal import Principal

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
p = Principal.from_str("2ipq2-uqaaa-aaaar-qailq-cai")
paths = [[b"canister", p.bytes, b"module_hash"], [b"canister", p.bytes, b"controllers"]]
cert = agent.read_state_raw("aaaaa-aa", paths)
print("cert type:", type(cert))
print("keys:", list(cert.keys()) if isinstance(cert, dict) else cert[:200])
tree = cert["tree"]
print("tree type:", type(tree))
def dump(node, depth=0, prefix=b""):
    if depth > 4: return
    for k, v in node:
        if isinstance(v, bytes):
            print("  "*depth, prefix+k, "= leaf", v.hex()[:80])
        else:
            print("  "*depth, prefix+k, "(node)")
            dump(v, depth+1)
dump(tree)
