#!/usr/bin/env python3
"""Chunked eth_getLogs scanner for the Vessel vault on Scroll (read-only, keyless RPC)."""
import json, sys, time, urllib.request

RPC = "https://scroll-rpc.publicnode.com"
VAULT = "0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2"

TOPICS = {
    "LogDeposit": "0x9dbb0e7dda3e09710ce75b801addc87cf9d9c6c581641b3275fca409ad086c62",
    "LogWithdraw": "0xda9a10d7b992511ddadbfc7ff712c1424ce2058bbcdac8c9876d6f8de590d43f",
    "LogNewPendingWithdrawAmount": "0x3d5561b621e43465d6af38b20b2302af33b357ca3160cb1400a9eed6a781002e",
    "LogNewPendingDepositAmount": "0x2f2ccd37e471c83db2291eb3299af0750759b269e0f8554443e293783153a26b",
    "LogProofCommitted": "0x321d78cce2319e8a11f283f534aa49cf60de36fd115b20210f087b4d403505a2",
    "LogFastWithdrawBackfill": "0xcdead1999054fa62315134142ab2da2ccfc7b6f340cbf8964493460222cebe13",
    "LogVesselKeyRegister": "0x30cbe686e3ee93ad523b320b5f68a0d5625223af5b0aec7fab06fc7868a8a4c4",
    "LogOperatorAdded": "0x50a18c352ee1c02ffe058e15c2eb6e58be387c81e73cc1e17035286e54c19a57",
    "LogOperatorRemoved": "0xec5f6c3a91a1efb1f9a308bb33c6e9e66bf9090fad0732f127dfdbf516d0625d",
    "LogExitManagerAdded": "0x9a8520da740f574ac36dbc80915c3a2e124842ff8d870158bb2f07c4716d5d31",
    "LogExitManagerRemoved": "0xf6761acc00c18a126c54e9b64383c52bbdca25b815044f87c5f5d5d8c1858023",
    "AdminTransferred": "0xf8ccb027dfcd135e000e9d45e6cc2d662578a8825d4c45b5e32e0adf67e79ec6",
    "LogAssetRegistered": "0xe474e5671ab1255dfb9155a63d2c8230abae68026941ef08139a71486c1a07a3",
    "LogAssetActive": "0xd9e0246a72572ba7b3dce3886102dbf7ad34ee2f7a8c23f6eb4bd6726a1f254d",
    "LogAmmPoolCreated": "0xac32822e6e43fe9fef55006be3a443452e4316a167e4b8a8e676a44935429e9a",
    "LogNewEternalTreeRoot": "0xc0be29b7ec0b30df5114f0303e84df73cbfe4edfa0ec51b31eaaf279f783e920",
    "LogNewEphemeralTreeRoot": "0x1aa7ea6469b3940f9a87c98ad31ffca7af2be0d18844f520319c3d0b03059414",
    "LogL1ToL2MessageQueueFastWithdraw": "0xa64a184913b18287f2ba9fe0e579c1bcdeb05d1dac1b7ca6ec5c47ec5c1339a4",
    "LogL1ToL2MessageQueueDeposit": "0x070589d8a6b7f7d7e8a5cd68adadc3ac4cdf10465981d9c4d060e3b4ed1afdc4",
    "LogL1ToL2MessageQueueRegister": "0x1cd7a88778ac7b85e7b035b44b5831b226446e48cc62cfd8e50ed522a755d01d",
    "LogL1ToL2MessageQueueUpdate": "0x93fe99441f323c380c582c7d6d40e9627e32aae706890eefb55978d74314ef3e",
    "LogL2ToL1MessageQueueUpdate": "0x4922d19a3dad367510434e1d8c74b309e5ca61ca7f8b98cdfdbe3f7778ffe26f",
    "Upgraded": "0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b",
    "AdminChanged": "0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f",
}

def rpc(method, params, retries=5):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=40) as r:
                d = json.load(r)
            if "result" in d:
                return d["result"]
            err = d.get("error", {})
            print("rpc error:", err, file=sys.stderr)
            if "limit" in str(err).lower() or "range" in str(err).lower():
                return "RANGE_TOO_LARGE"
        except Exception as e:
            print("retry", i, repr(e), file=sys.stderr)
        time.sleep(1.5 * (i + 1))
    return None

def get_logs(from_block, to_block, topics):
    return rpc("eth_getLogs", [{
        "address": VAULT, "fromBlock": hex(from_block), "toBlock": hex(to_block),
        "topics": [topics if isinstance(topics, list) else topics],
    }])

def main():
    latest = int(rpc("eth_blockNumber", []), 16)
    print("latest:", latest)
    # deployment block: proxy created 2025-11-15 -> find approx via binary search on code? assume scan window
    # Determine start block from a known early event: scan from Nov 2025 approx block. We'll binary-search
    # contract nonce: find via eth_getCode at ranges. Simpler: deploy tx block from explorer supplied separately.
    start = int(sys.argv[1]) if len(sys.argv) > 1 else latest - 2_000_000
    end = int(sys.argv[2]) if len(sys.argv) > 2 else latest
    topic_filter = sys.argv[3] if len(sys.argv) > 3 else None
    out = []
    chunk = 50_000
    b = start
    while b <= end:
        e = min(b + chunk - 1, end)
        topics = [TOPICS[topic_filter]] if topic_filter else [[t for t in TOPICS.values()]]
        # eth_getLogs topics: list of OR topics at position 0
        params_topics = topics[0] if isinstance(topics[0], list) else topics
        res = get_logs(b, e, params_topics)
        if res == "RANGE_TOO_LARGE":
            chunk = chunk // 2
            if chunk < 500:
                print("chunk too small", flush=True)
                break
            print(f"reducing chunk to {chunk}", flush=True)
            continue
        if res is None:
            print("failed chunk", b, e, flush=True)
            b = e + 1
            continue
        if res:
            out.extend(res)
            print(f"blocks {b}-{e}: +{len(res)} logs (total {len(out)})", flush=True)
        b = e + 1
    fn = sys.argv[4] if len(sys.argv) > 4 else "logs_scan.json"
    json.dump(out, open(fn, "w"))
    print("wrote", fn, len(out))

if __name__ == "__main__":
    main()
