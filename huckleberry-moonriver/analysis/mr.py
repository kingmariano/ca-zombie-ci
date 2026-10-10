#!/usr/bin/env python3
"""Batch JSON-RPC reader for Moonriver (frozen head).

Read-only. Public endpoints only. No secrets written anywhere.
"""
import json, time, urllib.request, urllib.error

UA = "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt-research/1.0"
ENDPOINTS = [
    "https://moonriver.api.onfinality.io/public",
    "https://moonriver.drpc.org",
]
HEAD = "0x1093916"  # 17,381,654 frozen head, 2026-08-10T08:27:48Z


def _post(url, payload, timeout=40, tries=4):
    data = json.dumps(payload).encode()
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(
                url, data=data,
                headers={"Content-Type": "application/json", "User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"rpc failed: {last}")


class Rpc:
    def __init__(self, endpoints=None, head=HEAD):
        self.endpoints = list(endpoints or ENDPOINTS)
        self.head = head
        self._i = 0

    def _url(self):
        return self.endpoints[self._i % len(self.endpoints)]

    def rotate(self):
        self._i += 1

    def batch_call(self, calls, block=None, chunk=40):
        """calls: list of (to, data). Returns list of hex results or None on error.
        Uses eth_call with explicit block (default frozen head)."""
        block = block or self.head
        out = []
        for s in range(0, len(calls), chunk):
            part = calls[s:s + chunk]
            payload = [
                {"jsonrpc": "2.0", "id": j, "method": "eth_call",
                 "params": [{"to": to, "data": data}, block]}
                for j, (to, data) in enumerate(part)
            ]
            for attempt in range(3):
                try:
                    res = _post(self._url(), payload)
                    break
                except Exception:
                    self.rotate()
            else:
                raise RuntimeError("batch failed after retries")
            if isinstance(res, dict):
                raise RuntimeError(f"batch error: {str(res)[:200]}")
            byid = {r.get("id"): r for r in res if isinstance(r, dict)}
            for j in range(len(part)):
                r = byid.get(j, {})
                out.append(r.get("result") if "result" in r else None)
            time.sleep(0.15)
        return out

    def batch_rpc(self, reqs, chunk=40):
        """reqs: list of (method, params). Returns list of results or error strings."""
        out = []
        for s in range(0, len(reqs), chunk):
            part = reqs[s:s + chunk]
            payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                       for j, (m, p) in enumerate(part)]
            for attempt in range(3):
                try:
                    res = _post(self._url(), payload)
                    break
                except Exception:
                    self.rotate()
            else:
                raise RuntimeError("batch failed after retries")
            if isinstance(res, dict):
                raise RuntimeError(f"batch error: {str(res)[:200]}")
            byid = {r.get("id"): r for r in res if isinstance(r, dict)}
            for j in range(len(part)):
                r = byid.get(j, {})
                if "result" in r:
                    out.append(r["result"])
                else:
                    out.append({"error": r.get("error")})
            time.sleep(0.15)
        return out

    def call(self, to, data, block=None):
        return self.batch_call([(to, data)], block=block)[0]

    def block(self, num):
        r = self.batch_rpc([("eth_getBlockByNumber", [num, False])])
        return r[0]


# ---------- ABI helpers ----------
def addr_word(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def enc_addr(selector, addr):
    return selector + addr_word(addr)


def enc_uint(selector, n):
    return selector + format(n, "x").rjust(64, "0")


def dec_addr(word):
    if not word or len(word) < 66:
        return None
    return "0x" + word[-40:].lower()


def dec_uint(word):
    if not word or word == "0x":
        return None
    try:
        return int(word, 16)
    except Exception:
        return None


def dec_string(word):
    """Decode an ABI-encoded string return (dynamic) from hex word blob."""
    if not word or len(word) < 130:
        return None
    try:
        b = bytes.fromhex(word[2:])
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        return b[off + 32:off + 32 + ln].decode("utf-8", "replace")
    except Exception:
        return None


# selectors
SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
    "balanceOf": "0x70a08231",
    "getReserves": "0x0902f1ac",
    "underlying": "0x6f307dc3",
    "getCash": "0x3b1d21a2",
    "totalBorrows": "0x47bd3718",
    "totalReserves": "0x8f840ddd",
    "exchangeRateStored": "0x182df0f5",
    "totalSupply": "0x18160ddd",
    "oracle": "0x7dc0d1d0",
    "getUnderlyingPrice": "0xfc57d4df",
    "comptroller": "0x5fe3b567",
    "factory": "0xc45a0155",
    "name": "0x06fdde03",
    "admin": "0xf851a440",
}

if __name__ == "__main__":
    r = Rpc()
    b = r.block(HEAD)
    print(json.dumps({k: b.get(k) for k in ["number", "hash", "timestamp", "gasUsed", "size"]}, indent=2))
