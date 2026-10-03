#!/usr/bin/env python3
"""Extra-contract sweep on Base: solver vault, LP token, executor, fee rebate, rebalancers.

Read-only. Writes raw/extras_base.json
"""
import json
import os

from rpc import Rpc

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
RPC = "https://base-rpc.publicnode.com"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
INTX = "0x7d27187eb33a7b1d99258ff222633670f84fa342"
DIAMOND = "0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43"
SLOTS = {
    "impl": 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,
    "admin": 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103,
}

ADDRESSES = {
    "vault_proxy_7785": "0x7785fE35F6510D111063579AA14F7D28aD84512A",
    "lp_token": "0xB6d340Af68279326402139C30934317929535D32",
    "vault_admin": "0x00f3e7930B15c6D8dd4376E5054832bB6a273c9D",
    "lp_admin": "0x4c15Bf47E901125FFe606204628081FC07c3dCbE",
    "balancer": "0x6b3535Be4eE1c383Bdc4e27f368971Deb1B4c485",
    "carbon_fee_rebate": "0xcB420c74625fEC41671458f3aC660616e1ad1357",
    "symm_executor": "0x1c529cF1392CDe198B5CdaC11C7e50780a0686A4",
    "target_rebalancer_6106": "0x6106D70228d8b1802aa6b5ea92366e5be09E634F",
    "target_rebalancer_A2eB": "0xA2eBb23020Ccfbf05bb85719C409D32d2775aa53",
    "target_rebalancer_767e": "0x767e88D36Fd7879c35939E9622C9930A17F61e9D",
    "target_rebalancer_74dC": "0x74dC2aeF96EFEbfE34054Ee615fd6ec5637Bfc9A",
    "vault_6e79": "0x6e79556F4c17A3B3903fFf9eD2db6973F3bb5558",
    "vault_Bc40": "0xBc40D95e2E7fe61ABF9f855fdc32Fe7F28181460",
    "vault_eD86": "0xeD865FF880904Ca4732Cc79F48e70AdeE02Ac563",
    "vault_0b2e": "0x0b2e5F8e002BC88a18fC85f69F7B7864bB5B7bfD",
    "fee_collector_new": "0x39e4cdd23ef0994d38da526da0d2cdfb5b1624f3",
    "fee_collector_old": "0x9BC9CA7e6A8F013f40617c4585508A988DB7C1c7",
    "owner_base_diamond": "0x92e89bb3ce2cea34df6168010bbefce2997b014d",
    "default_admin_base": "0x5146c35725d9b8f11a84ebd4a3abe9845698ada9",
    "deployer_vault": "0xf1d63df1CD64a3f3A8F440bAba619dbB4baBB020",
}
PARTYB_CANDIDATES = ADDRESSES | {
    "solver_partyB": "0xB49Cae38c96f6425Ce4A46e8220549C6a13362bE",
}


def main():
    r = Rpc(RPC)
    blk = r.block_number()
    bh = hex(blk)
    out = {"chain": "base", "block": blk, "addresses": ADDRESSES}
    res = {}
    for name, a in ADDRESSES.items():
        info = {"address": a}
        info["code_size"] = len(r.get_code(a, bh) or "0x") // 2
        info["native_balance"] = r.get_balance(a, bh)
        calls = [
            ("balanceOf", [a], USDC), ("balanceOf", [a], INTX),
        ]
        vals = r.batch_call(calls, bh)
        info["usdc"] = vals[0][0] if vals[0] else None
        info["intx"] = vals[1][0] if vals[1] else None
        # proxy slots if code exists
        if info["code_size"] > 100:
            impl = r.get_storage_at(a, SLOTS["impl"], bh)
            admin = r.get_storage_at(a, SLOTS["admin"], bh)
            info["eip1967_impl"] = ("0x" + impl[-40:]) if impl and impl != "0x" and int(impl, 16) else None
            info["eip1967_admin"] = ("0x" + admin[-40:]) if admin and admin != "0x" and int(admin, 16) else None
        res[name] = info
        print(f"{name:28} {a} code={info['code_size']} usdc={info['usdc']} intx={info['intx']} impl={info.get('eip1967_impl')}")

    # Vault-specific getters (try each vault proxy)
    vaults = [n for n in ADDRESSES if n.startswith("vault_")]
    for v in vaults + ["vault_proxy_7785"]:
        a = ADDRESSES[v]
        names = ["solver", "signer", "collateralTokenAddress", "lockedBalance",
                 "depositLimit", "currentDeposit", "withdrawalPeriod", "paused",
                 "lpToken", "vaultToken", "totalSupply", "symmioAddress", "minimumPaybackRatio"]
        vals = r.batch_call([(n, [], a) for n in names], bh)
        d = {n: (v[0] if v else None) for n, v in zip(names, vals)}
        res[v]["vault_state"] = d
        print(f"  {v} state: {json.dumps({k: str(x) for k, x in d.items()})[:400]}")

    # SymmExecutor + Carbon + rebalancer misc
    misc = {
        "symm_executor": ["multiAccount", "owner", "paused", "requestToClosePositionSelector"],
        "carbon_fee_rebate": ["owner", "rebateToken", "carbonTrustedAddress", "totalReward"],
        "lp_token": ["name", "symbol", "decimals", "totalSupply"],
        "default_admin_base": ["getOwners", "getThreshold", "VERSION", "NAME"],
        "owner_base_diamond": ["getOwners", "getThreshold", "VERSION", "NAME"],
    }
    for name, fns in misc.items():
        a = ADDRESSES[name]
        vals = r.batch_call([(n, [], a) for n in fns], bh)
        d = {n: (v[0] if v else None) for n, v in zip(fns, vals)}
        res[name]["state"] = d
        print(f"  {name}: {json.dumps({k: str(x) for k, x in d.items()})[:300]}")

    # PartyB status on diamond for all extras
    names = list(PARTYB_CANDIDATES)
    vals = r.batch_call([("isPartyB", [PARTYB_CANDIDATES[n]], DIAMOND) for n in names], bh)
    pt = {n: (v[0] if v else None) for n, v in zip(names, vals)}
    out["partyB_status"] = pt
    print("partyB status:", json.dumps(pt, indent=1))

    out["contracts"] = res
    with open(os.path.join(RAW, "extras_base.json"), "w") as f:
        json.dump(out, f, indent=1, default=lambda o: "0x" + o.hex() if isinstance(o, bytes) else str(o))
    print(f"[base] extras written at block {blk}")


if __name__ == "__main__":
    main()
