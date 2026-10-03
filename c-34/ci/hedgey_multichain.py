#!/usr/bin/env python3
"""CI job: read live Hedgey ClaimCampaigns token balances on ETH/ARB/OP/Base/BSC directly
(balanceOf), for every token observed with a non-zero balance during the local analysis.
Output: ci-out/hedgey_multichain.json
Env: RPC_URL, ARB_RPC_URL, OP_RPC_URL, BASE_RPC_URL, BSC_RPC_URL.
"""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
CC = "0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511"
UA = {"User-Agent": "zombie-hunt/read-only", "Content-Type": "application/json"}

CHAINS = {
    "ethereum": {
        "rpc": os.environ.get("FORK_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com",
        "tokens": {"0xcecfbfbed09bb3f06211a841d939223e093368a2": ("BIGCAT", 18),
                   "0x58b580c1d86c04a97d981e66fa64a73342864bdc": ("HDSF", 18)}},
    "arbitrum": {
        "rpc": os.environ.get("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc"),
        "tokens": {"0x69b678c8e02a23cc8f3b33cef339424245841439": ("TACO", 18),
                   "0x999999990237e901c537bbd768e09562be02efa5": ("Unishop.ai", 18)}},
    "optimism": {
        "rpc": os.environ.get("OP_RPC_URL", "https://mainnet.optimism.io"),
        "tokens": {"0x425a01aed423f5b9f967f20cb9df623087fab7c9": ("SEAL", 18)}},
    "base": {
        "rpc": os.environ.get("BASE_RPC_URL", "https://mainnet.base.org"),
        "tokens": {"0x4229c271c19ca5f319fb67b4bc8a40761a6d6299": ("NEGED", 18),
                   "0x094198c92dc32f39684c4db645b007cf72ca2b45": ("AICATS", 18),
                   "0x89cd883fb050f4b8f5f2b97fcb7854586d0d166c": ("WLR", 18),
                   "0xf919997223a5ae9353207769eb0b03cc4f6c2843": ("Bfarm", 18),
                   "0xd49bd9397ebcc75333993ba42b8a004df8b405f6": ("WOLF", 18),
                   "0x91f45aa2bde7393e0af1cc674ffe75d746b93567": ("FRAME", 18),
                   "0x6206b837c3183260ae2de9df6993ad69b94720c5": ("BWEN", 18),
                   "0x9535b2ac357a8e23e933946aa8c1995660af5f93": ("PARA", 18),
                   "0xa24ec2966b2d782831467702f278f4cd18740c1d": ("SIMS", 18),
                   "0x7c6b66617fd106ac2fa1ab0eb0bdcc57b6c0865a": ("MONCAST", 18),
                   "0x8395f203d8f26ae5f7ffe24b2e6408e2aaa74646": ("AVIA", 18),
                   "0xb56d0839998fd79efcd15c27cf966250aa58d6d3": ("USA", 18),
                   "0x13339fba0a49a0c0d9d664c3ae07db4b5f98693d": ("WARI", 18),
                   "0x41a5189f62e71c75824e6f7ff033e29b44cfe2d3": ("OOMER", 18),
                   "0xb783ca3da835120b5a96cf6bad0cae7c5ffd845e": ("GOYBASE", 18),
                   "0xc590b4e4ec5d1a5421ced44907777df1d830ffed": ("GTF", 18)}},
    "bsc": {
        "rpc": os.environ.get("BSC_RPC_URL", "https://bsc-dataseed.binance.org"),
        "tokens": {"0x55d398326f99059ff775485246999027b3197955": ("USDT", 18),
                   "0x1587c8dbf2e05ef3c13ae70da1253036f6d8a5ad": ("DEGEN 2.0", 18),
                   "0xa5438df34698df262d5ed463f10387c998edc24a": ("BFK", 18)}},
}

def call(rpc, to, data):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": to, "data": data}, "latest"]}).encode()
    req = urllib.request.Request(rpc, data=body, headers=UA)
    for i in range(5):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.load(r)
            if "result" in d:
                return int(d["result"], 16)
        except Exception:
            time.sleep(1 + i)
    return None

def main():
    res = {}
    for chain, cfg in CHAINS.items():
        res[chain] = {}
        for token, (sym, dec) in cfg["tokens"].items():
            data = "0x70a08231" + "0" * 24 + CC[2:].lower()
            bal = call(cfg["rpc"], token, data)
            res[chain][sym] = {"token": token, "raw": str(bal) if bal is not None else None,
                               "balance": (bal / 10 ** dec) if bal is not None else None}
            time.sleep(0.15)
        print(chain, {k: v["balance"] for k, v in res[chain].items()}, flush=True)
    json.dump({"claim_campaigns": CC, "balances": res},
              open(os.path.join(OUT, "hedgey_multichain.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
