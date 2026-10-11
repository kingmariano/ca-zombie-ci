#!/usr/bin/env python3
"""Curate targets.json for the CI custody enumeration.
Merges adapter-extracted addresses with DefiLlama chain data.
Each protocol gets: candidate chains (to probe), addresses with role hints,
factory/comptroller flags, and llama reference numbers."""
import json, os, re
from collections import defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))
CA = os.path.dirname(os.path.dirname(BASE))

# DefiLlama chain name -> our chain id
CHAIN_MAP = {
    "Ethereum": "ethereum", "Binance": "bsc", "Polygon": "polygon", "Arbitrum": "arbitrum",
    "Optimism": "optimism", "Base": "base", "Avalanche": "avalanche", "Fantom": "fantom",
    "Sei": "sei", "Mantle": "mantle", "XDC": "xdc", "OKExChain": "okc", "Kava": "kava",
    "Moonriver": "moonriver", "Aurora": "aurora", "Astar": "astar", "Polygon zkEVM": "polygon-zkevm",
    "Metis": "metis", "Monad": "monad", "Hyperliquid L1": "hyperliquid", "Cronos": "cronos",
    "Gnosis": "gnosis", "Celo": "celo", "Mode": "mode", "Blast": "blast", "zkSync Era": "zksync",
    "Linea": "linea", "Scroll": "scroll", "Boba": "boba", "Moonbeam": "moonbeam",
    "Klaytn": "klaytn", "CORE": "core", "Fuse": "fuse", "Telos": "telos", "Heco": "heco",
    "Harmony": "harmony", "Evmos": "evmos", "DogeChain": "dogechain", "Canto": "canto",
    "ApeChain": "apechain", "X Layer": "xlayer", "Degen": "degen", "Bittorrent": "bittorrent",
}
OUT_OF_SCOPE = {"Solana", "Persistence", "Alephium", "Bitcoin", "Oasis", "Filecoin", "Sui", "Starknet", "ICP"}

def main():
    mine = json.load(open(os.path.join(CA, "ci/L2-SPLIT-A.json")))
    raw = json.load(open(os.path.join(BASE, "targets-raw.json")))
    detail = {}
    for r in mine:
        s = r["slug"].strip("`")
        fp = os.path.join(BASE, "llama-detail", s + ".json")
        detail[s] = json.load(open(fp)) if os.path.exists(fp) else {}

    out = []
    for r in mine:
        s = r["slug"].strip("`")
        d = detail.get(s) or {}
        # chains + last tvl + last tokens from llama
        llama_chains = {}
        for ch, v in (d.get("chainTvls") or {}).items():
            base_ch = ch.split("-")[0]
            if base_ch in OUT_OF_SCOPE: continue
            if ch.endswith("-borrowed") or ch.endswith("-staking") or ch.endswith("-pool2") or ch == "staking" or ch == "pool2" or ch == "borrowed":
                # keep only as sub-info
                pass
            tv = v.get("tvl") or []
            if not tv: continue
            last = tv[-1]
            toks = v.get("tokens") or []
            lasttok = toks[-1]["tokens"] if toks else {}
            key = ch
            llama_chains[key] = {"chain": CHAIN_MAP.get(base_ch), "tvl": last.get("totalLiquidityUSD"), "tokens": lasttok}

        # candidate chains to probe
        probe = set()
        for ch in llama_chains.values():
            if ch["chain"]: probe.add(ch["chain"])
        items = (raw.get(s) or {}).get("items", [])
        addrs = {}
        for it in items:
            a = it["addr"]
            if it["chain"] and it["chain"] != "?":
                probe.add(it["chain"])
            role = it["role"]
            is_tok = it["is_known_token"]
            addrs.setdefault(a, {"addr": a, "roles": set(), "chain_guess": it["chain"], "known_token": is_tok})
            addrs[a]["roles"].add(role)
        # classify factory/comptroller from roles
        for a, v in addrs.items():
            v["roles"] = sorted(v["roles"])
        out.append({
            "protocol": r["protocol"], "slug": s,
            "llama_chains": llama_chains,
            "probe_chains": sorted(probe),
            "addresses": list(addrs.values()),
        })
    json.dump(out, open(os.path.join(BASE, "targets.json"), "w"), indent=1)
    naddr = sum(len(o["addresses"]) for o in out)
    print("protocols:", len(out), "addresses:", naddr)
    for o in out:
        print(f"{o['slug']:28} chains={','.join(o['probe_chains'])[:60]:60} addrs={len(o['addresses'])}")

if __name__ == "__main__":
    main()
