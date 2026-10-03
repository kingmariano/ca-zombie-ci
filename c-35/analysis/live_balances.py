#!/usr/bin/env python3
"""c-35 live balance snapshot for legacy stuck-funds contracts.
Read-only JSON-RPC (eth_getBalance / eth_getCode / eth_call). No transactions.
Usage: RPC_URL=... python3 live_balances.py [out.json]
"""
import json, os, sys, urllib.request

RPC = os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"

# name -> address (lowercase). Curated from github_stuck_funds.md §1.1, §1.3, §6 + C-35 names.
TARGETS = {
    # C-35 named
    "HongCoin_HONG": "0x9fa8fa61a10ff892e4ebceb7f4e0fc684c2ce0a9",
    # top live ETH, §1.1
    "IDEX_v1": "0x2a0c0dbecc7e4d658f48e01e3fa353f44050c208",
    "EtherDelta_v2": "0x8d12a197cb00d4747a1fe03395095ce2a5cc6819",
    "zkSyncLite_distributor": "0x0a14b696350546110a0d8acdb86226983af9d2a0",
    "Neufund_EtherToken_v1": "0xb59a226a2b8a2f2b0512baa35cc348b6b213b671",
    "Neufund_LockedAccount_v1": "0xb1e4675f0dbe360ba90447a7e58c62c762ad62d4",
    "Unknown_DEX_0x4d55": "0x4d55f76ce2dbbae7b48661bef9bd144ce0c9091b",
    "LastWinner_0xdd9f": "0xdd9fd6b6f8f7ea932997992bbe67eabb3e316f3c",
    "PoWH3D": "0xb3775fb83f7d12a36e0475abdd1fca35c091efbe",
    "Old_WETH": "0xecf8f87f810ecf450940c9f60066b4a7a501d6a7",
    "Fomo3D_Long": "0xa62142888aba8370742be823c1782d17a0389da1",
    "Ethfinex_WrapperLockEth": "0xaa7427d8f17d87a28f5e1ba3adbb270badbe1011",
    "SingularX": "0x9a2d163ab40f88c625fd475e807bbc3556566f80",
    "Augur_v1": "0xd5524179cb7ae012f5b642c1d6d700bbaa76b96b",
    "Rewards_0x0": "0x02b15c47b4b516a22fd2d8b1fc662afb808a2169",
    "GandhiJi": "0x167cb3f2446f829eb327344b66e271d1a7efec9a",
    "Token_Store": "0x1ce7ae555139c5ef5a57cc8d814a867ee6ee33d8",
    "MCDEX_ETHPERP": "0x220a9f0dd581cbc58fcfb907de0454cbf3777f76",
    # Signal D / shortlist 5,6,12,15 + honourable mentions
    "FoMo3D_Ultra": "0xab83d96de35bad6f234178fbb6507203488e9626",
    "CryptoCats_v0v1": "0x9508008227b6b3391959334604677d60169ef540",
    "Transit_refund": "0xc213f258f4142f53d086f9edb7a36e67eb347f63",
    "Zethr": "0xd48b633045af65ff636f3c6edd744748351e020d",
    "Zethr_Casino": "0xb9ab8eed48852de901c13543042204c6c569b811",
    "Bingo4Beast_dep2": "0x4fb7d68e0116f35ade131b6535b2db1027bf7650",
    "ReadyPlayerONE": "0x6db943251e4126f913e9733821031791e75df713",
    "DailyDivs": "0xd2bfceeab8ffa24cdf94faa2683df63df4bcbdc8",
    "FEG_WrappedETH": "0xf786c34106762ab4eeb45a51b42a62470e9d5332",
    "FoMo3Dshort_v2": "0x0ad3227eb47597b566ec138b3afd78cfea752de5",
    "Fomo3D_Quick": "0x4e8ecf79ade5e2c49b9e30d795517a81e0bf00b8",
    "Fomo3D_Short": "0x52083b1a21a5abc422b1b0bce5c43ca86ef74cd1",
    "FoMoJP": "0xcb47c89cb17c10b719fc5ed9665bae157cac2cb1",
    # extra legacy DEX / claim contracts around the top-15
    "EtherDelta_v0": "0x4aea7cf559f67cedcad07e12ae6bc00f07e8cf65",
    "EtherDelta_v1": "0x373c55c277b866a69dc047cad488154ab9759466",
    "SingularX_Fund": "0x0286f920f893513c7ec9fe35ba0a4760229a243e",
    "Neufund_EtherToken_v2": "0x0b7dc5a43ce121b4eaaa41b0f4f43bba47bb8951",
    "Celer_PaymentChannels": "0xa6cd930fc92f1634d8183af2fb86bd1766f2f82a",
    "Rook_kTokens": "0x35ffd6e268610e764ff6944d07760d0efe5e40e5",
    "Aave_v1_LendingPoolCore": "0x3dfd23a6c5e8bbcfc9581d2e864a68feb6a076d3",
    "DigixDAO_refund": "0x78988d377227c8801905e517c042e61d85601a75",
    "OpenGSN_RelayHub_v1": "0xd216153c06e857cd7f72665e0af1d7d82172f494",
}


RPCS = [RPC, "https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth", "https://rpc.flashbots.net"]


def rpc(method, params):
    last = None
    for url in RPCS:
        for _ in range(2):
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
                )
                with urllib.request.urlopen(req, timeout=25) as r:
                    return json.loads(r.read())["result"]
            except Exception as e:  # noqa
                last = e
    raise RuntimeError(f"rpc failed {method} {params}: {last}")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "balances_latest.json"
    block = int(rpc("eth_blockNumber", []), 16)
    res = {"block": block, "rpc": RPC, "contracts": {}}
    for name, addr in TARGETS.items():
        bal = int(rpc("eth_getBalance", [addr, "latest"]), 16)
        code = rpc("eth_getCode", [addr, "latest"])
        res["contracts"][name] = {"address": addr, "balance_wei": str(bal), "balance_eth": bal / 1e18, "code_size": len(code) // 2 - 1}
    with open(out, "w") as f:
        json.dump(res, f, indent=1)
    print(json.dumps({k: v["balance_eth"] for k, v in res["contracts"].items()}, indent=0))
    print("block", block)


if __name__ == "__main__":
    main()
