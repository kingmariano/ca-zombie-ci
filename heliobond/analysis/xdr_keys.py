#!/usr/bin/env python3
"""Minimal Stellar XDR helpers for read-only Soroban RPC ledger-entry queries.

No external deps. Used to build LedgerKey base64 blobs for:
  - ContractCode(hash)          -> does a WASM blob exist on this network?
  - ContractData(instance)      -> contract instance (executable + storage)
  - ContractData(persistent,key)-> a specific storage slot

Reference: stellar-core Stellar-ledger-entries.x / Stellar-transaction.x.
"""
import base64
import hashlib
import json
import struct
import sys
import urllib.request

# LedgerEntryType
ACCOUNT = 0
TRUSTLINE = 1
OFFER = 2
DATA = 3
CLAIMABLE_BALANCE = 4
LIQUIDITY_POOL = 5
CONTRACT_DATA = 6
CONTRACT_CODE = 7
CONFIG_SETTING = 8
TTL = 9

# ContractDataDurability
TEMPORARY = 0
PERSISTENT = 1

# SCAddressType
SC_ADDRESS_TYPE_ACCOUNT = 0
SC_ADDRESS_TYPE_CONTRACT = 1

# SCValType
SCV_LEDGER_KEY_CONTRACT_INSTANCE = 20

# SCValType for symbols/strings etc.
SCV_SYMBOL = 15
SCV_STRING = 14
SCV_U32 = 3
SCV_I128 = 11
SCV_BYTES = 13


def _i32(v):
    return struct.pack(">i", v)


def contract_id_payload(contract_id):
    """Decode a C... strkey contract ID into its 32-byte payload."""
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    # strkey: version byte 0x10 + 32 bytes payload + 2 bytes crc16 (little endian)
    data = _base32_decode(contract_id)
    assert len(data) == 35, f"unexpected strkey length {len(data)}"
    assert data[0] == 0x10, f"unexpected version byte {data[0]}"
    return data[1:33]


def _base32_decode(s):
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    bits = 0
    value = 0
    out = bytearray()
    for ch in s:
        if ch == "=":
            break
        value = (value << 5) | alphabet.index(ch)
        bits += 5
        if bits >= 8:
            bits -= 8
            out.append((value >> bits) & 0xFF)
    return bytes(out)


def contract_code_key(wasm_hash_hex):
    """LedgerKey for ContractCode(hash)."""
    h = bytes.fromhex(wasm_hash_hex)
    assert len(h) == 32
    return _i32(CONTRACT_CODE) + h


def contract_data_key(contract_id, key_bytes=None, durability=PERSISTENT):
    """LedgerKey for ContractData. key_bytes=None => instance key."""
    payload = contract_id_payload(contract_id)
    out = _i32(CONTRACT_DATA) + _i32(SC_ADDRESS_TYPE_CONTRACT) + payload
    if key_bytes is None:
        out += _i32(SCV_LEDGER_KEY_CONTRACT_INSTANCE)
    else:
        out += key_bytes
    out += _i32(durability)
    return out


def scval_symbol(sym):
    b = sym.encode()
    out = _i32(SCV_SYMBOL) + struct.pack(">I", len(b)) + b
    while len(out) % 4:
        out += b"\x00"
    return out


def b64(b):
    return base64.b64encode(b).decode()


RPC_DEFAULT = "https://mainnet.sorobanrpc.com"


def rpc(method, params, url=RPC_DEFAULT):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) heliobond-readonly-research/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def get_ledger_entries(keys_b64, url=RPC_DEFAULT):
    return rpc("getLedgerEntries", {"keys": keys_b64}, url)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "health"
    url = sys.argv[2] if len(sys.argv) > 2 else RPC_DEFAULT
    if cmd == "health":
        print(json.dumps(rpc("getHealth", {}, url), indent=2)[:800])
    elif cmd == "code":
        # code <wasm_hash_hex> [url]
        wasm = sys.argv[2]
        url = sys.argv[3] if len(sys.argv) > 3 else RPC_DEFAULT
        key = contract_code_key(wasm)
        print("key:", b64(key))
        r = get_ledger_entries([b64(key)], url)
        print(json.dumps(r, indent=2)[:1500])
    elif cmd == "instance":
        # instance <contract_id> [url]
        cid = sys.argv[2]
        url = sys.argv[3] if len(sys.argv) > 3 else RPC_DEFAULT
        key = contract_data_key(cid)
        r = get_ledger_entries([b64(key)], url)
        print(json.dumps(r, indent=2)[:4000])
