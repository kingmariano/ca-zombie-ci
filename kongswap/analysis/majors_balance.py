import cbor2
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request
client = Client(url="https://ic0.app"); agent = Agent(identity=Identity(), client=client)
def call_query(canister, method, params):
    data = encode(params)
    req = {'request_type':'query','sender':agent.identity.sender().bytes,'canister_id':Principal.from_str(canister).bytes,'method_name':method,'arg':data,'ingress_expiry':agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(canister, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied': raise RuntimeError(str(d.get('reject_message'))[:100])
    arg = d['reply'].get('arg'); return decode(arg) if arg else None
BAL_T = Types.Record({'owner': Types.Principal, 'subaccount': Types.Opt(Types.Vec(Types.Nat8))})
DEX = "2ipq2-uqaaa-aaaar-qailq-cai"
majors = {
 'ckBTC':'mxzaz-hqaaa-aaaar-qaada-cai','ckETH':'ss2fx-dyaaa-aaaar-qacoq-cai','ckUSDC':'xevnm-gaaaa-aaaar-qafnq-cai',
 'ckUSDT':'cngnf-vqaaa-aaaar-qag4q-cai','ICP':'ryjl3-tyaaa-aaaaa-aaaba-cai','CHAT':'2ouva-viaaa-aaaaq-aaamq-cai',
 'BOB':'7pail-xaaaa-aaaas-aabmq-cai','KONG':'o7oak-iyaaa-aaaaq-aadzq-cai','WTN':'jcmow-hyaaa-aaaaq-aadlq-cai',
 'SNS1':'3e3x2-xyaaa-aaaaq-aaalq-cai','TRAX':'ylks7-xiaaa-aaaaq-aablq-cai','DOLR':'6rdgd-kyaaa-aaaaq-aaavq-cai',
 'GHOST':'4c4fd-caaaa-aaaaq-aaa3a-cai','PANDA':'druyg-tyaaa-aaaaq-aactq-cai','NTN':'f54if-eqaaa-aaaaq-aacea-cai',
 'MOTOKO':'k45jy-aiaaa-aaaaq-aadcq-cai','ICPSwap':'ca6gz-lqaaa-aaaaq-aacwa-cai'}
for sym, cid in majors.items():
    try:
        r = call_query(cid, "icrc1_balance_of", [{'type': BAL_T, 'value': {'owner': DEX, 'subaccount': []}}])
        print(f"{sym:10s} {r[0]['value']}")
    except Exception as e:
        print(f"{sym:10s} ERR {str(e)[:80]}")
