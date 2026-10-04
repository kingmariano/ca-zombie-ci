#!/usr/bin/env python3
"""Enumerate LND Hyperliquid pool reserves at pinned block. Raw JSON evidence."""
import json, sys
sys.path.insert(0,'.')
from lib import rpc, call, balance, storage, blocknum, HL

BLK = int(sys.argv[1]) if len(sys.argv)>1 else blocknum(HL)
POOL = "0x4b0B2f51596c52ebf89c1109882b32FCE50e8F63"
AP   = "0xa717D758D8776121aba09cDE137Fea6a917bbe0d"
ACL  = "0x7c3396AC1306507040CE338c8b7f99C9540FB3e2"
CONF = "0x4A96E73D6449dE2ea67401909caf5649AB05CCBa"
ORACLE = "0xa99200A4Ab13462eF293A370AcAd133808dc1fDe"

S = {
 "getReserveData":"0x35ea6a75","getConfiguration":"0xc44b11f7","POOL":"0x7535d246",
 "UNDERLYING_ASSET_ADDRESS":"0xb16a19de","totalSupply":"0x18160ddd","balanceOf":"0x70a08231",
 "symbol":"0x95d89b41","name":"0x06fdde03","decimals":"0x313ce567",
 "impl_slot":"0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
 "admin_slot":"0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
}

def pad(a):
    return a.lower().replace("0x","").rjust(64,"0")

def dec_string(hexstr):
    try:
        b = bytes.fromhex(hexstr[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64],'big')
            return b[64:64+ln].decode('utf-8', errors='replace')
        return hexstr
    except Exception:
        return hexstr

out = {"chain":"hyperevm","chain_id":999,"block":BLK,"pool":POOL,"addresses_provider":AP,
       "acl_manager":ACL,"configurator":CONF,"oracle":ORACLE,"reserves":[]}

rl_hex = call(HL, POOL, "0xd1946dbc", BLK)
body = rl_hex[2:]
n = int(body[64:128],16)
reserves = ["0x"+body[128+i*64+24:128+(i+1)*64] for i in range(n)]
out["reserves_list"] = reserves

for r in reserves:
    rd = call(HL, POOL, S["getReserveData"]+pad(r), BLK)
    words = [rd[2+i*64:2+(i+1)*64] for i in range(len(rd[2:])//64)]
    cfg = int(words[0],16)
    conf = call(HL, POOL, S["getConfiguration"]+pad(r), BLK)
    entry = {"asset": r, "config_raw": conf, "reserve_data_raw": rd, "reserve_data_words": len(words),
             "config_decoded": {
                "ltv": cfg & 0xffff, "liquidation_threshold": (cfg>>16)&0xffff,
                "liquidation_bonus": (cfg>>32)&0xffff, "decimals": (cfg>>48)&0xff,
                "isActive": bool((cfg>>56)&1), "isFrozen": bool((cfg>>57)&1),
                "borrowingEnabled": bool((cfg>>58)&1), "stableBorrowRateEnabled": bool((cfg>>59)&1),
                "isPaused": bool((cfg>>60)&1), "borrowableInIsolation": bool((cfg>>61)&1),
                "flashLoanEnabled": bool((cfg>>62)&1), "siloedBorrowing": bool((cfg>>63)&1)},
             "liquidityIndex": int(words[1],16), "lastUpdateTimestamp": int(words[6],16),
             "id": int(words[7],16), "aToken": "0x"+words[8][24:],
             "stableDebtToken": "0x"+words[9][24:], "variableDebtToken": "0x"+words[10][24:],
             "interestRateStrategy": "0x"+words[11][24:]}
    entry["underlying_symbol"] = dec_string(call(HL, r, S["symbol"], BLK))
    entry["underlying_decimals"] = int(call(HL, r, S["decimals"], BLK),16)
    entry["underlying_totalSupply"] = int(call(HL, r, S["totalSupply"], BLK),16)
    entry["underlying_balanceOf_pool"] = int(call(HL, r, S["balanceOf"]+pad(POOL), BLK),16)
    entry["underlying_balanceOf_aToken"] = int(call(HL, r, S["balanceOf"]+pad(entry["aToken"]), BLK),16)
    for tk in ["aToken","variableDebtToken","stableDebtToken"]:
        t = entry[tk]
        if int(t,16)==0:
            entry[tk+"_data"]=None; continue
        try:
            impl = storage(HL, t, int(S["impl_slot"],16), BLK)
            adm = storage(HL, t, int(S["admin_slot"],16), BLK)
            entry[tk+"_data"] = {"impl":"0x"+impl[-40:], "admin_slot":"0x"+adm[-40:],
                "totalSupply": int(call(HL, t, S["totalSupply"], BLK),16),
                "underlying_balanceOf_self": int(call(HL, t, S["balanceOf"]+pad(t), BLK),16),
                "underlying_address_read": "0x"+call(HL, t, S["UNDERLYING_ASSET_ADDRESS"], BLK)[-40:] if int(t,16)!=0 else None}
        except Exception as e:
            entry[tk+"_data"] = {"err": str(e)[:120]}
    try:
        entry["oracle_price"] = int(call(HL, ORACLE, "0xb3596f07"+pad(r), BLK),16)
    except Exception as e:
        entry["oracle_price"] = f"ERR {str(e)[:100]}"
    out["reserves"].append(entry)

addrs = {
 "pool": POOL, "provider": AP, "configurator": CONF, "acl": ACL, "oracle": ORACLE,
 "hl_owner_eoa": "0x5b8a72bb69Fe0e766562c2BCD3b6EdbF21360b11",
 "rogue_deployer": "0xc0454e29835479ee80d6f42965a16dcee9bfd868",
 "safe_9b644a": "0x9b644a58713f5731be089620ec61bdb1075cb3f5",
 "revoker_e82e": "0xe82e0ab25f8c4bd8ba9ff1216ef5a9f0b54aaba4",
 "addr_40c79e": "0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8",
 "addr_5149a7": "0x5149a7696188f083297281d10293a20476252cdd",
}
out["native_balances"] = {}
for k,v in addrs.items():
    try: out["native_balances"][k] = int(balance(HL, v, BLK),16)
    except Exception as e: out["native_balances"][k] = f"ERR {str(e)[:80]}"

with open("raw/hl_reserves.json","w") as f:
    json.dump(out,f,indent=2)
print("block", BLK, "reserves", reserves)
for e in out["reserves"]:
    print(e["asset"], e["underlying_symbol"], "paused=",e["config_decoded"]["isPaused"], "active=",e["config_decoded"]["isActive"],
          "aTok=",e["aToken"], "aTok_underlying_bal=",e["underlying_balanceOf_aToken"],
          "aTok_totalSupply=",(e["aToken_data"] or {}).get("totalSupply"), "impl=",(e["aToken_data"] or {}).get("impl"),
          "oracle=",e["oracle_price"])
print("native:", out["native_balances"])
