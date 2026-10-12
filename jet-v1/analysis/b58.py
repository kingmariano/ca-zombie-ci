#!/usr/bin/env python3
"""Base58 + ed25519 on-curve check helper (read-only analysis)."""
import sys

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58encode(b: bytes) -> str:
    n = int.from_bytes(b, "big")
    out = ""
    while n > 0:
        n, r = divmod(n, 58)
        out = ALPHABET[r] + out
    pad = 0
    for c in b:
        if c == 0:
            pad += 1
        else:
            break
    return "1" * pad + out

def b58decode(s: str) -> bytes:
    n = 0
    for c in s:
        n = n * 58 + ALPHABET.index(c)
    b = n.to_bytes(32, "big") if n else b""
    pad = 0
    for c in s:
        if c == "1":
            pad += 1
        else:
            break
    return b"\x00" * pad + b

# ed25519 curve check: y given as little-endian 32 bytes with top bit = x sign.
p = 2**255 - 19
d = (-121665 * pow(121666, p - 2, p)) % p

def is_on_curve(pubkey: bytes) -> bool:
    y = int.from_bytes(pubkey, "little") & ((1 << 255) - 1)
    if y >= p:
        return False
    # x^2 = (y^2 - 1) / (d*y^2 + 1)
    y2 = (y * y) % p
    num = (y2 - 1) % p
    den = (d * y2 + 1) % p
    if den == 0:
        return False
    x2 = (num * pow(den, p - 2, p)) % p
    # Euler criterion
    if x2 == 0:
        return True
    return pow(x2, (p - 1) // 2, p) == 1

if __name__ == "__main__":
    for arg in sys.argv[1:]:
        try:
            b = b58decode(arg)
            print(f"{arg}: len={len(b)} on_curve={is_on_curve(b)}")
        except Exception as e:
            print(f"{arg}: error {e}")
