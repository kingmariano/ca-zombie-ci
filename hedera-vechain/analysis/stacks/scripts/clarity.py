#!/usr/bin/env python3
"""Minimal Clarity value encoder/decoder + Hiro call-read client (keyless public API).

Usage:
  python3 clarity.py read <principal> <contract-name> <function> [arg...]
     arg forms: uint:123 | principal:SP... | principal:SP....name | some:... | none
                bool:true | string:hello | list:uint:1,uint:2
  python3 clarity.py decode 0x0100000000000000000000000000000007
"""
import json
import sys
import urllib.request

API = "https://api.hiro.so"

# ---------- c32check codec (verified against c32check reference) ----------
C32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
import hashlib

def c32check_encode(version: int, payload: bytes) -> str:
    chk = hashlib.sha256(hashlib.sha256(bytes([version]) + payload).digest()).digest()[:4]
    v = int.from_bytes(payload + chk, "big")
    digits = ""
    for _ in range(39):
        digits = C32[v % 32] + digits
        v //= 32
    assert v == 0
    return "S" + C32[version] + digits

def c32check_decode(addr: str):
    version = C32.index(addr[1])
    v = 0
    for ch in addr[2:]:
        v = v * 32 + C32.index(ch)
    payload = v.to_bytes(24, "big")
    h160, chk = payload[:20], payload[20:]
    exp = hashlib.sha256(hashlib.sha256(bytes([version]) + h160).digest()).digest()[:4]
    assert chk == exp, f"checksum mismatch for {addr}"
    return version, h160

def principal_from_bytes(version: int, h160: bytes, name: str | None = None) -> str:
    addr = c32check_encode(version, h160)
    return addr if name is None else f"{addr}.{name}"



def principal_to_bytes(p: str) -> bytes:
    if "." in p:
        addr, name = p.split(".", 1)
        version, h160 = c32check_decode(addr)
        nb = name.encode()
        return bytes([0x06, version]) + h160 + bytes([len(nb)]) + nb
    else:
        version, h160 = c32check_decode(p)
        return bytes([0x05, version]) + h160

def encode_arg(arg: str) -> bytes:
    if arg.startswith("uint:"):
        v = int(arg[5:])
        return b"\x01" + v.to_bytes(16, "big")
    if arg.startswith("int:"):
        v = int(arg[4:])
        return b"\x00" + v.to_bytes(16, "big", signed=True)
    if arg.startswith("principal:"):
        return principal_to_bytes(arg[len("principal:"):])
    if arg == "none":
        return b"\x09"
    if arg.startswith("some:"):
        return b"\x0a" + encode_arg(arg[5:])
    if arg == "bool:true":
        return b"\x03"
    if arg == "bool:false":
        return b"\x04"
    if arg.startswith("string:"):
        s = arg[7:].encode()
        return b"\x0d" + len(s).to_bytes(4, "big") + s
    if arg.startswith("list:"):
        items = arg[5:].split(",")
        enc = b"".join(encode_arg(i) for i in items)
        return b"\x0b" + len(items).to_bytes(4, "big") + enc
    raise SystemExit(f"cannot encode arg: {arg}")

# ---------- decoder (repr-json) ----------
def read_len(b, i):
    return int.from_bytes(b[i:i+4], "big"), i+4

def decode(b: bytes, i: int = 0):
    t = b[i]; i += 1
    if t == 0x07:  # ok
        v, i = decode(b, i); return {"ok": v}, i
    if t == 0x08:  # err
        v, i = decode(b, i); return {"err": v}, i
    if t == 0x02:  # buffer
        n, i = read_len(b, i); return b[i:i+n].hex(), i+n
    if t == 0x00:  # int
        return int.from_bytes(b[i:i+16], "big", signed=True), i+16
    if t == 0x01:  # uint
        return int.from_bytes(b[i:i+16], "big"), i+16
    if t in (0x03, 0x04):
        return (t == 0x03), i
    if t == 0x05:
        version = b[i]; h160 = b[i+1:i+21]; return principal_from_bytes(version, h160), i+21
    if t == 0x06:
        version = b[i]; h160 = b[i+1:i+21]; n = b[i+21]; name = b[i+22:i+22+n].decode(); return principal_from_bytes(version, h160, name), i+22+n
    if t == 0x09:
        return None, i
    if t == 0x0a:
        v, i = decode(b, i); return ("some", v), i
    if t == 0x0b:
        n, i = read_len(b, i); out = []
        for _ in range(n):
            v, i = decode(b, i); out.append(v)
        return out, i
    if t == 0x0c:
        n, i = read_len(b, i); out = {}
        for _ in range(n):
            kl = b[i]; i += 1
            k = b[i:i+kl].decode(); i += kl
            v, i = decode(b, i); out[k] = v
        return out, i
    if t == 0x0d:
        n, i = read_len(b, i); return b[i:i+n].decode(), i+n
    if t == 0x0e:
        n, i = read_len(b, i); return b[i:i+n].decode("utf-8", "replace"), i+n
    if t == 0x0f:
        n, i = read_len(b, i); return b[i:i+n].hex(), i+n
    raise SystemExit(f"unknown type byte {t:#x} at {i-1}; raw={b.hex()}")

def call_read(contract_id: str, fn: str, args: list, sender: str):
    addr, name = contract_id.split(".", 1)
    body = {"sender": sender, "arguments": ["0x" + encode_arg(a).hex() for a in args]}
    req = urllib.request.Request(
        f"{API}/v2/contracts/call-read/{addr}/{name}/{fn}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "research-readonly"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        resp = json.loads(r.read())
    if resp.get("okay"):
        val, _ = decode(bytes.fromhex(resp["result"][2:]))
        resp["decoded"] = val
    return resp

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "read":
        contract_id, fn = sys.argv[2], sys.argv[3]
        args = sys.argv[4:]
        sender = "SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR"
        resp = call_read(contract_id, fn, args, sender)
        print(json.dumps(resp, indent=2))
    elif mode == "decode":
        val, _ = decode(bytes.fromhex(sys.argv[2].replace("0x", "")))
        print(json.dumps(val, indent=2, default=str))
