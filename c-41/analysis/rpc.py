"""Minimal batched JSON-RPC helper for read-only Ionic state enumeration.

Usage:
    from rpc import RPC, sel
    r = RPC("https://mainnet.mode.network")
    res = r.read(to, "getCash()(uint256)")
    markets = r.read(to, "getAllMarkets()(address[])")
"""
import json
import os
import time

import requests
from eth_abi import encode as abi_encode, decode as abi_decode
from eth_utils import keccak, to_checksum_address


def sel(sig: str) -> str:
    """Selector from a full 'name(args)(rets)' or 'name(args)' signature."""
    name, argtypes = _types_of(sig)
    return keccak(text=f"{name}({','.join(argtypes)})")[:4].hex()


def _types_of(sig: str):
    """Split 'name(arg1,arg2)(rets)' -> (name, [args]) ignoring tuple innards."""
    name = sig.split("(")[0]
    start = sig.find("(")
    depth = 0
    end = None
    for i in range(start, len(sig)):
        if sig[i] == "(":
            depth += 1
        elif sig[i] == ")":
            depth -= 1
            if depth == 0:
                end = i
                break
    inner = sig[start + 1 : end]
    if inner.strip() == "":
        return name, []
    # naive split (no nested tuples used here)
    args = []
    depth = 0
    cur = ""
    for ch in inner:
        if ch == "," and depth == 0:
            args.append(cur.strip())
            cur = ""
        else:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            cur += ch
    if cur.strip():
        args.append(cur.strip())
    return name, args


class RPC:
    def __init__(self, url: str, batch_size: int = 3, timeout: int = 120):
        self.url = url
        self.batch_size = batch_size
        self.timeout = timeout

    def _raw_batch(self, methods):
        out = [None] * len(methods)
        pending = list(range(len(methods)))
        headers = {
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
        }
        for attempt in range(7):
            if not pending:
                break
            # build chunks from pending ids
            still = []
            for i in range(0, len(pending), self.batch_size):
                chunk = pending[i : i + self.batch_size]
                payload = [
                    {
                        "jsonrpc": "2.0",
                        "id": j,
                        "method": methods[idx][0],
                        "params": methods[idx][1],
                    }
                    for j, idx in enumerate(chunk)
                ]
                try:
                    r = requests.post(self.url, json=payload, headers=headers, timeout=self.timeout)
                    if r.status_code != 200:
                        still.extend(chunk)
                        time.sleep(1.0 * (attempt + 1))
                        continue
                    res = r.json()
                    if isinstance(res, dict):
                        res = [res]
                    got = {}
                    for item in res:
                        got[item.get("id")] = item
                    for j, idx in enumerate(chunk):
                        item = got.get(j)
                        if item is None:
                            still.append(idx)
                            continue
                        if "error" in item:
                            msg = str(item["error"].get("message", ""))
                            if (
                                "Temporary internal error" in msg
                                or "rate limit" in msg.lower()
                                or "too many" in msg.lower()
                            ):
                                still.append(idx)
                            else:
                                out[idx] = ("error", item["error"].get("message", str(item["error"])))
                        else:
                            out[idx] = ("ok", item.get("result", "0x"))
                except Exception:  # noqa: BLE001
                    still.extend(chunk)
                    time.sleep(1.0 * (attempt + 1))
            pending = still
            if pending:
                time.sleep(0.7 * (attempt + 1))
        for idx in pending:
            out[idx] = ("error", "transient-rpc-failure")
        return out

    def block_number(self) -> int:
        r = requests.post(
            self.url,
            json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []},
            timeout=self.timeout,
        )
        r.raise_for_status()
        return int(r.json()["result"], 16)

    def eth_call_batch(self, calls, block="latest"):
        """calls: list of (to, calldata_hex) -> list of (status, result_hex)."""
        methods = [
            ("eth_call", [{"to": to, "data": data}, block]) for (to, data) in calls
        ]
        return self._raw_batch(methods)

    def get_logs(self, address, topics, from_block="0x0", to_block="latest"):
        r = requests.post(
            self.url,
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getLogs",
                "params": [
                    {
                        "address": address,
                        "topics": topics,
                        "fromBlock": from_block,
                        "toBlock": to_block,
                    }
                ],
            },
            timeout=self.timeout,
        )
        r.raise_for_status()
        j = r.json()
        if "error" in j:
            raise RuntimeError(j["error"])
        return j["result"]

    def read_many(self, specs, block="latest"):
        """specs: list of (to, signature, arg_values). Returns list of decoded python values
        or ('ERROR', msg)."""
        calls = []
        meta = []
        for (to, sig, args) in specs:
            _, argtypes = _types_of(sig)
            data = "0x" + sel(sig)
            if args:
                data += abi_encode(argtypes, args).hex()
            calls.append((to, data))
            # output types = args after the name parens: sig is like name(args)(rets)
            # we require callers to pass signature in full 'name(args)(rets)' form
            meta.append(sig)
        raw = self.eth_call_batch(calls, block)
        out = []
        for (status, val), sig in zip(raw, meta):
            if status == "error":
                out.append(("ERROR", val))
                continue
            if val in ("0x", None):
                out.append(("ERROR", "empty"))
                continue
            name = sig.split("(")[0]
            # find matching ')' of the args section
            start = sig.find("(")
            depth = 0
            end = None
            for i in range(start, len(sig)):
                if sig[i] == "(":
                    depth += 1
                elif sig[i] == ")":
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
            rets_str = sig[end + 1 :]
            rets = _parse_rets(rets_str)
            try:
                dec = abi_decode(rets, bytes.fromhex(val[2:]))
            except Exception as e:  # noqa: BLE001
                out.append(("ERROR", f"decode:{e}"))
                continue
            if len(dec) == 1:
                out.append(dec[0])
            else:
                out.append(dec)
        return out

    def read(self, to, sig, args=()):
        v = self.read_many([(to, sig, list(args))])[0]
        return v

    def encode_call(self, sig, args=()):
        _, argtypes = _types_of(sig)
        data = "0x" + sel(sig)
        if args:
            data += abi_encode(argtypes, args).hex()
        return data


def _parse_rets(rets_str):
    rets_str = rets_str.strip()
    assert rets_str.startswith("(") and rets_str.endswith(")"), rets_str
    inner = rets_str[1:-1].strip()
    if inner == "":
        return []
    out = []
    depth = 0
    cur = ""
    for ch in inner:
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def checksum(a):
    return to_checksum_address(a)
