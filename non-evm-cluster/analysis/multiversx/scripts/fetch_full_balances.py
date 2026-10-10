#!/usr/bin/env python3
"""Exhaustively page /tokens and /nfts for a set of addresses; aggregate totals by token/collection.
Handles >100 nonces (MetaESDT truncation). Saves raw/full_balances.json.
"""
import json, os, time, urllib.request
from collections import defaultdict

BASE = "https://api.multiversx.com"
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")

def get(path, retries=4, timeout=60):
    url = BASE + path
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "research-readonly/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if i == retries - 1:
                return {"__error__": str(e), "__path__": path}
            time.sleep(1.5 * (i + 1))

def page_all(path_tmpl, kind):
    all_items = []
    frm = 0
    while True:
        d = get(path_tmpl.format(frm=frm))
        if not isinstance(d, list) or not d:
            if isinstance(d, dict) and "__error__" in d:
                all_items.append(d)
            break
        all_items.extend(d)
        if len(d) < 100:
            break
        frm += 100
        time.sleep(0.12)
    return all_items

TARGETS = [
    ("proxy_dex_v1_legacy", "erd1qqqqqqqqqqqqqpgqrc4pg2xarca9z34njcxeur622qmfjp8w2jps89fxnl"),
    ("metabonding_staking_legacy", "erd1qqqqqqqqqqqqqpgqt7tyyswqvplpcqnhwe20xqrj7q7ap27d2jps7zczse"),
    ("simple_lock_legacy_0", "erd1qqqqqqqqqqqqqpgqs0jjyjmx0cvek4p8yj923q5yreshtpa62jpsz6vt84"),
    ("simple_lock_legacy_1", "erd1qqqqqqqqqqqqqpgqawujux7w60sjhm8xdx3n0ed8v9h7kpqu2jpsecw6ek"),
    ("simple_lock_legacy_2", "erd1qqqqqqqqqqqqqpgq6nu2t8lzakmcfmu4pu5trjdarca587hn2jpsyjapr5"),
    ("price_discovery_0", "erd1qqqqqqqqqqqqqpgq38cmvwwkujae3c0xmc9p9554jjctkv4w2jps83r492"),
    ("price_discovery_1", "erd1qqqqqqqqqqqqqpgq666ta9cwtmjn6dtzv9fhfcmahkjmzhg62jps49k7k8"),
    ("price_discovery_2", "erd1qqqqqqqqqqqqqpgqq93kw6jngqjugfyd7pf555lwurfg2z5e2jpsnhhywk"),
    ("farm_v1.2_0", "erd1qqqqqqqqqqqqqpgqye633y7k0zd7nedfnp3m48h24qygm5jl2jpslxallh"),
    ("farm_v1.2_1", "erd1qqqqqqqqqqqqqpgqsw9pssy8rchjeyfh8jfafvl3ynum0p9k2jps6lwewp"),
    ("farm_v1.2_2", "erd1qqqqqqqqqqqqqpgqv4ks4nzn2cw96mm06lt7s2l3xfrsznmp2jpsszdry5"),
    ("farm_v1.3_locked_0", "erd1qqqqqqqqqqqqqpgqyawg3d9r4l27zue7e9sz7djf7p9aj3sz2jpsm070jf"),
    ("farm_v1.3_locked_2", "erd1qqqqqqqqqqqqqpgq7qhsw8kffad85jtt79t9ym0a4ycvan9a2jps0zkpen"),
    ("farm_v1.3_custom_0", "erd1qqqqqqqqqqqqqpgq5e2m9df5yxxkmr86rusejc979arzayjk2jpsz2q43s"),
    ("farm_v2_deprecated_0", "erd1qqqqqqqqqqqqqpgqapxdp9gjxtg60mjwhle3n6h88zch9e7kkp2s8aqhkg"),
    ("distribution_legacy", "erd1qqqqqqqqqqqqqpgqyg62a3tswuzun2wzp8a83sjkc709wwjt2jpssphddm"),
    ("locked_asset_factory_legacy", "erd1qqqqqqqqqqqqqpgqjpt0qqgsrdhp2xqygpjtfrpwf76f9nvg2jpsg4q7th"),
    ("wegld_swap_shard1", "erd1qqqqqqqqqqqqqpgqhe8t5jewej70zupmh44jurgn29psua5l2jps3ntjj3"),
    ("wegld_swap_shard2", "erd1qqqqqqqqqqqqqpgqmuk0q2saj0mgutxm4teywre6dl8wqf58xamqdrukln"),
    ("community_delegation", "erd1qqqqqqqqqqqqqpgqxwakt2g7u9atsnr03gqcgmhcv38pt7mkd94q6shuwt"),
]

def main():
    out = {}
    for name, addr in TARGETS:
        print(f"== {name} {addr}", flush=True)
        t0 = time.time()
        tokens = page_all(f"/accounts/{addr}/tokens?size=100&from={{frm}}", "tokens")
        nfts = page_all(f"/accounts/{addr}/nfts?size=100&from={{frm}}", "nfts")
        # aggregate fungible tokens
        ftok = defaultdict(lambda: {"balance": 0, "decimals": 18, "usd": None})
        for t in tokens:
            if not isinstance(t, dict) or "identifier" not in t:
                continue
            k = t["identifier"]
            ftok[k]["balance"] += int(t.get("balance", "0"))
            ftok[k]["decimals"] = t.get("decimals", 18)
            if t.get("valueUsd") is not None:
                ftok[k]["usd"] = t.get("valueUsd")
        ncoll = defaultdict(lambda: {"count": 0, "balance": 0})
        for n in nfts:
            if not isinstance(n, dict) or "collection" not in n:
                continue
            k = n["collection"]
            ncoll[k]["count"] += 1
            ncoll[k]["balance"] += int(n.get("balance", "0"))
        out[addr] = {"name": name, "token_pages": len(tokens), "nft_pages": len(nfts),
                     "fungible": {k: v for k, v in ftok.items()},
                     "metaesdt": {k: v for k, v in ncoll.items()}}
        for k, v in ftok.items():
            if v["balance"]:
                print(f"   FT {k:22s} {v['balance']/10**v['decimals']:>22,.6f} usd={v['usd']}")
        for k, v in ncoll.items():
            print(f"   NFT {k:22s} nonces={v['count']:>4} raw={v['balance']}")
        print(f"   ({time.time()-t0:.1f}s)")
    json.dump(out, open(os.path.join(RAW, "full_balances.json"), "w"), indent=1)
    print("wrote raw/full_balances.json")

if __name__ == "__main__":
    main()
