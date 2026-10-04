import json, cbor2, datetime
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
def call_query(canister, method, params):
    data = encode(params)
    req = {'request_type':'query','sender':agent.identity.sender().bytes,
           'canister_id':Principal.from_str(canister).bytes,'method_name':method,
           'arg':data,'ingress_expiry':agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(canister, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied': raise RuntimeError(str(d.get('reject_message'))[:150])
    arg = d['reply'].get('arg')
    return decode(arg) if arg else None
ACC = Types.Record({'owner': Types.Principal, 'subaccount': Types.Opt(Types.Vec(Types.Nat8))})
GT = Types.Record({'account': ACC, 'start': Types.Opt(Types.Nat), 'max_results': Types.Nat})
DEX = "2ipq2-uqaaa-aaaar-qailq-cai"
r = call_query("onixt-eiaaa-aaaaq-aad2q-cai", "get_account_transactions", [{'type': GT, 'value': {'account': {'owner': DEX, 'subaccount': []}, 'start': [], 'max_results': 100}}])
txs = r[0]['value']['_17724']['_3331539157']
print("n txs:", len(txs))
for tx in txs:
    tid=tx['_23515']; t=tx['_1266835934']
    tr=t['_3664621355'][0]
    frm=tr['_25979']['_947296307']; to=tr['_1136829802']['_947296307']
    amt=tr['_3573748184']; ts=tr['_2781795542']/1e9
    when=datetime.datetime.utcfromtimestamp(ts).isoformat()
    direction = "IN " if to==DEX else ("OUT" if frm==DEX else "?? ")
    print(f'tx {tid}: {when} {direction} from {frm[:20]}.. to {to[:20]}.. amount {amt} ({amt/1e8:,.2f} KONG)')
