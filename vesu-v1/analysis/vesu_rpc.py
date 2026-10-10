#!/usr/bin/env python3
"""
Minimal Starknet JSON-RPC client for the C2-50 (Vesu V1.1) deep-dive.

No external dependencies: keccak-256 is implemented in pure Python
(fallback), and pycryptodome is used when available for speed.

Read-only: only starknet_call / starknet_getClassHashAt / getClassAt /
getEvents / simulateTransactions (with skip_validate) are used.

NEVER stores RPC URLs with secrets. Public endpoints only by default.
"""
import json
import os
import sys
import time
import urllib.request

# ---------------------------------------------------------------------------
# keccak-256 (pure python) + starknet selector
# ---------------------------------------------------------------------------
_KECCAK_RC = [
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
_MASK64 = (1 << 64) - 1


def _keccak_f1600(a):
    for rnd in range(24):
        # theta
        c = [a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20] for x in range(5)]
        d = [c[(x - 1) % 5] ^ (((c[(x + 1) % 5] << 1) | (c[(x + 1) % 5] >> 63)) & _MASK64) for x in range(5)]
        for x in range(5):
            for y in range(5):
                a[x + 5 * y] ^= d[x]
        # rho + pi
        b = [0] * 25
        for x in range(5):
            for y in range(5):
                b[y + 5 * ((2 * x + 3 * y) % 5)] = (
                    (a[x + 5 * y] << _ROT[x][y]) | (a[x + 5 * y] >> (64 - _ROT[x][y]))
                ) & _MASK64
        # chi
        for x in range(5):
            for y in range(5):
                a[x + 5 * y] = b[x + 5 * y] ^ ((~b[(x + 1) % 5 + 5 * y]) & b[(x + 2) % 5 + 5 * y])
                a[x + 5 * y] &= _MASK64
        # iota
        a[0] ^= _KECCAK_RC[rnd]
    return a


def _keccak256_pure(data: bytes) -> bytes:
    rate = 136  # 1088 bits
    # pad: keccak uses 0x01 domain byte
    padlen = rate - (len(data) % rate)
    if padlen == 1:
        padded = data + b"\x81"
    else:
        padded = data + b"\x01" + b"\x00" * (padlen - 2) + b"\x80"
    state = [0] * 25
    for off in range(0, len(padded), rate):
        block = padded[off:off + rate]
        for i in range(rate // 8):
            lane = int.from_bytes(block[i * 8:(i + 1) * 8], "little")
            state[i] ^= lane
        state = _keccak_f1600(state)
    out = b""
    for i in range(4):  # 32 bytes = 4 lanes
        out += state[i].to_bytes(8, "little")
    return out


try:
    from Crypto.Hash import keccak as _pyc_keccak

    def keccak256(data: bytes) -> bytes:
        h = _pyc_keccak.new(digest_bits=256)
        h.update(data)
        return h.digest()
except Exception:  # pragma: no cover
    keccak256 = _keccak256_pure


def starknet_keccak(data) -> int:
    if isinstance(data, str):
        data = data.encode()
    return int.from_bytes(keccak256(data), "big") & ((1 << 250) - 1)


def selector(name: str) -> str:
    return hex(starknet_keccak(name))


# ---------------------------------------------------------------------------
# JSON-RPC
# ---------------------------------------------------------------------------
DEFAULT_RPC = os.environ.get("STARKNET_RPC", "https://starknet-rpc.publicnode.com")


def rpc(method, params, url=None, retries=4, timeout=30):
    url = url or DEFAULT_RPC
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    last_err = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url, data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research; read-only)"},
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = json.loads(resp.read().decode())
            if "error" in body:
                return {"error": body["error"]}
            return body.get("result")
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(1.5 * (attempt + 1))
    return {"error": {"message": f"transport failure: {last_err}"}}


def _block_id(block):
    if isinstance(block, int):
        return {"block_number": block}
    if isinstance(block, str) and block.startswith("0x"):
        return {"block_hash": block}
    return block


def call_view(to: str, func: str, calldata=None, block="latest", url=None):
    """starknet_call with caller=0 (sequencer context). Returns raw result or error dict."""
    res = rpc(
        "starknet_call",
        {"request": {"contract_address": to, "entry_point_selector": selector(func),
                     "calldata": [hexify(x) for x in (calldata or [])]},
         "block_id": _block_id(block)},
        url=url,
    )
    return res


def hexify(x):
    if isinstance(x, int):
        return hex(x)
    if isinstance(x, str):
        s = x.strip()
        if not s.startswith("0x"):
            return "0x" + s
        return s
    raise TypeError(x)


def to_int(x):
    if isinstance(x, str):
        return int(x, 16)
    return int(x)


def u256_from_felts(felts, idx=0):
    """Read a u256 as (low, high) from a felt array (Cairo serialization)."""
    low = to_int(felts[idx])
    high = to_int(felts[idx + 1])
    return low + (high << 128)


def i257_from_felts(felts, idx=0):
    """Read an i257 as (abs, sign) from a felt array."""
    val = to_int(felts[idx])
    sign = to_int(felts[idx + 1])
    return val, sign


def get_class_hash_at(addr, block="latest", url=None):
    return rpc("starknet_getClassHashAt", {"block_id": _block_id(block), "contract_address": hexify(addr)}, url=url)


def get_class_at(addr, block="latest", url=None):
    return rpc("starknet_getClassAt", {"block_id": _block_id(block), "contract_address": hexify(addr)}, url=url)


def get_block_number(url=None):
    return rpc("starknet_blockNumber", [], url=url)


def get_events(from_block, to_block, address=None, keys=None, chunk_size=100, continuation=None, url=None):
    base = {
        "from_block": {"block_number": from_block},
        "to_block": {"block_number": to_block},
        "chunk_size": chunk_size,
    }
    if address:
        base["address"] = hexify(address)
    if keys:
        base["keys"] = [[hexify(k) for k in group] for group in keys]

    def _try(token_inside):
        params = {"filter": dict(base)}
        if continuation:
            if token_inside:
                params["filter"]["continuation_token"] = continuation
            else:
                params["continuation_token"] = continuation
        return rpc("starknet_getEvents", params, url=url, timeout=60)

    r = _try(True)
    if isinstance(r, dict) and "error" in r and continuation:
        msg = str(r["error"])
        if "continuation_token" in msg or "invalid or unknown" in msg:
            r2 = _try(False)
            if not (isinstance(r2, dict) and "error" in r2):
                return r2
    return r


# ---------------------------------------------------------------------------
# high level helpers
# ---------------------------------------------------------------------------
def erc20_balance(token, holder, block="latest", url=None):
    """Try balance_of (snake) then balanceOf (camel). Returns int or error."""
    for fn in ("balance_of", "balanceOf"):
        res = call_view(token, fn, [holder], block=block, url=url)
        if isinstance(res, list) and len(res) >= 2:
            return u256_from_felts(res)
        if isinstance(res, list) and len(res) == 1:
            return to_int(res[0])
    return None


def erc20_decimals(token, block="latest", url=None):
    for fn in ("decimals",):
        res = call_view(token, fn, [], block=block, url=url)
        if isinstance(res, list) and res:
            return to_int(res[0])
    return None


def price_usd(coin_ids):
    """DefiLlama prices for a list like ['starknet:0x...']. Returns dict."""
    url = "https://coins.llama.fi/prices/current/" + ",".join(coin_ids)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        return data.get("coins", {})
    except Exception as e:  # noqa: BLE001
        return {"error": str(e)}


if __name__ == "__main__":
    # quick self-test: known Starknet selectors
    assert selector("balanceOf") == "0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e", selector("balanceOf")
    assert selector("transfer") == "0x83afd3f4caedc6eebf44246fe54e38c95e3179a5ec9ea81740eca5b482d12e", selector("transfer")
    # pure-python keccak vs pycryptodome
    try:
        from Crypto.Hash import keccak as _k

        h = _k.new(digest_bits=256)
        h.update(b"balanceOf")
        assert h.digest() == _keccak256_pure(b"balanceOf"), "keccak mismatch"
        print("pure keccak matches pycryptodome")
    except ImportError:
        print("pycryptodome unavailable; pure keccak in use")
    print("block:", get_block_number())
    for fn in ("owner", "pending_owner", "singleton_v1", "extension", "upgrade_name",
               "whitelisted_extension", "migrator", "position_unsafe", "asset_config_unsafe",
               "check_collateralization_unsafe", "creator_nonce", "delegation"):
        print(f"selector({fn}):", selector(fn))
