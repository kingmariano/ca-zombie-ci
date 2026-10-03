#!/usr/bin/env python3
"""H-10 mySwap V1 — full live-state verification (READ-ONLY, no transactions).

Measures:
  A. Sunset state (historical calls at block 1,397,398): 8 pools, reserves, shares, admin, impl.
  B. Current state: class hashes, legacy-contract balances (all pool tokens + CL tokens + STRK),
     LP token supplies/owners/balances, CL singleton balances, Merkle distributor.
  C. Upgrade tx verification (sender, block, timestamp).
Writes JSON to the path given as argv[1] (default ../ci-out/live_state.json).

Stdlib-only via starknet_nodep (pure-python keccak + urllib).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from starknet_nodep import rpc, call, call_sel, sel, norm, block_number, u256, hexint  # noqa

CORE = "0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28"
ADMIN_EXPECTED = "0x1dec3416dc353a5b9fa9030016837df7226f2a8767b786fecd3566e8b57d3c8"
IMPL_EXPECTED = "0x55ef1b2cb1313b8202f68ef32aaefca4133b21cbce68c4bfee453e595ce646f"
LEGACY_CLASS_EXPECTED = "0x40b83509bc9cebd1af068b7d32e8b04cda394db1aedacb512f321d8a825e683"
UPGRADE_TX = "0x5fb287a8f9099c2c258819ccb6e2baf97414308ff6ddbc8dafe98091603a418"
SUNSET_BLOCK = 1397398
CL_SINGLETON = "0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111"
MERKLE_DISTRIBUTOR = "0x005763f02381e89c6894ffea078d1cf9e58da0ead33d5b52aa608acc04063053"

TOKENS = {
    "ETH":  "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "DAI":  "0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "wstETH": "0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "LORDS": "0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "LUSD": "0x070a76fd48ca0ef910631754d77dd822147fe98a569b826ec85e3c33fde586ac",
    "RETH": "0x0319111a5037cbec2b3e638cc34a3474e2d2608299f3e62866e9cc683208c610",
}

LP_TOKENS = {
    1: "0x22b05f9396d2c48183f6deaf138a57522bcc8b35b67dee919f76403d1783136",
    2: "0x7c662b10f409d7a0a69c8da79b397fd91187ca5f6230ed30effef2dceddc5b3",
    3: "0x25b392609604c75d62dde3d6ae98e124a31b49123b8366d7ce0066ccb94f696",
    4: "0x41f9a1e9a4d924273f5a5c0c138d52d66d2e6a8bee17412c6b0f48fe059ae04",
    5: "0x1ea237607b7d9d2e9997aa373795929807552503683e35d8739f4dc46652de1",
    6: "0x611e8f4f3badf1737b9e8f0ca77dd2f6b46a1d33ce4eed951c6b18ac497d505",
    7: "0x14e644c20bd5f9888033d2093c8ba3334caa0c7d15ed142962a9bebf36cc7e0",
    8: "0x2699b69786cb08b4c83c1c02e943eca3eba00234d80a564ebe00c40226ea70b",
}


def short_string(felt_hex):
    b = int(felt_hex, 16).to_bytes(32, "big").lstrip(b"\x00")
    try:
        return b.decode("ascii")
    except Exception:
        return "0x" + felt_hex


def balance_of(token, account, block="latest"):
    r = call(token, "balanceOf", [account], block=block)
    return u256(r)


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "ci-out", "live_state.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out = {"core": CORE, "chain": "starknet", "read_only": True}

    out["latest_block"] = block_number()
    print("latest block:", out["latest_block"])

    # ---------- C. upgrade tx ----------
    try:
        tx = rpc("starknet_getTransactionByHash", [UPGRADE_TX])
        blk = rpc("starknet_getBlockWithTxHashes", [{"block_number": 1397399}])
        out["upgrade_tx"] = {
            "hash": UPGRADE_TX,
            "sender": tx.get("sender_address"),
            "calldata_len": len(tx.get("calldata", [])),
            "nonce": tx.get("nonce"),
            "version": tx.get("version"),
            "block_number": blk.get("block_number"),
            "timestamp": blk.get("timestamp"),
            "tx_ok": UPGRADE_TX in blk.get("transactions", []),
        }
        print("upgrade tx sender:", out["upgrade_tx"]["sender"], "block ts:", blk.get("timestamp"))
    except Exception as e:
        out["upgrade_tx_error"] = str(e)

    # ---------- A. sunset state ----------
    hist = {"block": SUNSET_BLOCK}
    hist["class_hash"] = rpc("starknet_getClassHashAt",
                             {"block_id": {"block_number": SUNSET_BLOCK}, "contract_address": norm(CORE)})
    try:
        hist["admin"] = call_sel(CORE, sel("getAdmin"), [], block={"block_number": SUNSET_BLOCK})
    except Exception as e:
        hist["admin_error"] = str(e)
    try:
        hist["impl"] = call_sel(CORE, sel("getImplementationHash"), [], block={"block_number": SUNSET_BLOCK})
    except Exception as e:
        hist["impl_error"] = str(e)
    n = call(CORE, "get_total_number_of_pools", block={"block_number": SUNSET_BLOCK})
    hist["pool_count"] = int(n[0], 16)
    pools = []
    for i in range(1, hist["pool_count"] + 1):
        p = call(CORE, "get_pool", [i], block={"block_number": SUNSET_BLOCK})
        ts = call(CORE, "get_total_shares", [i], block={"block_number": SUNSET_BLOCK})
        pools.append({
            "id": i,
            "name": short_string(p[0]),
            "token_a": norm(p[1]),
            "reserves_a": str(u256(p, 2)),
            "token_b": norm(p[4]),
            "reserves_b": str(u256(p, 5)),
            "fee_percentage": int(p[7], 16),
            "cfmm_type": int(p[8], 16),
            "lp_token": norm(p[9]),
            "total_shares": str(u256(ts)),
        })
    hist["pools"] = pools
    out["sunset_state"] = hist
    print(f"sunset: {hist['pool_count']} pools, class {hist['class_hash'][:18]}..., admin {hist.get('admin')}, impl {hist.get('impl')}")

    # ---------- B. current state ----------
    cur = {}
    cur["core_class_hash"] = rpc("starknet_getClassHashAt",
                                 {"block_id": "latest", "contract_address": norm(CORE)})
    cur["core_class_hash_ok"] = cur["core_class_hash"] == LEGACY_CLASS_EXPECTED

    cur["balances"] = {}
    for name, t in TOKENS.items():
        try:
            cur["balances"][name] = str(balance_of(t, CORE))
        except Exception as e:
            cur["balances"][name] = f"ERR {e}"
    print("legacy balances:", cur["balances"])

    # LP tokens
    lps = {}
    for pid, lp in LP_TOKENS.items():
        e = {}
        try:
            e["class_hash"] = rpc("starknet_getClassHashAt", {"block_id": "latest", "contract_address": norm(lp)})
            e["total_supply"] = str(u256(call(lp, "totalSupply")))
            e["owner"] = call(lp, "owner")[0]
            e["balance_of_core"] = str(u256(call(lp, "balanceOf", [CORE])))
            e["decimals"] = int(call(lp, "decimals")[0], 16)
            e["name"] = short_string(call(lp, "name")[0])
        except Exception as ex:
            e["error"] = str(ex)
        lps[str(pid)] = e
    cur["lp_tokens"] = lps
    print("LP tokens done")

    # CL singleton residual
    cl = {}
    for name, t in TOKENS.items():
        try:
            cl[name] = str(balance_of(t, CL_SINGLETON))
        except Exception as e:
            cl[name] = f"ERR {e}"
    cur["cl_singleton_balances"] = cl
    cur["cl_singleton_class_hash"] = rpc("starknet_getClassHashAt",
                                         {"block_id": "latest", "contract_address": norm(CL_SINGLETON)})
    print("CL balances:", cl)

    # Merkle distributor
    md = {}
    try:
        md["class_hash"] = rpc("starknet_getClassHashAt",
                               {"block_id": "latest", "contract_address": norm(MERKLE_DISTRIBUTOR)})
        cls = rpc("starknet_getClassAt", {"block_id": "latest", "contract_address": norm(MERKLE_DISTRIBUTOR)})
        abi = cls.get("abi")
        md["abi"] = json.loads(abi) if isinstance(abi, str) else abi
        md["balances"] = {name: str(balance_of(t, MERKLE_DISTRIBUTOR)) for name, t in TOKENS.items()}
    except Exception as e:
        md["error"] = str(e)
    cur["merkle_distributor"] = md
    print("merkle distributor:", {k: v for k, v in md.items() if k != "abi"})

    out["current_state"] = cur

    # assert_admin gate via starknet_call (caller = zero address)
    try:
        call(CORE, "assert_admin")
        out["assert_admin_from_zero"] = "RETURNED (no gate!)"
    except Exception as e:
        out["assert_admin_from_zero"] = str(e)[:400]
    print("assert_admin:", out["assert_admin_from_zero"][:150])

    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
