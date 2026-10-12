#!/usr/bin/env python3
"""Enumerate Mobius gauges: LP token, staked amount, reward tokens. Read-only.
Output: analysis/gauges.json
"""
import json, urllib.request, time, os

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))
GAUGES = [
"0xdAA2ab880b7f3D5697e6F85e63c28b9120AA9E07","0xD38e76E17E66b562B61c149Ca0EE53CEa1145733",
"0x1A8938a37093d34581B21bAd2AE7DC1c19150C05","0xd1B3C05FE24bda6F52e704daf1ACBa8c440d8573",
"0xe2d6095685248F38Ae9fef1b360D772b78Ea19D1","0x52517feb1Fc6141d5CF6718111C7Cc0FD764fA5d",
"0x27D9Bfa5F864862BeDC23cFab7e00b6b94488CC6","0x1A648004d8AB84eE34d2D1cd2F2A7a7828D6939F",
"0x1250D6dd3B51D20c14a8ECb10CC2dd713967767e","0xCF34F4ec5DC9E09428A4f4a45475f6277694166c",
"0x5489b2F0A1992b889F47601D71E068Fd15c63f26","0x2459BDb59a3BF6Ab6C412Ac0b220e7CDA1D4ea26",
"0xF2ae5c2D2D2eD13dd324C0942163054fc4A3D4d9","0xc96AeeaFF32129da934149F6134Aa7bf291a754E",
"0x487c30CB18AA9Ced435911E2B414e0e85D7E52bB","0x127b524c74C2162Ee4BB2e42d8d2eB9050C0293E",
"0x0A125D473cd3b1968e728DDF7d424c928C09222A","0xE1f9D952EecC07cfEFa69df9fBB0cEF260957119",
"0xE965Dd2B957448CaE3291048A9944fC2F3a693D8","0x73fDa87297627Fe985bc1D40c7d68868C2624D67",
"0x4E3E91b61c6cA47cF3664aA88Ee3f690e3E41185","0xE7195E651Cc47853f0054d85c8ADFc79D532929f",
"0xD0d57a6689188F854F996BEAE0Cb1949FDB5FF86","0xCAEd243de23264Bdd8297c6eECcF320846eee18A",
"0x107F94409746E8c8E6eFF139A100D17D9ca7FdfE","0x7ed927E685d7196Ff2e7Bc48c5cB5e8af88c9332",
"0x70AE7265545f001cb015399D672B85D8f2CaCA72",
]
SEL_LP = "0x82c37b2d"      # lp_token()
SEL_TS = "0x18160ddd"      # totalSupply()
SEL_RC = "0x5153bccd"      # reward_count()? verify
SEL_RT = None
# compute selectors via eth_call probing: use known curve gauge signatures
KNOWN = {
    "lp_token": "0x82c63066",
    "totalSupply": "0x18160ddd",
    "decimals": "0x313ce567",
    "name": "0x06fdde03",
    "symbol": "0x95d89b41",
    "reward_count": "0x963c94b9",
    "inflation_rate": "0x180692d0",
    "controller": "0xf77c4791",
    "period": "0xef78d4fd",
    "reward_tokens": "0x54c49fe9",
    "reward_data": "0x48e9c65e",
}


def rpc(calls, tries=6):
    """calls: list of (method, params); chunked to 8."""
    res = []
    for i in range(0, len(calls), 8):
        chunk = calls[i:i + 8]
        body = json.dumps([{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                           for j, (m, p) in enumerate(chunk)]).encode()
        last = None
        for t in range(tries):
            try:
                req = urllib.request.Request(RPC, data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research)"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    d = json.loads(r.read().decode())
                by = {it["id"]: it for it in d}
                for j in range(len(chunk)):
                    it = by.get(j)
                    res.append(it.get("result") if it and "result" in it else None)
                last = None
                break
            except Exception as e:
                last = e
                time.sleep(0.8 + t)
        if last is not None:
            res.extend([None] * len(chunk))
    return res


def uint(s):
    if not isinstance(s, str) or s == "0x":
        return None
    try:
        return int(s[2:66], 16)
    except Exception:
        return None


def addr(s):
    if not isinstance(s, str) or s == "0x":
        return None
    try:
        return "0x" + s[2:66][-40:]
    except Exception:
        return None


def sstr(s):
    if not isinstance(s, str) or s == "0x":
        return None
    h = s[2:]
    try:
        off = int(h[0:64], 16) * 2
        ln = int(h[off:off + 64], 16) * 2
        return bytes.fromhex(h[off + 64:off + 64 + ln]).decode("utf-8", "replace")
    except Exception:
        return None


out = {}
for g in GAUGES:
    calls = [("eth_call", [{"to": g, "data": KNOWN["lp_token"]}, "latest"]),
             ("eth_call", [{"to": g, "data": KNOWN["totalSupply"]}, "latest"]),
             ("eth_call", [{"to": g, "data": KNOWN["symbol"]}, "latest"]),
             ("eth_call", [{"to": g, "data": KNOWN["reward_count"]}, "latest"]),
             ("eth_call", [{"to": g, "data": KNOWN["inflation_rate"]}, "latest"]),
             ("eth_call", [{"to": g, "data": KNOWN["period"]}, "latest"]),
             ("eth_call", [{"to": g, "data": KNOWN["controller"]}, "latest"])]
    r = rpc(calls)
    e = {"lp_token": addr(r[0]), "totalSupply": uint(r[1]), "symbol": sstr(r[2]),
         "reward_count": uint(r[3]), "inflation_rate": uint(r[4]), "period": uint(r[5]),
         "controller": addr(r[6])}
    out[g] = e
    print(g, json.dumps(e), flush=True)

with open(os.path.join(HERE, "gauges.json"), "w") as f:
    json.dump(out, f, indent=1)
print("wrote gauges.json")
