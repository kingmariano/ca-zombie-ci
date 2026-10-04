import cbor2
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
        raise RuntimeError(f"{d.get('status')}: {str(d.get('reject_message'))[:200]}")
    arg = d['reply'].get('arg')
    return decode(arg) if arg else None

BAL_T = Types.Record({'owner': Types.Principal, 'subaccount': Types.Opt(Types.Vec(Types.Nat8))})
ACC_T = Types.Record({'account': Types.Vec(Types.Nat8)})

r = call_query("ryjl3-tyaaa-aaaaa-aaaba-cai", "account_balance", [{'type': ACC_T, 'value': {'account': bytes.fromhex("f39d9b22c382c25f832fd1d3e6ad5216249623b204a7fc5498f991f4cf2df1e1")}}])
v = r[0]['value']
print("SNS treasury ICP account:", v)

for owner, sub, label in [
    ("oypg6-faaaa-aaaaq-aadza-cai", list(bytes.fromhex("ecfd73b8ea0a1d24c36a1affe890b81bf2506e4a4f183591c9600872a5edc72")), "gov treasury sub"),
    ("2ipq2-uqaaa-aaaar-qailq-cai", [], "DEX main"),
    ("okjrh-jqaaa-aaaaq-aad2a-cai", [], "swap main"),
]:
    r = call_query("o7oak-iyaaa-aaaaq-aadzq-cai", "icrc1_balance_of", [{'type': BAL_T, 'value': {'owner': owner, 'subaccount': sub}}])
    print(f"KONG {label}:", r[0]['value'])
