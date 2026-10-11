#!/usr/bin/env python3
"""Extract candidate custody addresses + chain attribution from DefiLlama adapters.
Filters out known token addresses (coreAssets.json). Output: analysis/targets-raw.json"""
import json, os, re, sys
from collections import defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))
ADDR_RE = re.compile(r"0x[a-fA-F0-9]{40}")

# chain keys as they appear in adapters
CHAIN_KEYS = ["ethereum","eth","bsc","binance","polygon","arbitrum","optimism","base","avax","avalanche",
    "fantom","sei","mantle","xdc","okexchain","okc","kava","moonriver","aurora","astar","polygon_zkevm",
    "polygon-zkevm","zkevm","celo","cronos","gnosis","mode","blast","era","zksync","linea","scroll","monad",
    "hyperliquid","solana","tron","boba","metis","klaytn","core","manta","op_bnb","opbnb","iotex","velas",
    "telos","thundercore","songshan","rsk","ontology","fusion","elastos","cube","conflux","syscoin","milkomeda",
    "kcc","kucoin","heco","harmony","eos","evmos","energi","dogechain","dfk","degen","canto","bittorrent",
    "bitgert","aurora","arbitrum_nova","apechain","abey","algorand","acala","moonbeam","moonbase","godwoken"]

def chain_normalize(c):
    c = c.lower()
    m = {"eth":"ethereum","binance":"bsc","avax":"avalanche","okexchain":"okc","era":"zksync",
         "polygon_zkevm":"polygon-zkevm","arbitrum_nova":"arbitrum-nova"}
    return m.get(c, c)

def load_known_tokens():
    ca = json.load(open(os.path.join(BASE, "coreAssets.json")))
    known = set()
    for ch, toks in ca.items():
        if isinstance(toks, dict):
            for sym, val in toks.items():
                if isinstance(val, str) and ADDR_RE.fullmatch(val):
                    known.add(val.lower())
    return known

def extract(adapter_text):
    """returns list of (address, chain_guess, role_hint)"""
    # find chain key positions: patterns like "  bsc: {" or "chain: 'bsc'" or "'ethereum':"
    positions = []
    for m in re.finditer(r"[{,]\s*[\"']?([a-zA-Z0-9_\-]+)[\"']?\s*:", adapter_text):
        key = m.group(1)
        if key.lower() in CHAIN_KEYS:
            positions.append((m.start(), chain_normalize(key)))
    positions.sort()
    out = []
    for m in ADDR_RE.finditer(adapter_text):
        addr = m.group(0)
        pos = m.start()
        # nearest preceding chain key within 1500 chars
        chain = None
        for p, c in positions:
            if p < pos and pos - p < 1500:
                chain = c
            elif p >= pos:
                break
        # role hint: look backwards up to 120 chars for keyword
        ctx = adapter_text[max(0, pos-160):pos]
        role = "unknown"
        for kw in ["owner", "holders", "bridges", "stakingContract", "staking", "pool2", "factory",
                   "comptroller", "vault", "bank", "pool", "escrow", "router", "rewards", "farm",
                   "controller", "manager", "proxy", "token", "underlying", "collateral", "cToken"]:
            if re.search(r"\b" + kw + r"\b", ctx, re.I):
                role = kw
        out.append((addr.lower(), chain, role))
    return out

def main():
    mine = json.load(open("/home/heisenberg/CA/ci/L2-SPLIT-A.json"))
    known = load_known_tokens()
    res = {}
    for r in mine:
        s = r["slug"].strip("`")
        fp = os.path.join(BASE, "adapters", s + ".js")
        if not os.path.exists(fp):
            res[s] = {"error": "no adapter"}; continue
        txt = open(fp).read()
        addrs = extract(txt)
        # dedupe by (addr, chain)
        seen = set(); items = []
        for a, c, role in addrs:
            k = (a, c)
            if k in seen: continue
            seen.add(k)
            items.append({"addr": a, "chain": c, "role": role, "is_known_token": a in known})
        res[s] = {"n_raw": len(addrs), "items": items}
    json.dump(res, open(os.path.join(BASE, "targets-raw.json"), "w"), indent=1)
    # summary
    for s, v in res.items():
        if "items" in v:
            cust = [i for i in v["items"] if not i["is_known_token"]]
            print(f"{s:28} raw={v['n_raw']:3} custody_candidates={len(cust):3}")
        else:
            print(s, v.get("error"))

if __name__ == "__main__":
    main()
