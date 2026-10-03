#!/usr/bin/env python3
"""Pin a PulseChain block and dump the exact live state used in c-39/README.md."""
import json, os, subprocess, time, urllib.request

RPC = "https://pulsechain-rpc.publicnode.com"
D = os.path.dirname(os.path.abspath(__file__))

def cast(*args):
    return subprocess.check_output(["cast", *args, "--rpc-url", RPC]).decode().strip()

def main():
    blk = int(cast("block-number"))
    out = {"block": blk, "rpc": RPC}
    def call(to, sig, *args, block=None):
        a = [sig] + [str(x) for x in args]
        r = subprocess.run(["cast", "call", to, *a, "--rpc-url", RPC] + (["--block", str(block)] if block else []),
                           capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else "REVERT:" + r.stderr.strip()[:120]
    out["factories"] = {
        "v1": {"address": "0x1715a3E4A142d8b698131108995174F37aEBA10D"},
        "v2": {"address": "0x29eA7545DEf87022BAdc76323F373EA1e707C523"},
    }
    for k, f in out["factories"].items():
        f["feeTo"] = call(f["address"], "feeTo()(address)")
        f["feeToSetter"] = call(f["address"], "feeToSetter()(address)")
        f["allPairsLength"] = call(f["address"], "allPairsLength()(uint256)")
    out["feeTo_setter_is_eoa"] = cast("code", "0x3a27c0a67D6bbc3DC024Af200bb309cB1FE1F091") in ("0x", "")
    out["buyandburn"] = {}
    for k, a in (("v1", "0xD46BD969d995A122AD5B803A45d309021A647B87"),
                 ("v2", "0xd6cA7ee047a6F45d20d2962E4394E070cF27724F")):
        out["buyandburn"][k] = {
            "proxy": a,
            "impl": "0x5f02fbb0f8d924e9b67c7daae523ff51175699f9",
            "owner": call(a, "owner()(address)"),
            "anyAuth": call(a, "anyAuth()(bool)"),
            "devCut": call(a, "devCut()(uint256)"),
            "devAddr": call(a, "devAddr()(address)"),
            "bountyFee": call(a, "BOUNTY_FEE()(uint256)"),
            "authorized0": call(a, "authorized(uint256)(address)", 0),
            "wpls_balance": call("0xA1077a294dDE1B09bB078844df40758a5D0f9a27", "balanceOf(address)(uint256)", a),
        }
    stable = "0xe3acfa6c40d53c3faf2aa62d0a715c737071511c"
    out["stableswap"] = {
        "pool": stable,
        "owner": call(stable, "owner()(address)"),
        "fee": call(stable, "fee()(uint256)"),
        "admin_fee": call(stable, "admin_fee()(uint256)"),
        "A": call(stable, "A()(uint256)"),
        "balances": {
            "USDT": call("0x0cb6f5a34ad42ec934882a05265a7d5f59b51a2f", "balanceOf(address)(uint256)", stable),
            "USDC": call("0x15d38573d2feeb82e7ad5187ab8c1d52810b1f07", "balanceOf(address)(uint256)", stable),
            "DAI": call("0xefd766ccb38eaf1dfd701853bfce31359239f305", "balanceOf(address)(uint256)", stable),
        },
    }
    out["routers"] = {}
    for name, a in (("v1_router_a", "0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02"),
                    ("v1_router_b", "0xaf5e33cb31A3454C950bee39ed1C76fd65b394cf"),
                    ("v2_router", "0x165C3410fC91EF562C50559f7d2289fEbed552d9")):
        out["routers"][name] = {
            "address": a,
            "plsx_balance": call("0x95B303987A60C71504D99Aa1b13B4DA07b0790ab", "balanceOf(address)(uint256)", a),
            "wpls_balance": call("0xA1077a294dDE1B09bB078844df40758a5D0f9a27", "balanceOf(address)(uint256)", a),
        }
    top = {
        "v1_plsx_wpls": "0x1b45b9148791d3a104184cd5dfe5ce57193a3ee9",
        "v1_hex_wpls": "0xf1f4ee610b2babb05c635f726ef8b0c568c8dc65",
        "v1_usdc_wpls": "0x6753560538eca67617a9ce605178f788be7e524e",
        "v1_dai_wpls": "0xe56043671df55de5cdf8459710433c10324de0ae",
        "v1_weth_wpls": "0x42abdfdb63f3282033c766e72cc4810738571609",
        "v2_dai_wpls": "0xae8429918fdbf9a5867e3243697637dc56aa76a1",
        "v2_hex_wpls": "0x19bb45a7270177e303dee6eaa6f5ad700812ba98",
        "v2_weth_wpls": "0x29d66d5900eb0d629e1e6946195520065a6c5aee",
        "v2_wpls_plsx": "0x149b2c629e652f2e89e11cd57e5d4d77ee166f9f",
    }
    out["top_pairs"] = {}
    for name, p in top.items():
        rec = {"pair": p,
               "reserves": call(p, "getReserves()(uint112,uint112,uint32)", block=blk),
               "token0": call(p, "token0()(address)"),
               "token1": call(p, "token1()(address)")}
        t0 = rec["token0"]; t1 = rec["token1"]
        rec["bal0"] = call(t0, "balanceOf(address)(uint256)", p, block=blk)
        rec["bal1"] = call(t1, "balanceOf(address)(uint256)", p, block=blk)
        out["top_pairs"][name] = rec
    json.dump(out, open(os.path.join(D, "live_state.json"), "w"), indent=1)
    print(json.dumps(out, indent=1)[:2500])

if __name__ == "__main__":
    main()
