#!/usr/bin/env python3
"""HyperEVM JSON-RPC helper (read-only) with revert-tolerant error handling.
Copy of hl_rpc.py; eth_call reverts return '0x' instead of retrying, so probes with
nonexistent selectors are fast. Network errors still retry.
"""
import json, urllib.request, time

RPC = "https://rpc.hyperliquid.xyz/evm"
_id = 0


def _is_revert(err):
    if err is None:
        return False
    code = err.get("code") if isinstance(err, dict) else None
    msg = json.dumps(err).lower()
    return code == 3 or "revert" in msg or "execution" in msg or "invalid opcode" in msg


def _is_rate_limit(err):
    if isinstance(err, dict):
        return err.get("code") == -32005 or "rate" in str(err.get("message", "")).lower()
    return False


def rpc(method, params):
    global _id
    _id += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _id, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    last = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                out = json.loads(r.read())
            if "result" in out:
                return out["result"]
            if _is_revert(out.get("error")):
                return "0x" if method == "eth_call" else None
            last = RuntimeError(f"rpc error: {out.get('error')}")
            if _is_rate_limit(out.get("error")):
                time.sleep(6 + 5 * attempt)
                continue
        except Exception as e:
            last = e
        time.sleep(1.5 * (attempt + 1))
    raise last if last else RuntimeError("rpc failed")


def batch(calls, chunk=10):
    all_res = []
    for i in range(0, len(calls), chunk):
        if i:
            time.sleep(1.0)
        all_res.extend(_batch_once(calls[i:i + chunk]))
    return all_res


def _batch_once(calls):
    global _id
    payload = []
    meta = []
    for m, p in calls:
        _id += 1
        payload.append({"jsonrpc": "2.0", "id": _id, "method": m, "params": p})
        meta.append(m)
    body = json.dumps(payload).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read())
            if isinstance(out, dict):
                if _is_revert(out.get("error")):
                    return [None] * len(calls)
                if _is_rate_limit(out.get("error")):
                    time.sleep(8 + 6 * attempt)
                    continue
                raise RuntimeError(f"batch error: {out.get('error')}")
            byid = {o["id"]: o for o in out if isinstance(o, dict)}
            res = []
            for o, m in zip(payload, meta):
                item = byid.get(o["id"], {}) or {}
                if "result" in item:
                    res.append(item["result"])
                elif _is_revert(item.get("error")):
                    res.append("0x" if m == "eth_call" else None)
                else:
                    res.append(None)
            return res
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return [None] * len(calls)


def eth_call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])


def get_code(addr, block="latest"):
    return rpc("eth_getCode", [addr, block])


def get_balance(addr, block="latest"):
    r = rpc("eth_getBalance", [addr, block])
    return int(r, 16) if r else 0


def block_number():
    return int(rpc("eth_blockNumber", []), 16)


def storage(addr, slot, block="latest"):
    return rpc("eth_getStorageAt", [addr, slot, block])


_SEL_CACHE = {}


def enc_sel(sig):
    if sig in _SEL_CACHE:
        return _SEL_CACHE[sig]
    import subprocess
    s = subprocess.run(["cast", "sig", sig], capture_output=True, text=True).stdout.strip()
    if not s.startswith("0x"):
        raise RuntimeError(f"cast sig failed for {sig}: {s[:100]}")
    _SEL_CACHE[sig] = s
    return s


def enc_args(args):
    out = ""
    for a in args:
        if isinstance(a, int):
            out += f"{a:064x}"
        elif isinstance(a, str) and a.startswith("0x"):
            out += a[2:].rjust(64, "0")
        elif isinstance(a, bool):
            out += f"{int(a):064x}"
        else:
            out += str(a).rjust(64, "0")
    return out


def call_u256(to, sig, args=(), block="latest"):
    data = enc_sel(sig) + enc_args(args)
    out = eth_call(to, data, block)
    if out in (None, "0x"):
        return None
    return int(out, 16)


def call_str(to, sig, args=(), block="latest"):
    data = enc_sel(sig) + enc_args(args)
    out = eth_call(to, data, block)
    if not out or out == "0x":
        return None
    b = bytes.fromhex(out[2:])
    try:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        return b[off + 32:off + 32 + ln].decode(errors="replace")
    except Exception:
        return None


def call_addr(to, sig, args=(), block="latest"):
    data = enc_sel(sig) + enc_args(args)
    out = eth_call(to, data, block)
    if not out or out == "0x" or len(out) < 42:
        return None
    return "0x" + out[-40:]


def call_bool(to, sig, args=(), block="latest"):
    r = call_u256(to, sig, args, block)
    return bool(r) if r is not None else None


if __name__ == "__main__":
    print("block:", block_number())
