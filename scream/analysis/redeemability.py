#!/usr/bin/env python3
"""For each current scLINK holder: membership in dead-feed markets + redeem simulation."""
import json, time, urllib.request

POOL = ["https://rpcapi.fantom.network", "https://fantom.api.onfinality.io/public", "https://fantom.drpc.org"]
_i = [0]

def post(payload):
    last = None
    for a in range(9):
        url = POOL[_i[0] % len(POOL)]
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
        try:
            return json.loads(urllib.request.urlopen(req, timeout=40).read())
        except Exception as e:
            last = e; _i[0] += 1; time.sleep(0.7 + a * 0.3)
    raise last

def eth_call(to, data, frm=None, block="latest"):
    obj = {"to": to, "data": data}
    if frm: obj["from"] = frm
    r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [obj, block]})
    return r.get("result", {"error": r.get("error")})

CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"
M = "0x2359012ebe36cca231203d78b914284947b58aa3"

def fw(r):
    return int(r[2:66], 16) if isinstance(r, str) and len(r) >= 66 else None

def arr(r):
    if not isinstance(r, str) or len(r) < 130: return r
    b = r[2:]; off = int(b[:64], 16); ln = int(b[off*2:off*2+64], 16)
    return ["0x" + b[(off+32+j*32)*2+24:(off+32+j*32+32)*2] for j in range(ln)]

# dead-feed markets (oracle reverts) - from scan
DEAD = {
    "0xe45ac34e528907d0a0239ab5db507688070b20bf": "scUSDC",
    "0x8d9aed9882b4953a0c9fa920168fa1fdfa0ebe75": "scDAI",
    "0x5aa53f03197e08c4851cad8c92c7922da5857e5d": "scWFTM",
    "0x2bf25cd481626283d8db0ceb7d7498b538ba027e": "scWBTC",
    "0x56e828ab9dc9cb8c91c6d14ef705e61c7d1933a0": "scWETH",
    "0xe196c5f077885ad0b8251adb110b4fb1478d5bd3": "scFUSDT",
    "0x4565dc3ef685e4775cdf920129111ddf43b9d882": "scYFI",
    "0xc772ba6c2c28859b7a0542faa162a56115ddce25": "scCRV",
    "0x2359012ebe36cca231203d78b914284947b58aa3": "scLINK",
    "0x4e6854ea84884330207fb557d1555961d85fc17e": "scFRAX-A",
    "0x182ee724db200ab067c43f3d255c265bdf80fc8a": "scDOLA",
    "0x02224765bc8d54c21bb51b0951c80315e1c263f9": "scMIM",
    "0x7c94562373ed1606130a2ed0a5d89fa8f0ade75c": "scBIFI",
    "0x4ad6c49fc206c8070915151f31eabe4c70016f55": "scTUSD",
    "0xb19b33fff3a9b21f120b6ac585b8ce21635beb96": "scSPELL",
    "0xa25f9ffd7855fc350a103d91ab7c906d6bf1977d": "scBOO-a25f",
    "0x68c102aba11f5e086c999d99620c78f5bc30ecd8": "scDEI",
}

def main():
    balances = json.load(open("/home/heisenberg/CA/scream/analysis/sclink_balances.json"))
    holders = [(int(v), a) for a, v in balances.items() if v and int(v) > 0]
    holders.sort(reverse=True)
    print("holders:", len(holders), "total ctokens:", sum(v for v, _ in holders) / 1e8)
    res = []
    for v, a in holders:
        assets = arr(eth_call(CTRL, "0xabfceffc" + a[2:].rjust(64, "0")))  # getAssetsIn
        dead = [DEAD[x.lower()] for x in assets if isinstance(assets, list) and x.lower() in DEAD]
        member_link = isinstance(assets, list) and M.lower() in [x.lower() for x in assets]
        # simulate redeem of 1 cToken from holder
        r = eth_call(M, "0xdb006a75" + hex(100000000)[2:].rjust(64, "0"), frm=a)
        can_redeem = isinstance(r, str) and r != "0x"
        res.append({"addr": a, "ctokens": v, "assets": assets, "dead": dead, "member_link": member_link,
                    "can_redeem": can_redeem})
        print(f"{a} ct={v/1e8:14.4f} member_link={member_link} dead={dead} can_redeem={can_redeem}")
    json.dump(res, open("/home/heisenberg/CA/scream/analysis/sclink_redeemability.json", "w"), indent=2)
    ok = sum(x["ctokens"] for x in res if x["can_redeem"])
    bad = sum(x["ctokens"] for x in res if not x["can_redeem"])
    print(f"\nREDEEMABLE ctokens: {ok/1e8:.4f}  STUCK ctokens: {bad/1e8:.4f}")

if __name__ == "__main__":
    main()
