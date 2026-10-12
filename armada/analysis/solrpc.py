#!/usr/bin/env python3
"""Solana read-only RPC helper for the Armada CLP vault audit.

Never writes keys anywhere. Endpoints: ALCHEMY_API_KEY env (Solana mainnet) then public fallbacks.
All output redacts URLs that could contain keys.
"""
import base64
import hashlib
import json
import os
import sys
import time

import requests

PUB = [
    "https://api.mainnet-beta.solana.com",
    "https://solana-rpc.publicnode.com",
]

def _endpoints():
    eps = []
    ak = os.environ.get("ALCHEMY_API_KEY")
    if ak:
        eps.append(f"https://solana-mainnet.g.alchemy.com/v2/{ak}")
    eps += PUB
    return eps

def redact(s):
    s = str(s)
    ak = os.environ.get("ALCHEMY_API_KEY")
    if ak:
        s = s.replace(ak, "<key>")
    return s

_session = requests.Session()
_session.headers.update({"User-Agent": "Mozilla/5.0 (zombie-research; read-only)"})

def rpc(method, params, timeout=60, retries=3):
    last = None
    for attempt in range(retries):
        for u in _endpoints():
            try:
                r = _session.post(u, json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=timeout)
                if r.status_code != 200:
                    last = f"HTTP {r.status_code} via {u}"
                    continue
                j = r.json()
                if j.get("error"):
                    err = j["error"]
                    # method-not-found etc: try next endpoint
                    last = redact(err)
                    continue
                return j.get("result")
            except Exception as e:
                last = redact(e)
        time.sleep(1.0 + attempt)
    raise RuntimeError(redact(f"solana {method}: {last}"))

# ---------- encodings ----------
_B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58encode(b: bytes) -> str:
    n = int.from_bytes(b, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = _B58[r] + out
    pad = 0
    for c in b:
        if c == 0:
            pad += 1
        else:
            break
    return "1" * pad + (out or "")

_B58MAP = {c: i for i, c in enumerate(_B58)}

def b58decode(s: str) -> bytes:
    n = 0
    for c in s:
        n = n * 58 + _B58MAP[c]
    b = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    pad = 0
    for c in s:
        if c == "1":
            pad += 1
        else:
            break
    return b"\x00" * pad + b

def disc(seed: str) -> bytes:
    return hashlib.sha256(seed.encode()).digest()[:8]

# ---------- high level ----------
def get_account(pubkey, encoding="base64", data_slice=None):
    cfg = {"encoding": encoding}
    if data_slice:
        cfg["dataSlice"] = data_slice
    r = rpc("getAccountInfo", [pubkey, cfg])
    return r.get("value") if isinstance(r, dict) else None

def get_accounts(pubkeys, encoding="base64", data_slice=None):
    cfg = {"encoding": encoding}
    if data_slice:
        cfg["dataSlice"] = data_slice
    out = []
    for i in range(0, len(pubkeys), 100):
        chunk = pubkeys[i:i + 100]
        r = rpc("getMultipleAccounts", [chunk, cfg])
        out += r.get("value", []) if isinstance(r, dict) else (r or [])
    return out

def get_program_accounts(program, filters=None, encoding="base64", data_slice=None, timeout=120):
    cfg = {"encoding": encoding}
    if filters:
        cfg["filters"] = filters
    if data_slice:
        cfg["dataSlice"] = data_slice
    return rpc("getProgramAccounts", [program, cfg], timeout=timeout)

def get_token_accounts_by_owner(owner, mint=None, program_id="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"):
    cfg = {"encoding": "jsonParsed"}
    if mint:
        cfg["mint"] = mint
    return rpc("getTokenAccountsByOwner", [owner, cfg, {"encoding": "jsonParsed"}]) if False else rpc(
        "getTokenAccountsByOwner", [owner, ({"mint": mint} if mint else {"programId": program_id}), {"encoding": "jsonParsed"}])

def get_balance(pubkey):
    return rpc("getBalance", [pubkey])

def find_pda(seeds, program):
    """seeds: list of bytes or str (str -> utf8)."""
    enc = [s.encode() if isinstance(s, str) else s for s in seeds]
    for bump in range(255, -1, -1):
        h = hashlib.sha256(b"".join(enc) + bytes([bump]) + b58decode(program) + b"ProgramDerivedAddress").digest()
        if not _is_on_curve(h):
            return b58encode(h), bump
    raise RuntimeError("no pda")

# ed25519 on-curve check
_P = 2**255 - 19
_D = (-121665 * pow(121666, _P - 2, _P)) % _P
_I = pow(2, (_P - 1) // 4, _P)

def _is_on_curve(b: bytes) -> bool:
    if len(b) != 32:
        return False
    y = int.from_bytes(b, "little") & ((1 << 255) - 1)
    if y >= _P:
        return False
    u = (y * y - 1) % _P
    v = (_D * y * y + 1) % _P
    x2 = (u * pow(v, _P - 2, _P)) % _P
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P != 0:
        x = (x * _I) % _P
    return (x * x - x2) % _P == 0

def spl_mint_parsed(pubkey):
    a = get_account(pubkey, encoding="jsonParsed")
    if not a:
        return None
    try:
        return a["data"]["parsed"]["info"]
    except Exception:
        return None

def spl_token_amount(pubkey):
    a = get_account(pubkey, encoding="jsonParsed")
    if not a:
        return None
    try:
        info = a["data"]["parsed"]["info"]
        return {"mint": info["mint"], "owner": info["owner"], "amount": int(info["tokenAmount"]["amount"]),
                "decimals": info["tokenAmount"]["decimals"], "ui": info["tokenAmount"]["uiAmountString"]}
    except Exception:
        return None

def programdata_address(program_id):
    a = get_account(program_id, encoding="base64")
    if not a:
        return None
    raw = base64.b64decode(a["data"][0]) if isinstance(a["data"], list) else None
    if raw is None or len(raw) < 36:
        return None
    tag = int.from_bytes(raw[:4], "little")
    if tag != 2:  # Program state enum: 2 = Program
        return None
    return b58encode(raw[4:36])

if __name__ == "__main__":
    prog = "ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d"
    a = get_account(prog)
    print("program account:", json.dumps(a, default=str)[:400] if a else None)
    pd = programdata_address(prog)
    print("programdata:", pd)
    if pd:
        pda = get_account(pd)
        raw = base64.b64decode(pda["data"][0])
        # upgradeable loader ProgramData: tag u32=3, slot u64, option<Pubkey> upgrade_authority
        tag = int.from_bytes(raw[:4], "little")
        slot = int.from_bytes(raw[4:12], "little")
        has_auth = raw[12]
        auth = b58encode(raw[13:45]) if has_auth else None
        print("programdata tag:", tag, "slot:", slot, "upgrade_authority:", auth)
        print("programdata lamports:", pda.get("lamports"), "len:", len(raw))
