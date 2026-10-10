#!/usr/bin/env python3
"""Parallel read-only live-state probe for Cozy Finance v2 Sets on Optimism.

Public RPC only. No secrets written. Outputs JSON to stdout / file.
"""
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

RPC = "https://optimism-rpc.publicnode.com"

SETS = [
    "0x17705474203F7ff7ba8a940c433AB43D1F58E249",
    "0x1a684C688AcA00944B22B9380219c7bBbC3B7fB9",
    "0x426713c9E9522Bd840b8506BC14a3fE761A5fBd8",
    "0xfB8b6E5b35b70324701adE10dafbdEFb8D0EB276",
]
MKTSIG = "markets(uint256)(address,address,(address,address,uint16,uint16,uint16),uint8,uint256,uint256,uint256,uint128,uint128,uint64)"

CPTS = [
    "0xC1304c0Db0bb2001e11E5c45ecb4F3D0e7158655",
    "0xFa1c5663aCeC49aD17422d2E846eA113534a8abf",
    "0x1F626C96Ed2AedB69DfF96B653F733b1767E9cce",
    "0x2086DcfB21761183ed0b20812F61F0984096AF99",
    "0x658CeBADEa3a833EB7E186bE626Ae88496A6F76E",
    "0xcFA3560c768946446e9B8fbd734Be7b2a39dAB6F",
    "0x996e0a0A3801A3F642be2c5A4745BF9d526fA668",
    "0x17aFF89bf88B4eB56a1bCB256ff49FA1910E8410",
]

TRIGGERS = [
    "0xeB6613FAC35fED17c276e3FE45D67Da67685f1eF",
    "0xaCD105FEEa362D5c27CAAbA0B45F53D91B92dE27",
    "0x41701936CD5F4B8F5284dB0C68f0c2B9dF3B1618",
]

HELPERS = [
    "0x9E47C805587362eF36F2cAB9d1E4E7D546f953d4",
    "0xeF9886f4C8823Dc9457267A7b76A55Db2C2f5F8d",
    "0x003FE7359A4E03C85Ac2f521eC699ED84C7c5ccB",
]

ENUMS = {0: "ACTIVE", 1: "PAUSED", 2: "FROZEN"}  # SetState
MKT_ENUMS = {0: "ACTIVE", 1: "FROZEN", 2: "TRIGGERED"}
TRIG_ENUMS = {0: "ACTIVE", 1: "FROZEN", 2: "TRIGGERED"}


def cast_block():
    out = subprocess.run(["cast", "block-number", "--rpc-url", RPC], capture_output=True, text=True, timeout=60)
    return int(out.stdout.strip())


def call(addr, sig, *args):
    cmd = ["cast", "call", addr, sig, *[str(a) for a in args], "--rpc-url", RPC]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        val = out.stdout.strip()
        err = out.stderr.strip()
        if out.returncode != 0:
            return {"ok": False, "error": err.split("\n")[0][:300]}
        return {"ok": True, "raw": val}
    except Exception as e:  # noqa
        return {"ok": False, "error": str(e)[:300]}


def main():
    bn = cast_block()
    tasks = []  # (key, addr, sig, args)

    def add(key, addr, sig, *args):
        tasks.append((key, addr, sig, args))

    for s in SETS:
        add(f"set:{s}:asset", s, "asset()(address)")
        add(f"set:{s}:name", s, "name()(string)")
        add(f"set:{s}:symbol", s, "symbol()(string)")
        add(f"set:{s}:decimals", s, "decimals()(uint8)")
        add(f"set:{s}:totalSupply", s, "totalSupply()(uint256)")
        add(f"set:{s}:totalCollateralAvailable", s, "totalCollateralAvailable()(uint256)")
        add(f"set:{s}:maxDeposit", s, "maxDeposit()(uint256)")
        add(f"set:{s}:setState", s, "setState()(uint8)")
        add(f"set:{s}:owner", s, "owner()(address)")
        add(f"set:{s}:pendingOwner", s, "pendingOwner()(address)")
        add(f"set:{s}:pauser", s, "pauser()(address)")
        add(f"set:{s}:manager", s, "manager()(address)")
        add(f"set:{s}:backstop", s, "backstop()(address)")
        add(f"set:{s}:ptokenFactory", s, "ptokenFactory()(address)")
        add(f"set:{s}:setConfig", s, "setConfig()(uint32,uint16,bool)")
        add(f"set:{s}:accounting", s, "accounting()(uint128,uint128,uint128,uint128,uint128,uint128,uint128)")
        add(f"set:{s}:lastConfigUpdate", s, "lastConfigUpdate()(bytes32,uint64,uint64)")
        add(f"set:{s}:balanceOfHelper1", s, "balanceOf(address)(uint256)", HELPERS[0])
        add(f"set:{s}:balanceOfHelper2", s, "balanceOf(address)(uint256)", HELPERS[1])
        add(f"set:{s}:balanceOfAttackerEOA", s, "balanceOf(address)(uint256)", HELPERS[2])
        add(f"set:{s}:usdceBalance", "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", "balanceOf(address)(uint256)", s)
        add(f"set:{s}:convertToAssets1", s, "convertToAssets(uint256)(uint256)", 1000000)
        add(f"set:{s}:convertToShares1", s, "convertToShares(uint256)(uint256)", 1000000)
        for i in range(0, 16):
            add(f"set:{s}:markets{i}", s, MKTSIG, i)
            add(f"set:{s}:remainingProtection{i}", s, "remainingProtection(uint16)(uint256)", i)
            add(f"set:{s}:effectiveActiveProtection{i}", s, "effectiveActiveProtection(uint16)(uint256)", i)
            add(f"set:{s}:previewPurchase{i}", s, "previewPurchase(uint16,uint256)(uint128,uint128,uint128,uint128,uint128)", i, 1000000000)
            add(f"set:{s}:previewClaim1e9_{i}", s, "previewClaim(uint16,uint256)(uint128)", i, 1000000000)
            add(f"set:{s}:previewClaim1_{i}", s, "previewClaim(uint16,uint256)(uint128)", i, 1)
            add(f"set:{s}:previewSale{i}", s, "previewSale(uint16,uint256)(uint128,uint128,uint128,uint128)", i, 1000000000)

    for t in CPTS:
        add(f"token:{t}:name", t, "name()(string)")
        add(f"token:{t}:symbol", t, "symbol()(string)")
        add(f"token:{t}:decimals", t, "decimals()(uint8)")
        add(f"token:{t}:totalSupply", t, "totalSupply()(uint256)")
        add(f"token:{t}:set", t, "set()(address)")
        for h in HELPERS:
            add(f"token:{t}:balanceOf:{h}", t, "balanceOf(address)(uint256)", h)

    for t in TRIGGERS:
        add(f"trigger:{t}:state", t, "state()(uint8)")
        add(f"trigger:{t}:oracle", t, "oracle()(address)")
        add(f"trigger:{t}:bondAmount", t, "bondAmount()(uint256)")
        add(f"trigger:{t}:proposalDisputeWindow", t, "proposalDisputeWindow()(uint256)")
        add(f"trigger:{t}:rewardToken", t, "rewardToken()(address)")
        add(f"trigger:{t}:requestTimestamp", t, "requestTimestamp()(uint256)")
        add(f"trigger:{t}:queryIdentifier", t, "queryIdentifier()(bytes32)")
        add(f"trigger:{t}:query", t, "query()(string)")
        add(f"trigger:{t}:expirationTime", t, "expirationTime()(uint256)")
        add(f"trigger:{t}:reward", t, "reward()(uint256)")
        add(f"trigger:{t}:set", t, "set()(address)")

    results = {}
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(call, a, s, *args): (k, a, s, args) for (k, a, s, args) in tasks}
        for f in futs:
            k, a, s, args = futs[f]
            results[k] = f.result()

    out = {"chain": "optimism", "chainId": 10, "block": bn, "rpc": "publicnode (public)", "results": results}
    with open(sys.argv[1] if len(sys.argv) > 1 else "probe_live.json", "w") as fh:
        json.dump(out, fh, indent=1)
    print(f"block={bn} calls={len(results)} ok={sum(1 for r in results.values() if r['ok'])}")


if __name__ == "__main__":
    main()
