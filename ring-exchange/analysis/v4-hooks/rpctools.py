#!/usr/bin/env python3
"""Read-only helpers for HyperEVM (chainid 999) research.
Loads keys from /home/heisenberg/CA/.env WITHOUT printing them.
Never sends transactions; JSON-RPC read methods only.
"""
import json, time, urllib.request, urllib.parse, os, hashlib

ENV_PATH = "/home/heisenberg/CA/.env"
RPC = os.environ.get("HYPER_RPC", "https://rpc.hyperliquid.xyz/evm")
RPC_FALLBACKS = [
    "https://rpc.hyperliquid.xyz/evm",
    "https://hyperliquid.drpc.org",
]

_KEYS = {}
for line in open(ENV_PATH):
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    _KEYS[k.strip()] = v.strip().strip('"').strip("'")

def key(name):
    return _KEYS.get(name)

def rpc(method, params, url=None, retries=5):
    urls = [url] if url else RPC_FALLBACKS
    last = None
    for u in urls:
        for i in range(retries):
            try:
                payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
                req = urllib.request.Request(
                    u, data=json.dumps(payload).encode(),
                    headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    out = json.loads(r.read())
                if "error" in out:
                    return {"error": out["error"]}
                return out.get("result")
            except Exception as e:
                last = e
                time.sleep(1.0 * (i + 1))
    raise RuntimeError(f"rpc failed: {last}")

def rpc_batch(calls, url=None, chunk=10):
    """calls: list of [method, params-list]. Returns list of results/errors."""
    urls = [url] if url else RPC_FALLBACKS
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                   for j, (m, p) in enumerate(part)]
        last = None
        for u in urls:
            for attempt in range(5):
                try:
                    req = urllib.request.Request(
                        u, data=json.dumps(payload).encode(),
                        headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
                    with urllib.request.urlopen(req, timeout=60) as r:
                        res = json.loads(r.read())
                    by = {r.get("id"): r for r in res}
                    for j in range(len(part)):
                        rr = by.get(j, {})
                        out.append(rr.get("result") if "error" not in rr else {"error": rr["error"]})
                    last = None
                    break
                except Exception as e:
                    last = e
                    time.sleep(1.0 * (attempt + 1))
            if last is None:
                break
        if last is not None:
            raise RuntimeError(f"batch failed: {last}")
        time.sleep(0.2)
    return out

def eth_getCode(addr, block="latest"):
    return rpc("eth_getCode", [addr, hex(block) if isinstance(block, int) else block])

def eth_getBalance(addr, block="latest"):
    return rpc("eth_getBalance", [addr, hex(block) if isinstance(block, int) else block])

def eth_blockNumber():
    return int(rpc("eth_blockNumber", []), 16)

def eth_getStorageAt(addr, slot, block="latest"):
    return rpc("eth_getStorageAt", [addr, hex(slot), hex(block) if isinstance(block, int) else block])

def etherscan(chainid, params):
    """Etherscan V2 API read query. params: dict of query params (module/action/...)."""
    p = dict(params)
    p["chainid"] = chainid
    p["apikey"] = key("ETHERSCANV2_API_KEY")
    url = "https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(p)
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("etherscan query failed")

# ---- minimal keccak-256 + ABI encode/decode helpers ----
def _keccak256(data: bytes) -> bytes:
    RC = [0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
          0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
          0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
          0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
          0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
          0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008]
    R = [[0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61],
         [28, 55, 25, 21, 56], [27, 20, 39, 8, 14]]
    M = (1 << 64) - 1

    def rol(x, n):
        return ((x << n) | (x >> (64 - n))) & M

    data = bytearray(data)
    rate = 136
    data.append(0x01)
    while len(data) % rate != 0:
        data.append(0)
    data[-1] |= 0x80
    st = [0] * 25
    for off in range(0, len(data), rate):
        block = data[off:off + rate]
        for i in range(rate // 8):
            st[i] ^= int.from_bytes(block[i * 8:i * 8 + 8], "little")
        for rnd in range(24):
            C = [st[x] ^ st[x + 5] ^ st[x + 10] ^ st[x + 15] ^ st[x + 20] for x in range(5)]
            D = [C[(x + 4) % 5] ^ rol(C[(x + 1) % 5], 1) for x in range(5)]
            for x in range(5):
                for y in range(5):
                    st[x + 5 * y] ^= D[x]
            B = [0] * 25
            for x in range(5):
                for y in range(5):
                    B[y + 5 * ((2 * x + 3 * y) % 5)] = rol(st[x + 5 * y], R[x][y])
            for x in range(5):
                for y in range(5):
                    st[x + 5 * y] = B[x + 5 * y] ^ ((~B[(x + 1) % 5 + 5 * y]) & B[(x + 2) % 5 + 5 * y])
            st[0] ^= RC[rnd]
    return b"".join(st[i].to_bytes(8, "little") for i in range(4))[:32]

def sel(sig):
    return "0x" + _keccak256(sig.encode()).hex()[:8]

def pad32(h):
    h = h.lower().replace("0x", "")
    return h.rjust(64, "0")

def enc_addr(a):
    return pad32(a)

def dec_uint(hexstr):
    if not hexstr or hexstr in ("0x", "0x0"):
        return 0
    return int(hexstr, 16)

def dec_addr(hexstr):
    return "0x" + hexstr[-40:] if hexstr and len(hexstr) >= 42 else None

def call(addr, data, block="latest"):
    return rpc("eth_call", [{"to": addr, "data": data}, hex(block) if isinstance(block, int) else block])
