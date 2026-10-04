#!/usr/bin/env python3
"""Multicall3 balance scan: all known LND contracts/EOAs vs all relevant assets, both chains."""
import json, sys, subprocess, time
sys.path.insert(0,'.')
from lib import rpc, call, balance, blocknum, SONIC, HL, _post, SONIC_ENDPOINTS, HL_ENDPOINTS

MC3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
MCFROM = "0x0000000000000000000000000000000000000000"

def mc_call(rpc_url, data, block_hex):
    eps = SONIC_ENDPOINTS if "sonic" in rpc_url else [rpc_url]
    last = None
    for i in range(6):
        for ep in eps:
            try:
                out = _post(ep, "eth_call", [{"to": MC3, "data": data}, block_hex])
                if "error" not in out and isinstance(out.get("result"), str):
                    return out["result"]
                last = out.get("error")
            except Exception as e:
                last = e
            time.sleep(0.6)
        time.sleep(2.0 * (i + 1))
    raise RuntimeError(f"mc_call failed: {last}")

def pad_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def pad_u256(v): return hex(v)[2:].rjust(64,"0")

def encode_aggregate3(calls):
    # calls: list of (target, calldata_hex). Correct ABI encoding for aggregate3((address,bool,bytes)[])
    n = len(calls)
    tuple_heads = []
    tuple_tails = []
    lens = []
    for (t, cd) in calls:
        cd_b = bytes.fromhex(cd[2:])
        lens.append(96 + 32 + ((len(cd_b)+31)//32)*32)
        tuple_heads.append(pad_addr(t) + pad_u256(1) + pad_u256(96))
        tuple_tails.append(pad_u256(len(cd_b)) + cd_b.hex().ljust(((len(cd_b)+31)//32)*64, "0"))
    table_bytes = 32 * n
    offs = []
    cur = table_bytes
    tuples = []
    for i in range(n):
        offs.append(cur)
        tuples.append(tuple_heads[i] + tuple_tails[i])
        cur += lens[i]
    body = pad_u256(n) + "".join(pad_u256(o) for o in offs) + "".join(tuples)
    selector = "0x82ad56cb"  # aggregate3
    return selector + pad_u256(32) + body

def decode_aggregate3(result_hex):
    b = result_hex[2:]
    w0 = int(b[0:64],16)  # offset to array
    n = int(b[w0*2:w0*2+64],16)
    arr_start = w0*2 + 64
    outs = []
    for i in range(n):
        off = int(b[arr_start+i*64:arr_start+(i+1)*64],16)
        tstart = arr_start + off*2
        success = int(b[tstart:tstart+64],16) == 1
        boff = int(b[tstart+64:tstart+128],16)
        bstart = tstart + boff*2
        blen = int(b[bstart:bstart+64],16)
        data = b[bstart+64:bstart+64+blen*2]
        outs.append((success, data))
    return outs

SEL_BAL = "0x70a08231"

def scan(rpc_url, block, holders, tokens):
    keys = []
    calls = []
    for h in holders:
        for t in tokens:
            calls.append((t, SEL_BAL + pad_addr(h)))
            keys.append((h,t))
    res = {}
    CH = 30
    for i in range(0, len(calls), CH):
        chunk = calls[i:i+CH]
        kchunk = keys[i:i+CH]
        raw = mc_call(rpc_url, encode_aggregate3(chunk), hex(block))
        outs = decode_aggregate3(raw)
        for (h,t),(ok,data) in zip(kchunk,outs):
            v = None
            if ok and data:
                try: v = int(data[:64],16)
                except Exception: v = None
            res.setdefault(h,{})[t] = v
        time.sleep(1.2)
    return res

if __name__ == "__main__":
    SONIC_TOKENS = {
        "wS":"0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38",
        "stS":"0xE5DA20F15420aD15DE0fa650600aFc998bbE3955",
        "USDC":"0x29219dd400f2Bf60E5a23d13Be72B486D4038894",
        "WETH":"0x50c42dEAcD8Fc9773493ED674b675bE577f2634b",
        "scUSD":"0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE",
        "scETH":"0x3bcE5CB273F0F148010BbEa2470e7b5df84C7812",
        "wOS":"0x9F0dF7799f6FDAd409300080cfF680f5A23df4b1",
        "USDT":"0x6047828dc181963ba44974801FF68e538dA5eaF9",
    }
    # holders: every contract the rogue deployed + key contracts + EOAs
    creators = [l.strip() for l in open("raw/sonic_created_addrs.txt") if l.strip()]
    extras = [
        "0x648Abc6Fd9D69F7B4b6514B3b777359C029Dfe67", # gen1 pool proxy
        "0x01171d5be2734Dc4eB8E6738783AD1Bd88A49Add", # gen1 configurator proxy
        "0x8bd74ef333c8f7b320bfbdd30a641c46cbffd4c0", # configurator proxy 2
        "0x30b5cab2c6a2dc5564e46bf73f3a4a9f87aee521", # gen2 pool
        "0x47d54e734e1007f56c565e95a21092054771fad4", # gen3 pool
        "0xc0454e29835479ee80d6f42965a16dcee9bfd868","0x9b644a58713f5731be089620ec61bdb1075cb3f5",
        "0xe82e0ab25f8c4bd8ba9ff1216ef5a9f0b54aaba4","0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8",
        "0x5149a7696188f083297281d10293a20476252cdd","0x18DA2c1B3A76F909B90C1da52481a0c65A9d9873",
        "0x46CA84728CD14eeE4B4187D483520974a8CdD89E","0x5fe73a0b956DB317A74eC72c5886D784c19EEd1f",
        "0x663dc15d3c1ac63ff12e45ab68fea3f0a883c251",
    ]
    # all reserved token proxies + debts
    for fn in ["raw/sonic_reserves.json"]:
        j=json.load(open(fn))
        for e in j["reserves"]:
            extras += [e["aToken"], e["stableDebtToken"], e["variableDebtToken"]]
    # gen2/gen3 aTokens
    extras += ["0x510db90b0b2e720c3649081e56eb7ec57492932c","0xa91a5647acdba2ad3b0236c43600ce718020de7d",
               "0x56804b2827ac660ca0eaea0e2da5de4a26ccc05c","0x9a6e464e87536cf1c5fc49059c231b0766d3f97e",
               "0xd167087e4290414a5a04883ffae51cb28b3d8649","0x474e0a7cf9987c46a92807bea01f8e597b426d83",
               "0xc59af2f839d6ee1cb1bb5d0d518f7759add388d7","0x3d349af3fc99375fbb7ed4a9faef47bc6ac744c1",
               "0x8f6c0e8ceeb985a996669eeb9d9dce1f85a31d1e"]
    holders = sorted(set([h.lower() for h in creators+extras]))
    BLK_S = 80323917
    res = scan(SONIC, BLK_S, holders, {k:v.lower() for k,v in SONIC_TOKENS.items()})
    # native balances
    native = {}
    for h in holders:
        try: native[h] = int(balance(SONIC, h, BLK_S),16)
        except Exception as e: native[h]=f"ERR {e}"
    out = {"chain":"sonic","block":BLK_S,"tokens":SONIC_TOKENS,"balances":res,"native":native}
    json.dump(out, open("raw/sonic_all_balances.json","w"), indent=2)
    # report non-zero token holders
    print("=== SONIC non-zero token balances (block %d) ===" % BLK_S)
    for h,d in res.items():
        nz = {k:v for k,v in d.items() if v}
        if nz:
            print(h, json.dumps(nz))
    print("=== SONIC non-zero native ===")
    for h,v in native.items():
        if isinstance(v,int) and v>0: print(h, v, f"({v/1e18:.6f})")

    # ---- HL ----
    HL_TOKENS = {"WHYPE":"0x5555555555555555555555555555555555555555","wstHYPE":"0x94e8396e0869c9F2200760aF0621aFd240E1CF38"}
    hl_creators = [l.strip() for l in open("raw/hl_created_addrs.txt") if l.strip()] if __import__("os").path.exists("raw/hl_created_addrs.txt") else []
    hl_extras = ["0x4b0B2f51596c52ebf89c1109882b32FCE50e8F63","0xa717D758D8776121aba09cDE137Fea6a917bbe0d",
                 "0x4A96E73D6449dE2ea67401909caf5649AB05CCBa","0x7c3396AC1306507040CE338c8b7f99C9540FB3e2",
                 "0xa99200A4Ab13462eF293A370AcAd133808dc1fDe","0x6824429DDd4d3cE5Ff50e67e3CC909d7298dc759",
                 "0x3383e37cad159bb00a56e330ce71d9f24e89a6c4","0x0a4b8b46ca84cdf4a4833a1611a01176839483a6",
                 "0x5b8a72bb69Fe0e766562c2BCD3b6EdbF21360b11","0xc0454e29835479ee80d6f42965a16dcee9bfd868",
                 "0x9b644a58713f5731be089620ec61bdb1075cb3f5","0xe82e0ab25f8c4bd8ba9ff1216ef5a9f0b54aaba4",
                 "0x40c79ebc5a8ee251a9670ba3f4c5720f874410c8","0x5149a7696188f083297281d10293a20476252cdd",
                 "0xffaa4a3d97fe9107cef8a3f48c069f577ff76cc1"]
    hl_holders = sorted(set([h.lower() for h in hl_creators+hl_extras]))
    BLK_H = 47621590
    resH = scan(HL, BLK_H, hl_holders, {k:v.lower() for k,v in HL_TOKENS.items()})
    nativeH = {}
    for h in hl_holders:
        try: nativeH[h]=int(balance(HL,h,BLK_H),16)
        except Exception as e: nativeH[h]=f"ERR {e}"
    outH={"chain":"hyperevm","block":BLK_H,"tokens":HL_TOKENS,"balances":resH,"native":nativeH}
    json.dump(outH, open("raw/hl_all_balances.json","w"), indent=2)
    print("=== HL non-zero token balances (block %d) ===" % BLK_H)
    for h,d in resH.items():
        nz={k:v for k,v in d.items() if v}
        if nz: print(h, json.dumps(nz))
    print("=== HL non-zero native ===")
    for h,v in nativeH.items():
        if isinstance(v,int) and v>0: print(h, str(v), f"({v/1e18:.6f})")
