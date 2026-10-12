#!/usr/bin/env python3
"""Jaypeggers live-state collector (read-only, no secrets).

Writes a JSON snapshot of all Jaypeggers (v1 JAY + v1 staking + v1 splitter +
Uniswap V2 JAY/USDC pair; v2 jUSDC + v2 staking + v2 splitter + jUSDC/WETH pair)
at a single block, using `cast` eth_calls against $RPC_URL (or a public
fallback). Never prints or stores the RPC URL.
"""
import json
import os
import subprocess
import sys
import urllib.request

RPC = os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"
BLOCK = os.environ.get("BLOCK")

V1_JAY = "0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E"
V1_STK = "0x112E9FdAd728aDFBb1CE407a9CFa9339E1C6E130"
V1_SPL = "0x4826B4DE107623e0A42e85C2649CaeF736cBCaE9"
V1_PAIR = "0xEb7b5294c79b0369315Ed7fE76b52d3108B0A62D"
V2_JAYD = "0xca9f9671765F8D1A7e19ae2639E01FFF730f0D9B"
V2_STK = "0xF70C2657C4135C2cE81977C32F7bC1E012A7226d"
V2_SPL = "0x0b4E01AB9938E554f4d02B579C3474B3B673A08F"
V2_PAIR = "0x893Be9aca9bE32a9bCE005D034E4C1facd4709Ac"
USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
TEAM_SPL_V1 = "0x985b6b9064212091b4b325f68746b77262801bcb"
TEAM_SPL_V2 = "0xEDe8e7D9659ae7FA69DE57DAF1F75D6729628320"


def cast(*args, timeout=90):
    cmd = ["cast", *args, "--rpc-url", RPC]
    if BLOCK:
        # block pin only applies to state calls, not to cast block-number
        pass
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        return None
    return r.stdout.strip()


def c(addr, sig, *args, block=None):
    a = ["call", addr, sig, *[str(x) for x in args]]
    if block is not None:
        a += ["--block", str(block)]
    out = cast(*a)
    return out.split()[0] if out else None


def bal(addr, block=None):
    a = ["balance", addr]
    if block is not None:
        a += ["--block", str(block)]
    out = cast(*a)
    return out.split()[0] if out else None


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "ci-out/live-state.json"
    blk = int(cast("block-number") or "0")
    b = blk

    data = {
        "block": b,
        "rpc_hosted_public": RPC.split("/")[2],
        "v1": {
            "jay_eth_reserve_wei": bal(V1_JAY, b),
            "jay_total_supply": c(V1_JAY, "totalSupply()(uint256)", block=b),
            "jay_start": c(V1_JAY, "start()(bool)", block=b),
            "jay_sell_fee": c(V1_JAY, "SELL_FEE()(uint16)", block=b),
            "jay_buy_fee": c(V1_JAY, "BUY_FEE()(uint16)", block=b),
            "jay_owner": c(V1_JAY, "owner()(address)", block=b),
            "staking_eth_wei": bal(V1_STK, b),
            "staking_total_staked": c(V1_STK, "getTotalStaked()(uint256)", block=b),
            "staking_prev_reward_total": c(V1_STK, "previusRewardTotal()(uint256)", block=b),
            "staking_rpt": c(V1_STK, "rewardPerTokenStored()(uint256)", block=b),
            "staking_start": c(V1_STK, "start()(bool)", block=b),
            "staking_lp_token": c(V1_STK, "liquidityToken()(address)", block=b),
            "staking_lp_balance": c(V1_PAIR, "balanceOf(address)(uint256)", V1_STK, block=b),
            "splitter_eth_wei": bal(V1_SPL, b),
            "pair_total_supply": c(V1_PAIR, "totalSupply()(uint256)", block=b),
            "pair_reserves": c(V1_PAIR, "getReserves()(uint112,uint112,uint32)", block=b),
            "pair_token0": c(V1_PAIR, "token0()(address)", block=b),
            "pair_token1": c(V1_PAIR, "token1()(address)", block=b),
        },
        "v2": {
            "jusdc_usdc_reserve": c(USDC, "balanceOf(address)(uint256)", V2_JAYD, block=b),
            "jusdc_total_supply": c(V2_JAYD, "totalSupply()(uint256)", block=b),
            "jusdc_start": c(V2_JAYD, "start()(bool)", block=b),
            "jusdc_jaynft": c(V2_JAYD, "JAYNFT()(address)", block=b),
            "jusdc_owner": c(V2_JAYD, "owner()(address)", block=b),
            "staking_usdc_balance": c(USDC, "balanceOf(address)(uint256)", V2_STK, block=b),
            "staking_total_staked": c(V2_STK, "getTotalStaked()(uint256)", block=b),
            "staking_prev_reward_total": c(V2_STK, "previusRewardTotal()(uint256)", block=b),
            "staking_rpt": c(V2_STK, "rewardPerTokenStored()(uint256)", block=b),
            "staking_reward_token": c(V2_STK, "rewardToken()(address)", block=b),
            "staking_start": c(V2_STK, "start()(bool)", block=b),
            "staking_lp_balance": c(V2_PAIR, "balanceOf(address)(uint256)", V2_STK, block=b),
            "splitter_usdc_balance": c(USDC, "balanceOf(address)(uint256)", V2_SPL, block=b),
            "splitter_team_wallet": c(V2_SPL, "TEAM_WALLET()(address)", block=b),
            "splitter_lp_wallet": c(V2_SPL, "LP_WALLET()(address)", block=b),
            "splitter_nft_wallet": c(V2_SPL, "NFT_WALLET()(address)", block=b),
            "splitter_jay_wallet": c(V2_SPL, "JAY_WALLET()(address)", block=b),
            "pair_total_supply": c(V2_PAIR, "totalSupply()(uint256)", block=b),
            "pair_reserves": c(V2_PAIR, "getReserves()(uint112,uint112,uint32)", block=b),
        },
        "team_fee_sinks": {
            "thesplitoooor_v1_eth_wei": bal(TEAM_SPL_V1, b),
            "thesplitoooor_v2_usdc": c(USDC, "balanceOf(address)(uint256)", TEAM_SPL_V2, block=b),
        },
    }

    # keyless prices (DefiLlama)
    try:
        url = (
            "https://coins.llama.fi/prices/current/"
            "ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,"
            "ethereum:0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E,"
            "ethereum:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        )
        with urllib.request.urlopen(url, timeout=45) as r:
            data["prices"] = json.load(r).get("coins", {})
    except Exception as e:
        data["prices"] = {"error": str(e)}

    if data["v1"]["jay_eth_reserve_wei"] is None or data["v2"]["jusdc_usdc_reserve"] is None:
        print("ERROR: eth_call reads failed (RPC may not support eth_call / archive)")
        sys.exit(1)

    with open(out_path, "w") as f:
        json.dump(data, f, indent=1)
    print(f"wrote {out_path} at block {b}")


if __name__ == "__main__":
    main()
