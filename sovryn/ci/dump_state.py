#!/usr/bin/env python3
"""Read-only RSK state dump for H2-01 (Sovryn legacy Lend/Borrow).

Usage: dump_state.py [rpc_url]
Keyless public RPC by default. No secrets; output is safe to publish.
"""
import json
import sys
import urllib.request

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://public-node.rsk.co"

PROTO = "0x5a0D867E0D70FCc6ADe25c3f1B89d618b5B4EaA7"
BEACON_WRBTC = "0x845eF7Be59664899398282Ef42239634aBDd752C"
BEACON_LM = "0x5b155ECcC1dC31Ea59F2c12d2F168C956Ac0FFAa"
TIMELOCK = "0x967c84b731679E36A344002b8E3CE50620A7F69f"

ITOKENS = {
    "iWRBTC": "0xa9DcDC63eaBb8a2b6f39D7fF9429d88340044a7A",
    "iUSDT": "0x849C47f9C259E9D62F289BF1b2729039698D8387",
    "iXUSD": "0x8f77ECf69711a4b346F23109C40416be3dC7F129",
    "iDOC": "0xd8D25f03EBbA94E15Df2eD4d6D38276B595593c1",
    "iDLLR": "0x077FCB01cAb070a30bC14b44559C96F529eE017F",
    "iBPro": "0x6e2Fb26a60DA535732f8149B25018c9C0823a715",
}

# keccak256("LOAN_TOKEN_LOGIC_BEACON_ADDRESS_SLOT") — per-iToken beacon pointer slot
BEACON_SLOT = "0xd918085b6ac26c71bca17b569f873038d2b9c0a3a62611d7037f46a40829de6a"

SEL = {
    "getTarget(bytes4)": "0x374e4047",
    "logicTargets(bytes4)": "0x17548b79",
    "checkPause(string)": "0xbe194217",
    "isProtocolPaused()": "0xdac88561",
    "delay()": "0x6a42b8f8",
    "admin()": "0xf851a440",
    "owner()": "0x8da5cb5b",
    "loanTokenAddress()": "0x797bf385",
    "totalSupply()": "0x18160ddd",
    "tokenPrice()": "0x7ff9b596",
    "totalAssetBorrow()": "0x20f6d07c",
    "balanceOf(address)": "0x70a08231",
}

SELECTOR_PROBES = {
    "mint": "0x40c10f19",
    "burn": "0x9dc29fac",
    "borrow": "0x2ea295fa",
    "marginTrade": "0x28a02f19",
    "transfer": "0xa9059cbb",
    "flashBorrow": "0xd4299134",
    "protocol_liquidate": "0xe4f3e739",
    "protocol_marginTrade": "0x28a02f19",
    "protocol_borrow": "0x2ea295fa",
    "protocol_closeWithSwap": "0xf8de21d2",
    "protocol_borrowOrTradeFromPool": "0xd84ca254",
}


def rpc(method, params):
    req = urllib.request.Request(
        RPC,
        data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "h2-01-research/1.0"},
    )
    r = json.load(urllib.request.urlopen(req, timeout=60))
    if "error" in r:
        return "ERR:" + str(r["error"])[:120]
    return r["result"]


def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])


def enc_selector(sel):
    return sel + "0" * 56


def enc_string(sel, text):
    b = text.encode()
    data = b.hex().ljust(((len(b) + 31) // 32) * 64, "0")
    return sel + "0" * 62 + "20" + hex(len(b))[2:].rjust(64, "0") + data


def uint(hexstr):
    if not isinstance(hexstr, str) or not hexstr.startswith("0x"):
        return hexstr
    return int(hexstr, 16)


def addr(hexstr):
    if not isinstance(hexstr, str) or not hexstr.startswith("0x"):
        return hexstr
    return "0x" + hexstr[-40:]


out = {"rpc": "keyless-public", "block": uint(rpc("eth_blockNumber", []))}

out["control"] = {
    "protocol_owner": addr(call(PROTO, enc_selector(SEL["owner()"]))),
    "beacon_wrbtc_owner": addr(call(BEACON_WRBTC, enc_selector(SEL["owner()"]))),
    "beacon_lm_owner": addr(call(BEACON_LM, enc_selector(SEL["owner()"]))),
    "timelock_delay_seconds": uint(call(TIMELOCK, enc_selector(SEL["delay()"]))),
    "timelock_admin": addr(call(TIMELOCK, enc_selector(SEL["admin()"]))),
    "protocol_paused": uint(call(PROTO, enc_selector(SEL["isProtocolPaused()"]))) == 1,
}

out["targets"] = {"beacon_wrbtc": {}, "beacon_lm": {}, "protocol": {}}
for name, sel in SELECTOR_PROBES.items():
    payload = sel[2:].ljust(64, "0")
    if name.startswith("protocol_"):
        out["targets"]["protocol"][name] = addr(call(PROTO, SEL["logicTargets(bytes4)"] + payload))
    elif name in ("mint", "burn", "borrow", "marginTrade", "transfer", "flashBorrow"):
        out["targets"]["beacon_wrbtc"][name] = addr(call(BEACON_WRBTC, SEL["getTarget(bytes4)"] + payload))
        out["targets"]["beacon_lm"][name] = addr(call(BEACON_LM, SEL["getTarget(bytes4)"] + payload))

out["itokens"] = {}
for name, a in ITOKENS.items():
    entry = {"address": a}
    entry["beacon"] = addr(rpc("eth_getStorageAt", [a, BEACON_SLOT, "latest"]))
    entry["underlying"] = addr(call(a, enc_selector(SEL["loanTokenAddress()"])))
    entry["totalSupply"] = uint(call(a, enc_selector(SEL["totalSupply()"])))
    entry["tokenPrice"] = uint(call(a, enc_selector(SEL["tokenPrice()"])))
    entry["totalAssetBorrow"] = uint(call(a, enc_selector(SEL["totalAssetBorrow()"])))
    entry["poolBal"] = uint(call(entry["underlying"], SEL["balanceOf(address)"] + a[2:].rjust(64, "0")))
    entry["protocolBal"] = uint(call(entry["underlying"], SEL["balanceOf(address)"] + PROTO[2:].rjust(64, "0")))
    for f in ("borrow", "marginTrade", "mint", "burn"):
        entry["paused_" + f] = uint(call(a, enc_string(SEL["checkPause(string)"], f))) == 1
    out["itokens"][name] = entry

print(json.dumps(out, indent=1))
