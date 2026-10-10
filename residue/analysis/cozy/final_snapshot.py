#!/usr/bin/env python3
"""Final consolidated live-state snapshot for the Cozy residual analysis.

All reads at a single explicit block. Public RPC only, read-only.
"""
import json
import subprocess

RPC = "https://optimism-rpc.publicnode.com"
USDC = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"
SETS = [
    "0x17705474203F7ff7ba8a940c433AB43D1F58E249",
    "0x1a684C688AcA00944B22B9380219c7bBbC3B7fB9",
    "0x426713c9E9522Bd840b8506BC14a3fE761A5fBd8",
    "0xfB8b6E5b35b70324701adE10dafbdEFb8D0EB276",
    "0x09947441e3F379Ed98cDEdE84c6E38D77Bb73c84",
    "0xCd1889f7DeB404D489678fB9C243B41Ca1321d40",
]
CPTS = [
    "0xC1304c0Db0bb2001e11E5c45ecb4F3D0e7158655",
    "0xFa1c5663aCeC49aD17422d2E846eA113534a8abf",
    "0x2086DcfB21761183ed0b20812F61F0984096AF99",
]
TRIGGERS = [
    "0xeB6613FAC35fED17c276e3FE45D67Da67685f1eF",
    "0xaCD105FEEa362D5c27CAAbA0B45F53D91B92dE27",
    "0x41701936CD5F4B8F5284dB0C68f0c2B9dF3B1618",
    "0xb634BF771915f1A22f26498098620f19340C06b0",
    "0xeaADbc9eDeB1F398AE603227A7EB508eF7e39392",
]


def call(to, sig, *args, block=None):
    cmd = ["cast", "call", to, sig, *[str(a) for a in args], "--rpc-url", RPC]
    if block:
        cmd += ["--block", str(block)]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return (out.stdout.strip() if out.returncode == 0 else "ERR:" + out.stderr.strip().split("\n")[0][:160])


def block_number():
    return int(subprocess.run(["cast", "block-number", "--rpc-url", RPC], capture_output=True, text=True).stdout.strip())


def main():
    bn = block_number()
    res = {"block": bn, "rpc": "publicnode (public)"}
    mk = "markets(uint256)(address,address,(address,address,uint16,uint16,uint16),uint8,uint256,uint256,uint256,uint128,uint128,uint64)"

    res["sets"] = {}
    for s in SETS:
        d = {
            "usdce_balance": call(USDC, "balanceOf(address)(uint256)", s, block=bn),
            "setState": call(s, "setState()(uint8)", block=bn),
            "totalSupply": call(s, "totalSupply()(uint256)", block=bn),
            "convertToAssets_1": call(s, "convertToAssets(uint256)(uint256)", 1000000, block=bn),
            "totalCollateralAvailable": call(s, "totalCollateralAvailable()(uint256)", block=bn),
            "accounting": call(s, "accounting()(uint128,uint128,uint128,uint128,uint128,uint128,uint128)", block=bn),
            "owner": call(s, "owner()(address)", block=bn),
            "pauser": call(s, "pauser()(address)", block=bn),
            "manager": call(s, "manager()(address)", block=bn),
            "markets": {},
        }
        for i in range(0, 7):
            m = call(s, mk, i, block=bn)
            if not m.startswith("ERR"):
                d["markets"][i] = m.replace("\n", " | ")
        res["sets"][s] = d

    res["cpts"] = {}
    for t in CPTS:
        res["cpts"][t] = {
            "totalSupply": call(t, "totalSupply()(uint256)", block=bn),
            "set": call(t, "set()(address)", block=bn),
            "previewClaim_1000e6": call(t, "previewClaim(uint16,uint256)(uint128)", 0, 1000000000, block=bn),
        }

    res["triggers"] = {}
    for t in TRIGGERS:
        res["triggers"][t] = {
            "state": call(t, "state()(uint8)", block=bn),
            "bondAmount": call(t, "bondAmount()(uint256)", block=bn),
            "proposalDisputeWindow": call(t, "proposalDisputeWindow()(uint256)", block=bn),
            "oracle": call(t, "oracle()(address)", block=bn),
        }

    # claim simulations at this block
    PROBE = "0x1111111111111111111111111111111111111111"
    H5 = "0x18AA2A4aB4af7058f536173df904f649455306ac"
    H3 = "0xcD01A3acED67e266be21117376C7025B384Cd4d7"
    res["simulations"] = {
        "claim_holder_H5_set1_mkt5_10000CPT": call(SETS[0], "claim(uint16,uint256,address,address)(uint128)", 5, 10000000000, H5, H5, block=bn),
        "claim_thirdparty_set1_mkt5_from_PROBE": call(SETS[0], "claim(uint16,uint256,address,address)(uint128)", 5, 10000000000, PROBE, H5, block=bn),
        "claim_holder_H3_set3_mkt0_111PT": call(SETS[2], "claim(uint16,uint256,address,address)(uint128)", 0, 111844016, H3, H3, block=bn),
        "purchase_set1_mkt1_from_PROBE": call(SETS[0], "purchase(uint16,uint256,address)(uint256,(uint128,uint128,uint128,uint128,uint128))", 1, 1000000, PROBE, block=bn),
        "deposit_set3_from_PROBE": call(SETS[2], "deposit(uint256,address)(uint256,(uint128,uint128,uint128))", 1000000, PROBE, block=bn),
        "redeem_HCSET1_1e6": call(SETS[0], "redeem(uint256,address,address)(uint64,uint256)", 1000000, "0xD43982b638b12f78B1fb48F9372539AC00D93c8A", "0xD43982b638b12f78B1fb48F9372539AC00D93c8A", block=bn),
        "claimSetFees_from_PROBE": call(SETS[0], "claimSetFees(address,address)(uint128)", PROBE, PROBE, block=bn),
    }
    # claim sims need --from which `call` doesn't pass; record separately via cast
    for name, (to, sig, args, frm) in {
        "claim_holder_H5_with_from": (SETS[0], "claim(uint16,uint256,address,address)(uint128)", [5, 10000000000, H5, H5], H5),
        "claim_thirdparty_with_from": (SETS[0], "claim(uint16,uint256,address,address)(uint128)", [5, 10000000000, PROBE, H5], PROBE),
        "claim_holder_H3_with_from": (SETS[2], "claim(uint16,uint256,address,address)(uint128)", [0, 111844016, H3, H3], H3),
        "purchase_set1_mkt1_with_from": (SETS[0], "purchase(uint16,uint256,address)(uint256,(uint128,uint128,uint128,uint128,uint128))", [1, 1000000, PROBE], PROBE),
        "deposit_set3_with_from": (SETS[2], "deposit(uint256,address)(uint256,(uint128,uint128,uint128))", [1000000, PROBE], PROBE),
        "redeem_HCSET1_with_from": (SETS[0], "redeem(uint256,address,address)(uint64,uint256)", [1000000, "0xD43982b638b12f78B1fb48F9372539AC00D93c8A", "0xD43982b638b12f78B1fb48F9372539AC00D93c8A"], "0xD43982b638b12f78B1fb48F9372539AC00D93c8A"),
    }.items():
        out = subprocess.run(["cast", "call", to, sig, *[str(a) for a in args], "--from", frm, "--rpc-url", RPC, "--block", str(bn)],
                             capture_output=True, text=True, timeout=60)
        res["simulations"][name] = out.stdout.strip() if out.returncode == 0 else "ERR:" + out.stderr.strip().split("\n")[0][:200]

    with open("live_state_final.json", "w") as fh:
        json.dump(res, fh, indent=1)
    print("snapshot at block", bn)
    for s, d in res["sets"].items():
        print(s, "usdce=", d["usdce_balance"], "state=", d["setState"], "supply=", d["totalSupply"])
    print(json.dumps(res["simulations"], indent=1))


if __name__ == "__main__":
    main()
