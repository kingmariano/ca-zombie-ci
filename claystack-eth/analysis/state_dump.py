#!/usr/bin/env python3
"""ClayStack ETH (H-07) live-state dump.

Read-only JSON-RPC against a public Ethereum endpoint. No keys required.
Usage: python3 state_dump.py [rpc_url]
Outputs JSON to stdout (and a summary to stderr).
"""
import json, sys, urllib.request, time

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://ethereum-rpc.publicnode.com"

def batch(calls, chunk=12, tries=5):
    out = []
    for s in range(0, len(calls), chunk):
        part = calls[s:s + chunk]
        payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
                   for i, (m, p) in enumerate(part)]
        data = json.dumps(payload).encode()
        for attempt in range(tries):
            try:
                req = urllib.request.Request(RPC, data=data, headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 research"})
                resp = json.load(urllib.request.urlopen(req, timeout=45))
                if isinstance(resp, dict):
                    resp = [resp]
                by_id = {r["id"]: r for r in resp}
                out += [by_id[i].get("result", {"error": by_id[i].get("error")})
                        for i in range(len(part))]
                break
            except Exception as e:
                if attempt == tries - 1:
                    out += [{"error": str(e)} for _ in part]
                else:
                    time.sleep(1.0)
    return out

def i(x, d=0):
    try:
        return int(x, 16)
    except Exception:
        return d

# ---- target set (all ClayStack ETH-related contracts found) ----
TOKENS = {
    "csETH":  "0x5d74468b69073f809D4FaE90AfeC439e69Bf6263",
    "csMATIC":"0x38b7Bf4eeCF3EB530b1529c9401FC37d2a71a912",
    "xcsETH": "0xf2F65Cf87F2fC22da5FE4579A4f143062B41D0B0",
    "WETH":   "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "stETH":  "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
    "rETH":   "0xae78736Cd615f374D3085123A210448E74Fc6393",
}
CONTRACTS = [
    # (label, address)
    ("csETH_token",            "0x5d74468b69073f809D4FaE90AfeC439e69Bf6263"),
    ("clayMain_ETH_proxy",     "0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8"),
    ("clayMain2_proxy",        "0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051"),
    ("current_impl",           "0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59"),
    ("intermediate_78e1",      "0x78e1c86474bd2f70d83bdc767ca303243bba18d0"),
    ("intermediate_4716",      "0x471627b16214a31dd0fa6f5531abb0fdc14d3207"),
    ("executor_proxy",         "0x4c06a181edafe572c44ab2a818b625a927484519"),
    ("impl_2024_594e",         "0x594e80D1be1c7d0f574d3556eCacB8dF4b2f35B8"),
    ("roleManager_proxy",      "0x574e6bc316d4032d2Bd6D847ae6166FC7aC81bc3"),
    ("roleManager_impl",       "0x9cC565BCC55AA20E122BFe14cb316632A86970CB"),
    ("timelock",               "0x7a1104Feb0D460Aa437008e54D7D6Db0bA7e8876"),
    ("timelock_upgrades",      "0x376b467dFf007dD8d3f24404cAddff7F72257Fe4"),
    ("csMATIC_main_proxy",     "0x91730940DCE63a7C0501cEDfc31D9C28bcF5F905"),
    ("csMATIC_main_impl",      "0xDB15A54Ea0Ecd4f86aFe653aAC16FbCB488D0948"),
    ("xcsETH_main_proxy",      "0x19C1bF1Ff06E5702aef056b41290C6a7FF231c88"),
    ("xcsETH_main_impl",       "0x8bfD6fE95C3c78c7101387068c09a72dF91dfF17"),
    ("new_proxy_769B",         "0x769BcD144644A5EB0a590E9436671353Ad82b809"),
    ("new_impl_F22E",          "0xF22E703BfCc912F82eb0831C2713fd675370d4c6"),
    ("new_proxy_93b7",         "0x93b7a777D333c4F8dce3135bCd3Dac85aD14D708"),
    ("new_impl_547D",          "0x547D6013A3ffA103d051E6aAa225A7c7b29F6CF0"),
    ("new_proxy_745A",         "0x745A87ec92CB83aF63369A6fA916950BBF4A1Efb"),
    ("new_impl_0723",          "0x0723292882D066Ad5C24a1a22BfeF012EDaA73fc"),
    ("new_proxy_0c82",         "0x0c82528Ce7337C2D0af469654331fa62ba753C0b"),
    ("strategy_stETH_36c4",    "0x36c48f0A77c38B447F2fF77926Ff1B8fA57D564E"),
    ("strategy_rETH_3E6e",     "0x3E6ea5e63Ca289f827420c051e2eC6598940cDF5"),
    ("depositsManager_82E0",   "0x82E0707ABD5f6E25C06Af00d7dc7Cf1939B19c92"),
    ("proxy_A360",             "0xA360690676D2Ad036b1426496aFe53ae46F3CEF3"),
    ("impl_af18",              "0xaf1845cE91aCB2D4C0d4669bfbDfb06e1501E002"),
    ("proxy_3494",             "0x349405b80C8bAfd74DA9d4308F3c7b60B4Bf10E5"),
    ("impl_dcf7",              "0xDcF7Dbe6865e52409A0fa2b4B23433DB2Af3646f"),
    ("proxy_5764",             "0x5764cD55ffb62E2b089c2D1eaD7dc68eDe813355"),
    ("impl_d776",              "0xD776098AeBD0525E00a2C0E77350Ad5e0BB582dF"),
    ("proxy_4542",             "0x454296e1E6B665b8D4a26b5890150629Bd6B54Be"),
    ("impl_52D4",              "0x52D4b98c506EE19295b4c707C16Aa0b6C196D56c"),
    ("proxy_11F1",             "0x11F11eC5c881e119baF066a784f9f6F3Fc163BeF"),
    ("eoa_admin_a72d",         "0xa72df45a431b12ef4e37493d2bcf3d19af3d24fa"),
    ("eoa_6b62",               "0x6b6246dc8413d8004ca19ce56b928c8c9a7712cc"),
    ("eoa_deployer_36e6",      "0x36e655069464Be6202e0e4D5Ee9f76034c0ad9b6"),
    ("eoa_c27a",               "0xc27a5BC83BB4d50791DC3F9a7C2Db59eC33e822a"),
]
IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
NS_A00 = 0xf364fa666b2e082663ca7dd04c16a2c736d1990df80fd97015fe242a48f33a00
NS_7050 = 0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3
NS_FEA1 = 0xfea148c8c2f2338f72b534095739ecee32b8eecb808237f2bf87d23eda223800

block = i(batch([("eth_blockNumber", [])])[0])
res = {"rpc": RPC, "block": block, "contracts": {}, "tokens": {}, "roles": {}}

calls, keys = [], []
for label, a in CONTRACTS:
    calls += [("eth_getCode", [a, hex(block)]),
              ("eth_getBalance", [a, hex(block)]),
              ("eth_getStorageAt", [a, IMPL_SLOT, hex(block)]),
              ("eth_getStorageAt", [a, ADMIN_SLOT, hex(block)])]
    keys += [(label, "code"), (label, "eth"), (label, "impl"), (label, "admin")]
out = batch(calls, chunk=12)
for (label, kind), r in zip(keys, out):
    e = res["contracts"].setdefault(label, {"addr": dict(CONTRACTS)[label]})
    if kind == "code":
        e["code_size"] = (len(r) - 2) // 2 if isinstance(r, str) else None
    elif kind == "eth":
        e["eth_wei"] = str(i(r))
    elif kind == "impl":
        e["impl"] = "0x" + r[-40:] if isinstance(r, str) and i(r) else None
    elif kind == "admin":
        e["admin"] = "0x" + r[-40:] if isinstance(r, str) and i(r) else None

# token supplies + clayMain pointers
sel = {"totalSupply": "0x18160ddd", "clayMain": "0x3b2f6f1f"}
calls, keys = [], []
for name, t in TOKENS.items():
    calls.append(("eth_call", [{"to": t, "data": "0x18160ddd"}, hex(block)]))
    keys.append((name, "totalSupply"))
out = batch(calls, chunk=12)
for (name, _), r in zip(keys, out):
    res["tokens"].setdefault(name, {})["totalSupply_wei"] = str(i(r)) if isinstance(r, str) else None

# csETH.clayMain() selector = clayMain() -> keccak('clayMain()')[:4] = 0x3b2f6f1f (verify live)
for name, t in [("csETH", TOKENS["csETH"]), ("xcsETH", TOKENS["xcsETH"])]:
    r = batch([("eth_call", [{"to": t, "data": "0x3b2f6f1f"}, hex(block)])])[0]
    res["tokens"].setdefault(name, {})["clayMain"] = "0x" + r[-40:] if isinstance(r, str) and len(r) >= 42 else None

# clayMain namespaced storage
calls, keys = [], []
for label, a in [("clayMain_ETH_proxy", CONTRACTS[1][1]), ("clayMain2_proxy", CONTRACTS[2][1])]:
    for off in range(0, 8):
        for base, bn in [(NS_A00, "A"), (NS_7050, "S"), (NS_FEA1, "F")]:
            calls.append(("eth_getStorageAt", [a, hex(base + off), hex(block)]))
            keys.append((label, f"{bn}{off:02x}"))
    for slot in range(0, 4):
        calls.append(("eth_getStorageAt", [a, hex(slot), hex(block)]))
        keys.append((label, f"slot{slot}"))
out = batch(calls, chunk=12)
for (label, k), r in zip(keys, out):
    if isinstance(r, str) and i(r):
        res["contracts"].setdefault(label, {}).setdefault("storage", {})[k] = r

# RoleManager roles
def keccak(s):
    import subprocess
    return subprocess.run(["cast", "keccak", s], capture_output=True, text=True).stdout.strip()

ROLES = ["TIMELOCK_ROLE", "TIMELOCK_UPGRADES_ROLE", "CS_SERVICE_ROLE", "DEFAULT_ADMIN_ROLE"]
WHO = [a for _, a in CONTRACTS] + ["0x084a0738a29a3bfc233d3cb318ff7b63d97d49e4",
                                   "0x84382d41f08401C4530FCB215938cb8D054d9F55",
                                   "0xC4e16E439c40Bba288b84e2a2974BDF6273919a1"]
rm = "0x574e6bc316d4032d2Bd6D847ae6166FC7aC81bc3"
calls, keys = [], []
for role in ROLES:
    h = keccak(role)
    for w in WHO:
        calls.append(("eth_call", [{"to": rm,
                     "data": "0x91d14854" + h[2:] + w.lower()[2:].rjust(64, "0")}, hex(block)]))
        keys.append((role, w))
out = batch(calls, chunk=12)
for (role, w), r in zip(keys, out):
    v = isinstance(r, str) and i(r) == 1
    if v:
        res["roles"].setdefault(role, []).append(w)

# token balances of key contracts
calls, keys = [], []
for label, a in CONTRACTS:
    for tn, t in TOKENS.items():
        calls.append(("eth_call", [{"to": t, "data": "0x70a08231" + a.lower()[2:].rjust(64, "0")}, hex(block)]))
        keys.append((label, tn))
out = batch(calls, chunk=12)
for (label, tn), r in zip(keys, out):
    v = i(r)
    if v:
        res["contracts"].setdefault(label, {}).setdefault("tokens", {})[tn] = str(v)

print(json.dumps(res, indent=1))
sys.stderr.write(f"block={block} contracts={len(res['contracts'])} roles={ {k: len(v) for k, v in res['roles'].items()} }\n")
