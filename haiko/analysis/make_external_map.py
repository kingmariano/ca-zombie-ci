#!/usr/bin/env python3
"""Generate analysis/external_map.json: contracts, roles, markets, call targets, gates."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from starknet_rpc import rpc, call, selector_from_name, block_number  # noqa

STRATEGY = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
SOLVER = "0x073cc79b07a02fe5dcd714903d62f9f3081e15aeb34e3725f44e495ecd88a5a1"
QUOTER = "0x5860f2d7c1efc21e27fdeb1716a806c7604770603d1c5f161e473231eb261dc"
DIST = "0x5eb02e164f78fd91b9be6a0b9b3aa02c936db485bd760730f65711533c70a26"
OWNER = "0x43777a54d5e36179709060698118f1f6f5553ca1918d1004b07640dfc425000"
ORACLE = "0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b"
ORACLE_SUMMARY = "0x54563a0537b3ae0ba91032d674a6d468f30a59dc4deb8f0dce4e642b94be15c"

out = {"block": block_number(), "contracts": {}, "strategy_markets": {}, "external_call_targets": {}}

for name, addr in [("ReplicatingStrategy", STRATEGY), ("MarketManager", MM), ("ReplicatingSolver", SOLVER),
                   ("Quoter", QUOTER), ("Distributor", DIST), ("Owner_multisig", OWNER)]:
    ch = rpc("starknet_getClassHashAt", {"block_id": "latest", "contract_address": addr})
    nonce = rpc("starknet_getNonce", {"block_id": "latest", "contract_address": addr})
    out["contracts"][name] = {"address": addr, "class_hash": ch.get("result"), "nonce": nonce.get("result")}

# strategy markets + owners + params
MARKETS = {
    "M1_ETH_USDC": "0x6812a18046f6b1d926ce6d081ceee71cb0ec7fbdb38167cc07d618ee8f5713e",
    "M2_wstETH_ETH": "0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2",
    "M3_USDC_USDT": "0xeb87f342e5267cb250240851fdeaa111ce548934e529c41137fea49ccebdf",
    "M4_STRK_USDC": "0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b",
    "M5_STRK_ETH": "0x3ddeeae1e54ed0b70d57e067fa696ef333e69cc6dbe8b4469ad0e9900546b54",
    "M6_ETH_WBTC": "0x16707e0f13b27d91c357a8294b28ff023e30acbf1456e5391f61fa22cdb0d76",
}
for name, mid in MARKETS.items():
    e = {}
    e["market_info"] = call(MM, selector_from_name("market_info"), [mid]).get("result")
    e["strategy_owner"] = call(STRATEGY, selector_from_name("strategy_owner"), [mid]).get("result")
    e["is_paused"] = call(STRATEGY, selector_from_name("is_paused"), [mid]).get("result")
    e["strategy_params"] = call(STRATEGY, selector_from_name("strategy_params"), [mid]).get("result")
    out["strategy_markets"][name] = e

out["external_call_targets"] = {
    "MarketManager": MM,
    "Pragma_oracle": ORACLE,
    "Pragma_oracle_summary": ORACLE_SUMMARY,
    "tokens": {
        "ETH": "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
        "STRK": "0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
        "USDC": "0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
        "USDT": "0x68f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
        "wstETH": "0x42b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
        "WBTC": "0x3fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    },
    "note": "strategy calls only these; admin gated by Owner_multisig / per-market strategy_owner",
}

json.dump(out, open(os.path.join(HERE, "external_map.json"), "w"), indent=1)
print("saved external_map.json at block", out["block"])
print(json.dumps(out["contracts"], indent=1)[:800])
