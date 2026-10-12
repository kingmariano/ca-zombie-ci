#!/usr/bin/env python3
"""Adaptive getLogs scanner: splits ranges when the RPC caps results at 10000.
Usage: scan_events2.py <event> <start> <end> <outfile> [pool1,pool2,...]
Events: swap|mint|burn|collect. Correct topic/data layouts (UniV3 canonical)."""
import json, os, sys, urllib.request, time

RPC = os.environ["BSC_RPC"]
TOPICS = {
    "swap": "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67",
    "mint": "0x7a53080ba414158be7ec69b987b5fb7d07dee101fe85488f0853ae16239d0bde",
    "burn": "0x0c396cd989a39f4459b5fa1aed6a9a8dcdbc45908acfd67e028cd568da98982c",
    "collect": "0x70935338e69775456a85ddef226c395fb668b63fa0115f5f20610b388e6ca9c0",
}

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"})
    for a in range(4):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                resp = json.load(r)
            if "error" in resp:
                return {"error": resp["error"]}
            return {"result": resp["result"]}
        except Exception as e:
            time.sleep(2)
    return {"error": {"message": "request failed"}}

def get_logs(addr, topic, start, end, depth=0):
    res = rpc("eth_getLogs", [{"address": addr, "topics": [topic],
                               "fromBlock": hex(start), "toBlock": hex(end)}])
    if "error" in res:
        msg = str(res["error"].get("message", ""))
        if "exceeds max results" in msg or "10000" in msg or "limit" in msg.lower():
            if end - start < 2:
                return []
            mid = (start + end) // 2
            if depth > 20:
                print("  depth limit", start, end); return []
            return get_logs(addr, topic, start, mid, depth+1) + get_logs(addr, topic, mid+1, end, depth+1)
        print("  err:", msg[:120], start, end)
        return []
    return res["result"]

def word(h, i):
    return h[i*64:(i+1)*64]

def parse(ev, lg):
    t = lg["topics"]; data = lg["data"][2:]
    rec = {"pool": lg["address"], "block": int(lg["blockNumber"], 16), "tx": lg["transactionHash"], "logIndex": int(lg["logIndex"], 16)}
    if ev == "swap":
        rec["sender"] = "0x" + t[1][-40:]; rec["recipient"] = "0x" + t[2][-40:]
        rec["amount0"] = int.from_bytes(bytes.fromhex(word(data,0)), "big", signed=True)
        rec["amount1"] = int.from_bytes(bytes.fromhex(word(data,1)), "big", signed=True)
        rec["sqrtPriceX96"] = int(word(data,2), 16)
        rec["liquidity"] = int(word(data,3), 16)
        rec["tick"] = int.from_bytes(bytes.fromhex(word(data,4)), "big", signed=True)
    elif ev == "mint":
        rec["owner"] = "0x" + t[1][-40:]
        rec["tickLower"] = int.from_bytes(bytes.fromhex(t[2][2:]), "big", signed=True)
        rec["tickUpper"] = int.from_bytes(bytes.fromhex(t[3][2:]), "big", signed=True)
        rec["amount"] = int(word(data,0), 16)
        rec["amount0"] = int(word(data,1), 16)
        rec["amount1"] = int(word(data,2), 16)
    elif ev == "burn":
        rec["owner"] = "0x" + t[1][-40:]
        rec["tickLower"] = int.from_bytes(bytes.fromhex(t[2][2:]), "big", signed=True)
        rec["tickUpper"] = int.from_bytes(bytes.fromhex(t[3][2:]), "big", signed=True)
        rec["amount"] = int(word(data,0), 16)
        rec["amount0"] = int(word(data,1), 16)
        rec["amount1"] = int(word(data,2), 16)
    elif ev == "collect":
        rec["owner"] = "0x" + t[1][-40:]
        rec["recipient"] = "0x" + t[2][-40:]
        rec["tickLower"] = int.from_bytes(bytes.fromhex(t[3][2:]), "big", signed=True)
        rec["tickUpper"] = int.from_bytes(bytes.fromhex(t[4][2:]), "big", signed=True)
        rec["amount0"] = int(word(data,0), 16)
        rec["amount1"] = int(word(data,1), 16)
    return rec

if __name__ == "__main__":
    ev, start, end, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    pools = sys.argv[5].split(",") if len(sys.argv) > 5 else None
    if pools is None:
        pools = [p["pool"] for p in json.load(open("pools-state.json"))["pools"]]
    all_events = []
    for i in range(0, len(pools), 10):
        chunk = pools[i:i+10]
        logs = get_logs(chunk, TOPICS[ev], start, end)
        for lg in logs:
            all_events.append(parse(ev, lg))
        print(f"{ev} pools {i}-{i+len(chunk)} cum={len(all_events)}", flush=True)
    all_events.sort(key=lambda e: (e["block"], e["logIndex"]))
    json.dump(all_events, open(out, "w"))
    print(f"wrote {out}: {len(all_events)} events")
