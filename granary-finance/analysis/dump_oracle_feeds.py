#!/usr/bin/env python3
"""Dump every Granary oracle feed (source aggregator + latestRoundData) per chain.
Detects stale/frozen feeds. Read-only, public RPCs."""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = {
    "optimism":  "https://mainnet.optimism.io",
    "metis":     "https://metis-rpc.publicnode.com",
    "arbitrum":  "https://arb1.arbitrum.io/rpc",
    "fantom":    "https://rpcapi.fantom.network",
    "avalanche": "https://avalanche-c-chain-rpc.publicnode.com",
    "bsc":       "https://bsc-rpc.publicnode.com",
    "ethereum":  "https://ethereum-rpc.publicnode.com",
    "base":      "https://base-rpc.publicnode.com",
}

_id = [0]
def _post(url, payload, timeout=40):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "granary-audit/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def batch(url, calls, chunk=10, retries=2):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = []
        for m, p in part:
            _id[0] += 1
            payload.append({"jsonrpc": "2.0", "id": _id[0], "method": m, "params": p})
        got = None
        for a in range(retries):
            try:
                res = _post(url, payload)
                byid = {r.get("id"): r for r in res}
                got = [byid.get(c["id"], {}).get("result") for c in payload]
                break
            except Exception as e:
                if a == retries - 1: got = [None]*len(part)
                else: time.sleep(0.7*(a+1))
        out.extend(got)
        time.sleep(0.05)
    return out

def dec_string(hexstr):
    try:
        s = hexstr[2:] if hexstr.startswith("0x") else hexstr
        off = int(s[0:64], 16) // 32
        n = int(s[off*64:(off+1)*64], 16)
        return bytes.fromhex(s[(off+1)*64:(off+1)*64+n*2]).decode("utf-8", "replace")
    except Exception:
        return None

def main():
    now = int(time.time())
    out = {}
    for chain, rpc in RPCS.items():
        st = json.load(open(os.path.join(HERE, f"state-{chain}.json")))
        oracle = st.get("oracle")
        if not oracle or not oracle.startswith("0x"):
            continue
        reserves = [r for r in st.get("reserves", []) if isinstance(r, dict) and "config" in r]
        calls = []
        for r in reserves:
            calls.append(("eth_call", [{"to": oracle, "data": "0x92bf2be0" + r["asset"][2:].rjust(64, "0")}, "latest"]))
        srcs = batch(rpc, calls)
        out[chain] = []
        for r, src in zip(reserves, srcs):
            row = {"asset": r["asset"], "symbol": r.get("assetSymbol"), "source": src}
            if isinstance(src, str) and len(src) >= 42:
                saddr = "0x" + src[-40:]
                row["source"] = saddr
                if saddr != "0x" + "0"*40:
                    c2 = [
                        ("eth_call", [{"to": saddr, "data": "0xfeaf968c"}, "latest"]),   # latestRoundData
                        ("eth_call", [{"to": saddr, "data": "0x7284e416"}, "latest"]),   # description
                        ("eth_call", [{"to": saddr, "data": "0x313ce567"}, "latest"]),   # decimals
                    ]
                    rr = batch(rpc, c2)
                    if isinstance(rr[0], str) and len(rr[0]) >= 2 + 5*64:
                        s = rr[0][2:]
                        row["roundId"] = int(s[0:64], 16)
                        row["answer"] = int(s[64:128], 16)
                        row["startedAt"] = int(s[128:192], 16)
                        row["updatedAt"] = int(s[192:256], 16)
                        row["age_sec"] = now - row["updatedAt"]
                    row["description"] = dec_string(rr[1]) if isinstance(rr[1], str) else None
                    row["feed_decimals"] = int(rr[2], 16) if isinstance(rr[2], str) else None
            out[chain].append(row)
        print(f"[{chain}] {len(out[chain])} feeds")
        for row in out[chain]:
            print(f"   {str(row['symbol']):>8} src={str(row['source'])[:12]} desc={row.get('description')} ans={row.get('answer')} age={row.get('age_sec')}s")
    json.dump(out, open(os.path.join(HERE, "oracle-feeds.json"), "w"), indent=1)
    print("saved oracle-feeds.json")

if __name__ == "__main__":
    main()
