import json, time, cbor2
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request

client = Client(url="https://ic0.app"); agent = Agent(identity=Identity(), client=client)
DEX="2ipq2-uqaaa-aaaar-qailq-cai"; GOV="oypg6-faaaa-aaaaq-aadza-cai"; KONG="o7oak-iyaaa-aaaaq-aadzq-cai"
ICP_LEDGER="ryjl3-tyaaa-aaaaa-aaaba-cai"; TREAS="f39d9b22c382c25f832fd1d3e6ad5216249623b204a7fc5498f991f4cf2df1e1"
KONG_SUB=bytes.fromhex("0ecfd73b8ea0a1d24c36a1affe890b81bf2506e4a4f183591c9600872a5edc72")
BAL_T=Types.Record({"owner":Types.Principal,"subaccount":Types.Opt(Types.Vec(Types.Nat8))})
ACC_T=Types.Record({"account":Types.Vec(Types.Nat8)})
OPT=Types.Opt(Types.Text)

def q(canister, method, params):
    data=encode(params)
    req={"request_type":"query","sender":agent.identity.sender().bytes,"canister_id":Principal.from_str(canister).bytes,
         "method_name":method,"arg":data,"ingress_expiry":agent.get_expiry_date()}
    _,payload=sign_request(req,agent.identity)
    ret=agent.query_endpoint(canister,payload)
    d=ret if not isinstance(ret,bytes) else cbor2.loads(ret)
    if d.get("status")!="replied": raise RuntimeError(str(d.get("reject_message"))[:150])
    arg=d["reply"].get("arg"); return decode(arg) if arg else None
def unwrap(v):
    if isinstance(v,list) and v and isinstance(v[0],dict) and "value" in v[0]: v=v[0]["value"]
    if isinstance(v,dict): v=next(iter(v.values()))
    return v
def bal(cid, owner, sub=None):
    r=q(cid,"icrc1_balance_of",[{"type":BAL_T,"value":{"owner":owner,"subaccount":[list(sub)] if sub else []}}])
    return str(unwrap(r))

out={"ts_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())}
out["icrc1_name"]=unwrap(q(DEX,"icrc1_name",[]))
out["pools_all"]=unwrap(q(DEX,"pools",[{"type":OPT,"value":[]}]))
out["tokens_count"]=len(unwrap(q(DEX,"tokens",[{"type":OPT,"value":[]}])) or [])
for pn in ["KONG_ICP","ICP_ckUSDT","ckBTC_ICP"]:
    r=unwrap(q(DEX,"pools",[{"type":OPT,"value":[pn]}]))
    if r: out["pool_"+pn]={"pool_id":r[0].get("_3290882718"),"balance_0":r[0].get("_1283592060"),"balance_1":r[0].get("_1283592061")}
out["dex_balances"]={
 "SNEED":bal("r7cp6-6aaaa-aaaag-qco5q-cai",DEX),
 "ICE":bal("ifwyg-gaaaa-aaaaq-aaeqq-cai",DEX),
 "NUA":bal("rxdbk-dyaaa-aaaaq-aabtq-cai",DEX),
 "BIL":bal("57uyz-cyaaa-aaaap-qpvgq-cai",DEX),
 "ICP":bal(ICP_LEDGER,DEX),
 "ckBTC":bal("mxzaz-hqaaa-aaaar-qaada-cai",DEX),
 "ckETH":bal("ss2fx-dyaaa-aaaar-qacoq-cai",DEX),
 "ckUSDT":bal("cngnf-vqaaa-aaaar-qag4q-cai",DEX),
 "KONG":bal(KONG,DEX),
}
r=q(ICP_LEDGER,"account_balance",[{"type":ACC_T,"value":{"account":bytes.fromhex(TREAS)}}])
tv=unwrap(r); tv=tv.get("_5035232") if isinstance(tv,dict) else tv
out["treasury_icp_e8s"]=str(tv)
out["treasury_kong_e8s"]=bal(KONG,GOV,KONG_SUB)
p=Principal.from_str(DEX)
def find(node,path):
    for k,v in node:
        if k==path[0]: return v if len(path)==1 else find(v,path[1:])
    return None
for attempt in range(3):
    try:
        cert=agent.read_state_raw(DEX,[[b"canister",p.bytes,b"module_hash"],[b"canister",p.bytes,b"controllers"]])
        mh=find(cert["tree"],[b"canister",p.bytes,b"module_hash"]); ct=find(cert["tree"],[b"canister",p.bytes,b"controllers"])
        out["dex_module_hash"]=cbor2.loads(mh).hex(); out["dex_controllers"]=[Principal(c).to_str() for c in cbor2.loads(ct)]
        break
    except Exception as e:
        out["read_state_error_attempt_%d"%attempt]=str(e)[:120]
        time.sleep(2)
print(json.dumps(out,indent=1))
json.dump(out,open("final_recheck.json","w"),indent=1)
