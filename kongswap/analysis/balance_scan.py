import json, cbor2, concurrent.futures, time
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
DEX = "2ipq2-uqaaa-aaaar-qailq-cai"

BAL_T = Types.Record({'owner': Types.Principal, 'subaccount': Types.Opt(Types.Vec(Types.Nat8))})

def call_query(canister, method, params):
    data = encode(params)
    req = {'request_type':'query','sender':agent.identity.sender().bytes,
           'canister_id':Principal.from_str(canister).bytes,'method_name':method,
           'arg':data,'ingress_expiry':agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(canister, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied':
        raise RuntimeError(f"{d.get('status')}: {str(d.get('reject_message'))[:120]}")
    arg = d['reply'].get('arg')
    return decode(arg) if arg else None

def bal(token):
    cid = token['canister']; sym = token['symbol']
    try:
        r = call_query(cid, "icrc1_balance_of", [{'type': BAL_T, 'value': {'owner': DEX, 'subaccount': []}}])
        v = r[0]['value'] if isinstance(r, list) and r else None
        return {'symbol': sym, 'canister': cid, 'decimals': token['decimals'], 'fee': token['fee'], 'balance_raw': str(v)}
    except Exception as e:
        return {'symbol': sym, 'canister': cid, 'decimals': token['decimals'], 'fee': token['fee'], 'error': str(e)[:160]}

tokens = json.load(open('tokens_ic.json'))
tokens = [t for t in tokens if t['canister']]
# add ICP native
tokens = [{'symbol':'ICP','canister':'ryjl3-tyaaa-aaaaa-aaaba-cai','decimals':8,'fee':10000}] + tokens
print("scanning", len(tokens), "ledgers...")
res = []
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
    for r in ex.map(bal, tokens):
        res.append(r)
json.dump(res, open('dex_balances_raw.json','w'), indent=1)
ok = [r for r in res if 'balance_raw' in r and r['balance_raw'] not in ('0',)]
err = [r for r in res if 'error' in r]
print("nonzero balances:", len(ok), "errors:", len(err))
for r in sorted(ok, key=lambda x: -int(x['balance_raw'])):
    print(f"{r['symbol']:12s} {r['balance_raw']:>28s}  dec={r['decimals']}  {r['canister']}")
print("--- errors ---")
for r in err[:40]:
    print(f"{r['symbol']:12s} {r['canister']}  {r['error'][:100]}")
