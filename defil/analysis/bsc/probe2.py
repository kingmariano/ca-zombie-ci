#!/usr/bin/env python3
"""Probe #2: mining chain + superiors on BSC. Public RPC only."""
import subprocess, sys, json

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://bsc-mainnet.public.blastapi.io"
BLOCK = sys.argv[2] if len(sys.argv) > 2 else "latest"

def call(addr, sig, *args):
    cmd = ["cast", "call", "--rpc-url", RPC, "--block", str(BLOCK), addr, sig, *args]
    for attempt in range(3):
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        out = r.stdout.strip()
        if out:
            return out
        err = (r.stderr or "").strip().split("\n")[0]
        if "429" in err or "timeout" in err.lower() or "502" in err or "500" in err:
            import time; time.sleep(1 + attempt); continue
        return ("REVERT: " + err[:150]) if err else None
    return "RATELIMIT"

def sim(addr, sig, *args, frm="0x000000000000000000000000000000000000dEaD"):
    cmd = ["cast", "call", "--rpc-url", RPC, "--block", str(BLOCK), "--from", frm, addr, sig, *args]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    out = r.stdout.strip()
    err = (r.stderr or "").strip().split("\n")[0]
    return out or ("REVERT: " + err[:200])

NFT = "0xB02F118013150C7F2D4F2030E15F198E1CaA60eb"
NFTM = "0x3e3945c7e5cb7a6286b48A016d9D52B5826c3F4e"
PC = "0xb94E91ea1cf2AB3c44f48123d9e81CA5CDF6fa82"
POSTER = "0x81dA506420364b3d960229dFc8B9315acEF22dC5"

out = {}

out["MiningNFT"] = {
    "owner": call(NFT, "owner()(address)"),
    "poster": call(NFT, "poster()(address)"),
    "getCurrentTokenId": call(NFT, "getCurrentTokenId()(uint256)"),
    "getInitialTokenId": call(NFT, "getInitialTokenId()(uint256)"),
    "uri_100001": call(NFT, "uri(uint256)(string)", "100001"),
    "balanceOf_poster_100001": call(NFT, "balanceOf(address,uint256)(uint256)", POSTER, "100001"),
    "balanceOf_dead_100001": call(NFT, "balanceOf(address,uint256)(uint256)", "0x000000000000000000000000000000000000dEaD", "100001"),
}
out["MiningNFT_sims"] = {
    "mint_from_DEAD": sim(NFT, "mint(address,uint256)(uint256)", "0x000000000000000000000000000000000000dEaD", "1"),
}

out["MiningNFTManage"] = {
    "owner": call(NFTM, "owner()(address)"),
    "minerManage": call(NFTM, "minerManage()(address)"),
    "miningNFT": call(NFTM, "miningNFT()(address)"),
    "filChainStatOracle": call(NFTM, "filChainStatOracle()(address)"),
    "miningNFTMintingLimitation": call(NFTM, "miningNFTMintingLimitation()(address)"),
    "totalMintedInTiB": call(NFTM, "totalMintedInTiB()(uint256)"),
    "totalSectorInitialPledge": call(NFTM, "totalSectorInitialPledge()(uint256)"),
    "getAvgInitialPledge": call(NFTM, "getAvgInitialPledge()(uint256)"),
    "getMinerIdByTokenId_100001": call(NFTM, "getMinerIdByTokenId(uint256)(string)", "100001"),
    "getMinerIdByTokenId_101000": call(NFTM, "getMinerIdByTokenId(uint256)(string)", "101000"),
    "getLastMintedTokenId_f0218293": call(NFTM, "getLastMintedTokenId(string)(uint256)", "f0218293"),
}
out["MiningNFTManage_sims"] = {
    "mint_from_DEAD": sim(NFTM, "mint(uint256)", "1"),
}

mm = out["MiningNFTManage"]["minerManage"]
if isinstance(mm, str) and mm.startswith("0x"):
    out["MinerManage"] = {
        "address": mm,
        "owner()": call(mm, "owner()(address)"),
        "getMinerId_S_LP1": call(mm, "getMinerId(address)(string)", "0xde6239b3138910c68f318e799b3d332925e9929f"),
        "getMinerId_DEAD": call(mm, "getMinerId(address)(string)", "0x000000000000000000000000000000000000dEaD"),
        "whiteList_DEAD": call(mm, "whiteList(address)(bool)", "0x000000000000000000000000000000000000dEaD"),
    }
    try:
        l = call(mm, "getMinerList()(string[])")
        out["MinerManage"]["getMinerList"] = l[:2000] if l else l
    except Exception as e:
        out["MinerManage"]["getMinerList"] = f"ERR {e}"

lim = out["MiningNFTManage"]["miningNFTMintingLimitation"]
if isinstance(lim, str) and lim.startswith("0x"):
    out["MintingLimitation"] = {
        "address": lim,
        "owner()": call(lim, "owner()(address)"),
        "poster()": call(lim, "poster()(address)"),
        "mintAmountLimitationRatio": call(lim, "mintAmountLimitationRatio()(uint256)"),
        "getTotalLimitationCap": call(lim, "getTotalLimitationCap()(uint256)"),
        "getMinerLimitationCap_f0218293": call(lim, "getMinerLimitationCap(string)(uint256)", "f0218293"),
        "limitationData": call(lim, "limitationData()(address)"),
    }

out["PriceConverter"] = {
    "owner": call(PC, "owner()(address)"),
    "filstUsdtPair": call(PC, "filstUsdtPair()(address)"),
    "dflUsdtPair": call(PC, "dflUsdtPair()(address)"),
    "initialFilstPrice": call(PC, "initialFilstPrice()(uint256)"),
    "getFilstPrice": call(PC, "getFilstPrice()(uint256)"),
    "getDflPrice": call(PC, "getDflPrice()(uint256)"),
    "convert_1FILST_to_DFL": call(PC, "convertFromFilstToDFLAmount(uint256)(uint256)", str(10**18)),
    "convert_0.05FILST_to_DFL": call(PC, "convertFromFilstToDFLAmount(uint256)(uint256)", str(5 * 10**16)),
}

SUP1 = "0xFA6bF5bE237570Cf326CeEeC2b467A38b4FCCAa0"
SUP2 = "0x2426da4e8FCEA0e39aDa3EA671767a236AD39e09"
SUP3 = "0xe0F23BeE9c884Bf28eBC75Ee59FD12377E59A327"
out["SUP1"] = {
    "superior": call(SUP1, "superior()(address)"),
    "allMembers": call(SUP1, "allMembers()(address[],uint256[])"),
    "memberState_S_LP1": call(SUP1, "memberState(address)(uint256,uint256,uint256)", "0xde6239b3138910c68f318e799b3d332925e9929f"),
    "memberState_S_LP2": call(SUP1, "memberState(address)(uint256,uint256,uint256)", "0x6b9ee349810e660dda9e3557c7a7412e5424ea39"),
    "memberState_S_P2": call(SUP1, "memberState(address)(uint256,uint256,uint256)", "0x6b6811a710f07b8ac430f6e172833e87c4bd8716"),
    "accruedStored_LP1": call(SUP1, "accruedStored(address)(uint256)", "0xde6239b3138910c68f318e799b3d332925e9929f"),
}
out["SUP2"] = {
    "filstAddress": call(SUP2, "filstAddress()(address)"),
    "efilAddress": call(SUP2, "efilAddress()(address)"),
    "admin": call(SUP2, "admin()(address)"),
    "implementation": call(SUP2, "implementation()(address)"),
}
out["SUP3"] = {
    "superior": call(SUP3, "superior()(address)"),
    "allMembers": call(SUP3, "allMembers()(address[],uint256[])"),
    "memberState_S_DFL": call(SUP3, "memberState(address)(uint256,uint256,uint256)", "0x272257bb03a2b99978a1e6badeba7ccba444d285"),
}
out["SUP_sims"] = {
    "SUP1_accrue_from_DEAD": sim(SUP1, "accrue()(uint256)"),
    "SUP3_accrue_from_DEAD": sim(SUP3, "accrue()(uint256)"),
    "S_LP1_accrue_from_DEAD": sim("0xde6239b3138910c68f318e799b3d332925e9929f", "accrue()(uint256)"),
    "S_LP1_claimAll_from_DEAD": sim("0xde6239b3138910c68f318e799b3d332925e9929f", "claimAll()"),
    "S_FILST_claimAll_from_DEAD": sim("0x6c753ca90bad578504314699580c8b01e067a765", "claimAll()"),
    "S_DFL_claimAll_from_DEAD": sim("0x272257bb03a2b99978a1e6badeba7ccba444d285", "claimAll()"),
    "S_P2_claimAll_from_DEAD": sim("0x6b6811a710f07b8ac430f6e172833e87c4bd8716", "claimAll()"),
    "S_LP2_claimAll_from_DEAD": sim("0x6b9ee349810e660dda9e3557c7a7412e5424ea39", "claimAll()"),
}

print(json.dumps(out, indent=1))
