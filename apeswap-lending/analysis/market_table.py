#!/usr/bin/env python3
"""Build the final market table (analysis/market_table.json + market_table.md)."""
import json

# live reads (see analysis/markets.tsv, cash.tsv, oracles.tsv; block ~126,489,929-126,494,000)
data = {
 # sym: (cToken, underlying, cash_wei, totalSupply, totalBorrows, totalReserves, er, rf, cf, lf, li, cap, used, price_len, decimals)
 'oBANANA': ('0xC2E840BdD02B4a1d970C87A912D8576a7e61D314','0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95',1591482769750980619864538,5203198841765268,19612853344630233124860,261502483630944797081,309585347321740793072663406,300000000000000000,400000000000000000,700000000000000000,1120000000000000000,1,508701939588073,1000000000000),
 'oETH': ('0xaA1b1E1f251610aE10E4D553b05C662e60992EEd','0x2170Ed0880ac9A755fd29B2688956BD959F933F8',6139523707312969402,30618609569,228215073359391376,1570551287162027,207918266668472921700620284,250000000000000000,700000000000000000,750000000000000000,1100000000000000000,0,27793758899,2442609906330000000000),
 'oBUSD': ('0x0096B6B49D13b347033438c4a699df3Afd9d2f96','0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',34946627265219379723687,83923897915122,5057594482104883657346,37407155746726586717,476226862484375075479272753,200000000000000000,0,750000000000000000,1100000000000000000,0,80157947230724,1000000000000000000),
 'oUSDT': ('0xdBFd516D42743CA3f1C555311F7846095D85F6Fd','0x55d398326f99059fF775485246999027B3197955',11378977051268384230385,76600539766792,12654393446593963964067,1449831920882220012872,294822185923689578643594408,250000000000000000,700000000000000000,750000000000000000,1100000000000000000,0,41732693069757,999140000000000000),
 'oCake': ('0x3353f5bcfD7E4b146F2eD8F1e8D875733Cd754a7','0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',6127183502665295105135,23666506961497,166182763234900620699,9727651479892553856,265507648621029886955160461,300000000000000000,400000000000000000,500000000000000000,1120000000000000000,0,17495226845963,2117570310000000000),
 'oUSDC': ('0x91B66a9Ef4f4CAD7F8AF942855C37Dd53520f151','0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',31778547035579161352078,106241637334709,3894774283218649118508,2867136374278964430257,308788397539136094904131577,200000000000000000,700000000000000000,750000000000000000,1100000000000000000,0,88686344638348,999842320000000000),
 'oBNB': ('0x34878F6a484005AA90E7188a546Ea9E52b538F6f','0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',60450520580100396152,306719467100,8533708152937393211,104967470470552690,224567621722264125155034869,250000000000000000,700000000000000000,750000000000000000,1100000000000000000,0,240538041605,726916010000000000000),
 'oBTCB': ('0x5fce5D208DC325ff602c77497dC18F8EAdac8ADA','0x7130d2A12B9BCBFAe4f2634d864A1Ee1Ce3Ead9c',926712553592836909,4663787612,42632489497583744,301170568713176,207780446525554062259042683,250000000000000000,700000000000000000,750000000000000000,1100000000000000000,0,4143438725,81443130000000000000000),
 'oDOT': ('0x92D106c39aC068EB113B3Ecb3273B23Cd19e6e26','0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402',980093147254060370535,4619437372238,29884904534311389866,264825299550026954,218579265205979259313135447,300000000000000000,500000000000000000,600000000000000000,1120000000000000000,1500000000000000000000000,3251208722940,1036760000000000000),
 'oBNBx': ('0x3EE2bd8C244B5B3656673c2A49447e41D31F8E1e','0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275',305630603600000000,1528153018,0,0,200000000000000000000000000,300000000000000000,600000000000000000,600000000000000000,1120000000000000000,956359268,0,None),
}
real_price = {'oBANANA':1.0e-10,'oETH':2437.4413317,'oBUSD':0.9978991,'oUSDT':0.9993229,'oCake':2.1134435,'oUSDC':0.9996619,'oBNB':729.3033,'oBTCB':80586.1119,'oDOT':1.0225013,'oBNBx':805.2339}

rows=[]
tot_cash=0.0; tot_borrows=0.0; tot_claims=0.0; tot_reserves=0.0
for sym,(tok,und,cash,ts,tb,tr,er,rf,cf,lf,li,cap,used,price_len) in data.items():
    er_f = er/1e18
    claims_tok = ts*er_f/1e18          # underlying in whole tokens (ts is 8-dec, er 1e18-scaled)
    cash_tok = cash/1e18
    tb_tok = tb/1e18
    tr_tok = tr/1e18
    p = real_price[sym]
    row = {
        'market': sym, 'cToken': tok, 'underlying': und,
        'cash_tokens': round(cash_tok,8), 'total_supply_ctokens': ts,
        'total_borrows_tokens': round(tb_tok,8), 'total_reserves_tokens': round(tr_tok,8),
        'exchange_rate': er, 'reserve_factor': rf/1e18,
        'collateral_factor': cf/1e18, 'liquidation_factor': lf/1e18, 'liquidation_incentive': li/1e18,
        'active_collateral_usd_cap': cap, 'active_collateral_used': used,
        'oracle_price_1e18': price_len, 'real_price_usd': p,
        'cash_usd': round(cash_tok*p,2), 'borrows_usd': round(tb_tok*p,2),
        'supplier_claims_usd': round(claims_tok*p,2), 'reserves_usd': round(tr_tok*p,2),
    }
    rows.append(row)
    tot_cash += row['cash_usd']; tot_borrows += row['borrows_usd']
    tot_claims += row['supplier_claims_usd']; tot_reserves += row['reserves_usd']

out={'block':126489929,'note':'prices: DefiLlama 2026-10-08 ~18:37-19:48 UTC; BANANA ~$1.0e-10 (CMC 2026-10-08; DEX pools imply $1.3e-10); BNBx real price DefiLlama (oracle feed dead)',
     'markets':rows,'totals':{'cash_usd':round(tot_cash,2),'borrows_usd':round(tot_borrows,2),
     'supplier_claims_usd':round(tot_claims,2),'reserves_usd':round(tot_reserves,2)}}
json.dump(out,open('/home/heisenberg/CA/apeswap-lending/analysis/market_table.json','w'),indent=1)

hdr='| market | cash (tok) | cash USD | borrows USD | claims USD | ER | CF | LF | LI | mint/borrow paused | oracle price | real price |'
sep='|---|---|---|---|---|---|---|---|---|---|---|---|'
lines=[hdr,sep]
for r in rows:
    lines.append('| {market} | {cash_tokens:,.4f} | ${cash_usd:,.2f} | ${borrows_usd:,.2f} | ${supplier_claims_usd:,.2f} | {exchange_rate:.3e} | {collateral_factor:.2f} | {liquidation_factor:.2f} | {liquidation_incentive:.2f} | true/true | {oracle} | {real} |'.format(
        market=r['market'], cash_tokens=r['cash_tokens'], cash_usd=r['cash_usd'], borrows_usd=r['borrows_usd'], supplier_claims_usd=r['supplier_claims_usd'],
        exchange_rate=r['exchange_rate'], collateral_factor=r['collateral_factor'], liquidation_factor=r['liquidation_factor'], liquidation_incentive=r['liquidation_incentive'],
        oracle=(r['oracle_price_1e18'] if r['oracle_price_1e18'] is not None else 'REVERT'),
        real=r['real_price_usd']))
lines.append('')
lines.append(f"Totals: cash ${tot_cash:,.2f} · borrows ${tot_borrows:,.2f} · supplier claims ${tot_claims:,.2f} · reserves ${tot_reserves:,.2f}")
open('/home/heisenberg/CA/apeswap-lending/analysis/market_table.md','w').write('\n'.join(lines)+'\n')
print('\n'.join(lines))
print(json.dumps(out['totals'],indent=1))
