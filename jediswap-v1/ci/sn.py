#!/usr/bin/env python3
"""Starknet read-only helper for JediSwap V1 deep-dive.
Public keyless RPC endpoints only. No secrets. Read-only (call/getClass/getStorageAt/simulate only).
"""
import json, gzip, base64, time, urllib.request, urllib.error

RPC_URLS = [
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.drpc.org",
]

# ---------------- keccak256 (pure python, compact) ----------------
_MASK = (1 << 64) - 1
_RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_ROTC = [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44]
_PILN = [10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1]


def _keccak_f(state):
    for rnd in range(24):
        bc = [state[i] ^ state[i + 5] ^ state[i + 10] ^ state[i + 15] ^ state[i + 20] for i in range(5)]
        for i in range(5):
            t = bc[(i + 4) % 5] ^ (((bc[(i + 1) % 5] << 1) | (bc[(i + 1) % 5] >> 63)) & _MASK)
            for j in range(0, 25, 5):
                state[j + i] ^= t
        t = state[1]
        for i in range(24):
            j = _PILN[i]
            bc0 = state[j]
            state[j] = (((t << _ROTC[i]) | (t >> (64 - _ROTC[i]))) & _MASK)
            t = bc0
        for j in range(0, 25, 5):
            bc = [state[j + i] for i in range(5)]
            for i in range(5):
                state[j + i] = (state[j + i] ^ ((~bc[(i + 1) % 5]) & bc[(i + 2) % 5])) & _MASK
        state[0] ^= _RC[rnd]
    return state


def keccak256(data: bytes) -> bytes:
    rate = 136
    msg = bytearray(data)
    msg.append(0x01)
    while len(msg) % rate != 0:
        msg.append(0x00)
    msg[-1] |= 0x80
    state = [0] * 25
    for off in range(0, len(msg), rate):
        blk = msg[off:off + rate]
        for i in range(rate // 8):
            state[i] ^= int.from_bytes(blk[i * 8:(i + 1) * 8], "little")
        state = _keccak_f(state)
    out = b""
    for i in range(4):
        out += state[i].to_bytes(8, "little")
    return out


def selector(name: str) -> str:
    return hex(int.from_bytes(keccak256(name.encode()), "big") & ((1 << 250) - 1))


# ---------------- RPC ----------------
def rpc(method, params, urls=None, timeout=60, retries=3):
    urls = urls or RPC_URLS
    last = None
    for i in range(retries):
        for u in urls:
            try:
                req = urllib.request.Request(
                    u, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    d = json.loads(r.read().decode())
                if "result" in d:
                    return d["result"]
                last = d.get("error")
            except Exception as e:
                last = f"{type(e).__name__}: {e}"
        time.sleep(1.0 * (i + 1))
    raise RuntimeError(f"{method} failed: {last}")


def call(addr, func, calldata=None, block="latest"):
    return rpc("starknet_call", {"request": {
        "contract_address": hex(int(addr, 16)),
        "entry_point_selector": selector(func),
        "calldata": [hex(x) if isinstance(x, int) else x for x in (calldata or [])],
    }, "block_id": block})


def call_sel(addr, sel, calldata=None, block="latest"):
    return rpc("starknet_call", {"request": {
        "contract_address": hex(int(addr, 16)),
        "entry_point_selector": sel,
        "calldata": [hex(x) if isinstance(x, int) else x for x in (calldata or [])],
    }, "block_id": block})


def batch_calls(calls, chunk=100):
    """calls: list of (addr, selector_hex, calldata). Returns list of results/errors in order."""
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = []
        for j, (addr, sel, cd) in enumerate(part):
            payload.append({"jsonrpc": "2.0", "id": j, "method": "starknet_call", "params": {
                "request": {"contract_address": hex(int(addr, 16)), "entry_point_selector": sel,
                            "calldata": [hex(x) if isinstance(x, int) else x for x in cd]},
                "block_id": "latest"}})
        ok = False
        for attempt in range(4):
            for u in RPC_URLS:
                try:
                    req = urllib.request.Request(u, data=json.dumps(payload).encode(),
                                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=120) as r:
                        resp = json.loads(r.read().decode())
                    byid = {d["id"]: d for d in resp}
                    part_out = []
                    for j in range(len(part)):
                        d = byid.get(j, {})
                        part_out.append(d.get("result") if "result" in d else {"error": d.get("error")})
                    out.extend(part_out)
                    ok = True
                    break
                except Exception:
                    time.sleep(1.0 * (attempt + 1))
            if ok:
                break
        if not ok:
            raise RuntimeError("batch failed")
    return out


# ---------------- value helpers ----------------
def felt(x):
    if isinstance(x, str):
        return int(x, 16)
    return int(x)


def u256(ret, idx=0):
    return felt(ret[idx]) + (felt(ret[idx + 1]) << 128)


def hexaddr(a):
    return hex(int(a, 16))


def get_class_at(addr, block="latest"):
    return rpc("starknet_getClassAt", [block, hex(int(addr, 16))])


def get_class(class_hash, block="latest"):
    return rpc("starknet_getClass", [block, hex(int(class_hash, 16))])


def get_class_hash_at(addr, block="latest"):
    return rpc("starknet_getClassHashAt", [block, hex(int(addr, 16))])


def decode_program(cc):
    """Cairo0 CONTRACT_CLASS -> program dict (data, hints, etc)."""
    if "program" in cc:
        raw = base64.b64decode(cc["program"])
        try:
            raw = gzip.decompress(raw)
        except Exception:
            pass
        return json.loads(raw)
    return None


if __name__ == "__main__":
    # self-test: known selectors
    tests = {
        "get_all_pairs": "0x3e415d1aae9ddb9b1ffdb1f3bb6591b593e0a09748f635cdd067a74aba6f671",
        "token0": "0xad5d3ec16e143a33da68c00099116ef328a882b65607bec5b2431267934a20",
        "get_reserves": "0x3cb0e1486e633fbe3e2fafe8aedf12b70ca1860e7467ddb75a17858cde39312",
    }
    for k, v in tests.items():
        got = selector(k)
        assert got == v, (k, got, v)
    print("keccak/selector self-test OK; block:", rpc("starknet_blockNumber", []))
