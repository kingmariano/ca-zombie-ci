import json, cbor2
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
GOV = "oypg6-faaaa-aaaaq-aadza-cai"

def call_query(canister, method, params):
    data = encode(params)
    req = {'request_type':'query','sender':agent.identity.sender().bytes,
           'canister_id':Principal.from_str(canister).bytes,'method_name':method,
           'arg':data,'ingress_expiry':agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(canister, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied':
        raise RuntimeError(f"{d.get('status')}: {str(d.get('reject_message'))[:200]}")
    arg = d['reply'].get('arg')
    return decode(arg) if arg else None

# list_neurons args: record { of_principal: opt principal; limit: nat32; start_page_at: opt NeuronId }
# NeuronId = record { id: blob }
NID = Types.Record({'id': Types.Vec(Types.Nat8)})
ARGS = Types.Record({'of_principal': Types.Opt(Types.Principal), 'limit': Types.Nat32, 'start_page_at': Types.Opt(NID)})
all_neurons = []
start = None
for page in range(40):
    val = {'of_principal': [], 'limit': 100, 'start_page_at': [] if start is None else [{'id': start}]}
    r = call_query(GOV, "list_neurons", [{'type': ARGS, 'value': val}])
    # r is [{'type':..., 'value': {'neurons': [...], ...}}]
    neurons = r[0]['value'].get('_3923068064') if isinstance(r[0]['value'], dict) else None
    if neurons is None:
        print("unexpected", str(r)[:500]); break
    if not neurons:
        break
    all_neurons.extend(neurons)
    # neuron id field for pagination
    last = neurons[-1]
    # find id field: hash key for 'id' -> find value that's bytes length 32
    def find_id(rec):
        for k,v in rec.items():
            if isinstance(v, bytes) and len(v)==32:
                return v
        return None
    start = find_id(last)
    print(f"page {page}: got {len(neurons)} total {len(all_neurons)} start_next={start.hex()[:16] if start else None}")
    if len(neurons) < 100: break
json.dump(all_neurons, open('sns_neurons_raw.json','w'), default=str)
print("total neurons:", len(all_neurons))
