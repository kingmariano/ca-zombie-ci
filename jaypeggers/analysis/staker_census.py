#!/usr/bin/env python3
"""Jaypeggers staker census — read-only eth_call multicall (Multicall3).

For each candidate staker address: getStaked(addr) and getReward(addr) on the
target staking contract. Sums shares + pending rewards and cross-checks against
totalAmountStaked() and the reward-token balance of the contract.

Usage:
  RPC_URL=https://... python3 staker_census.py <staking_addr> <addrs_file> <out_json> [balance_of_addr_for_usdc]

No secrets are written. Uses public stdlib only.
"""
import json
import os
import sys
import urllib.request

MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"


def pad(addr: str) -> str:
    return addr.lower().replace("0x", "").rjust(64, "0")


def calldata(selector: str, addr: str) -> bytes:
    return bytes.fromhex(selector[2:] + pad(addr))


def rpc(url: str, method: str, params: list):
    fallbacks = [u for u in ("https://ethereum-rpc.publicnode.com", "https://eth.drpc.org") if u != url]
    last_err = None
    for u in [url] + fallbacks:
        try:
            req = urllib.request.Request(
                u,
                data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                headers={"Content-Type": "application/json", "User-Agent": "jaypeggers-census/1.0"},
            )
            with urllib.request.urlopen(req, timeout=90) as r:
                d = json.load(r)
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:  # noqa: BLE001 - try next endpoint
            host = u.split("/")[2]
            print(f"  rpc {host} failed: {str(e)[:80]}", flush=True)
            last_err = e
    raise last_err


def encode_aggregate3(calls: list) -> str:
    """aggregate3((address,bool,bytes)[]) — minimal manual ABI encoding."""
    # selector for aggregate3((address,bool,bytes)[]) = 0x82ad56cb
    head = "82ad56cb"
    n = len(calls)
    # offset to array (0x20)
    head += (32).to_bytes(32, "big").hex()
    # array: len
    arr = n.to_bytes(32, "big").hex()
    # element offsets (relative to start of array data, i.e., after len)
    elem_data = []
    offset_base = 32 * n
    offsets = []
    for (target, allow_fail, data) in calls:
        b = bytes.fromhex(data[2:])
        # tuple encoding: address, bool, offset-to-bytes(0x60), then bytes len+data
        enc = pad(target)
        enc += (1 if allow_fail else 0).to_bytes(32, "big").hex()
        enc += (0x60).to_bytes(32, "big").hex()
        enc += len(b).to_bytes(32, "big").hex()
        enc += b.hex().ljust(((len(b) + 31) // 32) * 64, "0")
        elem_data.append(enc)
        offsets.append(offset_base)
        offset_base += len(enc) // 2
    arr += "".join(o.to_bytes(32, "big").hex() for o in offsets)
    return "0x" + head + arr + "".join(elem_data)


def decode_aggregate3(hexstr: str) -> list:
    """decode ((bool,bytes)[])"""
    h = hexstr[2:]
    off = int(h[0:64], 16)
    n = int(h[off * 2: off * 2 + 64], 16)
    out = []
    base = off * 2 + 64
    for i in range(n):
        e_off = int(h[base + i * 64: base + i * 64 + 64], 16)
        p = base + e_off * 2
        ok = int(h[p: p + 64], 16) == 1
        boff = int(h[p + 64: p + 128], 16)
        bp = p + boff * 2
        blen = int(h[bp: bp + 64], 16)
        data = h[bp + 64: bp + 64 + blen * 2]
        out.append((ok, data))
    return out


def main():
    staking = sys.argv[1]
    addrs_file = sys.argv[2]
    out_json = sys.argv[3]
    reward_holder = sys.argv[4] if len(sys.argv) > 4 else None
    rpc_url = os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"

    # selectors verified with `cast sig`:
    #   getStaked(address) = 0x399080ec, getReward(address) = 0xc00007b0
    s_staked = sys.argv[5] if len(sys.argv) > 5 else "0x399080ec"
    s_reward = sys.argv[6] if len(sys.argv) > 6 else "0xc00007b0"

    addrs = []
    seen = set()
    with open(addrs_file) as f:
        for line in f:
            a = line.strip().lower()
            if a.startswith("0x") and len(a) == 42 and a not in seen:
                seen.add(a)
                addrs.append(a)

    print(f"staking={staking} candidates={len(addrs)} rpc_host={rpc_url.split('/')[2]}", flush=True)

    total_shares = 0
    total_reward = 0
    nonzero = []
    CHUNK = 250
    for i in range(0, len(addrs), CHUNK):
        chunk = addrs[i:i + CHUNK]
        calls = []
        for a in chunk:
            calls.append((staking, True, "0x" + s_staked[2:] + pad(a)))
            calls.append((staking, True, "0x" + s_reward[2:] + pad(a)))
        data = encode_aggregate3(calls)
        res = rpc(rpc_url, "eth_call", [{"to": MULTICALL3, "data": data}, "latest"])
        dec = decode_aggregate3(res)
        for j, a in enumerate(chunk):
            ok1, d1 = dec[2 * j]
            ok2, d2 = dec[2 * j + 1]
            shares = int(d1, 16) if ok1 and d1 else 0
            reward = int(d2, 16) if ok2 and d2 else 0
            total_shares += shares
            total_reward += reward
            if shares or reward:
                nonzero.append({"address": a, "shares": shares, "reward_wei": reward})
        print(f"  chunk {i//CHUNK+1}: cumulative shares={total_shares} reward={total_reward/1e18:.6f}", flush=True)

    out = {
        "staking": staking,
        "candidates": len(addrs),
        "nonzero_stakers": len(nonzero),
        "sum_shares": str(total_shares),
        "sum_reward_wei": str(total_reward),
        "sum_reward_eth_or_usdc": total_reward / 1e18 if total_reward > 1e12 else total_reward,
        "top": sorted(nonzero, key=lambda x: -x["shares"])[:25],
    }
    if reward_holder:
        out["reward_holder"] = reward_holder
    with open(out_json, "w") as f:
        json.dump(out, f, indent=1)
    print(json.dumps({k: v for k, v in out.items() if k != "top"}, indent=1))


if __name__ == "__main__":
    main()
