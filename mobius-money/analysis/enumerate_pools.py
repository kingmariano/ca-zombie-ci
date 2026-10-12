#!/usr/bin/env python3
"""Read-only live-state enumeration of Mobius (Celo) pool contracts.
Uses keyless public RPCs (no secrets). Output: analysis/live-state.json
One batched JSON-RPC POST per pool -> fast.
"""
import json, time, urllib.request, os, sys

RPCS = ["https://celo-rpc.publicnode.com", "https://forno.celo.org", "https://rpc.ankr.com/celo"]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "live-state.json")

POOLS = [
    "0xc0ba93d4aaf90d39924402162ee4a213300d1d60",
    "0xebf0536356256f8ff2a5eb6c65800839801d8b95",
    "0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae",
    "0x74ef28d635c6c5800dd3cd62d4c4f8752daacb09",
    "0x9906589ea8fd27504974b7e8201df5bbde986b03",
    "0xf3f65dfe0c8c8f2986da0fec159abe6fd4e700b4",
    "0xaefc4e8cf655a182e8346b24c8abce45616ee0d2",
    "0xcce0d62ce14fb3e4363eb92db37ff3630836c252",
    "0xa5037661989789d0310ac2b796fa78f1b01f195d",
    "0x0986b42f5f9c42feeef66fc23eba9ea1164c916d",
    "0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735",
    "0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a",
    "0x23c95678862a229fac088bd9705622d78130bc3e",
    "0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c",
    "0x63c1914bf00a9b395a2bf89aada55a5615a3656e",
    "0x2080aaa167e2225e1fc9923250ba60e19a180fb2",
    "0x19260b9b573569ddb105780176547875fe9feda3",
    "0xe0f2cc70e52f05edb383313393d88df2937da55a",
    "0xdbf27fd2a702cc02ac7acf0aea376db780d53247",
    "0x0ff04189ef135b6541e56f7c638489de92e9c778",
    "0x413ffcc28e6cdde7e93625ef4742810fe9738578",
    "0x382ed834c6b7dbd10e4798b08889eaed1455e820",
    "0x81b6a3d9f725ab5d706d9e552b128bc5bb0b58a1",
    "0xfa3df877f98ac5ecd87456a7accaa948462412f0",
]

SEL = {
    "getLpToken": "0x8214f5a4",
    "getSwapFee": "0xd4cadf68",
    "getAPrecise": "0x0ba81959",
    "getA": "0xd46300fd",
    "getVirtualPrice": "0xe25aa5fa",
    "owner": "0x8da5cb5b",
    "paused": "0x5c975abb",
    "swapStorage": "0x5fd65f0f",
    "totalSupply": "0x18160ddd",
    "defaultDepositFee": "0xbe2b8ac7",   # guessed; verify
    "defaultWithdrawFee": "0x8a25b3e6",  # guessed; verify
}
for i in range(4):
    SEL[f"getToken{i}"] = "0x82b86600" + hex(i)[2:].rjust(64, "0")
    SEL[f"getTokenBalance{i}"] = "0x91ceb3eb" + hex(i)[2:].rjust(64, "0")
    SEL[f"getAdminBalance{i}"] = "0xef0a712f" + hex(i)[2:].rjust(64, "0")


def rpc_batch(calls, tries=5):
    """calls: list of (method, params). Returns list of results/errors in order."""
    body = json.dumps([{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
                       for i, (m, p) in enumerate(calls)]).encode()
    last = None
    for u in RPCS:
        for t in range(2):
            try:
                req = urllib.request.Request(u, data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research; read-only)"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    d = json.loads(r.read().decode())
                if isinstance(d, dict) and d.get("error"):
                    last = d["error"]
                    continue
                by_id = {item["id"]: item for item in d} if isinstance(d, list) else {}
                out = []
                for i in range(len(calls)):
                    item = by_id.get(i)
                    if item is None:
                        out.append(None)
                    elif "result" in item:
                        out.append(item["result"])
                    else:
                        out.append({"__rpc_error__": item.get("error")})
                return out
            except Exception as e:
                last = e
                time.sleep(0.5)
    raise RuntimeError(f"rpc failed: {last}")


def word(s):
    if not s or not isinstance(s, str) or s == "0x":
        return None
    h = s[2:]
    return [h[i:i + 64] for i in range(0, len(h) - 63, 64)]


def dec_uint(s):
    w = word(s)
    return int(w[0], 16) if w else None


def dec_addr(s):
    w = word(s)
    return "0x" + w[0][-40:] if w else None


def pool_calls(p, extra_calls=None):
    calls = [("eth_getCode", [p, "latest"])]
    keys = ["code"]
    for k in ["getLpToken", "owner", "paused", "getSwapFee", "getAPrecise", "getA", "getVirtualPrice", "swapStorage"]:
        calls.append(("eth_call", [{"to": p, "data": SEL[k]}, "latest"]))
        keys.append(k)
    for i in range(4):
        calls.append(("eth_call", [{"to": p, "data": SEL[f"getToken{i}"]}, "latest"]))
        keys.append(f"getToken{i}")
        calls.append(("eth_call", [{"to": p, "data": SEL[f"getTokenBalance{i}"]}, "latest"]))
        keys.append(f"getTokenBalance{i}")
        calls.append(("eth_call", [{"to": p, "data": SEL[f"getAdminBalance{i}"]}, "latest"]))
        keys.append(f"getAdminBalance{i}")
    return calls, keys


def main():
    block = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
    out = {"rpcs": RPCS, "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "block": block, "pools": {}}
    for p in POOLS:
        calls, keys = pool_calls(p)
        res = rpc_batch(calls)
        r = dict(zip(keys, res))
        entry = {"address": p, "code_len": len(r.get("code") or "0x")}
        if entry["code_len"] <= 2:
            entry["note"] = "no code"
            out["pools"][p] = entry
            print(f"{p} :: no code", flush=True)
            continue
        entry["lpToken"] = dec_addr(r.get("getLpToken"))
        entry["owner"] = dec_addr(r.get("owner"))
        entry["paused"] = bool(dec_uint(r.get("paused")) or 0)
        entry["swapFee"] = dec_uint(r.get("getSwapFee"))
        entry["APrecise"] = dec_uint(r.get("getAPrecise"))
        entry["A"] = dec_uint(r.get("getA"))
        entry["virtualPrice"] = dec_uint(r.get("getVirtualPrice"))
        entry["swapStorage_raw_words"] = word(r.get("swapStorage"))
        toks, bals, admin = [], [], []
        for i in range(4):
            t = dec_addr(r.get(f"getToken{i}"))
            if t is None:
                break
            toks.append(t)
            bals.append(dec_uint(r.get(f"getTokenBalance{i}")))
            admin.append(dec_uint(r.get(f"getAdminBalance{i}")))
        entry["tokens"] = toks
        entry["balances"] = bals
        entry["adminBalances"] = admin
        out["pools"][p] = entry
        print(f"{p} lp={entry['lpToken']} n={len(toks)} paused={entry['paused']} owner={entry['owner']}", flush=True)
    with open(OUT, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", OUT, "block", block)


if __name__ == "__main__":
    main()
