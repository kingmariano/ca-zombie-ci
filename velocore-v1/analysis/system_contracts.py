#!/usr/bin/env python3
"""Check live state of Velocore V1 system contracts on zkSync Era (balances + key functions)."""
import json, urllib.request, subprocess

RPC = "https://mainnet.era.zksync.io"
BS = "https://zksync.blockscout.com/api/v2"
VC = "0x85D84c774CF8e9fF85342684b0E795Df72A24908"
SYS = {
    "VC_token": "0x85D84c774CF8e9fF85342684b0E795Df72A24908",
    "Voter_new": "0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A",
    "VotingEscrow": "0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F",
    "RewardsDistributor": "0xD7107a47B4fBBc585b25BbEe3777B2EDC11D156C",
    "Minter": "0x8f0b4B3e211c84061ab5959Bd3D49C6B3EeC1d7D",
    "Gauge_doc": "0xd06aD497EB89716B34a5EF6B9A2aA1Fb14A4c75e",
    "GaugeFactory": "0xB7D98F552B4484b52181600fA5360BBAdd09fA98",
    "ExternalBribe": "0xD822315C30001bB85BAE8a9dE5dB98a87d0656d1",
    "BribeFactory": "0xc365acD05609D9125Eb77dDF44322F3F561C9713",
    "WrappedExternalBribe": "0x0021C13C7bd19858E18EDdf54B82A6C7cd46cc96",
    "WrappedExternalBribeFactory": "0x5c5d9C7fe718cF3840d181C35c078aD6F4e315E1",
    "PairFactory_off": "0xE140EaC2bB748c8F456719a457F26636617Bb0E9",
    "PairFactory_old": "0xF5719b1Ea3C9bF6491E22C49379E31060d0FbFc1",
    "Router_new": "0xF29Eb540eEba673f8Fb6131a7C7403C8e4C3f143",
    "Router_old": "0xB2CEF7f2eCF1f4f0154D129C6e111d81f68e6d03",
    "RouterWrapper": "0xd999E16e68476bC749A28FC14a0c3b6d7073F50c",
    "Router_0x46db": "0x46dbd39e26a56778d88507d7aEC6967108C0BD36",
    "Old_Voter": "0x2C63AC5D42Bd20aB6A2a5bdB2b2B29597fC5Df77",
    "Old_Gauge_doc": "0xc3e495312300Ee0A940889a5af0394F01BBA30E5",
    "Old_GaugeFactory": "0xA5DC997cE8D4443Ad9cB39d2aB46D8F929be46B1",
    "Old_ExternalBribe": "0x3E7b8C06626089ABeB52C6B5A9D97F893451A32c",
    "Old_BribeFactory": "0xcE2d259dD1DCCf84e0c064ECcc49Ef060Ff4d73E",
    "Old_VotingEscrow": "0x83CDDc0282D51d77d21e71190B02124D59f40918",
    "Old_RewardsDistributor": "0xEb669307ffd656a90E79a8AA5D635ad5f703a69f",
    "Old_Minter": "0x594b5927AAcEf79a1bfe72959D2DF7d122AFBd63",
    "Old_Router": "0x389C30DafaEc0a0C637C33F39E1bDea75c4bA0e6",
    "F1_fees_pool0xa203": "0x03dc61793565b6073496fb0e24770c7e41b97edc",
    "Old_VC_token": "0x129c6e2D8619B3F20504dBB7188602300f4C7e16",
}

def rpc(method, params):
    payload = {"jsonrpc":"2.0","id":1,"method":method,"params":params}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    for i in range(3):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                d = json.loads(r.read())
            return d.get("result"), d.get("error")
        except Exception as e:
            if i == 2: return None, str(e)
            import time; time.sleep(2)

def cast_call(to, sig, *args):
    cmd = ["cast","call",to,sig] + [str(a) for a in args] + ["--rpc-url",RPC]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode==0 else "ERR: "+r.stderr.strip().split("\n")[0][:80]

def bs_balances(addr):
    try:
        req = urllib.request.Request(f"{BS}/addresses/{addr}", headers={"User-Agent":"Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=40) as r:
            d = json.loads(r.read())
        out = {"eth": d.get("coin_balance"), "tokens": []}
        for b in d.get("token_balances", []) or []:
            t = b.get("token") or {}
            out["tokens"].append({"sym": t.get("symbol"), "addr": t.get("address"), "val": b.get("value"), "usd": t.get("exchange_rate")})
        return out
    except Exception as e:
        return {"err": str(e)[:60]}

res = {}
for name, addr in SYS.items():
    code, _ = rpc("eth_getCode", [addr, "latest"])
    item = {"addr": addr, "code_len": (len(code)-2)//2 if code else 0}
    item["vc_balance"] = cast_call(VC, "balanceOf(address)(uint256)", addr)
    item["bs"] = bs_balances(addr)
    res[name] = item
    print(name, addr, "codelen", item["code_len"], "| VC:", item["vc_balance"], "| eth:", item["bs"].get("eth"), "| tokens:", [(t["sym"],t["val"]) for t in item["bs"].get("tokens",[])[:4]])
json.dump(res, open("/home/heisenberg/CA/velocore-v1/analysis/system_contracts.json","w"), indent=1)
print("saved")
