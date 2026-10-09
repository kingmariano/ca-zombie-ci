#!/usr/bin/env python3
"""Decode the Aurigami oracle keeper calldata (selector 0xec3115f9)."""
inp = open('/tmp/keeper_inp.hex').read().strip()
b = bytes.fromhex(inp[2:])


def word(i):
    return int.from_bytes(b[4 + 32 * i:4 + 32 * (i + 1)], 'big')


o1, o2 = word(0), word(1)
ln1 = word(o1 // 32)          # length of array1
ln2 = word(o2 // 32)          # length of array2
a_start = o1 // 32 + 1
v_start = o2 // 32 + 1
addrs = ['0x' + b[4 + 32 * (a_start + i) + 12:4 + 32 * (a_start + i + 1)].hex()
         for i in range(ln1)]
vals = [word(v_start + i) for i in range(ln2)]
names = ['auWBTC', 'auETH', 'auUSDC', 'auUSDCNative', 'auUSDT',
         'auUSDTNative', 'auDAI', 'auWNEAR', 'auSTNEAR', 'auNEARX', 'auAURORA']
print('selector=0xec3115f9 arrays:', ln1, ln2)
for n, a, v in zip(names, addrs, vals):
    print(f'{n:14s} {a} {v}  /1e18={v / 1e18:.6f}  /1e12={v / 1e12:.6f}  /1e28={v / 1e28:.8f}')
