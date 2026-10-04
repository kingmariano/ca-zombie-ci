"""Read-only on-chain probe of KONG liquidity venues + ledger balances.
All calls are IC query calls (anonymous). No updates, no transactions.
"""
import json, cbor2, sys
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)

def call_query(canister, method, params=None):
    data = encode(params if params is not None else [])
    req = {'request_type': 'query', 'sender': agent.identity.sender().bytes,
           'canister_id': Principal.from_str(canister).bytes, 'method_name': method,
           'arg': data, 'ingress_expiry': agent.get_expiry_date()}
    _, payload = sign_request(req, agent.identity)
    ret = agent.query_endpoint(canister, payload)
    d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
    if d.get('status') != 'replied':
        return {"_status": d.get('status'), "_err": str(d.get('reject_message', d))[:300]}
    arg = d['reply'].get('arg')
    return decode(arg) if arg else None

out = {}

KONG = "o7oak-iyaaa-aaaaq-aadzq-cai"
KONGSWAP = "2ipq2-uqaaa-aaaar-qailq-cai"
GOV = "oypg6-faaaa-aaaaq-aadza-cai"
BAL_T = Types.Record({'owner': Types.Principal, 'subaccount': Types.Opt(Types.Vec(Types.Nat8))})

# ---------- KongSwap ----------
ks = {}
for sym in ["KONG_ICP", "KONG_ckUSDT", "ICP_KONG", "ckUSDT_KONG"]:
    r = call_query(KONGSWAP, "pools", [{'type': Types.Opt(Types.Text), 'value': [sym]}])
    ks[f"pools({sym})"] = r
ks["pools(None)"] = call_query(KONGSWAP, "pools", [{'type': Types.Opt(Types.Text), 'value': []}])
ks["tokens(KONG)"] = call_query(KONGSWAP, "tokens", [{'type': Types.Opt(Types.Text), 'value': ["KONG"]}])
ks["swap_amounts(KONG 1KONG -> ICP)"] = call_query(KONGSWAP, "swap_amounts", [
    {'type': Types.Text, 'value': 'KONG'}, {'type': Types.Nat, 'value': 100000000},
    {'type': Types.Text, 'value': 'ICP'}])
out["kongswap"] = ks

# ---------- KONG ledger ----------
led = {}
led["icrc1_total_supply"] = call_query(KONG, "icrc1_total_supply")
led["icrc1_fee"] = call_query(KONG, "icrc1_fee")
sub64 = "0ecfd73b8ea0a1d24c36a1affe890b81bf2506e4a4f183591c9600872a5edc72"
sub = bytes.fromhex(sub64)
treas = call_query(KONG, "icrc1_balance_of", [{'type': BAL_T, 'value': {'owner': GOV, 'subaccount': [list(sub)]}}])
led["treasury_balance"] = treas
accounts = {
    "kongswap_dex": KONGSWAP,
    "gov_default": GOV,
    "sns_swap": "okjrh-jqaaa-aaaaq-aad2a-cai",
    "sns_root": "ormnc-tiaaa-aaaaq-aadyq-cai",
    "sns_extension_kxhyf": "kxhyf-dyaaa-aaaar-qbwza-cai",
    "icpswap_kong_icp": "ye4fx-gqaaa-aaaag-qnara-cai",
    "icpswap_kong_maptf": "tzap2-xaaaa-aaaar-qbm5q-cai",
    "icpswap_kong_cketh": "xm6pw-uaaaa-aaaag-qnbwa-cai",
    "icpswap_bob_kong": "nemoc-diaaa-aaaag-qndbq-cai",
    "icpswap_ics_kong": "y7qyo-piaaa-aaaar-qaq5a-cai",
    "icpswap_kong_exe": "ppk5w-5qaaa-aaaar-qbr3a-cai",
    "icpswap_nanas_kong": "yw2so-kaaaa-aaaag-qnasa-cai",
    "icpswap_picp_kong": "3icu4-6qaaa-aaaar-qaqvq-cai",
    "icpswap_ogy_kong": "szp7t-2aaaa-aaaar-qargq-cai",
}
for name, can in accounts.items():
    try:
        r = call_query(KONG, "icrc1_balance_of", [{'type': BAL_T, 'value': {'owner': can, 'subaccount': []}}])
    except Exception as e:
        r = {"_exception": str(e)[:200]}
    led[f"balance::{name}"] = r
out["kong_ledger"] = led

with open("market_depth_onchain.json", "w") as f:
    json.dump(out, f, default=str, indent=1, ensure_ascii=False)
print(json.dumps(out, default=str, indent=1, ensure_ascii=False)[:12000])
