#!/usr/bin/env python3
"""C2-51 Troves/STRKFarm retired-vault live state reader (read-only, keyless RPC).

Outputs JSON to stdout / file. Never touches keys or sends transactions.
"""
import json
import sys

from rpc import block_number, call, felt, rpc, selector

VAULTS = {
    "AutoCompounding_STRK": "0x00541681b9ad63dff1b35f79c78d8477f64857de29a27902f7298f7b620838ea",
    "AutoCompounding_USDC": "0x016912b22d5696e95ffde888ede4bd69fbbc60c5f873082857a47c543172694f",
    "Sensei_STRK": "0x020d5fc4c9df4f943ebb36078e703369c04176ed00accf290e8295b659d2cea6",
    "Sensei_USDC": "0x04937b58e05a3a2477402d1f74e66686f58a61a5070fcc6f694fb9a0b3bae422",
    "Sensei_ETH": "0x9d23d9b1fa0db8c9d75a1df924c3820e594fc4ab1475695889286f3f6df250",
    "Sensei_ETH_XL": "0x9140757f8fb5748379be582be39d6daf704cc3a0408882c0d57981a885eed9",
    "Master": "0x050314707690c31597849ed66a494fb4279dc060f8805f21593f52906846e28e",
}

TOKENS = {
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "USDC_bridged": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDC_circle": "0x033068f6539f8e6e6b131e6b2b814e6c34a5224bc66947c47dab9dfee93b35fb",
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "zSTRK": "0x06d8fa671ef84f791b7f601fa79fea8f6ceb70b5fa84189e3159d532162efc21",
    "zUSDC": "0x047ad51726d891f972e74e4ad858a261b43869f7126ce7436ee0b2529a98f486",
    "zETH": "0x1b5bd713e72fdc5d63ffd83762f81297f6175a5e0a4771cdadbc1dd5fe72cb1",
    "zETH_XL": "0x057146f6409deb4c9fa12866915dd952aa07c1eb2752e451d7f3b042086bdeb8",
}

SEL = {
    "balanceOf": selector("balanceOf"),
    "total_supply": selector("total_supply"),
    "total_assets": selector("total_assets"),
    "convert_to_assets": selector("convert_to_assets"),
    "preview_redeem": selector("preview_redeem"),
    "asset": selector("asset"),
    "get_asset": selector("get_asset"),
    "get_vault_status": selector("get_vault_status"),
    "owner": selector("owner"),
    "get_owner": selector("get_owner"),
    "decimals": selector("decimals"),
    "name": selector("name"),
    "symbol": selector("symbol"),
}


def u256(result):
    """Decode a u256 return: [low, high] or single felt."""
    if not result:
        return None
    vals = [int(x, 16) for x in result]
    if len(vals) == 1:
        return vals[0]
    return vals[0] + (vals[1] << 128)


def try_call(target, entry, calldata=(), block="latest"):
    try:
        return call(target, SEL[entry] if entry in SEL else selector(entry), calldata, block)
    except Exception as e:  # noqa: BLE001
        return {"__error__": str(e)[:200]}


def main():
    out = {"block": block_number(), "vaults": {}, "tokens": {}}

    # token metadata
    for tname, taddr in TOKENS.items():
        meta = {}
        meta["symbol"] = try_call(taddr, "symbol")
        meta["decimals"] = try_call(taddr, "decimals")
        meta["total_supply"] = try_call(taddr, "total_supply")
        out["tokens"][tname] = {"address": felt(taddr), **meta}

    for vname, vaddr in VAULTS.items():
        v = {"address": felt(vaddr)}
        try:
            v["class_hash"] = rpc("starknet_getClassHashAt", ["latest", felt(vaddr)])
        except Exception as e:  # noqa: BLE001
            v["class_hash_error"] = str(e)[:200]
        # vault's own ERC20-ish views
        v["vault_total_supply"] = try_call(vaddr, "total_supply")
        v["vault_total_assets"] = try_call(vaddr, "total_assets")
        v["vault_asset"] = try_call(vaddr, "asset")
        v["vault_get_asset"] = try_call(vaddr, "get_asset")
        v["vault_owner"] = try_call(vaddr, "owner")
        v["vault_get_owner"] = try_call(vaddr, "get_owner")
        v["vault_get_vault_status"] = try_call(vaddr, "get_vault_status")
        # token balances held by the vault
        v["balances"] = {}
        for tname, taddr in TOKENS.items():
            r = try_call(taddr, "balanceOf", [felt(vaddr)])
            if isinstance(r, list) and len(r) == 2:
                v["balances"][tname] = u256(r)
            else:
                v["balances"][tname] = r
        # preview_redeem of 1 share where supply known
        ts = v["vault_total_supply"]
        if isinstance(ts, list) and len(ts) == 2 and u256(ts) and u256(ts) > 0:
            shares = u256(ts)
            v["preview_redeem_all"] = try_call(
                vaddr, "preview_redeem", [hex(shares & ((1 << 128) - 1)), hex(shares >> 128)]
            )
            v["convert_to_assets_all"] = try_call(
                vaddr, "convert_to_assets", [hex(shares & ((1 << 128) - 1)), hex(shares >> 128)]
            )
        out["vaults"][vname] = v

    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
