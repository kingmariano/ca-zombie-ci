#!/usr/bin/env python3
"""Re-scan all Swapr V3 (Algebra V1.9) pools on Gnosis at latest block.

Multicall3 batched reads: token0, token1, balanceOf(pool) both tokens,
liquidity, globalState, activeIncentive, liquidityCooldown, tickSpacing.
Output: analysis/pools_latest.json (no secrets; public RPC only).
"""
import json, time
from web3 import Web3

RPC = "https://rpc.gnosischain.com"
MC3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
POOLS = json.load(open("pools_from_triage.json"))

w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 60}))

MC3_ABI = [{
    "inputs": [{"components": [
        {"internalType": "address", "name": "target", "type": "address"},
        {"internalType": "bool", "name": "allowFailure", "type": "bool"},
        {"internalType": "bytes", "name": "callData", "type": "bytes"}],
        "internalType": "struct Multicall3.Call3[]", "name": "calls", "type": "tuple[]"}],
    "name": "aggregate3", "outputs": [{"components": [
        {"internalType": "bool", "name": "success", "type": "bool"},
        {"internalType": "bytes", "name": "returnData", "type": "bytes"}],
        "internalType": "struct Multicall3.Result[]", "name": "returnData", "type": "tuple[]"}],
    "stateMutability": "payable", "type": "function"}]
mc3 = w3.eth.contract(address=MC3, abi=MC3_ABI)

def enc(sig, *args):
    from eth_abi import encode
    types = sig.split("(")[1].rstrip(")").split(",")
    return "0x" + Web3.keccak(text=sig)[:4].hex() + encode(types, args).hex()

SEL_TOKEN0 = "0x0dfe1681"
SEL_TOKEN1 = "0xd21220a7"
SEL_LIQ = "0x1a686502"
SEL_GS = "0xe76c01e4"
SEL_INC = "0xfacb0eb1"
SEL_COOLDOWN = "0x17e25b3c"
SEL_SPACING = "0xd0c93a7c"

def balof(pool):
    return "0x70a08231" + "0" * 24 + pool.lower()[2:]

def run_calls(calls, block):
    out = []
    for i in range(0, len(calls), 400):
        chunk = calls[i:i+400]
        res = mc3.functions.aggregate3([(Web3.to_checksum_address(t), True, d) for t, d in chunk]).call(block_identifier=block)
        out.extend(res)
        time.sleep(0.05)
    return out

def main():
    block = w3.eth.block_number
    print("latest block:", block, flush=True)
    results = {}
    t0 = time.time()
    per = 7
    for start in range(0, len(POOLS), 60):
        chunk = POOLS[start:start+60]
        calls = []
        for pool, _, _ in chunk:
            calls += [(pool, SEL_TOKEN0), (pool, SEL_TOKEN1), (pool, SEL_LIQ), (pool, SEL_GS),
                      (pool, SEL_INC), (pool, SEL_COOLDOWN), (pool, SEL_SPACING)]
        res = run_calls(calls, block)
        tmp = {}
        idx = 0
        for pool, _, _ in chunk:
            r = res[idx:idx+per]; idx += per
            try:
                if not all(x[0] for x in r):
                    tmp[pool] = {"err": "call failed"}
                    continue
                t0a = "0x" + r[0][1][-20:].hex()
                t1a = "0x" + r[1][1][-20:].hex()
                liq = int.from_bytes(r[2][1], "big")
                gs = r[3][1]
                w = [gs[i:i+32] for i in range(0, len(gs), 32)]
                tmp[pool] = {
                    "t0": t0a, "t1": t1a, "liquidity": liq,
                    "price": int.from_bytes(w[0], "big"),
                    "tick": int.from_bytes(w[1], "big", signed=True),
                    "fee": int.from_bytes(w[2], "big"),
                    "timepointIndex": int.from_bytes(w[3], "big"),
                    "communityFee0": int.from_bytes(w[4], "big") if len(w) > 4 else None,
                    "communityFee1": int.from_bytes(w[5], "big") if len(w) > 5 else None,
                    "unlocked": (int.from_bytes(w[6], "big") == 1) if len(w) > 6 else None,
                    "activeIncentive": "0x" + r[4][1][-20:].hex(),
                    "liquidityCooldown": int.from_bytes(r[5][1], "big"),
                    "tickSpacing": int.from_bytes(r[6][1], "big", signed=True),
                }
            except Exception as e:
                tmp[pool] = {"err": str(e)[:80]}
        # balances
        bcalls, bmeta = [], []
        for pool, st in tmp.items():
            if "err" in st:
                continue
            bcalls += [(st["t0"], balof(pool)), (st["t1"], balof(pool))]
            bmeta.append(pool)
        if bcalls:
            bres = run_calls(bcalls, block)
            bi = 0
            for pool in bmeta:
                b0, b1 = bres[bi], bres[bi+1]; bi += 2
                tmp[pool]["b0"] = int.from_bytes(b0[1], "big") if b0[0] else None
                tmp[pool]["b1"] = int.from_bytes(b1[1], "big") if b1[0] else None
        results.update(tmp)
        print(f"  {min(start+60, len(POOLS))}/{len(POOLS)} ({int(time.time()-t0)}s)", flush=True)
    json.dump({"block": block, "scanned_at": int(time.time()), "pools": results}, open("pools_latest.json", "w"))
    print("saved; block", block)

if __name__ == "__main__":
    main()
