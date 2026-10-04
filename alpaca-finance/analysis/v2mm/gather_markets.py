import json, subprocess, time, os, sys
B='125624409'
RPC='https://bsc-mainnet.public.blastapi.io'
RPC2='https://bsc.drpc.org'
D='0x7389aaf2e32872cABD766D0CEB384220e8F2A590'
AM='0xD20B887654dB8dC476007bdca83d22Fa51e93407'
MFL='0x4579587AE043131999cE3d9C66199726972E3Fb7'
tokens = {
 'WBNB':'0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
 'USDC':'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
 'USDT':'0x55d398326f99059fF775485246999027B3197955',
 'BUSD':'0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
 'BTCB':'0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
 'ETH':'0x2170Ed0880ac9A755fd29B2688956BD959F933F8',
 'HIGH':'0x5f4Bde007Dc06b867f86EBFE4802e34A1fFEEd63',
 'Cake':'0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
 'XRP':'0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE',
 'DOGE':'0xbA2aE424d960c26247Dd6c32edC70B295c744C43',
 'LTC':'0x4338665CBB7B2485A8855A139b75D5e34AB0DB94',
 'THE':'0xF4C8E32EaDEC4BFe97E0F595AdD0f4450a863a11',
}
def raw_call(to, sig, args=()):
    cmd=['cast','call',to,sig,*[str(a) for a in args],'--block',B,'--rpc-url',RPC]
    p=subprocess.run(cmd,capture_output=True,text=True,timeout=45)
    if p.returncode!=0:
        cmd=['cast','call',to,sig,*[str(a) for a in args],'--block',B,'--rpc-url',RPC2]
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=45)
    if p.returncode!=0:
        return 'ERR:'+(p.stderr.strip().splitlines()[-1] if p.stderr.strip() else 'unknown')
    return p.stdout.strip()
def call(to, sig, *args):
    for _ in range(4):
        r=raw_call(to,sig,args)
        if not r.startswith('ERR'): return r
        time.sleep(1.0)
    return r
for name, tok in tokens.items():
    path=f'partial/{name}.json'
    if os.path.exists(path):
        print(name,'cached'); continue
    d={'token':tok}
    d['ibToken']=call(D,'getIbTokenFromToken(address)(address)',tok)
    if not d['ibToken'].startswith('ERR'):
        d['tokenFromIb']=call(D,'getTokenFromIbToken(address)(address)',d['ibToken'])
        d['debtToken']=call(D,'getDebtTokenFromToken(address)(address)',tok)
        d['miniFLPoolId']=call(D,'getMiniFLPoolIdOfToken(address)(uint256)',tok)
        d['ibTotalSupply']=call(d['ibToken'],'totalSupply()(uint256)')
        d['ibTotalAssets']=call(d['ibToken'],'totalAssets()(uint256)')
        d['ibBalanceOfDiamond']=call(d['ibToken'],'balanceOf(address)(uint256)',D)
        d['ibBalanceOfMiniFL']=call(d['ibToken'],'balanceOf(address)(uint256)',MFL)
        d['ibBalanceOfAM']=call(d['ibToken'],'balanceOf(address)(uint256)',AM)
    d['floating']=call(D,'getFloatingBalance(address)(uint256)',tok)
    d['globalDebt']=call(D,'getGlobalDebtValue(address)(uint256)',tok)
    d['globalDebtPend']=call(D,'getGlobalDebtValueWithPendingInterest(address)(uint256)',tok)
    d['overCollatDebtValue']=call(D,'getOverCollatTokenDebtValue(address)(uint256)',tok)
    d['overCollatDebtShares']=call(D,'getOverCollatTokenDebtShares(address)(uint256)',tok)
    d['totalCollat']=call(D,'getTotalCollat(address)(uint256)',tok)
    d['protocolReserve']=call(D,'getProtocolReserve(address)(uint256)',tok)
    d['totalToken']=call(D,'getTotalToken(address)(uint256)',tok)
    d['totalTokenPend']=call(D,'getTotalTokenWithPendingInterest(address)(uint256)',tok)
    d['interestModel']=call(D,'getOverCollatInterestModel(address)(address)',tok)
    d['tokenConfig']=call(D,'getTokenConfig(address)((uint8,uint16,uint16,uint64,uint256,uint256))',tok)
    d['tokenBalanceOfDiamond']=call(tok,'balanceOf(address)(uint256)',D)
    d['tokenBalanceOfAM']=call(tok,'balanceOf(address)(uint256)',AM)
    d['tokenBalanceOfMiniFL']=call(tok,'balanceOf(address)(uint256)',MFL)
    json.dump(d, open(path,'w'), indent=1)
    print(name,'done', flush=True)
# merge
out={}
for name in tokens:
    p=f'partial/{name}.json'
    if os.path.exists(p): out[name]=json.load(open(p))
json.dump(out, open('markets_live.json','w'), indent=1)
print('MERGED', len(out))
