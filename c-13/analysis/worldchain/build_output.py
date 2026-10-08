#!/usr/bin/env python3
"""Assemble final worldchain_markets.json from all collected artifacts."""
import json

raw=json.load(open('markets_worldchain_raw.json'))
deploy=json.load(open('deploy_blocks.json'))
usd=json.load(open('market_usd.json'))
debt=json.load(open('current_debtors.json'))
liq=json.load(open('account_liquidity.json'))
short=json.load(open('shortfall_details.json'))
bl=json.load(open('borrow_logs_all.json'))

REF={
 'ETH':2443.0524992010046,'USDC':0.9996319585988306,'WBTC':80806.24668481229,
 'wARS':0.0006231513299872165,'WLD':0.4722488566032104,'wBRL':0.196601637897894,'LAC':0.010015,
}
LIQ_COUNT={'caETH':0,'caUSDC':32,'caWBTC':0,'caLAC':0,'caWARS':1,'caWLD':24,'caWBRL':0}
BORROW_RATE={'caETH':0,'caUSDC':2692627435,'caWBTC':43311,'caWARS':3406778079,'caWLD':1569993742,'caWBRL':3674143276,'caLAC':1268391679}
SUPPLY_RATE={'caETH':0,'caUSDC':971735502,'caWBTC':2,'caWARS':18239993,'caWLD':28206243,'caWBRL':132118396,'caLAC':0}

MDEC={m['symbol']:m['underlying_decimals'] for m in raw['markets']}
MPRICE={m['symbol']:int(m['oracle_price']) for m in raw['markets']}

# recompute per-account profit
profit_rows=[]; grand=0.0
for b,e in short.items():
    coll={}; dbt={}
    for name,s in e['snapshots'].items():
        val=s['cTokenBalance']*s['exchangeRate']/1e18
        coll[name]=val*MPRICE[name]/1e36
    for name,v in e['debts'].items():
        dbt[name]=v*MPRICE[name]/1e36
    best=0.0; bestpair=None
    for dm,dv in dbt.items():
        for cm,cv in coll.items():
            if cv<=0: continue
            repay=min(0.5*dv, cv/1.08); p=0.08*repay
            if p>best: best=p; bestpair={"borrow_market":dm,"collateral_market":cm,"repay_usd":round(repay,6)}
    grand+=best
    profit_rows.append({"account":b,"shortfall_usd":round(e['shortfall_1e18']/1e18,8),
                        "max_single_tx_profit_usd":round(best,6),"best_pair":bestpair,
                        "debts_usd":{k:round(v,6) for k,v in dbt.items()},
                        "collateral_usd":{k:round(v,6) for k,v in coll.items()}})
profit_rows.sort(key=lambda r:-r['max_single_tx_profit_usd'])

out={
 "chain":"World Chain","chain_id":480,
 "rpcs":["https://worldchain-mainnet.g.alchemy.com/public","https://480.rpc.thirdweb.com","https://worldchain.drpc.org"],
 "pinned_block":raw['block'],"head_at_scan":36075903,
 "verification":{
   "unitroller":{"address":raw['comptroller'],"code_present":True,"etherscan_name":"Unitroller",
                 "proxy":True,"implementation":raw['comptrollerImplementation'],
                 "pending_implementation":raw['pendingComptrollerImplementation'],
                 "admin":raw['admin'],"pending_admin":raw['pendingAdmin']},
   "oracle":{"address":raw['oracle'],"code_present":True,"etherscan_name":"ChainlinkPriceOracle",
             "proxy":False,"owner":raw['oracle_owner'],"pending_owner":"0x0000000000000000000000000000000000000000"},
   "compound_lens":{"address":"0xA386F452af98062811c1794E0c91c9Fc480C5658","code_present":True},
   "maximillion":{"address":"0x511E89CADa24C562277b880153fBB6E43dCb11a7","code_present":True},
   "docs_listed_markets":6,"onchain_markets":7,
   "docs_discrepancy":"caWBRL 0x90208d4Be7F539bd46E0e0847085E672E23b3d9A is listed on-chain but absent from docs. "
     "caLAC 0x03c1cF154d621E0Fd7e2b88be3aE60CCf07Aca31 IS a real World Chain cToken (underlying LAC 0x0Fe75...); "
     "its address coincidentally matches CapyFi's Ethereum ETH interest-rate-model address (cross-chain CREATE address reuse, "
     "different deployer 0x6a138b... on World Chain)."
 },
 "comptroller":{k:raw[k] for k in ['closeFactorMantissa','liquidationIncentiveMantissa','admin','pendingAdmin',
     'pauseGuardian','borrowCapGuardian','transferGuardianPaused','seizeGuardianPaused',
     'mintGuardianPaused_global','borrowGuardianPaused_global','maxAssets','compRate','getCompAddress']},
 "oracle_feeds":{"type":"CapyfiAggregatorV3 (custom, Etherscan-verified, compiler v0.8.10)",
   "note":"owner/authorizedAddresses can set updateAnswer; oracle (ChainlinkPriceOracle) does NOT check updatedAt staleness; returns 0 on answer<=0",
   "feeds":{}},
 "markets":[],
 "totals_usd":{"oracle_prices":{"cash":sum(v['cash_usd'] for v in usd.values()),
     "borrows":sum(v['borrows_usd'] for v in usd.values()),
     "reserves":sum(v['reserves_usd'] for v in usd.values()),
     "supplier_claims":sum(v['supply_usd'] for v in usd.values())},
   "reference_prices":{"cash":sum(int(m['cash'])/10**MDEC[m['symbol']]*REF[m['underlying_symbol']] for m in raw['markets'])}},
 "borrowers":{
   "historical_unique":{k:len(v) for k,v in json.load(open('borrowers_unique.json')).items()},
   "borrow_event_logs":{k:len(v) for k,v in bl.items()},
   "current_debtors":{k:len(v) for k,v in debt.items()},
   "liquidate_borrow_events":LIQ_COUNT,
   "shortfall_accounts_count":len(short),
   "shortfall_accounts":profit_rows,
   "max_total_extractable_usd_one_tx_each":round(grand,6),
   "note":"19 dust accounts; total gross liquidation profit ~$%.4f vs gas ~$0.001/tx. No material unprivileged extraction." % grand
 },
 "whitelist":{"address":"0xafBBC7FcD7Eb3516742D663BF548E9e1A85e3707","proxy":True,
   "implementation":"0x1897cae31886833527466df2f7109ad0cb4abeb7","name":"Whitelist (UUPS)",
   "isActive":True,"whitelisted_role_member_count":0,
   "note":"only market caLAC has a whitelist; it gates mint only (mintInternal _checkWhitelist). Active with 0 members => caLAC minting is effectively frozen for everyone."},
 "admin_identities":{
   "capyfi_admin_safe":{"address":"0x6C15e4Bc44CC5674b1d7956D0e9596d2E509eD24","type":"Gnosis Safe v1.4.1",
     "threshold":4,"owners":["0xf7104Ad39080C53E2C8C74a34C34E622D8aBE2c5","0xa40D7d22873001f0140D76Afc0FF0779e4210eD0",
       "0x5CA3F8EEBa12D83408fc097c2dAd79212456F20F","0x23ceC92F92bde95e401f0a2b50b072A6069dFBd5",
       "0x5b72e13f78FEB8f5b44392f2e32940D4f37FA313","0x9850b4F631F1cae37bb1C42C8004ffc2Cd31DcBe",
       "0x00A74411DDBC50C04353543d5D3f4296936DA645"]},
   "deployer_eoa":{"address":"0x3ee4af9184f968558046cdCCa74F89B064eCD6Ce","type":"EOA","nonce":122,
     "roles":"deployed 6/7 markets; caWBRL admin; wBRL feed owner (pending handover to CapyFi admin)"},
   "calac_deployer":{"address":"0x6a138bd6d69feb3c2f5426549e60e644778ad04c","type":"EOA","nonce":22},
   "price_updater_safe":{"address":"0x5c2c3e2ad9f9b19bb24f2b5183b9cf4eedd094a1","type":"Gnosis Safe v1.4.1",
     "threshold":1,"owners":["0xaCDC3EBA833Ec6Edb048C109956440Fcf0985314"],
     "authorized_on":"all 6 feeds","note":"1-of-1 Safe => single EOA effectively controls feed updates (bounded only for wARS/wBRL)"}
 },
 "notes":[
   "All 7 markets mintable & borrowable (mint/borrow pauses false, no global pauses); caLAC mint whitelist-gated with 0 members.",
   "Borrow caps: caUSDC 20,000e6; caWBTC 0.32e8; caETH 0.3e18; caLAC 1,000e18; caWARS 500,000e18; caWLD 5e18; caWBRL 20,000e18.",
   "Interest: borrowRatePerBlock (1e18): caUSDC 2.69e9, caWARS 3.41e9, caWLD 1.57e9, caWBRL 3.67e9, caWBTC 4.3e4, caETH 0.",
   "Historical donation: at block 19790112 a user (0x63789f76...) sent 10 USDC directly to caUSDC while totalSupply was only 50 cTokens, raising exchangeRate ~11x. Donations are not extractable by the donor.",
   "Oracle vs reference (DefiLlama) deviations: wARS +5.8%, wBRL +1.5%, LAC -20.1%, WBTC +0.6%, ETH -0.3%, WLD -0.1%, USDC +0.02%.",
   "No COMP distribution (compRate=0, getCompAddress=0x0).",
   "All markets use CErc20Delegate/Delegator (upgradeable) except caETH (CEther, non-delegator); caWBRL impl 0x592a... differs from the other CErc20Delegate impls.",
 ]
}
for m in raw['markets']:
    sym=m['symbol']; usym=m['underlying_symbol']
    rec={k:m[k] for k in ['market','symbol','name','decimals','underlying','underlying_symbol','underlying_decimals',
        'cash','totalSupply','totalBorrows','totalBorrowsCurrent','totalReserves','exchangeRateStored','exchangeRateCurrent',
        'reserveFactorMantissa','protocolSeizeShareMantissa','interestRateModel','accrualBlockNumber','borrowIndex','admin','pendingAdmin',
        'implementation','isListed','collateralFactorMantissa','isComped','borrowCap','oracle_price','mintGuardianPaused',
        'borrowGuardianPaused','oracle_config','whitelist']}
    if 'feed' in m: rec['feed']=m['feed']
    rec['deploy_block']=deploy.get(sym)
    rec['isCEther']=m['isCEther']
    rec['deprecated']=False
    rec['borrowRatePerBlock']=BORROW_RATE[sym]
    rec['supplyRatePerBlock']=SUPPLY_RATE[sym]
    rec['usd_oracle']=usd[sym]
    rec['usd_reference_cash']=int(m['cash'])/10**MDEC[sym]*REF[usym]
    rec['ref_price']=REF[usym]
    rec['oracle_vs_ref_pct']=round((int(m['oracle_price'])/10**(36-MDEC[sym])/REF[usym]-1)*100,3)
    out['markets'].append(rec)
    if m.get('oracle_config',{}).get('priceFeed','0x0000000000000000000000000000000000000000')!='0x0000000000000000000000000000000000000000':
        f=m['feed']; f['owner']='0x6C15e4Bc44CC5674b1d7956D0e9596d2E509eD24' if sym!='caWBRL' else '0x3ee4af9184f968558046cdCCa74F89B064eCD6Ce'
        f['authorized_updater']='0x5c2c3e2ad9f9b19bb24f2b5183b9cf4eedd094a1'
        out['oracle_feeds']['feeds'][sym]=f
out['oracle_feeds']['feeds']['caLAC']={'type':'fixed price','fixedPrice':str(raw['markets'][3]['oracle_config']['fixedPrice']),
    'price_usd':int(raw['markets'][3]['oracle_config']['fixedPrice'])/1e18}
json.dump(out,open('/home/heisenberg/CA/c-13/analysis/worldchain_markets.json','w'),indent=1)
print("wrote worldchain_markets.json", len(json.dumps(out)),"bytes")
print("extractable total: $%.6f"%grand)
