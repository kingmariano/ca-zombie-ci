#!/usr/bin/env python3
"""Probe a fixed list of Cozy Set candidates (read-only, public RPC)."""
import json
import subprocess
import sys

RPC = "https://optimism-rpc.publicnode.com"
USDC = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"

ADDRS = [
    # gen-2 extracted
    "0xC1B6eC68CB40459Ae1521b403d6f546f0a37914c",
    "0xBBf3a80c2ec900d877c13302f4407df08AeFfd28",
    "0xFE5a43AFa45EE3E56542635712d7f09cf62Da278",
    "0xEaf064dD483f878249F893c2F0Cdc590ef8d19d8",
    "0xCd1889f7DeB404D489678fB9C243B41Ca1321d40",
    # gen-1 extracted
    "0xd106aFb46F87E3Bd00823B9E29103672CB54eF6E",
    "0x5f55dE21bd34058E0D4F6A78FB1F1f024b85656E",
    "0x30EeF2828f831b995B79C144Ad1F99c6F7D0a4b9",
    "0x07d83aE2224594AB795A6C5c480db6E5e90c1E4F",
    "0x845936b9749d85d8B2e830bF165AC8506767eDfD",
    "0xb031A530a776CE7019bBc00D0a377F262A46A2f7",
    # unclassified (from token enumeration)
    "0x14c0AFB615EaEeB4366AA4DbbC19964bBF293F93",
    "0x288A668dFc5Bd873914210e23b186aD3473a0673",
    "0x09947441e3F379Ed98cDEdE84c6E38D77Bb73c84",
    "0x6A11F7C7a29590629086cd2ccA0061138FEBe6cB",
    "0x372893DAF3581179A2066326eEE907264692D0d5",
    "0x03ba90c6a214e6C943DF55589675857881E041a6",
    "0x05585408234dec93F475dA4271f95d6138908bA6",
    "0xf2E9B8795143fA3299357e0373589Fbb310558F5",
    "0x1cfD6c4683a6d790B49aEF88Be917EA1547c0803",
    "0x339a993111146b06cCd6Db44B05036b20eAdC8A7",
    "0x46fdF205d8aEE986d331a01dF1C2A8523EaB371b",
    # already-known
    "0x17705474203F7ff7ba8a940c433AB43D1F58E249",
    "0x1a684C688AcA00944B22B9380219c7bBbC3B7fB9",
    "0x426713c9E9522Bd840b8506BC14a3fE761A5fBd8",
    "0xfB8b6E5b35b70324701adE10dafbdEFb8D0EB276",
]


def rpc_batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    out = subprocess.run(["curl", "-s", "-m", "60", "-X", "POST", RPC, "-H", "Content-Type: application/json",
                          "-d", json.dumps(payload)], capture_output=True, text=True, timeout=120)
    try:
        data = json.loads(out.stdout)
    except Exception:
        return [None] * len(calls)
    res = [None] * len(calls)
    if isinstance(data, dict):
        return res
    for item in data:
        if "result" in item:
            res[item["id"]] = item["result"]
    return res


def sig(s):
    return subprocess.run(["cast", "sig", s], capture_output=True, text=True).stdout.strip()


SEL = {n: sig(n) for n in ["asset()", "setState()", "totalSupply()", "balanceOf(address)", "manager()", "name()", "symbol()"]}


def pad(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def one(a):
    calls = [
        ("eth_getCode", [a, "latest"]),
        ("eth_call", [{"to": USDC, "data": SEL["balanceOf(address)"] + pad(a)}, "latest"]),
        ("eth_call", [{"to": a, "data": SEL["setState()"]}, "latest"]),
        ("eth_call", [{"to": a, "data": SEL["totalSupply()"]}, "latest"]),
        ("eth_call", [{"to": a, "data": SEL["manager()"]}, "latest"]),
        ("eth_call", [{"to": a, "data": SEL["asset()"]}, "latest"]),
    ]
    r = rpc_batch(calls)
    def i(x):
        try:
            return int(x, 16) if x and x != "0x" else None
        except Exception:
            return None
    def ad(x):
        return "0x" + x[-40:] if x and x != "0x" else None
    code = r[0] or "0x"
    impl = "0x" + code[20:60] if len(code) > 60 else None
    return {
        "addr": a,
        "impl": impl,
        "codelen": (len(code) - 2) // 2,
        "usdce": i(r[1]),
        "setState": i(r[2]),
        "totalSupply": i(r[3]),
        "manager": ad(r[4]),
        "asset": ad(r[5]),
    }


def main():
    import concurrent.futures
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        out = list(ex.map(one, ADDRS))
    for o in out:
        print(f"{o['addr']} impl={o['impl']} len={o['codelen']} state={o['setState']} supply={o['totalSupply']} usdce={o['usdce']} manager={o['manager']} asset={o['asset']}")
    json.dump(out, open("sets_probe2.json", "w"), indent=1)


if __name__ == "__main__":
    main()
