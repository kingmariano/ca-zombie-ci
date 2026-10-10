#!/usr/bin/env python3
"""Minimal keyless Starknet RPC helper (read-only).

Endpoints are public and keyless. No secrets are read or written.
"""
import json
import time
import urllib.request

ENDPOINTS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
]

_id = 0


def rpc(method, params, endpoint=None, retries=3):
    global _id
    eps = [endpoint] if endpoint else ENDPOINTS
    last_err = None
    for ep in eps:
        for attempt in range(retries):
            _id += 1
            payload = json.dumps(
                {"jsonrpc": "2.0", "id": _id, "method": method, "params": params}
            ).encode()
            req = urllib.request.Request(
                ep,
                data=payload,
                headers={
                    "Content-Type": "application/json",
                    "User-Agent": "Mozilla/5.0 (research; read-only)",
                },
            )
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    out = json.loads(resp.read())
                if "error" in out:
                    last_err = out["error"]
                    # method not supported -> try next endpoint
                    break
                return out["result"]
            except Exception as e:  # noqa: BLE001
                last_err = str(e)
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"RPC {method} failed: {last_err}")


def felt(hexstr):
    """Normalize a hex address/felt to 0x + 64 chars."""
    return "0x" + format(int(hexstr, 16), "064x")


def block_number():
    return rpc("starknet_blockNumber", [])


def call(to, selector, calldata=(), block="latest"):
    return rpc(
        "starknet_call",
        [{"contract_address": felt(to), "entry_point_selector": felt(selector), "calldata": [felt(x) if isinstance(x, str) and x.startswith("0x") else hex(x) for x in calldata]}, block],
    )


def call_felts(to, entrypoint, calldata=(), block="latest"):
    """Call by entry point NAME using the newer RPC (v0.8 supports named entry points? no).
    We emulate by computing selector via starknet_keccak? Not available. Use starknet_call with selector."""
    raise NotImplementedError


def _keccak_bytes(data: bytes) -> bytes:
    """keccak-256 via pycryptodome/pysha3, falling back to the pure-python impl."""
    try:
        from Crypto.Hash import keccak

        k = keccak.new(digest_bits=256)
        k.update(data)
        return k.digest()
    except Exception:  # noqa: BLE001
        try:
            import sha3  # type: ignore

            return sha3.keccak_256(data).digest()
        except Exception:  # noqa: BLE001
            return _keccak256(data).to_bytes(32, "little")


def selector(name):
    """starknet_keccak of entry point name = keccak256(name) & (2**250 - 1)."""
    return "0x" + format(
        int.from_bytes(_keccak_bytes(name.encode()), "big") & ((1 << 250) - 1), "064x"
    )


# --- minimal Keccak-256 (public-domain style implementation) ---
_KECCAK_ROUNDS = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_RC = _KECCAK_ROUNDS
_ROT = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]
_MASK = (1 << 64) - 1


def _rol(x, n):
    n %= 64
    return ((x << n) | (x >> (64 - n))) & _MASK


def _keccak_f(a):
    for rnd in range(24):
        c = [a[x][0] ^ a[x][1] ^ a[x][2] ^ a[x][3] ^ a[x][4] for x in range(5)]
        d = [c[(x - 1) % 5] ^ _rol(c[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                a[x][y] ^= d[x]
        b = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                b[y][(2 * x + 3 * y) % 5] = _rol(a[x][y], _ROT[x][y])
        for x in range(5):
            for y in range(5):
                a[x][y] = b[x][y] ^ ((~b[(x + 1) % 5][y]) & b[(x + 2) % 5][y]) & _MASK
        a[0][0] ^= _RC[rnd]
    return a


def _keccak256(data: bytes) -> int:
    rate = 136
    # pad10*1
    padlen = rate - (len(data) % rate)
    if padlen == 1:
        padded = data + b"\x81"
    else:
        padded = data + b"\x01" + b"\x00" * (padlen - 2) + b"\x80"
    a = [[0] * 5 for _ in range(5)]
    for off in range(0, len(padded), rate):
        block = padded[off:off + rate]
        for i in range(rate // 8):
            lane = int.from_bytes(block[i * 8:(i + 1) * 8], "little")
            x, y = i % 5, i // 5
            a[x][y] ^= lane
        a = _keccak_f(a)
    out = b""
    for i in range(4):
        x, y = i % 5, i // 5
        out += a[x][y].to_bytes(8, "little")
    return int.from_bytes(out, "little")


if __name__ == "__main__":
    import sys

    print("block:", block_number())
    # sanity: selector('balanceOf') should equal known value 0x2e4263afad30923c891518314c3c95dee2bd7c5b5b0f10c9c3ceb3f34336e6b? no, print
    print("selector balanceOf:", selector("balanceOf"))
