#!/usr/bin/env python3
"""Enumerate LND Sonic pool reserves at a pinned block. Raw JSON evidence dump."""
import json, sys, time
sys.path.insert(0, '.')
from lib import rpc, call, balance, storage, blocknum, SONIC

BLK = int(sys.argv[1]) if len(sys.argv) > 1 else blocknum(SONIC)
POOL = "0x648Abc6Fd9D69F7B4b6514B3b777359C029Dfe67"
AP   = "0x0F69b45c5f7f54C4064D38a73b5BB74c7bda8A58"
ACL  = "0x97f91Ca15ce342ef92b6CA9673F5D5B44528bFa1"
CONF = "0x01171d5be2734Dc4eB8E6738783AD1Bd88A49Add"
ORACLE = "0x5D30854B3172bD227D8ef492858FFCBc4fe3F6FE"

# selectors (verified via cast sig)
S = {
 "ADDRESSES_PROVIDER":"0x0542975c",  # verified below by output
 "getReservesList":"0xd1946dbc",
 "getReserveData":"0x35ea6a75",
 "getConfiguration":"0xc44b11f7",
 "POOL":"0x7535d246",
 "UNDERLYING_ASSET_ADDRESS":"0xb16a19de",
 "totalSupply":"0x18160ddd",
 "scaledTotalSupply":"0xb1bf962d",
 "balanceOf":"0x70a08231",
 "symbol":"0x95d89b41",
 "name":"0x06fdde03",
 "decimals":"0x313ce567",
 "impl_slot":"0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
 "admin_slot":"0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
}

def pad(addr):
    a = addr.lower().replace("0x","")
    return a.rjust(64,"0")

def dec_string(hexstr):
    try:
        b = bytes.fromhex(hexstr[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64],'big')
            return b[64:64+ln].decode('utf-8', errors='replace')
        return hexstr
    except Exception:
        return hexstr

out = {"chain":"sonic","chain_id":146,"block":BLK,"pool":POOL,"addresses_provider":AP,
       "acl_manager":ACL,"configurator":CONF,"oracle":ORACLE,"reserves":[]}

# reserves list: word0=offset(0x20), word1=length, then items
rl_hex = call(SONIC, POOL, S["getReservesList"], BLK)
body = rl_hex[2:]
w0 = int(body[0:64],16)
n = int(body[64:128],16)
assert w0 == 32, f"unexpected array offset {w0}"
reserves = []
for i in range(n):
    w = body[128+i*64:128+(i+1)*64]
    reserves.append("0x"+w[24:])
# sanity
ap = call(SONIC, POOL, "0x0542975c", BLK)
out["pool_addresses_provider_actual"] = "0x"+ap[-40:]

for r in reserves:
    rd = call(SONIC, POOL, S["getReserveData"]+pad(r), BLK)
    words = [rd[2+i*64:2+(i+1)*64] for i in range(len(rd[2:])//64)]
    cfg = int(words[0],16)
    conf = call(SONIC, POOL, S["getConfiguration"]+pad(r), BLK)
    entry = {"asset": r, "config_raw": conf, "reserve_data_raw": rd, "reserve_data_words": len(words),
             "config_decoded": {
                "ltv": cfg & 0xffff,
                "liquidation_threshold": (cfg>>16)&0xffff,
                "liquidation_bonus": (cfg>>32)&0xffff,
                "decimals": (cfg>>48)&0xff,
                "isActive": bool((cfg>>56)&1),
                "isFrozen": bool((cfg>>57)&1),
                "borrowingEnabled": bool((cfg>>58)&1),
                "stableBorrowRateEnabled": bool((cfg>>59)&1),
                "isPaused": bool((cfg>>60)&1),
                "borrowableInIsolation": bool((cfg>>61)&1),
                "flashLoanEnabled": bool((cfg>>62)&1),
                "siloedBorrowing": bool((cfg>>63)&1),
             },
             "liquidityIndex": int(words[1],16),
             "lastUpdateTimestamp": int(words[6],16),
             "id": int(words[7],16),
             "aToken": "0x"+words[8][24:],
             "stableDebtToken": "0x"+words[9][24:],
             "variableDebtToken": "0x"+words[10][24:],
             "interestRateStrategy": "0x"+words[11][24:],
             }
    # token metadata for underlying
    sym = dec_string(call(SONIC, r, S["symbol"], BLK))
    dec = int(call(SONIC, r, S["decimals"], BLK),16)
    entry["underlying_symbol"] = sym
    entry["underlying_decimals"] = dec
    entry["underlying_totalSupply"] = int(call(SONIC, r, S["totalSupply"], BLK),16)
    entry["underlying_balanceOf_pool"] = int(call(SONIC, r, S["balanceOf"]+pad(POOL), BLK),16)
    entry["underlying_balanceOf_aToken"] = int(call(SONIC, r, S["balanceOf"]+pad(entry["aToken"]), BLK),16)
    for tk in ["aToken","variableDebtToken","stableDebtToken"]:
        t = entry[tk]
        if int(t,16) == 0:
            entry[tk+"_data"] = None
            continue
        impl = storage(SONIC, t, int(S["impl_slot"],16), BLK)
        adm = storage(SONIC, t, int(S["admin_slot"],16), BLK)
        entry[tk+"_data"] = {
            "impl": "0x"+impl[-40:],
            "admin": "0x"+adm[-40:],
            "totalSupply": int(call(SONIC, t, S["totalSupply"], BLK),16),
            "balanceOf_pool": int(call(SONIC, t, S["balanceOf"]+pad(POOL), BLK),16),
            "underlying_balanceOf_self": int(call(SONIC, t, S["balanceOf"]+pad(t), BLK),16),
            "underlying_address_read": "0x"+call(SONIC, t, S["UNDERLYING_ASSET_ADDRESS"], BLK)[-40:],
        }
    # oracle price (AaveOracle.getAssetPrice)
    try:
        p = call(SONIC, ORACLE, "0xb3596f07"+pad(r), BLK)
        entry["oracle_price"] = int(p,16)
    except Exception as e:
        entry["oracle_price"] = f"ERR {e}"
    out["reserves"].append(entry)

# native balances of key actors
addrs = {
 "pool": POOL, "provider": AP, "configurator": CONF, "acl": ACL, "oracle": ORACLE,
 "rogue_deployer": "0xc0454e29835479ee80d6f42965a16dcee9bfd868",
 "acl_admin_and_provider_owner": "0x9b644a58713f5731be089620ec61bdb1075cb3f5",
 "addr_40c79ebc": "0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8",
 "revoker_admin": "0xe82e0ab25f8c4bd8ba9ff1216ef5a9f0b54aaba4",
 "drain_target_5149a769": "0x5149a7696188f083297281d10293a20476252cdd",
}
out["native_balances"] = {k: int(balance(SONIC, v, BLK),16) for k,v in addrs.items()}

with open("raw/sonic_reserves.json","w") as f:
    json.dump(out, f, indent=2)
print(json.dumps({k: out[k] for k in ["block","pool_addresses_provider_actual"]}, indent=2))
for e in out["reserves"]:
    print(e["asset"], e["underlying_symbol"], "paused=",e["config_decoded"]["isPaused"],
          "active=",e["config_decoded"]["isActive"], "frozen=",e["config_decoded"]["isFrozen"],
          "aTok=",e["aToken"], "aTok_bal_underlying=",e["underlying_balanceOf_aToken"],
          "aTok_totalSupply=",e["aToken_data"]["totalSupply"] if e["aToken_data"] else None)
