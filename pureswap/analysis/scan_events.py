#!/usr/bin/env python3
"""Scan recent Swap/Mint/Burn/Sync events on selected PureSwap pairs."""
import json, os, urllib.request, time, sys

RPC = os.environ.get("RPC_BSC", "https://bsc-rpc.publicnode.com")

def rpc(method, params, retries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            d = json.loads(urllib.request.urlopen(req, timeout=60).read().decode())
            if "result" in d:
                return d["result"]
            if "error" in d:
                err = d["error"]
                if "limit" in str(err).lower() or "range" in str(err).lower():
                    return {"__range_error__": err}
                print("rpc error:", err, file=sys.stderr)
                return None
        except Exception as e:
            time.sleep(1.2 * (i + 1))
    return None

TOPICS = {
    "Swap": "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822",
    "Mint": "0x4c209b5fc8ad50758f13e2e1088ba56a560dff690a1c6fef26394f4c03821c4f",
    "Burn": "0xdccd412f0b1252819cb1fd330b93224ca42612892bb3f4f789976e6d81936496",
    "Sync": "0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1",
}
PAIRS = [
    "0xca7a9690f0b49c687ab6054fa1f5622d89e874ee",  # WBNB/BUSD
    "0x984648bd05103fde7ec448512da1f3a44f1b0b30",  # MX/WBNB
    "0xefb83ba7589cd602f621463c80a466e884744cd4",  # MX/BUSD
    "0xe69e6a6eda23eecebf5a2856c01344ca7b34685c",  # ETH/WBNB
    "0xdbb13ef5adc8e41f06a0277e0b4c70c6775bc788",  # BTCB/WBNB
    "0xe079424a4fef5c547478a85802b462e4699b0fa9",  # PURE/WBNB
    "0x18287642a6a675502c2cdff515c0838626ca36af",  # CAKE/WBNB
    "0x45b196696175f7b07917de64eacb5d4d83d8fc21",  # WBNB/XVS
]

def main():
    head = int(rpc("eth_blockNumber", []), 16)
    span = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    chunk = int(os.environ.get("LOG_CHUNK", "20000"))
    out = {"head": head, "span": span, "by_pair": {}}
    for p in PAIRS:
        counts = {}
        for name, topic in TOPICS.items():
            n = 0
            sampled = []
            lo = head - span
            while lo < head:
                hi = min(lo + chunk, head)
                got = rpc("eth_getLogs", [{"address": p, "fromBlock": hex(lo), "toBlock": hex(hi), "topics": [topic]}])
                if isinstance(got, dict) and "__range_error__" in got:
                    counts[name] = "range-error"
                    break
                if got is None:
                    counts[name] = "error"
                    break
                n += len(got)
                if got and name in ("Swap", "Mint", "Burn"):
                    for lg in got[-4:]:
                        sampled.append({
                            "block": int(lg["blockNumber"], 16),
                            "tx": lg["transactionHash"],
                            "topics": lg["topics"][1:],
                            "data": lg["data"],
                        })
                lo = hi + 1
            else:
                counts[name] = n
                if sampled:
                    out["by_pair"].setdefault(p, {}).setdefault(name, [])
                    out["by_pair"][p][name].extend(sampled[-12:])
        out.setdefault("counts", {})[p] = counts
        print(p, counts, flush=True)
    json.dump(out, open(os.path.join(os.path.dirname(__file__), "recent-events.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
