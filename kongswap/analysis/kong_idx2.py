import json, cbor2
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
IDX = "onixt-eiaaa-aaaaq-aad2q-cai"
DEX = "2ipq2-uqaaa-aaaar-qailq-cai"
KONG_LEDGER = "o7oak-iyaaa-aaaaq-aadzq-cai"
BAL_T = Types.Record({'owner': Types.Principal, 'subaccount': Types.Opt(Types.Vec(Types.Nat8))})

# KONG balances
sub = bytes.fromhex("0ecfd73b8ea0a1d24c36a1affe890b81bf2506e4a4f183591c9600872a5edc72")
for owner, s, label in [("2ipq2-uqaaa-aaaar-qailq-cai", [], "DEX"), ("oypg6-faaaa-aaaaq-aadza-cai", [list(sub)], "TREASURY(gov sub)"), ("ormnc-tiaaa-aaaaq-aadyq-cai", [], "ROOT")]:
    r = call_query(KONG_LEDGER, "icrc1_balance_of", [{'type': BAL_T, 'value': {'owner': owner, 'subaccount': s}}])
    print(f"KONG {label}: {r[0]['value']}")

# index methods
for m in ["icrc10_supported_standards", "icrc1_name", "get_account_transactions"]:
    try:
        if m == "get_account_transactions":
            GT = Types.Record({'account': ACC, 'start': Types.Opt(Types.Nat), 'max_results': Types.Nat})
            r = call_query(IDX, m, [{'type': GT, 'value': {'account': {'owner': DEX, 'subaccount': []}, 'start': [], 'max_results': 3}}])
        else:
            r = call_query(IDX, m, [])
        print(f"IDX {m}:", json.dumps(r, default=str)[:600])
    except Exception as e:
        print(f"IDX {m} ERROR:", str(e)[:180])
