#!/usr/bin/env python3
"""Scan the full Mycelium contract family for live balances (public RPC)."""
import json, sys
sys.path.insert(0, '.')
from rpc import rpc_batch, rpc

ARB = "https://arb1.arbitrum.io/rpc"
BLK = rpc(ARB, "eth_blockNumber", [])
print("block", int(BLK, 16))

FAMILY = {
    "Vault": "0xDfbA8AD57d2c62F61F0a60B2C508bCdeb182f855",
    "Router": "0x3cd2F02B9e39ccC781d0C07fc0286F654e53A76D",
    "MlpManager": "0x2DE28AB4827112Cd3F89E5353Ca5A8D80dB7018f",
    "MLP": "0x752b746426b6D0c3188bb530660374f92FD9cf7c",
    "USDG": "0xe61a61B9Ce1Bd12e17a53AeeeE1005Ef6C1b2E80",
    "VaultPriceFeed": "0xDffe2f49234001380119d89E9C965BEd4bf123f0",
    "FastPriceFeed": "0x2cA1DF570CcA0421cd4fd4798417a2B36C73e845",
    "FastPriceFeed2": "0x57ff9294b05065b88cb3ec148beedfb50eda3127",
    "VaultUtils": "0x875B5f3908E37367533b7D6c92535F9AB579B072",
    "Timelock": "0x25D390B53b06Ae32DAB3BDCb1C0D4fa44D2907D7",
    "MycTimelock": "0x971ec4ad4695e95faeb830b22d89f394540e5e91",
    "TokenManager": "0x8DA386B8e9E3C27411ec5972C5D91399ad0b9D02",
    "RewardManager": "0x7aB8083F6eAAC244A5248D5a23F348f60e3CD57e",
    "RewardRouterV2": "0xd98d8e458F7aD22DD3C1d7A8B35C74005eb52b0b",
    "OrderBook": "0x2eeef7852a306a580acf94f7c18c3ff124a59d4f",
    "PositionManager": "0x3892b8cf646b17709c91e653319ba5504a5feafe",
    "PositionRouter": "0xbB214233C570b8e9b732212974E7baeFFE63F0de",
    "PositionRouter2": "0xe510571cac76279dadf6c4b6eace5370f86e3dc2",
    "ReferralStorage": "0x3cd316df040f8a76eb2b496b92b358d3b2efb9f5",
    "StakedMlp": "0x9f4bc1ef5319af843e587a3bfdb3b228009f035f",
    "esMYC": "0x7CEC785fba5ee648B48FBffc378d74C8671BB3cb",
    "bnMYC": "0xb97f91bd8f7fb6ac761Fb84cB953e4F52f049486",
    "MYC": "0xC74fE4c715510Ec2F8C61d70D397B32043F55Abe",
    "mycVester": "0x67fF0614F6E4E04362B3b919Adc7371884895Ae8",
    "mlpVester": "0xCB6ac1EacF498118f4609462c0979fFB3eBD1821",
    "stakedMycTracker": "0x2BC8E28f5d41a4b112BC62EB7Db1B757c85f37Ff",
    "bonusMycTracker": "0xbF86a15fa2604dbA2ad7E843c589FAAAd78bF318",
    "feeMycTracker": "0x0cA0147c21F9DB9D4627e6a996342A11D25972C5",
    "stakedMlpTracker": "0xF7Bd2ed13BEf9C27a2188f541Dc5ED85C5325306",
    "feeMlpTracker": "0xF0BFB95087E611897096982c33B6934C8aBfA083",
    "tracker2023": "0xF9B003Ee160dA9677115Ad3c5bd6BB6dADcB2F93",
    "dist_stakedMyc": "0x3169b5719b8a7b40580965e8557379fe15209aad",
    "dist_bonusMyc": "0x68200f38ec38215219b63ccc428eb14a1d4481f3",
    "dist_feeMyc": "0xb91f4bc04f680f9ccfc11b8dec76b7dd4382ce3c",
    "dist_stakedMlp": "0xb000f7df69d74a1f3b3cdb8ddeb3317a0823af2b",
    "dist_feeMlp": "0x0f5976e0380e9b743a90271acbd031b4cc4d9de8",
    "dist_2023": "0xd5c7bba9073a8d3e21cf69f5a1fa01b870ac72c0",
    "dist_extra": "0xdb8cc5be809ebe47d2a96da599647209162c51e4",
    "LentMycWithMigration": "0x3b9acfcaaa405b672ef3a0efce4cf179f3742150",
    "MerkleTokenSale": "0xbc61d76cbd784bb3ede8c855f37deb465c5b43a9",
    "StakingRewards1": "0x5fd3fa0204ae9fd974f19430d8ea6bbbc7deb3d6",
    "StakingRewards2": "0x10260cf26c68df40017d5e488dc633f1642f2a38",
    "StakingRewards3": "0xa9234de71cb19b3217457fc2a3df14bca4837fa8",
    "StakingRewards4": "0xe01b6ba1e64ace0298f2e55152c7153b015b3d1c",
    "StakingRewards5": "0x574375868f76f49a9eeeb6a5720b984298c216be",
    "StakingRewards6": "0x2f09d08167ad714d48de65fa8c75fe19388f87c9",
    "StakingRewards7": "0xb22e2234d1fd6f9cd5800039710668eb602300d4",
    "StakingRewards8": "0x681e1b823292743f0a3dc1ce1e572c16225a1c23",
    "StakingRewards9": "0x9c2e161d00abf3e7fdfd50197b778c681117c45d",
    "unk_c4e6": "0xc4e695a2ae9fd060e24cdb87874b684db7447a18",
    "unk_b220": "0xb220724b6b68a84392ec22e841ede5519863a21f",
    "unk_eeb8": "0xeeb8d1b7f31be725417f88ed3115169eaa1213f7",
    "unk_1044": "0x1044345924277fd2e9bdf14edad8c1d1a67a4b8e",
    "unk_f122": "0xf1226775099a2f240c93fc3f4a0feb3295394d0f",
}

TOKENS = {
    "WETH": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    "MYC": "0xC74fE4c715510Ec2F8C61d70D397B32043F55Abe",
    "esMYC": "0x7CEC785fba5ee648B48FBffc378d74C8671BB3cb",
    "bnMYC": "0xb97f91bd8f7fb6ac761Fb84cB953e4F52f049486",
    "MLP": "0x752b746426b6D0c3188bb530660374f92FD9cf7c",
    "USDG": "0xe61a61B9Ce1Bd12e17a53AeeeE1005Ef6C1b2E80",
    "USDC": "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    "USDT": "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
    "DAI": "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
    "WBTC": "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f",
    "LINK": "0xf97f4df75117a78c1A5a0DBb814Af92458539FB4",
    "UNI": "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0",
    "FRAX": "0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F",
    "CRV": "0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978",
    "BAL": "0x040d1EdC9569d4Bab2D15287Dc5A4F10F56a56B8",
    "FXS": "0x9d2F299715D94d8A7E6F5eaa8E654E8c74a988A7",
    "MIM": "0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A",
}

def sel(sig):
    import subprocess
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

BAL = sel("balanceOf(address)(uint256)")

calls = []
meta = []
for name, addr in FAMILY.items():
    for tn, tok in TOKENS.items():
        calls.append((tok, BAL + addr.lower().replace("0x", "").rjust(64, "0")))
        meta.append((name, tn))

res = rpc_batch(ARB, calls, BLK)
out = {}
for (name, tn), r in zip(meta, res):
    if isinstance(r, str) and r.startswith("0x"):
        try:
            v = int(r, 16)
        except Exception:
            v = -1
        if v != 0:
            out.setdefault(name, {})[tn] = v

# ETH balances
eth = {}
import urllib.request
for name, addr in FAMILY.items():
    try:
        v = int(rpc(ARB, "eth_getBalance", [addr, BLK]), 16)
        if v:
            eth[name] = v
    except Exception as e:
        eth[name] = str(e)

print(json.dumps({"block": int(BLK, 16), "token_balances": out, "eth_balances": eth}, indent=1))
json.dump({"block": int(BLK, 16), "token_balances": out, "eth_balances": eth},
          open("family-balances.json", "w"), indent=1)
