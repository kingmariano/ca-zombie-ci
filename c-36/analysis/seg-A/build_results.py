#!/usr/bin/env python3
"""Finish seg-A: synthesize results.json from the child's raw evidence + parent verification."""
import json, os

BASE = "/home/heisenberg/CA/c-36/analysis"
segA = json.load(open(f"{BASE}/seg_A_addrs.json"))
wl = json.load(open(f"{BASE}/worklist.json"))
BLOCK = 26111193

# classification map: address -> (class, claim_model, evidence list, confidence, notes)
C = {
"0xb59a226a2b8a2f2b0512baa35cc348b6b213b671": ("H-O", "EtherToken.withdraw(amount) pays caller's own _balances[msg.sender]; reclaim(token) is ROLE_RECLAIMER-gated.",
    ["verified source EtherToken: withdraw requires _balances[msg.sender]; msg.sender.transfer", "prior deep-dive: v1 fully backed, self-only; index +3,383 gap is a counting artifact"], "high", "Index blind spot (3,385 live vs 2.07 mapped) = un-enumerated holders, not extractable."),
"0x0b7dc5a43ce121b4eaaa41b0f4f43bba47bb8951": ("H-O", "EtherToken v2 withdraw/withdrawPrivate pays caller's own _balances[msg.sender].",
    ["verified source: withdrawPrivate requires _balances[msg.sender]; withdraw/withdrawAndSend wrap it", "index note: 329.83 ETH tracked under LockedAccount, 54.18 excluded (withdraw reverts) -> +285.6 gap is not a shortfall"], "high", "Prior deep-dive covered v1+v2 conflation; all claim flows self-only."),
"0xb1E4675f0dBE360bA90447A7e58c62C762Ad62D4": ("H-O", "LockedAccount v1 withdraw pays caller's own balance; 0 ETH on contract (backing lives in paired EtherToken v1).",
    ["verified source LockedAccount: withdraw requires _balances[msg.sender]", "prior deep-dive: v1 LockedAccount holds exactly its totalLockedAmount (100% backed)"], "high", "No live ETH on this address."),
"0xECF8F87f810EcF450940c9f60066b4a7a501d6A7": ("H-O", "Original 2016 WETH wrapper: withdraw() burns caller's own balance and sends ETH.",
    ["unverified bytecode, standard WETH runtime; selector set matches WETH (deposit/withdraw/transfer/approve/balanceOf)", "holder simulation (child A): withdraw(own balance) OK 824/986, ok_sum 1,367.90 of 1,512.06 ETH; failures are contract wallets / stale balances"], "high", "~144 ETH tail may be stuck for non-EOA/stale holders, but $0 to a non-holder attacker."),
"0x2956356cd2a2bf3202f771f50d3d14a367b48070": ("H-O", "Maker W-ETH: withdraw(amount) requires balances[msg.sender] >= amount; sends to caller.",
    ["verified source EtherToken: balances[msg.sender] = safeSub(...); require(msg.sender.send(amount))"], "high", ""),
"0xD76b5c2A23ef78368d8E34288B5b65D616B746aE": ("H-O", "Bancor Old ETH Token: withdraw(_amount) debits balanceOf[msg.sender]; withdrawTokens is ownerOnly.",
    ["verified source: balanceOf[msg.sender] = safeSub(...); assert(msg.sender.send(_amount))", "withdrawTokens ownerOnly"], "high", ""),
"0x9fa8fa61a10ff892e4ebceb7f4e0fc684c2ce0a9": ("H-O", "HONG.refundMyIcoInvestment(): refunds caller's tracked weiGiven (requires holding HONG); 100% covered.",
    ["child A simulation at block 26,111,193: 43/43 outstanding holders refund OK, sum exactly 727.9738 ETH vs 727.9738 outstanding", "verified source: weiGiven[msg.sender], onlyTokenHolders, notLocked", "extraBalanceWallet child 0x034Cf4F8 holds 0 ETH"], "high", "Historical overflow was worked around; every recorded entitlement is claimable by its own holder. $0 non-holder."),
"0x899f9a0440face1397a1ee1e3f6bf3580a6633d1": ("H-O", "Delphi.redeemTokens(amount): transferFrom(msg.sender) burns caller's DEL for ETH at fixed exchangeRate.",
    ["verified source: require(Token(token).transferFrom(msg.sender, this, amount)); msg.sender.transfer(amount/exchangeRate)"], "high", ""),
"0x575cb87ab3c2329a0248c7d70e0ead8e57f3e3f7": ("H-O", "Ahoolee.refund(): saleBalances[msg.sender] only, refunded[msg.sender] guard; withdraw() is onlyOwner (softCapReached).",
    ["verified source AhooleeTokenSale: require(!refunded[msg.sender]); require(saleBalances[msg.sender] != 0)"], "high", ""),
"0x9AcA6aBFe63A5ae0Dc6258cefB65207eC990Aa4D": ("H-O", "DigiPulse.refundEther(): ethBalanceOf[msg.sender] zeroed then paid; requires icoFailed.",
    ["holder simulation from top depositor (10 ETH) -> OK; random address -> revert", "verified source: ethBalanceOf[msg.sender]"], "high", ""),
"0xe9778e69a961e64d3cdbb34cf6778281d34667c2": ("H-O", "NuCypher WorkLock: refund() pays msg.sender's own deposit; forceRefund(bidders) pays the listed bidders, never the caller.",
    ["verified source WorkLock: refund uses workInfo[msg.sender]; forceRefund transfers to _biddersForRefund entries"], "high", "forceRefund is a permissionless accounting/refund trigger but sends only to recorded bidders."),
"0x12d5b7c26DD8dc6E2F71f5bF240d5e76452b2FE5": ("H-O", "DirectCrypt.refund(): deposited[msg.sender] zeroed then paid; withdraw() onlyOwner.",
    ["holder simulation from top depositor -> OK", "verified source: refunded[msg.sender] guard, deposited[msg.sender]"], "high", ""),
"0xcc89405e3cfd38412093840a3ac2f851dd395dfb": ("H-O", "Status Buyer.withdraw(): deposits[msg.sender] zeroed then paid (with bounty adjustment).",
    ["verified source StatusBuyer: user_deposit = deposits[msg.sender]; deposits[msg.sender] = 0"], "high", ""),
"0x344285b2082d9c7981241dcc160beca6057637e6": ("H-O", "JustHodlIt: withdrawAll()/withdrawDividends() use users[msg.sender].",
    ["verified source JustHodlIt: User storage user = users[msg.sender]; msg.sender.transfer(payout)"], "high", ""),
"0xcd806502ad2f9aeb32e23f8d647341d4b568201d": ("H-O", "TruckHash.refund(): weiBalances[msg.sender] zeroed then paid; refundAllowed=true, softCapReached=false live.",
    ["live refundAllowed=true, softCapReached=false; verified source refund uses weiBalances[msg.sender]", "top balance-file address has weiBalances=0 on-chain (stale entry), so sim reverts for that address only"], "high", ""),
"0xb3b33f59174f2ef62167770e4c9cabaa3879eb5d": ("H-O", "Jincor.refund(): deposited[msg.sender] zeroed then paid; withdraw() onlyOwner.",
    ["holder simulation from top depositor -> OK", "verified source: deposited[msg.sender]"], "high", ""),
"0x3A8A97123bcCd826228e5EB4144b48cce169517B": ("H-O", "QCO.requestRefund(): ethPossibleRefunds[msg.sender] zeroed then paid; state Aborted live.",
    ["holder simulation from top depositor (11.4 ETH) -> OK; random -> revert", "verified source: requireState(States.Aborted); ethPossibleRefunds[msg.sender]"], "high", ""),
"0x1BB28e79f2482df6bf60efc7a33365703bCF1536": ("H-O", "hodlEthereum.party(): hodlers[msg.sender] zeroed then paid.",
    ["verified source: require(hodlers[msg.sender] > 0); msg.sender.transfer(value)"], "high", ""),
"0x9EA80e204045329Ba752D03C395F82A12799f13d": ("H-O", "Blocklancer.refund(): balances[msg.sender] / balancesEther[msg.sender] zeroed then paid.",
    ["holder simulation from top depositor (7 ETH) -> OK", "verified source: var ethValue = balancesEther[msg.sender]"], "high", ""),
"0xaf7aeA249098F2c2f50cc11d4000Ccf798194373": ("H-O", "ZeroTraffic.refund(): balances[msg.sender] zeroed then sent; requires stage Ended. endCrowdsale() is permissionless after end but pays only depositors.",
    ["verified source: refund atStage(Ended) uses balances[msg.sender]; endCrowdsale requires now >= end", "live stage=0, raised 28.4 ETH < min 20,000 ETH"], "high", "Permissionless state transition exists but yields no value to the caller."),
"0xe4972421f88c1f47986f54cbfd2d1e2e671680ac": ("H-O", "Abyss.refundCrowdsaleContributor(): contributions[msg.sender] zeroed then paid; state CrowdsaleRefund live.",
    ["holder simulation from top depositor -> OK", "verified source: require(state == FundState.CrowdsaleRefund); contributions[msg.sender]"], "high", ""),
"0xe8b1b40f2d307bce891833f46eef1f69560e6926": ("H-O", "Bayesin.safeWithdrawal(): fundBalance[msg.sender] zeroed then paid.",
    ["holder simulation -> OK", "verified source: fundBalance[msg.sender]"], "high", ""),
"0x17681500757628c7aa56d7e6546e119f94dd9479": ("H-O", "Confideal.withdrawRefund(): contributions[msg.sender] zeroed then paid; stage Failure live.",
    ["holder simulation -> OK", "verified source: withdrawRefund atStage(Failure) uses contributions[msg.sender]"], "high", ""),
"0x4363b5d64f228c819dc706889b09a0dc76e22fb0": ("H-O", "Crowdsale 0x4363b5: releaseEthers() pays etherHoldings[msg.sender]; returnETher(address) is a view.",
    ["verified source: releaseEthers uses msg.sender; returnETher is `return etherHoldings[_addr]`"], "high", ""),
"0xc699d90671cb8373f21060592d41a7c92280adc4": ("H-O", "Crowdsale 0xc699d9.refund(): balances[msg.sender] zeroed then paid.",
    ["holder simulation -> OK", "verified source: balances[msg.sender]"], "high", ""),
"0xe8205644fef286a2af423b72669e662feec127cd": ("H-O", "Crowdsale 0xe82056.safeWithdrawal(): balanceOf[msg.sender] zeroed then sent.",
    ["holder simulation -> OK", "verified source: balanceOf[msg.sender]"], "high", ""),
"0x6f303642844f734ad4176d0dfe93ef7e0776ef46": ("H-O", "CrowdsaleWatch.safeWithdrawal(): balanceOf[msg.sender] zeroed then sent.",
    ["holder simulation -> OK", "verified source: balanceOf[msg.sender]"], "high", ""),
"0x3091d37ef18cb33af72cf7ca63714733172ce724": ("H-O", "Gateway.refund(): balances[msg.sender] zeroed then paid.",
    ["holder simulation -> OK", "verified source: balances[msg.sender]"], "high", ""),
"0xa8df33a40fe2e3278e4d94a974f70778043fbd20": ("H-O", "I2 Presale.safeWithdrawal(): balanceOf[msg.sender] zeroed then sent.",
    ["holder simulation -> OK", "verified source: balanceOf[msg.sender]"], "high", ""),
"0xe117bb9d1e0fc6e859d9bf174c53baa7c673547a": ("H-O", "Mahala.refund(): balances[msg.sender] zeroed then paid.",
    ["holder simulation -> OK", "verified source: balances[msg.sender]"], "high", ""),
"0xde0b79f5e66fdc8a4ffb2c470756a1629e8ad569": ("H-O", "Reservation2.withdraw(): balanceOf[msg.sender] zeroed then paid.",
    ["holder simulation -> OK", "verified source: balanceOf[msg.sender]"], "high", ""),
"0x6feaf4e8f386c08b4518c175874b332329d0d6ba": ("H-O", "SingularDTV.withdrawContribution(): sentTokens[msg.sender]/contributions[msg.sender] only (needs token approval).",
    ["verified source: withdrawContribution uses sentTokens[msg.sender], contributions[msg.sender]"], "high", ""),
"0xe8da050c3140183d4f5f01e048ac136e2da5253f": ("H-O", "Start Mining.manualRefund(): ico_buyers_eth[msg.sender] zeroed then paid.",
    ["holder simulation -> OK", "verified source: ico_buyers_eth[msg.sender]"], "high", ""),
"0x943e99d9efd4b44d808f6c83373a9a2c1e15e0f8": ("H-O", "Foreground.claimRefund(): purchases[msg.sender].weiBalance zeroed then paid; state Refunding live.",
    ["holder simulation -> OK; live state=6 (Refunding)", "verified source: purchases[msg.sender].weiBalance"], "high", ""),
"0xcba6f10d1147b2c5a3d8d8cbd93c373b31c6c2c8": ("H-O", "VuePay.claimRefund(): ETHContributed[msg.sender] zeroed then paid; allowRefund=true live.",
    ["holder simulation -> OK; live allowRefund=true", "verified source: ETHContributed[msg.sender]"], "high", ""),
"0x18777Aec0B231D1a4A9C66B51253088a03affDFc": ("H-O", "Luckchemy.refund(): deposits[msg.sender] zeroed then paid.",
    ["holder simulation -> OK", "verified source: deposits[msg.sender]"], "high", ""),
"0x3fD30f3E1fbF4F3Ea6BDf3E3bb11826266708869": ("H-O", "AgroTechFarm.refund(): balances[msg.sender] zeroed then paid; state Refunding live (state=1).",
    ["live state=1; verified source: balances[msg.sender]"], "high", ""),
"0xe9426198aec621203ba1fe07cf292b3796ba6248": ("H-O", "Ambassadors Fund is an OZ PaymentSplitter: release(account) pays the account per its shares; caller gets nothing.",
    ["verified source: release(address payable account) sends to account, not msg.sender"], "high", ""),
"0x4d1886daf2617cbd9e27abfd0f18a54f04f33c41": ("H-O", "SpankChain Auction (unverified): deposit()/withdraw() pool; withdraw(1e18) reverts for non-depositor; top depositor withdraw() sim OK.",
    ["unverified; selector set incl. deposit()/withdraw()/balanceOf/transfer/token", "cast call withdraw() from top depositor (69 ETH) -> OK; withdraw(1e18) from fresh -> revert; deposit()/fail-style admin fns revert for randoms"], "medium", "Source unverified; self-scoping inferred from live probes (depositor sims succeed, non-depositor withdraw reverts)."),
"0x48c128eafc3b937fb1f97889ad174ac02b4952cb": ("H-O", "Presale Pool 0x48c128 (unverified pool family): withdrawAll()/withdraw(uint) self-scoped; fail()/transferFees()/deposit() revert for randoms.",
    ["top depositor (45.8 ETH) withdrawAll() -> OK; fresh address withdrawAll() -> success with 0; withdraw(1e18) -> revert; fail()/transferFees() -> revert"], "medium", "7-pool family (284.9 ETH total) shares the same selector set; all probed members behave self-scoped."),
"0xff2c689cb750f2a7d46e7471521189ced948f965": ("H-O", "Presale Pool 0xff2c68 (same family): withdrawAll() from sole 50 ETH depositor -> OK.",
    ["holder sim OK"], "medium", "Family member."),
"0xd6770aac65a48f5715889a4cdbf30a4faf73a073": ("H-O", "Presale Pool 0xd6770a (same family).", ["family selector match; self-scoped withdraw pattern"], "medium", "Family member."),
"0x796dbc51b37f2d92b0af1271fd9520c8efd1be61": ("H-O", "Presale Pool 0x796dbc (same family).", ["family selector match"], "medium", "Family member."),
"0x50c19ffdbda85d1a07c09f01e113a94923801d32": ("H-O", "Presale Pool 0x50c19f (same family).", ["family selector match"], "medium", "Family member."),
"0x6f40d96713b60d5083bc2493251907ca673de1b8": ("H-O", "Presale Pool 0x6f40d9 (same family).", ["family selector match"], "medium", "Family member."),
"0xb9906cf500d5e61b9673115151104c990a804dcb": ("H-O", "Presale Pool 0xb9906c (same family).", ["family selector match"], "medium", "Family member."),
"0xf8f6e626af09b0455acd9162beb5a484724f25b5": ("H-O", "PresalePool 2018 (unverified): withdrawAll() from top depositor (10 ETH) -> OK; index note says participants call withdrawAll().",
    ["top depositor withdrawAll() -> OK", "unverified; selector set shares withdraw/withdrawAll/deposit with the presale family"], "medium", ""),
"0xf058ee35f381a12b3a0f504025419dcaf047ce7f": ("H-O", "Presale Pool LINO/HEALP/Bulleon (unverified): withdraw() from top depositor (14 ETH) -> OK; owner()/transferOwnership present.",
    ["top depositor withdraw() -> OK", "selectors: 3ccfd60b withdraw, 8da5cb5b owner, f2fde38b transferOwnership, 3af32abf isWhitelisted"], "medium", ""),
"0xe0b7927c4af23765cb51314a0e0521a9645f0e2a": ("H-O", "DigixDAO: ETH claimable by DGD holders via Acid.burn() (approve DGD + burn flow); Acid child holds 11,681.83 ETH.",
    ["Acid verified source: burn() uses DGD.balanceOf(msg.sender) + transferFrom; 0.193054 ETH/DGD", "DGD/WETH UniV2 pair price 0.1925 ETH ~= redemption rate -> no arb; pool covers ~3% of DGD supply -> holder race"], "high", "Child Acid 0x23ea10cc verified H-O; no E-U."),
"0xbb9bc244d798123fde783fcc1c72d3bb8c189413": ("H-O", "The DAO token (0 ETH); backing WithdrawDAO child holds 81,399.81 ETH. withdraw() pays caller's own DAO balance; trusteeWithdraw() underflows to a no-op.",
    ["WithdrawDAO verified source; negative-control probe: withdraw() from fresh -> throw; trusteeWithdraw() -> no ETH moves", "DAO token transferFrom/approve standard; no non-holder path found"], "high", "Largest pot in the index; holder-only."),
"0xd7e011ad27b6128934e2afd1763120ede1274ae4": ("H-O", "VLB RefundableCrowdsale: ETH sits in sibling RefundVault; depositors claimRefund() self-only (vault state).",
    ["verified source VLBCrowdsale/RefundVault: claimRefund -> vault.refund(msg.sender); refund(investor) pays investor"], "high", "Listed contract holds 0 ETH; sibling vault value."),
"0xb4f10530e531c32490c68062662eb5684057afb4": ("H-O", "PallyCoin RefundableCrowdsale: vault.refund(msg.sender) via claimRefund(); refundTokens onlyCrowdsale.",
    ["verified source: claimRefund requires hasEnded && !goalReached && isRefunding; vault.refund(msg.sender)"], "high", "Listed contract holds 0 ETH."),
"0x5113309c84f7292b5f780748df5869cb9d0e3ad5": ("H-O", "Trend (TND) OZ RefundableCrowdsale; ETH in sibling RefundVault; refund path depositor-only.",
    ["selector set = OZ MintableToken+RefundableCrowdsale (fa89401a refund, 8d4e4083 isFinalized, fbfa77cf vault)", "unverified source"], "medium", "Listed contract holds 0 ETH; vault child not enumerated."),
"0xc213f258f4142f53d086f9edb7a36e67eb347f63": ("P", "Transit refund: owner must setClaim(false,0); claim() pays _refund[msg.sender] (recorded entitlement) after unpause; emergencyWithdraw onlyExecutor.",
    ["verified source: setClaim onlyOwner; claim requires !_claimed[msg.sender] and _refund[msg.sender].amount > 0"], "high", "Unlock is privileged; then holder-only."),
"0xaf5fc45258b5d0af72031ab154bf6dfcfec74b99": ("P", "RemovePutinBounty: state Initial; owner must cancel(); redeem() requires state cancelled and pays balanceOf[msg.sender]; cancelNoWinner requires executed.",
    ["verified source: cancel isOwner; redeem requires cancelled; state live = initial", "PBTY token is transferable but no market found"], "high", "No permissionless transition from Initial."),
"0x5535a72556727c221c567e0fc4208c5a99dba1cc": ("P", "PembiCoinICO: state Idle; owner must setFailed(); refund() inState(Failed) pays amounts[msg.sender].",
    ["verified source: refund inState(Failed); setFailed onlyOwner"], "high", ""),
"0x93d812bf90a575d628e246b0966505a9e466f534": ("P", "Circles RefundVault: state Active; owner must enableRefunds(); refund(buyer) pays recorded depositor.",
    ["verified source: enableRefunds onlyOwner; refund requires state Refunding; state live = 0 (Active)", "owner is a contract (multisig/controller)"], "high", ""),
"0xa812137eff2b368d0b2880a39b609fb60c426850": ("P", "Contribution Pool: withdraw() onlyBeneficiary sends full balance to beneficiary.",
    ["verified source: withdraw external onlyBeneficiary"], "high", ""),
}

results = []
CL = {k.lower(): v for k, v in C.items()}
for a in segA:
    r = wl[a]
    cls, model, ev, conf, notes = CL.get(a.lower(), ("UNREVIEWED", "", [], "low", "not covered"))
    results.append({
        "address": a, "name": r.get("name"), "live_eth": r.get("live_eth"), "mapped": r.get("mapped"),
        "classification": cls, "claim_model": model, "evidence": ev,
        "eu_candidate": None, "confidence": conf, "notes": notes,
    })

from collections import Counter
cnt = Counter(x["classification"] for x in results)
out = {
    "segment": "A", "reviewed_at_block": BLOCK, "eth_balances_block": 26111101,
    "summary": {"contracts": len(results), "eu_candidates": 0, "class_counts": dict(cnt)},
    "results": results,
}
json.dump(out, open(f"{BASE}/seg-A/results.json", "w"), indent=1)
print("wrote seg-A/results.json:", len(results), dict(cnt))
un = [x["address"] for x in results if x["classification"] == "UNREVIEWED"]
print("unreviewed:", un)
