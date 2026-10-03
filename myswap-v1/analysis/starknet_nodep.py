"""Dependency-free Starknet read-only helper (stdlib only): pure-Python Keccak-256 + urllib JSON-RPC.

Used by CI (ci/run.sh) where pip deps are not guaranteed. Local scripts use starknet_lib.py (eth_utils).
Read-only: starknet_call / getClassHashAt / getClassAt / getEvents / getTransactionByHash /
getBlockWithTxHashes / blockNumber / simulateTransactions. No signing, no sending.
"""
import json
import urllib.request
import urllib.error
import time

MASK = (1 << 250) - 1

# ---------------- Keccak-256 (original, padding 0x01) ----------------
_RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_ROT = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]
_M = (1 << 64) - 1


def _keccak_f(A):
    for rnd in range(24):
        C = [A[x][0] ^ A[x][1] ^ A[x][2] ^ A[x][3] ^ A[x][4] for x in range(5)]
        D = [C[(x - 1) % 5] ^ (((C[(x + 1) % 5] << 1) | (C[(x + 1) % 5] >> 63)) & _M) for x in range(5)]
        for x in range(5):
            for y in range(5):
                A[x][y] ^= D[x]
        B = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                v = A[x][y]
                B[y][(2 * x + 3 * y) % 5] = ((v << _ROT[x][y]) | (v >> (64 - _ROT[x][y]))) & _M
        for x in range(5):
            for y in range(5):
                A[x][y] = B[x][y] ^ ((~B[(x + 1) % 5][y]) & B[(x + 2) % 5][y] & _M)
        A[0][0] ^= _RC[rnd]
    return A


def keccak256(data: bytes) -> bytes:
    rate = 136
    padlen = rate - (len(data) % rate)
    if padlen == 1:
        data = data + b"\x81"
    else:
        data = data + b"\x01" + b"\x00" * (padlen - 2) + b"\x80"
    A = [[0] * 5 for _ in range(5)]
    for off in range(0, len(data), rate):
        block = data[off:off + rate]
        for i in range(rate // 8):
            lane = int.from_bytes(block[i * 8:(i + 1) * 8], "little")
            A[i % 5][i // 5] ^= lane
        A = _keccak_f(A)
    out = b""
    for i in range(4):
        out += A[i % 5][i // 5].to_bytes(8, "little")
    return out


def sel(name: str) -> str:
    return hex(int.from_bytes(keccak256(name.encode()), "big") & MASK)


# ---------------- JSON-RPC ----------------
RPC_URLS = [
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet-rpc.publicnode.com",
]


def rpc(method, params, rpc_url=None, retries=4):
    urls = [rpc_url] if rpc_url else RPC_URLS
    last = None
    for attempt in range(retries):
        for url in urls:
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": "zombie-hunt-readonly/1.0"},
                )
                with urllib.request.urlopen(req, timeout=60) as resp:
                    j = json.loads(resp.read().decode())
                if "error" in j:
                    last = RuntimeError(f"{method}: {j['error']}")
                    continue
                return j["result"]
            except Exception as e:  # noqa
                last = e
                time.sleep(1 + attempt)
    raise last


def felt(x):
    return hex(x) if isinstance(x, int) else x


def call(contract, fn, calldata=None, block="latest", rpc_url=None):
    return call_sel(contract, sel(fn), calldata=calldata, block=block, rpc_url=rpc_url)


def call_sel(contract, selector_hex, calldata=None, block="latest", rpc_url=None):
    """Call a Cairo0/1 entrypoint. Tries both RPC param shapes."""
    req = {
        "contract_address": felt(contract),
        "entry_point_selector": selector_hex,
        "calldata": [felt(c) for c in (calldata or [])],
    }
    errs = []
    for params in ({"request": req, "block_id": block}, [req, block]):
        try:
            return rpc("starknet_call", params, rpc_url=rpc_url)
        except Exception as e:  # noqa
            errs.append(e)
    raise errs[-1]


def u256(parts, offset=0):
    lo = int(parts[offset], 16)
    hi = int(parts[offset + 1], 16)
    return lo + (hi << 128)


def to_u256_parts(x):
    return [x & ((1 << 128) - 1), x >> 128]


def hexint(x):
    return int(x, 16) if isinstance(x, str) else int(x)


def norm(addr):
    return "0x" + format(hexint(addr), "064x")


def block_number(rpc_url=None):
    return rpc("starknet_blockNumber", [], rpc_url=rpc_url)


if __name__ == "__main__":
    # sanity: selector for transfer must match the well-known value
    assert sel("transfer") == "0x83afd3f4caedc6eebf44246fe54e38c95e3179a5ec9ea81740eca5b482d12e", sel("transfer")
    assert sel("balanceOf") == "0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e", sel("balanceOf")
    assert sel("get_total_number_of_pools") == "0x105b90925282800807177a6067e409237de3431ff129a80067088d890f2d9d3"
    print("keccak/sel OK; block", block_number())
