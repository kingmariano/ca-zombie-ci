#!/usr/bin/env python3
"""Build the C-33 Compound-v2 fork target universe.

Sources:
  - analysis/compound_registry.json : parsed from DefiLlama DefiLlama-Adapters
      registries/compound.js (all Compound-style forks DefiLlama tracks, 249 comptrollers).
  - manual additions: corpus-named forks that are absent from the registry
      (Scream, Benqi, Ionic, Sturdy v2, Lodestar v1) or were verified in
      zombie_hunt/verification_live_funds.md.
Corrections carried in the metadata: Geist/Valas/Voltage/Starlay/Ironclad are Aave
forks, NOT Compound v2 -- excluded from the EVM cToken scan (documented only).
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
REG = json.load(open(os.path.join(HERE, "compound_registry.json")))

# DefiLlama registry chain-key -> canonical scan chain id
ALIAS = {
    "ethereum": "ethereum", "bsc": "bsc", "arbitrum": "arbitrum", "polygon": "polygon",
    "base": "base", "optimism": "optimism", "fantom": "fantom", "cronos": "cronos",
    "moonriver": "moonriver", "sonic": "sonic", "avax": "avax", "moonbeam": "moonbeam",
    "aurora": "aurora", "era": "zksync", "linea": "linea", "scroll": "scroll",
    "mantle": "mantle", "mode": "mode", "metis": "metis", "kava": "kava", "flare": "flare",
    "fuse": "fuse", "rsk": "rsk", "taiko": "taiko", "blast": "blast", "core": "core",
    "sei": "sei", "klaytn": "klaytn", "harmony": "harmony", "telos": "telos",
    "iotex": "iotex", "iotaevm": "iotex", "evmos": "evmos", "oasis": "oasis",
    "conflux": "conflux", "xdai": "gnosis", "polygon_zkevm": "polygon_zkevm",
    "op_bnb": "opbnb", "manta": "manta", "bob": "bob", "bsquared": "bsquared",
    "hemi": "hemi", "zklink": "zklink", "unichain": "unichain", "berachain": "berachain",
    "ink": "ink", "morph": "morph", "soneium": "soneium", "boba": "boba", "wemix": "wemix",
    "canto": "canto", "shimmer_evm": "shimmer", "meter": "meter", "kcc": "kcc",
    "zilliqa": "zilliqa", "jbc": "jbc", "btr": "bitlayer", "lac": "lac",
    "wc": "worldchain", "zircuit": "zircuit", "bittorrent": "bittorrent",
    "ethereumclassic": "etc", "ronin": "ronin", "findora": "findora", "qiev3": "qie",
    "goat": "goat", "rei": "rei", "elastos": "elastos", "neon_evm": "neon",
    "nibiru": "nibiru", "okexchain": "okc", "apechain": "apechain", "sty": "sty",
    "xdc": "xdc", "kroma": "kroma", "astrzk": "astar_zkevm", "robinhood": "robinhood",
    "plasma": "plasma", "monad": "monad", "megaeth": "megaeth", "merlin": "merlin",
}

MANUAL = [
    # (protocol, chain, comptroller, tag)
    ("scream",        "fantom",   "0x260e596dabe3afc463e75b6cc05d8c46acacfb09", "corpus:verification_live_funds #3"),
    ("benqi-lending", "avax",     "0x486af39519b4dc9a7fccd318217352830e8ad9b4", "defillama adapter benqi"),
    ("benqi-lending", "avax",     "0xd7c4006d33da2a0a8525791ed212bbcd7aca763f", "defillama adapter benqi"),
    ("ionic-protocol","mode",     "0xfb3323e24743caf4add0fdccfb268565c0685556", "corpus:verification_live_funds #17 (Mode-A)"),
    ("ionic-protocol","mode",     "0x8fb3d4a94d0aa5d6edaac3ed82b59a27f56d923a", "corpus (Mode-B)"),
    ("ionic-protocol","base",     "0x05c9c6417f246600f8f5f49fca9ee991bff73d13", "corpus (Base)"),
    ("ionic-protocol","optimism", "0xafb4a254d125b0395610fdc8f1d022936c7b166b", "corpus (OP)"),
    ("ionic-protocol","lisk",     "0xf448a36fefb223b8e46e36ff12091baba97bdf60", "corpus (Lisk)"),
    ("sturdy-v2",     "ethereum", "0x69764e3e0671747a7768a1c1afb7c0c39868cc9e", "defillama adapter sturdy-v2"),
    ("sturdy-v2",     "mode",     "0xf0382a9eca5276d7b4bbcc503e4159c046c120ec", "defillama adapter sturdy-v2"),
    ("sturdy-v2",     "linea",    "0xd67da8636ae87b0cecbda2e66db58d4839722b52", "defillama adapter sturdy-v2"),
    ("sturdy-v2",     "optimism", "0x9dc7b2130e478c5810dc0cdbd46b9d479b2e1ac4", "defillama adapter sturdy-v2"),
    ("sturdy-v2",     "sei",      "0x4534f53a81416a83f6baf5ac63c94aed1fea1303", "defillama adapter sturdy-v2"),
    ("lodestar-v1",   "arbitrum", "0x92a62f8c4750d7fbdf9ee1db268d18169235117b", "defillama adapter lodestar"),
]

targets = []
seen = set()
for proto, chains in REG.items():
    for raw_chain, comptrollers in chains.items():
        chain = ALIAS.get(raw_chain, raw_chain)
        for c in comptrollers:
            key = (chain, c.lower())
            if key in seen:
                continue
            seen.add(key)
            targets.append(dict(protocol=proto, chain=chain, comptroller=c,
                                tag=f"llama-registry:{raw_chain}"))
for proto, chain, c, tag in MANUAL:
    key = (chain, c.lower())
    if key in seen:
        continue
    seen.add(key)
    targets.append(dict(protocol=proto, chain=chain, comptroller=c, tag=tag))

# corpus names known to be Aave forks / out of class -> documented, not scanned
EXCLUDED = {
    "starlay-finance": "Aave v2 fork (starlay-protocol repo uses LendingPoolAddressesProvider)",
    "geist-finance": "Aave fork (per docs + academic analysis)",
    "valas-finance": "Aave v2 fork (valas-protocol repo)",
    "voltage-lending": "Aave fork (docs.voltage.finance: 'fork of Aave Protocol')",
    "ironclad-finance": "Aave fork, provider bricked (corpus)",
    "resupply": "custom LendingOps share market; June-2025 empty-market donation hack already realized (document-only)",
    "zkLend": "Starknet, non-EVM (document-only)",
}

os.makedirs(HERE, exist_ok=True)
json.dump(dict(targets=targets, excluded=EXCLUDED), open(os.path.join(HERE, "targets.json"), "w"), indent=1)
print("targets:", len(targets))
from collections import Counter
print(Counter(t["chain"] for t in targets).most_common())
print("protocols:", len(set(t["protocol"] for t in targets)))
