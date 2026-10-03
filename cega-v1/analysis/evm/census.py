"""Deployment census for Cega V1 on Ethereum + Arbitrum. READ-ONLY."""
import json
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, "/home/heisenberg/CA/cega-v1/analysis/evm")
import lib

KNOWN = {
    1: {
        "CegaState": "0x0730AA138062D8Cc54510aa939b533ba7c30f26B",
        "CegaViewer": "0x31C73c07Dbd8d026684950b17dD6131eA9BAf2C4",
        "FCN:supercharger": "0x042021d59731d3fFA908c7c4211177137Ba362Ea",
        "FCN:go-fast": "0x56F00A399151EC74cf7bE8DC38225363E84975E6",
        "FCN:insanic": "0x784e3C592A6231D92046bd73508B3aAe3A7cc815",
        "FCN:puppy": "0x2aAE28E495626F587677ca779838266DB9bD6Cd1",
        "FCN:l2": "0x98b872604F36807169c096241ECD4646021de133",
        "FCN:starboard": "0xAB8631417271Dbb928169F060880e289877Ff158",
        "FCN:autopilot": "0xcf81b51AecF6d88dF12Ed492b7b7f95bBc24B8Af",
        "FCN:cruise-control": "0x80ec1c0da9bfBB8229A1332D40615C5bA2AbbEA8",
        "FCN:genesis-basket": "0x94C5D3C2fE4EF2477E562EEE7CCCF07Ee273B108",
    },
    42161: {
        "CegaState": "0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed",
        "CegaViewer": "0x8c32a5d9f29da36ed68a9d454eda1b374795b6ca",
        "LOV:puppy-lov": "0x6A9201Db9222cFb5164cfb8F192903270f8a6e93",
    },
}

TOPICS = {
    "RoleGranted": "0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d",
    "RoleRevoked": "0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b",
    "ProductAdded": "0x4cc39cf92556f56ba17184d656cf1bbcfd5f8e8d7b1071d0e295017b9f70f41b",
    "ProductRemoved": "0x1c40e49688e963884d475feda3ddb42c17aec5d2a82706904ba014ee7ce54a2a",
    "OracleAdded": "0x78cdb79fba1f42e6ca936bf7bd4be337a4a1734c57e4b9f68a1a465b4ac0d9b0",
    "OracleRemoved": "0xa28dc34059cd4716d51da651406dc8ff96399e3cf46725143a7f2855c68cf394",
    "MarketMakerPermissionUpdated": "0x57f98562c9f8bc4df2d505ef267a5a4a7782ada9b5e4660e2fe833510a33ecf1",
    "FeeRecipientUpdated": "0x7a7b5a0a132f9e0581eb8527f66eae9ee89c2a3e79d4ac7e41a1f1f4d48a7fc2",
    "FCNProductViewerUpdated": "0x10c7e41ec011086108a066b761fbe64a25de33c8aa43c41cc8ee40fbce355633",
    "VaultCreated2": "0x07f1052e1739f73da4d084bbe1c0487e548ac630147b598dbd9ab59bb157068a",
    "VaultCreated1": "0xd81bf987801128d3151aa0a1f9be2b84b0b24601e400c58717bdf988158dcf62",
    "VaultRemoved": "0xe71f3a50e5ad81964f352c411f1d45e35438ecd1acecef59ac81d9fbbf6cbc0a",
    "AssetsSentToTrade": "0x670c6d2cbe2ae11af0c85d75a02c9bab189955b99625cd49da5666e7a28fc5c3",
    "AssetsMovedToProduct": "0xf08bd4877b5a59894b35ac969f29efa3be8fd5d609ed28e01ad234fea3034e5a",
    "LOVProductCreated": "0xa3da5171f0184ad75dfcff7e31f261915436f695fe67a7e23fd108bcc1b2ebcf",
}


def drop_bc(c):
    c = dict(c)
    c.pop("creationBytecode", None)
    return c


def main():
    out = {"generated_at": lib.time.strftime("%Y-%m-%dT%H:%M:%SZ", lib.time.gmtime()), "chains": {}}
    for chainid in (1, 42161):
        print(f"=== chain {chainid} ===")
        ch = {"chainid": chainid, "known": KNOWN[chainid], "creations": {}, "creators": {}}
        addrs = list(KNOWN[chainid].values())
        creates = lib.es_getcreation(chainid, addrs)
        by_addr = {c["contractAddress"].lower(): c for c in creates}
        for name, a in KNOWN[chainid].items():
            c = by_addr.get(a.lower())
            if c:
                ch["creations"][a] = {
                    "label": name,
                    "creator": c["contractCreator"],
                    "txHash": c["txHash"],
                    "blockNumber": int(c["blockNumber"]),
                    "timestamp": int(c["timestamp"]),
                    "contractFactory": c.get("contractFactory", ""),
                }
            else:
                ch["creations"][a] = {"label": name, "error": "no creation found"}
        print(json.dumps(ch["creations"], indent=1)[:2000])

        # creators -> all contract creations in their txlist
        creators = sorted({c["creator"].lower() for c in ch["creations"].values() if "creator" in c})
        ch["creators"] = {}
        for cr in creators:
            txs = lib.es_txlist(chainid, cr)
            created = []
            for t in txs:
                if t.get("to", "") == "" and t.get("contractAddress") and t.get("isError") == "0":
                    created.append(
                        {
                            "address": t["contractAddress"],
                            "txHash": t["hash"],
                            "blockNumber": int(t["blockNumber"]),
                            "timestamp": int(t["timeStamp"]),
                            "input_selector": t.get("functionName", ""),
                        }
                    )
            ch["creators"][cr] = {
                "txcount": len(txs),
                "eth_balance_wei": lib.rpc(chainid, "eth_getBalance", [cr, "latest"]),
                "code_size": len(lib.rpc(chainid, "eth_getCode", [cr, "latest"])) // 2 - 1,
                "contracts_created": created,
            }
            print(f"creator {cr}: {len(txs)} txs, {len(created)} contract creations")
        out["chains"][str(chainid)] = ch
        lib.save_json("/home/heisenberg/CA/cega-v1/analysis/evm/census_raw.json", out)

    lib.save_json("/home/heisenberg/CA/cega-v1/analysis/evm/census_raw.json", out)


if __name__ == "__main__":
    main()
