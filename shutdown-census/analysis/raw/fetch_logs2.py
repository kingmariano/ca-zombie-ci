#!/usr/bin/env python3
"""Fetch all Summer.fi automation bot logs via Blockscout v1 getLogs with block-range paging."""
import json, sys, time, urllib.request, urllib.parse

UA = {"User-Agent": "Mozilla/5.0 (research; read-only)"}

def get(url, retries=8):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            wait = 3 * (i + 1)
            print(f"    retry {i} {str(e)[:70]} sleep {wait}", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError("fetch failed")

def fetch_range(base, address, topic0, from_block, tag):
    out = {}
    fb = from_block
    while True:
        q = {"module": "logs", "action": "getLogs", "address": address, "topic0": topic0,
             "fromBlock": str(fb), "toBlock": "latest", "offset": "1000"}
        url = base + "/api?" + urllib.parse.urlencode(q)
        d = get(url)
        res = d.get("result")
        if not isinstance(res, list) or len(res) == 0:
            if res is None:
                print(f"  {tag}: status={d.get('status')} msg={d.get('message')}", file=sys.stderr)
            break
        added = 0
        maxb = fb
        for ev in res:
            key = ev["transactionHash"] + ":" + ev["logIndex"]
            b = int(ev["blockNumber"], 16)
            if b > maxb:
                maxb = b
            if key not in out:
                out[key] = ev
                added += 1
        print(f"  {tag}: got {len(res)} (new {added}, total {len(out)}) up to block {maxb}", file=sys.stderr)
        if len(res) < 1000:
            break
        fb = maxb  # overlap one block to be safe; dedupe handles it
        time.sleep(2.0)
    return list(out.values())

JOBS = [
    ("eth_v2_added", "https://eth.blockscout.com", "0x5743b5606e94fb534a31e1cefb3242c8a9422e5e",
     "0x1b5e88d5103127ddf4ea702813b5961c204a11865735302ab58bc7708198037e", 22534690),
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

if __name__ == "__main__":
    which = sys.argv[1:] if len(sys.argv) > 1 else None
    for tag, base, addr, topic, fromb in JOBS:
        if which and tag not in which:
            continue
        print("FETCH", tag, file=sys.stderr)
        try:
            evs = fetch_range(base, addr, topic, fromb, tag)
            json.dump(evs, open(f"summerfi_{tag}_full.json", "w"))
            print(f"DONE {tag}: {len(evs)}")
        except Exception as e:
            print(f"FAIL {tag}: {e}")
