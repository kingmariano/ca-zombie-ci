#!/usr/bin/env python3
"""Decode markets_raw.json into a human-readable table with USD values."""
import json
import urllib.request

RPC = "https://mainnet.aurora.dev"
PRICES = {'ETH': 2474.63, 'WBTC': 81727.37, 'USDC': 0.99961, 'USDT': 0.99927,
          'DAI': 1.00006, 'WNEAR': 4.52201, 'STNEAR': 6.73006, 'AURORA': 0.058850,
          'TRI': 0.00012557, 'PLY': None, 'USN': None, 'NEARX': None}

d = json.load(open('/home/heisenberg/CA/aurigami/analysis/markets_raw.json'))
UNIT = d['unitroller']




def word(res):
    if not isinstance(res, str):
        return None
    b = bytes.fromhex(res[2:])
    vals = []
    for i in range(0, len(b), 32):
        vals.append(int.from_bytes(b[i:i + 32], 'big'))
    if len(vals) == 1:
        return vals[0]
    return vals


rows = []
for m, v in d['markets'].items():
    und = v.get('underlying')
    und_addr = ('0x' + und[-40:]) if isinstance(und, str) and len(und) == 66 else None
    ts = word(v.get('totalSupply'))
    tb = word(v.get('totalBorrows'))
    tr = word(v.get('totalReserves'))
    er = word(v.get('exchangeRateStored'))
    ier = word(v.get('initialExchangeRateMantissa'))
    rf = word(v.get('reserveFactorMantissa'))
    pss = word(v.get('protocolSeizeShareMantissa'))
    acc = word(v.get('accrualBlockTimestamp'))
    mi = word(v.get('marketInfo'))
    cap = word(v.get('borrowCap'))
    mp = word(v.get('mintPaused'))
    bp = word(v.get('borrowPaused'))
    px = word(v.get('price'))
    cash = v.get('cash')
    cash = int(cash, 16) if isinstance(cash, str) else None
    rows.append(dict(m=m, und=und_addr, ts=ts, tb=tb, tr=tr, er=er, ier=ier,
                     rf=rf, pss=pss, acc=acc, listed=mi[0] if mi else None,
                     cf=mi[1] if mi else None, cap=cap, mp=mp, bp=bp, px=px, cash=cash))

print('block', d['block'])
print(f"{'market':42s} {'und':14s} {'cash':>18s} {'supply':>18s} {'borrows':>18s} {'reserves':>16s} {'er':>22s} {'CF':>4s} {'px':>10s}")
for r in rows:
    print(f"{r['m']:42s} {str(r['und'])[:14]:14s} {str(r['cash']):>18s} {str(r['ts']):>18s} {str(r['tb']):>18s} {str(r['tr']):>16s} {str(r['er']):>22s} {str(r['cf']):>4s} {str(r['px']):>10s}")
print()
print('==== zero-supply check ====')
for r in rows:
    if r['ts'] == 0:
        print('ZERO SUPPLY:', r['m'], 'cash=', r['cash'], 'borrows=', r['tb'])
print()
print('==== raw json per market (initialExchangeRateMantissa etc) ====')
for r in rows:
    print(r['m'], 'ier=', r['ier'], 'rf=', r['rf'], 'pss=', r['pss'], 'acc=', r['acc'], 'cap=', r['cap'])
