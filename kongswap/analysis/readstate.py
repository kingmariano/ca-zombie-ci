import cbor2, json
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.principal import Principal

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)

def find(node, path):
    # node is list of [key, value] entries
    for k, v in node:
        if k == path[0]:
            if len(path) == 1:
                return v
            return find(v, path[1:])
    return None

targets = {
  "dex": "2ipq2-uqaaa-aaaar-qailq-cai",
  "root": "ormnc-tiaaa-aaaaq-aadyq-cai",
  "gov": "oypg6-faaaa-aaaaq-aadza-cai",
  "kong_ledger": "o7oak-iyaaa-aaaaq-aadzq-cai",
}
for name, cid in targets.items():
    p = Principal.from_str(cid)
    paths = [[b"canister", p.bytes, b"module_hash"], [b"canister", p.bytes, b"controllers"]]
    try:
        cert = agent.read_state_raw("aaaaa-aa", paths)
        tree = cert["tree"]
        mh = find(tree, [b"canister", p.bytes, b"module_hash"])
        ctl = find(tree, [b"canister", p.bytes, b"controllers"])
        mh_val = cbor2.loads(mh) if mh is not None else None
        ctl_val = cbor2.loads(ctl) if ctl is not None else None
        print(name, cid)
        print("  module_hash:", mh_val.hex() if mh_val else None)
        print("  controllers:", [Principal(c).to_str() if isinstance(c,bytes) else c for c in (ctl_val or [])])
    except Exception as e:
        print(name, "ERROR", str(e)[:300])
