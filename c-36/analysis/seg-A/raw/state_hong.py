import sys; sys.path.insert(0,'raw'); import rpc, json
A="0x9fa8fa61a10ff892e4ebceb7f4e0fc684c2ce0a9"
sigs=["isFundLocked()","isFundReleased()","isDistributionReady()","isDistributionInProgress()",
"isHarvestEnabled()","isFreezeEnabled()","isMinTokensReached()","isMaxTokensReached()",
"tokensCreated()","bountyTokensCreated()","closingTime()","currentFiscalYear()","totalInitialBalance()",
"returnWallet()","extraBalanceWallet()","managementFeeWallet()","rewardWallet()","managementBodyAddress()",
"owner()","weiPerInitialHONG()","maxTokensToCreate()","minTokensToCreate()","isDayThirtyChecked()","isDaySixtyChecked()",
"supportHarvestQuorum()","isKickoffEnabled(uint256)","lastKickoffDate()","isInTestMode()"]
calls=[{"to":A,"data":rpc.sel(s)} for s in sigs[:27]]
calls.append({"to":A,"data":rpc.sel("isKickoffEnabled(uint256)")+"0000000000000000000000000000000000000000000000000000000000000000"})
res=rpc.calls(calls)
bn=rpc.block_number()
print('block',bn)
for s,r in zip(sigs[:27]+["isKickoffEnabled(0)"],res):
    print(f"{s:40s} {r}")
# balances of wallets
w={}
for s,r in zip(sigs,res):
    if s.endswith('Wallet()') or s=='managementBodyAddress()' or s=='owner()':
        w[s]=('0x'+r[-40:]) if isinstance(r,str) and len(r)>=42 else r
print(json.dumps(w,indent=1))
bal=rpc.balances(list(set(w.values())))
print(json.dumps(bal,indent=1))
