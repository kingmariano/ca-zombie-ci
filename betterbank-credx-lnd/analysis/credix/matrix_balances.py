#!/usr/bin/env python3
"""Exhaustive matrix: every deployer-created contract x (tokens + native)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
SEL_BAL = "0x70a08231"

TOKENS = {
    "wS": "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38",
    "USDC": "0x29219dd400f2Bf60E5a23d13Be72B486D4038894",
    "scUSD": "0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE",
    "WETH": "0x50c42dEAcD8Fc9773493ED674b675bE577f2634b",
    "stS": "0xE5DA20F15420aD15DE0fa650600aFc998bbE3955",
    "acUSDC": "0xEc26D07B5c0a99D3690375A2CC229E5b943e7726",
    "acscUSD": "0xa175EE511de429275d26Ac5420fAbeb60C67C372",
    "acwS": "0x95cAF53667D912F3491173fd4712450dFcf4c89f",
    "aUSDC_A": "0x64d0071044ef8f98b8e5ecfcb4a6c12cb8bc1ec0",
    "ascUSD_A": "0x9154f0a385eef5d48cef78d9fea19995a92718a9",
    "awS_A": "0x61bc5ce0639aa0a24ab7ea8b574d4b0d6b619833",
    "aacUSDC_A": "0x0eee208934e66a6e44517e627a2475fc891b3a38",
    "aacscUSD_A": "0x1acd539e2a76cf876889dd8119c1d873821551a1",
    "aacwS_A": "0xed01f103c284253d0824c0125f673f11c14d2ea4",
    "WETH_A_?": "0x0000000000000000000000000000000000000000",
}


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    txs = json.load(open(os.path.join(RAW, "etherscan/account_txlist_deployer.json")))["result"]
    created = [t["contractAddress"].lower() for t in txs if not t.get("to")]
    # also include all known protocol contracts
    enum = json.load(open(os.path.join(RAW, "enumeration.json")))
    extra = set()
    for m in enum["markets"].values():
        for k in ("provider", "pool", "getPoolConfigurator", "getPriceOracle", "getACLManager",
                  "getACLAdmin", "getPoolDataProvider", "owner"):
            a = m.get(k)
            if a and a.lower() != "0x0000000000000000000000000000000000000000":
                extra.add(a.lower())
        for r in m["reserves"]:
            rd = r["reserveData"]
            for k in ("aTokenAddress", "variableDebtTokenAddress", "stableDebtTokenAddress",
                      "interestRateStrategyAddress"):
                if rd.get(k):
                    extra.add(rd[k].lower())
    addrs = sorted(set(created) | extra)
    EOAS = ["0xf321683831be16eed74dfa58b02a37483cec662e",
            "0x0dd010513f7abb8f9c628dc164a24d953bca09cf",
            "0x3d0c177e035c30bb8681e5859eb98d114b48b935",
            "0x75ef5d635388d7c97425596ce50c11844234128b",
            "0x6d0f4cec05a7066d3f509a732d59ede630989053",
            "0xd3e02c92f59a0ba5601464299d658d3a0a7cf96f"]
    addrs = sorted(set(addrs) | set(EOAS))

    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "contracts": {}, "addresses": addrs}
    calls, meta = [], []
    for a in addrs:
        calls.append(("eth_getBalance", [a, hex(block)]))
        meta.append(("native", a))
        for sym, tok in TOKENS.items():
            if tok == "0x0000000000000000000000000000000000000000":
                continue
            calls.append(("eth_call", [{"to": tok, "data": SEL_BAL + pad_a(a)}, hex(block)]))
            meta.append((sym, a))
    CH = 40
    for i in range(0, len(calls), CH):
        chunk = calls[i:i + CH]
        for attempt in range(4):
            try:
                res = batch(chunk, timeout=180)
                if any(isinstance(x, dict) and "error" in x for x in res) and attempt < 3:
                    raise RuntimeError("partial error")
                break
            except Exception as e:
                print(f"  chunk {i} attempt {attempt}: {e}", flush=True)
                import time
                time.sleep(2 * (attempt + 1))
                res = [None] * len(chunk)
        for (kind, a), v in zip(meta[i:i + CH], res):
            if kind == "native":
                out["contracts"].setdefault(a, {})["native"] = dec_u(v) if isinstance(v, str) else v
            else:
                out["contracts"].setdefault(a, {})[kind] = dec_u(v) if isinstance(v, str) else v
        print(f"chunk {i}/{len(calls)}", flush=True)
    with open(os.path.join(RAW, "matrix_balances.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("saved. non-zero holdings:")
    for a, d in out["contracts"].items():
        nz = {k: v for k, v in d.items() if k != "native" and isinstance(v, int) and v != 0}
        nat = d.get("native", 0)
        if nz or (isinstance(nat, int) and nat > 0):
            print(f"  {a}: native={nat/1e18 if isinstance(nat,int) else nat} {nz}")


if __name__ == "__main__":
    main()
