#!/usr/bin/env python3
"""Fetch Aequinox (BSC) vault pool state at a pinned block.

Reads RPC URL from env AEQ_RPC (never hardcoded keyed URLs).
Inputs : analysis/logs_poolregistered.json, analysis/logs_tokensregistered.json
Outputs: analysis/pools_state.json, analysis/vault_state.json
"""
import json, os, sys, time, urllib.request

RPC = os.environ.get("AEQ_RPC", "https://bsc-rpc.publicnode.com")
VAULT = "0xee1c8dbfbf958484c6a4571f5fb7b99b74a54aa7"
HERE = os.path.dirname(os.path.abspath(__file__))

def rpc_batch(calls, retries=4):
    """calls: list of (method, params). Returns list of results (None on error)."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                   for j, (m, p) in enumerate(chunk)]
        data = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(RPC, data=data, headers={
                    "Content-Type": "application/json",
                    "User-Agent": "Mozilla/5.0 (aequinox-audit)"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    resp = json.loads(r.read())
                break
            except Exception as e:
                if attempt == retries - 1:
                    print("batch failed:", e, file=sys.stderr)
                    resp = None
                else:
                    time.sleep(1.5 * (attempt + 1))
        byid = {}
        if resp:
            for item in resp:
                byid[item.get("id")] = item
        for j in range(len(chunk)):
            item = byid.get(j)
            out.append(item.get("result") if item and "error" not in item else None)
    return out

def enc_uint(x):
    return hex(x)[2:].rjust(64, "0")

def dec_addr_array(hexdata):
    """Decode (address[] tokens, uint256[] balances, uint256 lastChangeBlock)."""
    b = bytes.fromhex(hexdata[2:])
    def word(i):
        return int.from_bytes(b[i*32:(i+1)*32], "big")
    off_tok, off_bal, last = word(0), word(1), word(2)
    def arr(off):
        n = int.from_bytes(b[off:off+32], "big")
        vals = []
        for k in range(n):
            vals.append(b[off+32+k*32:off+64+k*32])
        return vals
    toks = ["0x" + v[12:].hex() for v in arr(off_tok)]
    bals = [int.from_bytes(v, "big") for v in arr(off_bal)]
    return toks, bals, last

def main():
    block = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
    print("pinned block:", block)

    poolreg = json.load(open(os.path.join(HERE, "logs_poolregistered.json")))["result"]["logs"]
    tokreg = json.load(open(os.path.join(HERE, "logs_tokensregistered.json")))["result"]["logs"]

    pools = {}
    for l in poolreg:
        pool_id = l["topics"][1]
        pool_addr = "0x" + l["topics"][2][-40:]
        spec = int(l["data"], 16) if l["data"] != "0x" else 0
        pools[pool_id] = {"poolId": pool_id, "pool": pool_addr, "specialization": spec,
                          "regBlock": int(l["blockNumber"], 16),
                          "regTx": l["transactionHash"]}
    for l in tokreg:
        pool_id = l["topics"][1]
        data = bytes.fromhex(l["data"][2:])
        # TokensRegistered(bytes32 indexed poolId, address[] tokens, address[] assetManagers)
        off_tok = int.from_bytes(data[0:32], "big")
        off_mgr = int.from_bytes(data[32:64], "big")
        def arr(off):
            n = int.from_bytes(data[off:off+32], "big")
            return [data[off+32+k*32:off+64+k*32] for k in range(n)]
        toks = ["0x" + v[12:].hex() for v in arr(off_tok)]
        mgrs = ["0x" + v[12:].hex() for v in arr(off_mgr)]
        if pool_id in pools:
            pools[pool_id]["tokens"] = toks
            pools[pool_id]["assetManagers"] = mgrs

    print("pools parsed:", len(pools))

    # getPoolTokens for each pool at pinned block
    ids = list(pools.keys())
    calls = [("eth_call", [{"to": VAULT,
                           "data": "0xf94d4668" + pool_id[2:]}, hex(block)]) for pool_id in ids]
    res = rpc_batch(calls)
    for pool_id, r in zip(ids, res):
        if r and len(r) > 2:
            try:
                toks, bals, last = dec_addr_array(r)
                pools[pool_id]["vaultTokens"] = toks
                pools[pool_id]["vaultBalances"] = [str(x) for x in bals]
                pools[pool_id]["lastChangeBlock"] = last
            except Exception as e:
                pools[pool_id]["decodeError"] = str(e) + " raw=" + r[:100]
        else:
            pools[pool_id]["getPoolTokens"] = "REVERT/None"

    # code of each pool address
    addrs = sorted({p["pool"] for p in pools.values()})
    calls = [("eth_getCode", [a, hex(block)]) for a in addrs]
    res = rpc_batch(calls)
    code = dict(zip(addrs, res))
    for p in pools.values():
        c = code.get(p["pool"]) or "0x"
        p["codeSize"] = (len(c) - 2) // 2

    # vault token balances for the known held tokens
    tokens = {
        "USDT": "0x55d398326f99059ff775485246999027b3197955",
        "USDC": "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",
        "BUSD": "0xe9e7cea3dedca5984780bafc599bd69add087d56",
        "WBNB": "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",
        "ETH": "0x2170ed0880ac9a755fd29b2688956bd959f933f8",
        "BTCB": "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c",
        "DAI": "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3",
        "TUSD": "0x14016e85a25aeb13065688cafb43044c2ef86784",
    }
    calls = [("eth_call", [{"to": t, "data": "0x70a08231" + enc_uint(int(VAULT, 16))}, hex(block)])
             for t in tokens.values()]
    res = rpc_batch(calls)
    vault_state = {"block": block, "vault": VAULT,
                   "tokenBalances": {s: str(int(r, 16)) if r else None for s, r in zip(tokens, res)}}
    json.dump(vault_state, open(os.path.join(HERE, "vault_state.json"), "w"), indent=1)
    json.dump({"block": block, "pools": pools}, open(os.path.join(HERE, "pools_state.json"), "w"), indent=1)
    print("written pools_state.json / vault_state.json")

if __name__ == "__main__":
    main()
