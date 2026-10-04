#!/usr/bin/env python3
"""Page Blockscout v1 getLogs for Summer.fi automation bots. Read-only."""
import json, time, urllib.request, urllib.parse, sys

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

def fetch_all(base, address, topic0, from_block, tag):
    results = []
    page = 1
    while True:
        q = {
            "module": "logs", "action": "getLogs", "address": address,
            "topic0": topic0, "fromBlock": str(from_block), "toBlock": "latest",
            "page": str(page), "offset": "1000",
        }
        url = base + "/api?" + urllib.parse.urlencode(q)
        try:
            d = get(url)
        except Exception as e:
            print(f"  {tag} page {page} ERROR {e}", file=sys.stderr)
            time.sleep(2)
            continue
        res = d.get("result") or []
        if not isinstance(res, list):
            print(f"  {tag} page {page} non-list: {str(res)[:100]}", file=sys.stderr)
            break
        if not res:
            break
        results.extend(res)
        print(f"  {tag} page {page}: {len(res)} (total {len(results)})", file=sys.stderr)
        if len(res) < 1000:
            break
        page += 1
        time.sleep(0.4)
    return results

def main():
    jobs = [
        # tag, base, address, topic0, from_block
        ("eth_v2_added", "https://eth.blockscout.com", "0x5743b5606e94fb534a31e1cefb3242c8a9422e5e",
         "0x1b5e88d5103127ddf4ea702813b5961c204a11865735302ab58bc7708198037e", 17229847),
        ("eth_v2_removed", "https://eth.blockscout.com", "0x5743b5606e94fb534a31e1cefb3242c8a9422e5e",
         "0x89103ac4e3656b0071f9ed259dd79d305afcee547f3105f30587f094300c3bc2", 17229847),
        ("eth_v1_added", "https://eth.blockscout.com", "0x6E87a7A0A03E51A741075fDf4D1FCce39a4Df01b",
         "0xcb616360dd177f28577e33576c8ac7ffcc1008cba7ac2323e0b2f170faf60bd2", 14583413),
        ("eth_v1_removed", "https://eth.blockscout.com", "0x6E87a7A0A03E51A741075fDf4D1FCce39a4Df01b",
         "0xb4a1fc324bd863f8cd42582bebf2ce7f2d309c6a84bf371f28e069f95a4fa9e1", 14583413),
        ("base_v2_added", "https://base.blockscout.com", "0x96D494b4544Bb7c3CB687ef7a9886Ed469e01ed8",
         "0x1b5e88d5103127ddf4ea702813b5961c204a11865735302ab58bc7708198037e", 0),
        ("base_v2_removed", "https://base.blockscout.com", "0x96D494b4544Bb7c3CB687ef7a9886Ed469e01ed8",
         "0x89103ac4e3656b0071f9ed259dd79d305afcee547f3105f30587f094300c3bc2", 0),
        ("arb_v2_added", "https://arbitrum.blockscout.com", "0xE018AeA83728a037D8B6f76cCA0E8331cDAb937a",
         "0x1b5e88d5103127ddf4ea702813b5961c204a11865735302ab58bc7708198037e", 0),
        ("arb_v2_removed", "https://arbitrum.blockscout.com", "0xE018AeA83728a037D8B6f76cCA0E8331cDAb937a",
         "0x89103ac4e3656b0071f9ed259dd79d305afcee547f3105f30587f094300c3bc2", 0),
        ("op_v2_added", "https://optimism.blockscout.com", "0xb2e2a088d9705cd412CE6BF94e765743Ec26b1e4",
         "0x1b5e88d5103127ddf4ea702813b5961c204a11865735302ab58bc7708198037e", 0),
        ("op_v2_removed", "https://optimism.blockscout.com", "0xb2e2a088d9705cd412CE6BF94e765743Ec26b1e4",
         "0x89103ac4e3656b0071f9ed259dd79d305afcee547f3105f30587f094300c3bc2", 0),
    ]
    out = {}
    for tag, base, addr, topic, fromb in jobs:
        print(f"FETCH {tag}", file=sys.stderr)
        out[tag] = fetch_all(base, addr, topic, fromb, tag)
    json.dump(out, open("summerfi_logs_all.json", "w"))
    for k, v in out.items():
        print(k, len(v))

if __name__ == "__main__":
    main()
