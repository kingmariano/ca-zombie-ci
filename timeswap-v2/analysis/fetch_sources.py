#!/usr/bin/env python3
"""Fetch exact-match verified sources from Sourcify for key Timeswap V2 deployments.
Read-only. Saves to analysis/sources/<name>/<path>."""
import json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "sources")

TARGETS = [
    ("arbitrum", 42161, "pool_v25", "0xcEa329e91e6B0eEC69CeBC6f42f64975d80c6DB0"),
    ("arbitrum", 42161, "optionpair_v25", "0x30138774ebfbd3df2c659200b7399dbe9f3476ff"),
    ("arbitrum", 42161, "poolfactory_v25", "0x97509c65Ff29C268F0D283A41201Be6b4090354c"),
    ("arbitrum", 42161, "tokenforliquidity", "0x136397158Ce3ee0e4e530372ec1f3181708e3DBB"),
    ("arbitrum", 42161, "periphery_close_lend_forliq", "0xFA68412383995c58b9A3484a6A878d789f4d0485"),
    ("arbitrum", 42161, "periphery_lend_nodex", "0xf253Ecea8aAFeAd83E2e76B8db75F0dcb9BA90F0"),
    ("arbitrum", 42161, "periphery_withdraw_nodex", "0xecEbd8FB1d3E0a4aCaA6DeCf5db90B99f0587451"),
    ("arbitrum", 42161, "periphery_collect_nodex", "0x1Ae701557E9a8cF003deFd07C717d2aB2099c8E0"),
    ("arbitrum", 42161, "periphery_collect_protocol_fees_owner", "0x70fEA7B1f981557d2B45cBDD9699D3687DDc73D9"),
    ("arbitrum", 42161, "liquiditytoken_v25", "0xF2A0624Dc666A097d338b7b0eF8Fe49c81020E09"),
]

def fetch(chainid, addr):
    url = f"https://sourcify.dev/server/v2/contract/{chainid}/{addr}?fields=all"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def main():
    for chain, cid, name, addr in TARGETS:
        try:
            d = fetch(cid, addr)
        except Exception as e:
            print(f"[{name}] fetch fail: {e}")
            continue
        if not d.get("match"):
            print(f"[{name}] no match: {d.get('matchId')}")
            continue
        ct = (d.get("metadata") or {}).get("settings", {}).get("compilationTarget") or {}
        dpath = os.path.join(OUT, name)
        os.makedirs(dpath, exist_ok=True)
        srcs = d.get("sources") or {}
        for k, v in srcs.items():
            content = v.get("content") if isinstance(v, dict) else None
            if content is None:
                continue
            fp = os.path.join(dpath, k.replace("/", "__"))
            with open(fp, "w") as f:
                f.write(content)
        meta = {"address": addr, "chainId": cid, "matchId": d.get("matchId"),
                "runtimeMatch": d.get("runtimeMatch"), "verifiedAt": d.get("verifiedAt"),
                "compilationTarget": ct, "numSources": len(srcs)}
        with open(os.path.join(dpath, "_meta.json"), "w") as f:
            json.dump(meta, f, indent=1)
        print(f"[{name}] OK {addr} target={ct} sources={len(srcs)}")

if __name__ == "__main__":
    main()
