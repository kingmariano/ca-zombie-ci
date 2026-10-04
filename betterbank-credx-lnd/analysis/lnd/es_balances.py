#!/usr/bin/env python3
"""Targeted token-balance scan via Etherscan V2 (different quota). Sonic + HL."""
import json, sys, time, urllib.request, urllib.parse, os
sys.path.insert(0,'.')

KEY = None
for line in open("/home/heisenberg/CA/.env"):
    if line.startswith("ETHERSCANV2_API_KEY="):
        KEY = line.split("=",1)[1].strip().strip('"').strip("'")
        break

def es(chainid, params):
    q = {"chainid":chainid, "apikey":KEY, **params}
    url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(q)
    for i in range(5):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                j = json.loads(r.read().decode())
            if j.get("status") == "1" or j.get("message") == "No transactions found":
                return j
            if "rate limit" in str(j).lower():
                time.sleep(3); continue
            return j
        except Exception:
            time.sleep(2.5*(i+1))
    return {"status":"0","message":"failed"}

SONIC_TOKENS = {
 "wS":"0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38","stS":"0xE5DA20F15420aD15DE0fa650600aFc998bbE3955",
 "USDC":"0x29219dd400f2Bf60E5a23d13Be72B486D4038894","WETH":"0x50c42dEAcD8Fc9773493ED674b675bE577f2634b",
 "scUSD":"0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE","scETH":"0x3bcE5CB273F0F148010BbEa2470e7b5df84C7812",
 "wOS":"0x9F0dF7799f6FDAd409300080cfF680f5A23df4b1","USDT":"0x6047828dc181963ba44974801FF68e538dA5eaF9"}
SONIC_HOLDERS = {
 "ecosystem_reserve_proxy":"0x1fe8c68f5378b53501f56b4113202e85661503",  # wrong? use below
}
SONIC_HOLDERS = {
 "eco_reserve_proxy_1fe8":"0x1fe8c68fc5378eb53501f56b4113202e85661503",
 "emission_manager":"0x4c6d372dc03e453c57ac3818a9e124c793d42623",
 "points":"0x4d62269c492a53c8bdec9be7004d6370edf7c662",
 "gateway_0b7b":"0x0b7b179d15bb52809b1d172f29659d5f50ed7dc7",
 "gateway_bc6b":"0xbc6b55bfb549018e89352e31c3ea4b1fdc224d4c",
 "gateway_c905":"0xc905288ba5a55e495bffdf2461db6ea0d0993736",
 "gen1_pool":"0x648abc6fd9d69f7b4b6514b3b777359c029dfe67",
 "gen1_configurator":"0x01171d5be2734dc4eb8e6738783ad1bd88a49add",
 "configurator_proxy2":"0x8bd74ef333c8f7b320bfbdd30a641c46cbffd4c0",
 "rewards_impl":"0x18571a61609355237bb43d7aeaebb9068e859e59",
 "gen2_pool":"0x30b5cab2c6a2dc5564e46bf73f3a4a9f87aee521",
 "gen3_pool":"0x47d54e734e1007f56c565e95a21092054771fad4",
 "recipient_5149a7":"0x5149a7696188f083297281d10293a20476252cdd",
 "recipient_40c79e":"0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8",
 "rogue":"0xc0454e29835479ee80d6f42965a16dcee9bfd868",
 "safe_9b644a":"0x9b644a58713f5731be089620ec61bdb1075cb3f5",
 "revoker_e82e":"0xe82e0ab25f8c4bd8ba9ff1216ef5a9f0b54aaba4",
}
out={"sonic":{},"hyperevm":{}}
for hn,h in SONIC_HOLDERS.items():
    d={}
    for tn,t in SONIC_TOKENS.items():
        j=es(146, {"module":"account","action":"tokenbalance","contractaddress":t,"address":h,"tag":"latest"})
        d[tn]=j.get("result") if j.get("status")=="1" else f"ERR {j.get('message')}"
        time.sleep(0.25)
    out["sonic"][hn]={"address":h,"balances":d}
    nz={k:v for k,v in d.items() if v not in ("0",) and not str(v).startswith("ERR")}
    print("SONIC",hn,h,"nonzero:",nz, flush=True)

HL_TOKENS={"WHYPE":"0x5555555555555555555555555555555555555555","wstHYPE":"0x94e8396e0869c9F2200760aF0621aFd240E1CF38"}
HL_HOLDERS={
 "gen_pool":"0x4b0B2f51596c52ebf89c1109882b32FCE50e8F63",
 "configurator":"0x4A96E73D6449dE2ea67401909caf5649AB05CCBa",
 "recipient_5149a7":"0x5149a7696188f083297281d10293a20476252cdd",
 "recipient_40c79e":"0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8",
 "owner_eoa":"0x5b8a72bb69Fe0e766562c2BCD3b6EdbF21360b11",
 "stHYPE_token_ffaa4a":"0xffaa4a3d97fe9107cef8a3f48c069f577ff76cc1",
 "aToken_WHYPE":"0x6824429DDd4d3cE5Ff50e67e3CC909d7298dc759",
 "aToken_wstHYPE":"0x3383e37cad159bb00a56e330ce71d9f24e89a6c4",
 "wstHYPE_token":"0x94e8396e0869c9F2200760aF0621aFd240E1CF38",
}
for hn,h in HL_HOLDERS.items():
    d={}
    for tn,t in HL_TOKENS.items():
        j=es(999, {"module":"account","action":"tokenbalance","contractaddress":t,"address":h,"tag":"latest"})
        d[tn]=j.get("result") if j.get("status")=="1" else f"ERR {j.get('message')}"
        time.sleep(0.25)
    out["hyperevm"][hn]={"address":h,"balances":d}
    nz={k:v for k,v in d.items() if v not in ("0",) and not str(v).startswith("ERR")}
    print("HL",hn,h,"nonzero:",nz, flush=True)
json.dump(out,open("raw/es_token_balances.json","w"),indent=2)
print("saved raw/es_token_balances.json")
