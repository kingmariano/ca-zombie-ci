#!/usr/bin/env python3
"""
Evidence that Moonbeam and Moonriver stopped producing usable blocks:
read latest block, timestamp, tx count, and search backwards for the last block
containing any transaction. Contrast with Base/OP live heads.
Outputs analysis/chain_freeze_evidence.json and .md
"""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = {
    "base": "https://base-rpc.publicnode.com",
    "optimism": "https://optimism-rpc.publicnode.com",
    "moonbeam": os.environ.get("MOONBEAM_RPC_URL", "https://moonbeam.api.onfinality.io/public"),
    "moonriver": os.environ.get("MOONRIVER_RPC_URL", "https://moonriver.api.onfinality.io/public"),
}


def rpc(url, method, params):
    req = urllib.request.Request(url, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 c32"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def check(name, url):
    out = {"chain": name, "rpc": url}
    head = int(rpc(url, "eth_blockNumber", [])["result"], 16)
    b = rpc(url, "eth_getBlockByNumber", [hex(head), False])["result"]
    out["head_block"] = head
    out["head_timestamp"] = int(b["timestamp"], 16)
    out["head_time_utc"] = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime(out["head_timestamp"]))
    out["head_tx_count"] = len(b.get("transactions") or [])
    # scan back up to 5000 blocks for any tx
    last = None
    for i in range(0, 5000, 50):
        blk = rpc(url, "eth_getBlockByNumber", [hex(head - i), False])["result"]
        if blk and (blk.get("transactions") or []):
            last = {"block": head - i, "tx_count": len(blk["transactions"]),
                    "time_utc": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime(int(blk["timestamp"], 16)))}
            break
    out["last_block_with_tx_within_5000"] = last
    out["head_age_days"] = round((time.time() - out["head_timestamp"]) / 86400, 2)
    return out


def main():
    res = []
    for name, url in RPCS.items():
        try:
            res.append(check(name, url))
        except Exception as e:
            res.append({"chain": name, "error": str(e)})
    with open(os.path.join(HERE, "chain_freeze_evidence.json"), "w") as f:
        json.dump(res, f, indent=1)
    lines = ["# Chain liveness evidence (read-only RPC, " + time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime()) + ")", ""]
    for r in res:
        if "error" in r:
            lines.append(f"- {r['chain']}: ERROR {r['error']}")
            continue
        lines.append(f"- **{r['chain']}**: head block {r['head_block']} @ {r['head_time_utc']} "
                     f"(age {r['head_age_days']}d, txs in head: {r['head_tx_count']}); "
                     f"last block with tx within 5000: {r['last_block_with_tx_within_5000']}")
    with open(os.path.join(HERE, "chain_freeze_evidence.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
