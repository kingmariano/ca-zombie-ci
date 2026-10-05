#!/usr/bin/env python3
"""Read-only batched eth_call scan: enumerate peers(eid) for a wide EID range.
No transactions. Uses plain JSON-RPC batch. Public RPCs only."""
import json, urllib.request, sys, time

OFT = "0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF"
SEL_PEERS = "0xbb0b6a53"  # cast sig "peers(uint32)"

def encode_eid_call(eid):
    return SEL_PEERS + f"{eid:064x}"

def rpc_batch(url, calls, retries=3):
    body = json.dumps([{"jsonrpc":"2.0","id":i,"method":"eth_call",
                        "params":[{"to":OFT,"data":c},"latest"]} for i,c in enumerate(calls)]).encode()
    req = urllib.request.Request(url, data=body, headers={"content-type":"application/json","User-Agent":"Mozilla/5.0 research"})
    last = None
    for _ in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:
            last = e; time.sleep(2)
    raise last

def main(chain, url):
    eids = list(range(30100, 30401)) + list(range(40100, 40251))
    found = []
    CHUNK = 40
    for i in range(0, len(eids), CHUNK):
        chunk = eids[i:i+CHUNK]
        calls = [encode_eid_call(e) for e in chunk]
        try:
            resp = rpc_batch(url, calls)
        except Exception as e:
            print(f"[{chain}] chunk {i} failed: {e}", file=sys.stderr); continue
        for item in resp:
            if "result" in item:
                val = item["result"]
                if val and int(val, 16) != 0:
                    found.append((chunk[item["id"]], val))
            elif "error" in item:
                pass
        time.sleep(0.2)
    print(f"# chain={chain} url={url} scanned={len(eids)} eids")
    if not found:
        print("NONZERO_PEERS: none")
    else:
        for eid, val in found:
            print(f"NONZERO peer eid={eid} = {val}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
