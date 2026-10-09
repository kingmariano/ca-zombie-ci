#!/usr/bin/env python3
"""Check liveness at pinned block for every item id seen in pre-attack PA TransferSingle
events (last 3M blocks) whose base type has NO shell.

- NFT-style ids (low64 != 0): PA.ownerOf(id)
- FT-style ids (low64 == 0): PA.balanceOf(lastTo, id) for each observed 'to'
Writes nonshell_liveness.jsonl and nonshell_summary.json.
"""
import json, os, glob, collections, time

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(CENSUS, "nonshell_liveness.jsonl")
SUM = os.path.join(CENSUS, "nonshell_summary.json")
BURN = "0x0000deaddeaddeaddeaddeaddeaddeaddead0000"
ZERO = "0x0000000000000000000000000000000000000000"
DEAD = "0x000000000000000000000000000000000000dead"
SENT = {BURN, ZERO, DEAD}

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_shells.py")).read().split("def main")[0])

def main():
    shell_bt = {int(s["baseType"]) for s in json.load(open(os.path.join(CENSUS, "shells_parsed.json")))["shells"]}
    seen = {}
    for fn in sorted(glob.glob(os.path.join(CENSUS, "raw", "ft_ts_*.json"))):
        try:
            body = json.load(open(fn))
        except Exception:
            continue
        logs = body.get("result") if isinstance(body, dict) and "result" in body else None
        if not isinstance(logs, list):
            continue
        for lg in logs:
            try:
                iid = int(lg["data"][2:66], 16)
            except Exception:
                continue
            seen[(lg["transactionHash"], lg["logIndex"])] = (int(lg["blockNumber"], 16), iid,
                                                             "0x" + lg["topics"][3][-40:])
    atk_lo = 25834071
    ids = {}          # id -> last seen 'to'
    for b, i, to in sorted(seen.values()):
        if b < atk_lo and (i >> 64) << 64 not in shell_bt:
            ids[i] = to
    print(f"non-shell ids: {len(ids)}", flush=True)

    [pinned] = [int(rpc_batch([("eth_blockNumber", [])])[0], 16)]
    PA = "0xfaafdc07907ff5120a76b34b731b278c38d6043c"
    results = {}
    id_list = sorted(ids)
    nft_ids = [i for i in id_list if i & ((1 << 64) - 1)]
    ft_ids = [i for i in id_list if not (i & ((1 << 64) - 1))]
    print(f"nft-style: {len(nft_ids)}, ft-style: {len(ft_ids)}", flush=True)

    for i in range(0, len(nft_ids), 10):
        chunk = nft_ids[i:i + 10]
        calls = [("eth_call", [{"to": PA, "data": "0x6352211e" + format(x, "064x")}, hex(pinned)]) for x in chunk]
        res = rpc_batch(calls)
        for x, r in zip(chunk, res):
            results[str(x)] = {"kind": "nft", "owner": None if isinstance(r, dict) else "0x" + r[-40:],
                               "error": (r.get("__error__") if isinstance(r, dict) else None)}
        if (i // 10) % 20 == 0:
            print(f"  nft {i + len(chunk)}/{len(nft_ids)}", flush=True)
    for i in range(0, len(ft_ids), 10):
        chunk = ft_ids[i:i + 10]
        calls = [("eth_call", [{"to": PA, "data": "0x00fdd58e" + "0" * 24 + ids[x][2:] + format(x, "064x")}, hex(pinned)]) for x in chunk]
        res = rpc_batch(calls)
        for x, r in zip(chunk, res):
            bal = None if isinstance(r, dict) else int(r, 16)
            results[str(x)] = {"kind": "ft", "holder_checked": ids[x], "balance": bal,
                               "error": (r.get("__error__") if isinstance(r, dict) else None)}

    live = {k: v for k, v in results.items() if (v.get("kind") == "nft" and v.get("owner") and v["owner"].lower() not in SENT) or (v.get("kind") == "ft" and v.get("balance"))}
    with open(OUT, "w") as f:
        json.dump({"block": pinned, "results": results}, f)
    byowner = collections.Counter(v.get("owner") for v in live.values() if v.get("kind") == "nft")
    summary = {"block": pinned, "idsChecked": len(ids), "liveCount": len(live), "liveNft": sum(1 for v in live.values() if v.get("kind") == "nft"),
               "liveFtBalances": sum(1 for v in live.values() if v.get("kind") == "ft"),
               "topOwners": byowner.most_common(20)}
    with open(SUM, "w") as f:
        json.dump(summary, f, indent=1)
    print(json.dumps(summary, indent=1))

if __name__ == "__main__":
    main()
