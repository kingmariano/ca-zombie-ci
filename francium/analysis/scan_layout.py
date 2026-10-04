#!/usr/bin/env python3
"""Scan sampled program accounts for embedded base58 pubkeys that match a watchlist
(known mints / programs), and decode u64 fields."""
import json, base64, sys, re

ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58(b):
    n = int.from_bytes(b, "big")
    s = ""
    while n:
        n, r = divmod(n, 58)
        s = ALPH[r] + s
    pad = 0
    for c in b:
        if c == 0: pad += 1
        else: break
    return "1" * pad + s

WATCH = {
    "So11111111111111111111111111111111111111112": "SOL",
    "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": "USDC",
    "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB": "USDT",
    "4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R": "RAY",
    "orcaEKTdK7LKz57vaAYr9QeNsVEPfiu6QeMU1kektZE": "ORCA",
    "mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So": "mSOL",
    "7dHbWXmci3dT8UFYWYZweBLXgycu7Y3iL6trKn1Y7ARj": "stSOL",
    "SRMuApVNdxXokk5GT7XD5cUUgXMBCoAz2LHeuAoKWRt": "SRM",
    "2FPyTwcZLUg1MDrwsyoP4D6s1tM7hAkHYRjkNb5w6Pxk": "soETH",
    "9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E": "soBTC",
    "3NZ9JMVBmGAqocybic2g7D2cNTg3V5Td2z2cQZ8Gx1q": "wBTC",
    "7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs": "wETH",
    "A9mUU4qviSctJVPJdBJWkb28deg915LYJKrzQ19ji3FM": "wUSDC",
    "Dn4noZ5jgGfkntzcQSUZ8czkreiZ1ForXYoV2H8Dm7S1": "wUSDT",
    "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA": "SPL_TOKEN",
    "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL": "ATA",
    "FC81tbGt6JWRXidaWYFXxGnTk4VgobhJHATvTRVMqgWj": "FRANCIUM_LEND",
    "3Katmm9dhvLQijAvomteYMo6rfVbY5NaCRNq9ZBqBgr6": "FRANCIUM_REWARD",
    "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N": "FRANCIUM_LYF_RAY",
    "DmzAmomATKpNp2rCBfYLS7CSwQqeQTsgRYJA1oSSAJaP": "FRANCIUM_LYF_ORCA",
    "RVKd61ztZW9GUwhRbbLoYVRE5Xf1B2tVscKqwZqXgEr": "RAYDIUM_AMM_V4",
    "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8": "RAYDIUM_AMM_V4b",
    "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc": "ORCA_WHIRLPOOL",
    "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM": "ORCA_V2",
}

def scan(raw):
    hits = []
    for off in range(0, len(raw) - 31):
        key = b58(raw[off:off+32])
        if key in WATCH:
            hits.append((off, key, WATCH[key]))
    return hits

def u64s(raw, offsets):
    return {o: int.from_bytes(raw[o:o+8], "little") for o in offsets if o + 8 <= len(raw)}

def main():
    path = sys.argv[1]
    d = json.load(open(path))
    print("PROGRAM", d["program"], "count", d["count"])
    for size, b in sorted(d["buckets"].items(), key=lambda x: int(x[0])):
        print("=" * 90)
        print(f"SIZE {size}  count={b['count']}")
        for s in b["samples"]:
            raw = base64.b64decode(s["data"])
            hits = scan(raw)
            print(f"  key={s['pubkey']} lamports={s['lamports']}")
            for off, key, label in hits:
                print(f"    +{off:4d} {label:18s} {key}")
            # print all 8-byte little endian values that are non-trivial at 8-aligned offsets
            vals = []
            for off in range(0, len(raw) - 7, 8):
                v = int.from_bytes(raw[off:off+8], "little")
                if v not in (0,):
                    vals.append((off, v))
            print("    u64s:", ", ".join(f"+{o}={v}" for o, v in vals[:20]))

if __name__ == "__main__":
    main()
