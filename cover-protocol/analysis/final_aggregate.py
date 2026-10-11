#!/usr/bin/env python3
"""Final aggregation: Cover Protocol live value by category (E-U / H-O / P / S) in USD."""
import json, os
from collections import defaultdict

D = os.path.dirname(os.path.abspath(__file__))
state = json.load(open(os.path.join(D, 'state.json')))
pools = json.load(open(os.path.join(D, 'pools.json')))
recon = json.load(open(os.path.join(D, 'pool_reconcile.json')))
hc = json.load(open(os.path.join(D, 'holders_classified.json')))

DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'
YDAI = '0x16de59092dae5ccf4a1e6439d611fd0653f0bd01'
BLOCK = state['block']
PPS_YDAI = 1143253938334778337 / 1e18  # on-chain getPricePerFullShare at block
P_DAI = 1.000072
P_YDAI = PPS_YDAI * P_DAI
FEE = 1 - 10 / 10000  # 0.1% redeem fee

# cover -> collateral
cover_col = {cv['cover']: cv['collateral'] for cv in state['covers']}
cover_col_by_name = {cv['name']: cv['collateral'] for cv in state['covers']}
# token -> (cover, kind)
tok_cover = {}
for cv in state['covers']:
    tok_cover[cv['noclaimCovToken']] = (cv['cover'], 'noclaim')
    tok_cover[cv['claimCovToken']] = (cv['cover'], 'claim')

# ---- totals ----
tot = defaultdict(float)
for cv in state['covers']:
    tot[cv['collateral']] += cv['collateralBalance']
print(f"block {BLOCK}")
print(f"total DAI  {tot[DAI]/1e18:.6f}  (${tot[DAI]/1e18*P_DAI:,.2f})")
print(f"total yDAI {tot[YDAI]/1e18:.6f}  (${tot[YDAI]/1e18*P_YDAI:,.2f})")
gross = tot[DAI]/1e18*P_DAI + tot[YDAI]/1e18*P_YDAI
print(f"gross total ${gross:,.2f}; net of 0.1% fee ${gross*FEE:,.2f}")

# ---- pool-held split (from reconcile, in weighted collateral units) ----
pool_ho = 0.0; pool_other = 0.0; pool_s = 0.0
pool_ho_col = defaultdict(float); pool_other_col = defaultdict(float); pool_s_col = defaultdict(float)
for r in recon:
    pool = next(p for p in pools['pools'] if p['addr'] == r['pool'])
    # weighted collateral per collateral type
    col_units = defaultdict(float)
    for h in pool['holdings']:
        c = cover_col_by_name[h['cover']]
        col_units[c] += h['bal'] / 1e18 * h['ratio']
    ts = r['bptSupply']
    if ts == 0:
        continue
    f_ho = (min(r['liveBR'], r['brBPT']) + min(r['liveBS'], r['bsBPT'])) / ts
    f_orph = ((r['brBPT'] - min(r['liveBR'], r['brBPT'])) + (r['bsBPT'] - min(r['liveBS'], r['bsBPT']))) / ts
    f_other = max(0.0, 1 - f_ho - f_orph)
    for c, v in col_units.items():
        pool_ho_col[c] += v * f_ho
        pool_other_col[c] += v * f_other
        pool_s_col[c] += v * f_orph
for c in (DAI, YDAI):
    pool_ho += pool_ho_col[c]; pool_other += pool_other_col[c]; pool_s += pool_s_col[c]

def usd(c_units):
    return c_units[DAI] * P_DAI + c_units[YDAI] * P_YDAI

print()
print(f"pool-held weighted collateral: {pool_ho+pool_other+pool_s:,.2f} units")
print(f"  live stakers (H-O):  {pool_ho:,.2f} units = ${usd(pool_ho_col):,.2f}")
print(f"  other BPT holders:   {pool_other:,.2f} units = ${usd(pool_other_col):,.2f}")
print(f"  orphaned (S):        {pool_s:,.2f} units = ${usd(pool_s_col):,.2f}")

# ---- direct holders ----
direct_col = defaultdict(float)
direct_dust_col = defaultdict(float)
for tok, rec in hc['tokens'].items():
    cover, kind = tok_cover[tok]
    c = cover_col[cover]
    for h in rec['holderList']:
        if h['codeLen'] == 22537:  # BPool (counted above)
            continue
        v = h['bal'] / 1e18 * rec['ratio']
        if h['isContract'] and h['codeLen'] not in (23,):  # non-EOA, non-7702 contracts
            direct_dust_col[c] += v
        else:
            direct_col[c] += v
print()
print(f"direct holder collateral (EOAs/7702): {sum(direct_col.values()):,.2f} units = ${usd(direct_col):,.2f}")
print(f"small contract dust: {sum(direct_dust_col.values()):,.4f} units = ${usd(direct_dust_col):,.4f}")

# ---- categories ----
ho_gross = usd(pool_ho_col) + usd(pool_other_col) + usd(direct_col)
s_usd = usd(pool_s_col) + usd(direct_dust_col)
print()
print("==== CATEGORIES ====")
print(f"E-U: $0 (no unprivileged extraction path)")
print(f"H-O gross: ${ho_gross:,.2f}  net of fee: ${ho_gross*FEE:,.2f}")
print(f"P (privileged): cover-proxy upgrade path = all ${gross:,.2f}; fee receiver ${601.0396*P_DAI + 25.693242*P_YDAI:,.2f}")
print(f"S: ${s_usd:,.2f}")
print(f"check sum: {ho_gross + s_usd:,.2f} vs gross {gross:,.2f}")

out = {
    'block': BLOCK,
    'prices': {'DAI': P_DAI, 'yDAI_pps': PPS_YDAI, 'yDAI_usd': P_YDAI},
    'totals': {'DAI': tot[DAI] / 1e18, 'yDAI': tot[YDAI] / 1e18, 'gross_usd': round(gross, 2), 'net_of_fee_usd': round(gross * FEE, 2)},
    'categories': {
        'E-U': 0.0,
        'H-O': round(ho_gross * FEE, 2),
        'H-O_gross': round(ho_gross, 2),
        'P_cover_upgrade_path_usd': round(gross, 2),
        'P_fee_receiver_usd': round(601.0395514076083 * P_DAI + 25.693242035141854 * P_YDAI, 2),
        'S': round(s_usd, 2),
    },
    'breakdown': {
        'pool_live_stakers_usd': round(usd(pool_ho_col), 2),
        'pool_other_bpt_holders_usd': round(usd(pool_other_col), 2),
        'direct_holders_usd': round(usd(direct_col), 2),
        'orphaned_staking_bpt_usd': round(usd(pool_s_col), 2),
        'dust_contracts_usd': round(usd(direct_dust_col), 4),
    },
}
json.dump(out, open(os.path.join(D, 'final_numbers.json'), 'w'), indent=1)
print('saved final_numbers.json')
