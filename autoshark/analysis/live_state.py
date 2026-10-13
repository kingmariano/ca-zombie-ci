#!/usr/bin/env python3
"""AutoShark live-state dump at PID block 127400000 (archive RPC from env BSC_ARCHIVE_RPC).
Read-only. No secrets in file. Batched JSON-RPC."""
import json, os, time, requests
RPC = os.environ.get("BSC_ARCHIVE_RPC", "https://bsc-rpc.publicnode.com")
BLOCK = 127400000
HEXBLK = hex(BLOCK)

SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "balanceOf": "0x70a08231",
    "owner": "0x8da5cb5b",
    "feeTo": "0x017e7e58",
    "feeToSetter": "0x094b7415",
    "paused": "0x5c975abb",
    "poolLength": "0x081e3eda",
    "finsPerBlock": "0xdd62d7a5",
    "fins": "0x2d00d9a9",
    "feeAddress": "0x4125c52b",
    "squidPerBlock": "0x4ee04b4c",
    "squid": "0x3e7a8f4c",
    "stakingToken": "0x72f702f3",
    "rewardsToken": "0xd1af0c7d",
    "totalAllocPoint": "0x17caf6f1",
    "periodFinish": "0xebe2b12b",
    "rewardRate": "0x7b0a47ee",
    "emergencyLock": "0x4d5f9e4b",
    "keeper": "0xaced1661",
    "router": "0x03c8d194",
    "maxSupply": "0xd5abeb01",
    "isMinter": "0xaa271e1a",
}

def enc_uint(v): return hex(v)[2:].rjust(64, "0")
def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")

class Rpc:
    def __init__(self, url):
        self.url = url
    def batch(self, items, chunk=100):
        out = {}
        for i in range(0, len(items), chunk):
            part = items[i:i+chunk]
            payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                        "params": [{"to": t, "data": d}, HEXBLK]} for j, (t, d, tag) in enumerate(part)]
            for attempt in range(6):
                try:
                    r = requests.post(self.url, json=payload, timeout=90, headers={"User-Agent": "research/1.0"})
                    res = r.json()
                    if isinstance(res, list):
                        for j, item in enumerate(res):
                            out[part[j][2]] = item.get("result")
                        break
                    print("rpc msg:", str(res)[:150]); time.sleep(3 + attempt * 2)
                except Exception as e:
                    print("retry", attempt, str(e)[:80]); time.sleep(3 + attempt * 2)
            else:
                raise RuntimeError("batch failed")
        return out

R = Rpc(RPC)
A = {
    "factory": "0xe759Dd4B9f99392Be64f1050a6A8018f73B53a13",
    "jawsPool": "0x5D2112Ba0969EC66012380C1fb88F2A3D182Eb90",
    "feeTo": "0x593CC303170367FCB249abdd08Aaaa736d552BA5",
    "feeVault": "0xe0B4Add509BAB9d04cA92541272C87CDB822FA32",
    "MasterOcean": "0x8857af8205f224870dea119e2c75af386efb192a",
    "MasterSquid": "0x86a47ddd4c6522251d6a5a5800f3f24c03332cb4",
    "FINS": "0x1b219Aca875f8C74c33CFF9fF98f3a9b62fCbff5",
    "SQUID": "0xAE61e7dc989718E700C046a2483e93513eDCA484",
    "JAWS": "0xdd97ab35e3c0820215bc85a395e13671d84ccba2",
    "helper": "0xBd17385A935C8D77d15DB2E2C0e1BDE82fdFCe44",
    "sharkChef_v1": "0x115BebB4CE6B95340aa84ba967193F1aF03ebC73",
    "NFTController": "0xc404446f0C5f93D665Cf905fEa7ef0C3b31deb41",
    "pair_WETH_BTCB": "0x3942940EfeEF8C6435b722082beB3Eb2837EBD69",
    "pair_DAI_USDT": "0xbD78f8Cf00e03C00afAf684B72D08CF8F997d4Bb",
    "pair_USDT_BUSD": "0x06347b91DaBc757cCD5A5AA2aF802cEc78e4D239",
    "pair_FINS_WBNB": "0x14B5a6d26577970953F9E6608d6604e4676Ac5b7",
    "team_EOA": "0x91d6136a45c10a8567ae9e2aac193d65fd4c7e01",
}

def u(h): return int(h, 16) if h and h != "0x" else None
def ad(h): return "0x" + h[-40:] if h and h != "0x" else None

out = {"pinned_block": BLOCK, "entries": {}}
E = out["entries"]
E["factory"] = {}
f = R.batch([(A["factory"], SEL["allPairsLength"], "n"),
             (A["factory"], SEL["feeTo"], "feet"),
             (A["factory"], SEL["feeToSetter"], "feets")])
E["factory"] = {"allPairsLength": u(f["n"]), "feeTo": ad(f["feet"]), "feeToSetter": ad(f["feets"])}
n = E["factory"]["allPairsLength"]
pairs = []
items = [(A["factory"], SEL["allPairs"] + enc_uint(i), f"p{i}") for i in range(n)]
rp = R.batch(items)
plist = [ad(rp[f"p{i}"]) for i in range(n)]
# per-pair reads
items = []
for p in plist:
    items += [(p, SEL["totalSupply"], p + ":ts"), (p, SEL["token0"], p + ":t0"), (p, SEL["token1"], p + ":t1")]
    for nm in ["feeTo", "feeVault", "MasterOcean", "MasterSquid", "jawsPool", "team_EOA"]:
        items.append((p, SEL["balanceOf"] + enc_addr(A[nm]), p + ":" + nm))
r1 = R.batch(items)
for p in plist:
    pairs.append({"pair": p, "token0": ad(r1[p + ":t0"]), "token1": ad(r1[p + ":t1"]),
                  "lp_totalSupply": u(r1[p + ":ts"]),
                  "lp_feeTo": u(r1[p + ":feeTo"]), "lp_feeVault": u(r1[p + ":feeVault"]),
                  "lp_MasterOcean": u(r1[p + ":MasterOcean"]), "lp_MasterSquid": u(r1[p + ":MasterSquid"]),
                  "lp_jawsPool": u(r1[p + ":jawsPool"]), "lp_team_EOA": u(r1[p + ":team_EOA"])})
out["pairs"] = pairs

# key contracts state
for nm in ["jawsPool", "feeTo", "feeVault", "MasterOcean", "MasterSquid"]:
    items = [(A[nm], SEL["owner"], nm + ":owner"), (A[nm], "0x5c60da1b", nm + ":impl_direct")]
    if nm in ("feeTo", "feeVault"):
        items += [(A[nm], SEL["keeper"], nm + ":keeper"), (A[nm], SEL["router"], nm + ":router")]
    r = R.batch(items)
    E[nm] = {"owner": ad(r[nm + ":owner"]), "impl_direct": ad(r[nm + ":impl_direct"])}
    if nm in ("feeTo", "feeVault"):
        E[nm]["keeper"] = ad(r[nm + ":keeper"]); E[nm]["router"] = ad(r[nm + ":router"])
E["MasterOcean"].update({
    "poolLength": u(R.batch([(A["MasterOcean"], SEL["poolLength"], "x")])["x"]),
    "totalAllocPoint": u(R.batch([(A["MasterOcean"], SEL["totalAllocPoint"], "x")])["x"]),
    "finsPerBlock": u(R.batch([(A["MasterOcean"], SEL["finsPerBlock"], "x")])["x"]),
    "fins": ad(R.batch([(A["MasterOcean"], SEL["fins"], "x")])["x"]),
    "feeAddress": ad(R.batch([(A["MasterOcean"], SEL["feeAddress"], "x")])["x"]),
    "FINS_balance": u(R.batch([(A["FINS"], SEL["balanceOf"] + enc_addr(A["MasterOcean"]), "x")])["x"]),
})
E["MasterSquid"].update({
    "poolLength": u(R.batch([(A["MasterSquid"], SEL["poolLength"], "x")])["x"]),
    "totalAllocPoint": u(R.batch([(A["MasterSquid"], SEL["totalAllocPoint"], "x")])["x"]),
    "squidPerBlock": u(R.batch([(A["MasterSquid"], SEL["squidPerBlock"], "x")])["x"]),
    "squid": ad(R.batch([(A["MasterSquid"], SEL["squid"], "x")])["x"]),
    "feeAddress": ad(R.batch([(A["MasterSquid"], SEL["feeAddress"], "x")])["x"]),
    "SQUID_balance": u(R.batch([(A["SQUID"], SEL["balanceOf"] + enc_addr(A["MasterSquid"]), "x")])["x"]),
})
r = R.batch([(A["jawsPool"], SEL["stakingToken"], "st"), (A["jawsPool"], SEL["rewardsToken"], "rt"),
             (A["jawsPool"], SEL["totalSupply"], "ts"), (A["jawsPool"], SEL["paused"], "pa"),
             (A["jawsPool"], SEL["periodFinish"], "pf"), (A["jawsPool"], SEL["rewardRate"], "rr"),
             (A["jawsPool"], SEL["emergencyLock"], "el"),
             (A["JAWS"], SEL["balanceOf"] + enc_addr(A["jawsPool"]), "jb")])
E["jawsPool"].update({"stakingToken": ad(r["st"]), "rewardsToken": ad(r["rt"]), "totalSupply": u(r["ts"]),
                      "paused": u(r["pa"]), "periodFinish": u(r["pf"]), "rewardRate": u(r["rr"]),
                      "emergencyLock": u(r["el"]), "JAWS_balance": u(r["jb"])})
r = R.batch([(A["jawsPool"], SEL["balanceOf"] + enc_addr(A["jawsPool"]), "x")])  # junk safeguard
for nm in ["FINS", "SQUID", "JAWS"]:
    items = [(A[nm], SEL["owner"], "o"), (A[nm], SEL["totalSupply"], "ts")]
    if nm != "JAWS":
        items += [(A[nm], SEL["maxSupply"], "ms"), (A[nm], SEL["isMinter"] + enc_addr(A["MasterOcean" if nm == "FINS" else "MasterSquid"]), "im")]
    r = R.batch(items)
    E[nm] = {"owner": ad(r["o"]), "totalSupply": u(r["ts"])}
    if nm != "JAWS":
        E[nm]["maxSupply"] = u(r["ms"]); E[nm]["isMinter_farm"] = u(r["im"]) == 1
# spot holder check
spots = {}
items = []
for pnm in ["pair_WETH_BTCB", "pair_DAI_USDT", "pair_USDT_BUSD", "pair_FINS_WBNB"]:
    p = A[pnm]
    items += [(p, SEL["totalSupply"], pnm + ":ts")]
    for nm in ["feeTo", "feeVault", "MasterOcean", "MasterSquid", "team_EOA"]:
        items.append((p, SEL["balanceOf"] + enc_addr(A[nm]), pnm + ":" + nm))
r = R.batch(items)
for pnm in ["pair_WETH_BTCB", "pair_DAI_USDT", "pair_USDT_BUSD", "pair_FINS_WBNB"]:
    spots[pnm] = {"pair": A[pnm], "lp_totalSupply": u(r[pnm + ":ts"])}
    for nm in ["feeTo", "feeVault", "MasterOcean", "MasterSquid", "team_EOA"]:
        spots[pnm]["lp_" + nm] = u(r[pnm + ":" + nm])
E["pair_spot"] = spots
json.dump(out, open("/home/heisenberg/CA/autoshark/analysis/live_state_pinned.json", "w"), indent=1)
print("saved. block", BLOCK, "pairs", len(pairs))
print(json.dumps(E["factory"]))
print(json.dumps({k: E[k] for k in ["jawsPool", "feeTo", "feeVault", "MasterOcean", "MasterSquid", "FINS", "SQUID", "JAWS"]}, indent=1))
