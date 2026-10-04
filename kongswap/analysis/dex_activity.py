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
    if d.get('status') != 'replied':
        raise RuntimeError(f"{d.get('status')}: {str(d.get('reject_message'))[:180]}")
    arg = d['reply'].get('arg')
    return decode(arg) if arg else None

ACC = Types.Record({'owner': Types.Principal, 'subaccount': Types.Opt(Types.Vec(Types.Nat8))})
GT = Types.Record({'account': ACC, 'start': Types.Opt(Types.Nat), 'max_results': Types.Nat})
IDX = "onixt-eiaaa-aaaaq-aad2q-cai"
DEX = "2ipq2-uqaaa-aaaar-qailq-cai"
r = call_query(IDX, "get_account_transactions", [{'type': GT, 'value': {'account': {'owner': DEX, 'subaccount': []}, 'start': [], 'max_results': 100}}])
res = r[0]['value']['_17724']
print("balance:", res['_596483356'], "log_length:", res.get('_3331539157') and len(res['_3331539157']))
txs = res['_3331539157']
rows=[]
for t in txs:
    tid=t['_23515']; tx=t['_1266835934']
    kind=tx['_1191829844']
    ts=tx.get('_2781795542')
    amount=tx.get('_3573748184')
    frm=tx.get('_25979'); to=tx.get('_1136829802')
    def acct(a):
        if not a: return '?'
        o=a.get('_947296307'); s=a.get('_1349681965')
        return f"{o}" + (f" sub={bytes(s).hex()[:8]}" if s else "")
    rows.append((tid, kind, ts, amount, acct(frm), acct(to)))
rows.sort(key=lambda x: x[0])
print("first tx id:", rows[0][0], "last tx id:", rows[-1][0])
for tid,kind,ts,amount,frm,to in rows[-15:]:
    when = datetime.datetime.utcfromtimestamp(ts/1e9).isoformat() if ts else '?'
    print(f"id={tid} {kind:8s} {when} amt={amount} from={frm[:60]} to={to[:60]}")
