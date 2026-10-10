#!/usr/bin/env python3
"""Zilliqa bech32 decode/encode — standard bech32 (BIP-173) over the 20-byte address.
Per zilliqa-js: toBech32Address = encode('zil', convertBits(20-byte-addr, 8, 5))."""
import sys

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

def convertbits(data, frombits, tobits, pad=True):
    acc = 0; bits = 0; ret = []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret

def bech32_polymod(values):
    GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = (chk & 0x1ffffff) << 5 ^ v
        for i in range(5):
            chk ^= GEN[i] if ((b >> i) & 1) else 0
    return chk

def hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]

def bech32_encode(hrp, data):
    values = hrp_expand(hrp) + data
    polymod = bech32_polymod(values + [0,0,0,0,0,0]) ^ 1
    checksum = [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]
    return hrp + '1' + ''.join([CHARSET[d] for d in data + checksum])

def bech32_decode(bech):
    pos = bech.rfind('1')
    hrp = bech[:pos]
    data = [CHARSET.find(x) for x in bech[pos+1:]]
    if any(d == -1 for d in data):
        raise ValueError('bad char')
    if bech32_polymod(hrp_expand(hrp) + data) != 1:
        raise ValueError('bad checksum')
    return hrp, data[:-6]

def zil_bech32_to_hex(bech):
    hrp, data = bech32_decode(bech)
    assert hrp == 'zil', hrp
    payload = bytes(convertbits(data, 5, 8, False))
    assert len(payload) == 20, len(payload)
    return payload.hex()

def hex_to_zil_bech32(hexaddr, hrp='zil'):
    addr = bytes.fromhex(hexaddr.replace('0x','').lower())
    assert len(addr) == 20
    d5 = convertbits(list(addr), 8, 5, True)
    return bech32_encode(hrp, d5)

if __name__ == '__main__':
    test_hex = '5a7c1e6b8f2d3a4b5c6d7e8f9a0b1c2d3e4f5a6b'
    enc = hex_to_zil_bech32(test_hex)
    dec = zil_bech32_to_hex(enc)
    assert dec == test_hex
    print('roundtrip OK:', test_hex, '->', enc, f'({len(enc)-4} data chars)')
    for arg in sys.argv[1:]:
        if arg.startswith('zil1'):
            print(arg, '->', '0x'+zil_bech32_to_hex(arg))
        elif arg.startswith('0x'):
            print(arg, '->', hex_to_zil_bech32(arg))
