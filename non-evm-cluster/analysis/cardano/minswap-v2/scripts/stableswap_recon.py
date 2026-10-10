#!/usr/bin/env python3
"""Extract Minswap stableswap mainnet configs from SDK constants.ts; query Koios for each pool address; save state."""
import re, json, urllib.request, time, sys, os

SDK = "/tmp/opencode/minswap-sdk/src/types/constants.ts"
txt = open(SDK).read()

# isolate StableswapConstant namespace
m = re.search(r'export namespace StableswapConstant \{(.*?)\n\}\n', txt, re.S)
body = m.group(1)
# mainnet section
mi = body.index('[NetworkId.MAINNET]: [')
section = body[mi:]
# cut at the matching "[NetworkId." next occurrence to avoid bleeding
nxt = section.find('[NetworkId.', 5)
if nxt > 0: section = section[:nxt]

pools = []
for blk in re.finditer(r'\{\s*orderAddress:\s*"([^"]+)",\s*poolAddress:\s*"([^"]+)",\s*nftAsset:\s*"([^"]+)",\s*lpAsset:\s*"([^"]+)",\s*assets:\s*\[(.*?)\],\s*multiples:\s*\[([^\]]*)\],\s*fee:\s*(\d+)n,\s*adminFee:\s*(\d+)n,\s*feeDenominator:\s*(\d+)n,?\s*\}', section, re.S):
    order, pool, nft, lp, assets, multiples, fee, adminfee, denom = blk.groups()
    asset_list = re.findall(r'"([0-9a-f]+)"', assets)
    pools.append({
        "orderAddress": order, "poolAddress": pool, "nftAsset": nft, "lpAsset": lp,
        "assets": asset_list, "multiples": [int(x.strip().rstrip('n')) for x in multiples.split(',')],
        "fee": int(fee), "adminFee": int(adminfee), "feeDenominator": int(denom),
        "pair_name": bytes.fromhex(nft[56:]).decode('utf8', 'replace')
    })
print(f"stableswap mainnet pools: {len(pools)}")
json.dump(pools, open("minswap-stableswap-configs.json", "w"), indent=1)
for p in pools: print(" ", p["pair_name"], p["poolAddress"])

def koios(endpoint, body, query="", retries=7, base="https://api.koios.rest/api/v1"):
    url = f"{base}/{endpoint}{query}"; data = json.dumps(body).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=data, method="POST", headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=180) as r: return json.loads(r.read().decode())
        except Exception as e:
            print("retry", i, e, file=sys.stderr); time.sleep(2*(i+1))
    return None

addrs = [p["poolAddress"] for p in pools] + [p["orderAddress"] for p in pools]
res = koios("address_assets", {"_addresses": addrs})
json.dump(res, open("koios_stableswap_assets.json", "w"), indent=1)
res2 = koios("address_info", {"_addresses": [p["poolAddress"] for p in pools]})
json.dump(res2, open("koios_stableswap_info.json", "w"), indent=1)
for a in (res2 or []):
    print("POOL", a["address"], "lovelace", a["balance"], "utxos", len(a.get("utxo_set",[])))
print("done")
