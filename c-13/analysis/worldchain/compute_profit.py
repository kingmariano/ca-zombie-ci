#!/usr/bin/env python3
"""Compute USD totals, per-account liquidation profit bounds, and verify getAccountLiquidity scaling."""
import json

mk=json.load(open('markets_worldchain_raw.json'))
details=json.load(open('shortfall_details.json'))

# reference prices (DefiLlama, 2026-10-08)
REF={
 'ETH':2443.0524992010046,
 'USDC':0.9996319585988306,
 'WBTC':80806.24668481229,
 'wARS':0.0006231513299872165,
 'WLD':0.4722488566032104,
 'wBRL':0.196601637897894,
 'LAC':0.010015,
}
MDEC={m['symbol']:m['underlying_decimals'] for m in mk['markets']}
MPRICE={m['symbol']:int(m['oracle_price']) for m in mk['markets']}  # scaled 1e(36-dec)
MCF={m['symbol']:int(m['collateralFactorMantissa'])/1e18 for m in mk['markets']}

def usd(sym, base_units):
    return base_units * MPRICE[sym] / 1e36

print("== market USD (oracle prices, value = base*price/1e36) ==")
tot={}
for m in mk['markets']:
    sym=m['symbol']; usym=m['underlying_symbol']
    cash=int(m['cash']); tb=int(m['totalBorrowsCurrent']); tr=int(m['totalReserves'])
    cash_usd=usd(sym,cash); tb_usd=usd(sym,tb); tr_usd=usd(sym,tr); sup_usd=usd(sym,cash+tb-tr)
    tot[sym]={'cash_usd':cash_usd,'borrows_usd':tb_usd,'reserves_usd':tr_usd,'supply_usd':sup_usd}
    ref=REF.get(usym)
    cash_ref=cash/10**MDEC[sym]*ref if ref else None
    print(f"{sym:8s} cash=${cash_usd:12,.2f} (ref ${cash_ref:12,.2f})  borrows=${tb_usd:10,.2f}  reserves=${tr_usd:9,.2f}  suppliers=${sup_usd:12,.2f}")
print("TOTAL cash USD (oracle):   $%.2f" % sum(v['cash_usd'] for v in tot.values()))
print("TOTAL cash USD (llama):    $%.2f" % sum(int(m['cash'])/10**MDEC[m['symbol']]*REF[m['underlying_symbol']] for m in mk['markets']))
print("TOTAL borrows USD (oracle): $%.2f" % sum(v['borrows_usd'] for v in tot.values()))
print("TOTAL supply USD (oracle):  $%.2f" % sum(v['supply_usd'] for v in tot.values()))
json.dump(tot,open('market_usd.json','w'),indent=1)

print("\n== liquidation profit bounds (closeFactor=0.5, incentive=1.08) ==")
grand=0.0; rows=[]
for b,e in details.items():
    coll={}
    for name,s in e['snapshots'].items():
        val=s['cTokenBalance']*s['exchangeRate']/1e18
        coll[name]=usd(name,val)
    dbt={}
    for name,v in e['debts'].items():
        dbt[name]=usd(name,v)
    best=0.0; bestpair=None
    for dm,dv in dbt.items():
        for cm,cv in coll.items():
            if cv<=0: continue
            repay=min(0.5*dv, cv/1.08)
            profit=0.08*repay
            if profit>best: best=profit; bestpair=(dm,cm,round(repay,6))
    grand+=best
    rows.append((b,e['shortfall_1e18']/1e18,best,bestpair,dbt,coll))
rows.sort(key=lambda r:-r[2])
for b,S,prof,pair,dbt,coll in rows:
    print(f"{b} shortfall=${S:.6f} bestProfit=${prof:.6f} pair={pair}")
    print(f"    debts={ {k:round(v,6) for k,v in dbt.items()} } coll={ {k:round(v,6) for k,v in coll.items()} }")
print("GRAND TOTAL extractable (one tx per account): $%.6f" % grand)

print("\n== verification vs getAccountLiquidity ==")
ok=0
for b,e in details.items():
    tot_c=0.0; tot_d=0.0
    for name,s in e['snapshots'].items():
        val=s['cTokenBalance']*s['exchangeRate']/1e18
        tot_c+=usd(name,val)*MCF[name]
    for name,v in e['debts'].items():
        tot_d+=usd(name,v)
    calc=tot_c-tot_d
    got=-e['shortfall_1e18']/1e18
    diff=abs(calc-got)
    status="OK" if diff<max(1e-5,abs(got)*0.05) else "MISMATCH"
    if status=="OK": ok+=1
    print(f"{b} calc_liq=${calc:.8f} chain_liq=${got:.8f} diff=${diff:.2e} {status}")
print(f"verified {ok}/{len(details)}")
