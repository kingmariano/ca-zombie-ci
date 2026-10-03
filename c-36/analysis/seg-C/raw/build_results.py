#!/usr/bin/env python3
"""Build seg-C/results.json from the analysis performed (read-only review)."""
import json, os

BASE = "/home/heisenberg/CA/c-36/analysis"
live = json.load(open(f"{BASE}/seg-C/raw/live_balances.json"))
lb = live["balances"]          # ETH balances at block 26111158
BLK = live["block"]

wl = json.load(open(f"{BASE}/worklist.json"))
def W(a):
    for k, v in wl.items():
        if k.lower() == a.lower():
            return v
    raise KeyError(a)

def E(a, name, cls, claim, evidence, notes, conf="high", eu=None):
    v = W(a)
    return {
        "address": a,
        "name": name,
        "live_eth": round(lb[a], 8),
        "mapped": v["mapped"],
        "classification": cls,
        "claim_model": claim,
        "evidence": evidence,
        "eu_candidate": eu,
        "confidence": conf,
        "notes": notes,
    }

R = []

# ---------------- PRIOR (one-line re-check) ----------------
R.append(E("0x2a0c0DBEcC7E4D658f48E01e3fA353F44050c208", "IDEX v1", "H-O",
  "Per-user ETH/token balances; withdraw() pays msg.sender only (Exchange contract).",
  [f"live 15729.774 ETH (block {BLK}); prior $0 — no new surface", "selectors match verified 'Exchange' source"],
  "PRIOR. No new surface; largest single pot in segment but self-service only.", "high"))
R.append(E("0x8d12A197cB00D4747a1fe03395095ce2A5CC6819", "EtherDelta v2", "H-O",
  "Per-user balances; withdraw()/withdrawToken() pay msg.sender after subtracting balance; admin cannot move user funds.",
  [f"live 15168.574 ETH (block {BLK}); prior $0 — no new surface", "verified EtherDelta source; admin set = 0x1ed014ae... only sets fees"],
  "PRIOR.", "high"))
R.append(E("0x1ce7ae555139c5ef5a57cc8d814a867ee6ee33d8", "Token.Store", "H-O",
  "Per-user balances; self withdraw only.",
  [f"live 632.620 ETH (block {BLK}); prior $0 — no new surface", "verified TokenStore source"],
  "PRIOR.", "high"))
R.append(E("0x373c55c277b866a69dc047cad488154ab9759466", "EtherDelta v1", "H-O",
  "Early EtherDelta (Dec 2016): per-user balances, self withdraw.",
  [f"live 122.273 ETH (block {BLK}); prior $0 — no new surface", "selectors match EtherDelta family; admin()=0x1ed014ae..."],
  "PRIOR (brief listed v1 as prior-covered if selectors match; they do).", "high"))
R.append(E("0x9a2d163ab40f88c625fd475e807bbc3556566f80", "SingularX", "H-O",
  "Per-user balances; self withdraw.",
  [f"live 854.996 ETH (block {BLK}); prior $0 — no new surface", "verified Dex source"],
  "PRIOR. Not to be confused with SingularX Fund (0x0286f9...).", "high"))
R.append(E("0x4d55f76ce2dbbae7b48661bef9bd144ce0c9091b", "Unknown DEX (0x4d55, EnclavesDEX old)", "H-O",
  "Per-user balances; self withdraw.",
  [f"live 2479.088 ETH (block {BLK}); prior $0 — no new surface", "worklist desc: 'ETH balances in defunct EnclavesDEX contract'"],
  "PRIOR.", "high"))
R.append(E("0xaA7427D8f17D87a28F5e1ba3aDBB270bAdbe1011", "Ethfinex Trustless", "H-O",
  "WrapperLockEth: per-user WETH-style balances; withdrawToken() self-only.",
  [f"live 929.510 ETH (block {BLK}); prior $0 — no new surface", "verified WrapperLockEth source"],
  "PRIOR.", "high"))
R.append(E("0x50cb61afa3f023d17276dcfb35abf85c710d1cff", "Ethfinex Trustless v2", "H-O",
  "WrapperLockEth v2; self-only withdraw.",
  [f"live 71.896 ETH (block {BLK}); prior $0 — no new surface"],
  "PRIOR.", "high"))
R.append(E("0x7ee7ca6e75de79e618e88bdf80d0b1db136b22d0", "Switcheo BrokerV2", "H-O",
  "Per-user deposits; self withdraw.",
  [f"live 406.894 ETH (block {BLK}); prior $0 — no new surface"],
  "PRIOR.", "high"))
R.append(E("0x0a14b696350546110a0d8acdb86226983af9d2a0", "zkSync Lite", "H-O",
  "zkSync v1 bridge; verified withdrawal root; users exit with merkle proof against verified root.",
  [f"live 10779.070 ETH (block {BLK}); prior root verified — no new surface", "live USDC 2.42M / DAI 907k / WETH 54.0 at block 26111283; decreasing (active withdrawals)"],
  "PRIOR. Balance dropped ~147 ETH since worklist measurement (26,111,001) — bridge is live, withdrawals ongoing.", "high"))
R.append(E("0x9508008227b6b3391959334604677d60169ef540", "CryptoCats v0/v1", "H-O",
  "Legacy CryptoCats contracts; self withdraw.",
  [f"live 43.685 ETH (block {BLK}); prior $0 — no new surface"],
  "PRIOR.", "high"))
R.append(E("0x4aea7cf559f67cedcad07e12ae6bc00f07e8cf65", "EtherDelta v0 (Aug 2016)", "H-O",
  "Original EtherDelta: per-user balances, self withdraw; no admin selector.",
  [f"live 220.892 ETH (block {BLK}); prior $0 — no new surface", "selectors = ED v0 set + order(); admin() reverts (no selector), withdraw(1) from random reverts"],
  "PRIOR (brief listed v0 as prior-covered if selectors match; they do).", "high"))
R.append(E("0x5995ca61d845e045cd1327a32707a66f7daccf6d", "Unknown DEX (0x5995)", "H-O",
  "Per-user balances; self withdraw.",
  [f"live 75.980 ETH (block {BLK}); prior $0 — no new surface"],
  "PRIOR.", "high"))

# ---------------- DEX family (non-prior) ----------------
R.append(E("0xbf29685856fae1e228878dfb35b280c0adcc3b05", "Decentrex", "H-O",
  "EtherDelta-clone: deposit()/depositToken(); withdraw() pays msg.sender after subtracting tokens[0][msg.sender]; admin only changes fees.",
  ["verified source 'DecentrEx' (EtherDelta clone)", "admin()=0xfeed93432ba27ac818dbc97ec67bc227d8318d4b; withdraw(1) from random reverts (0 balance)"],
  "ED family. No admin fund path. 33.09 ETH user balances."))
R.append(E("0x04f062809b244e37e7fdc21d9409469c989c2342", "Joyso", "H-O",
  "lockMe() → wait lockPeriod → withdraw() self-only; admin withdrawals require admin role + user signature; collectFee onlyOwner (fee balance).",
  ["verified Joyso source: withdraw() requires userLock[msg.sender] and subtracts balances[token][msg.sender]",
   "withdrawByAdmin_Unau is onlyAdmin and hash-bound"],
  "Owner 0x3a6386e7...; 83.25 ETH user balances; admin cannot unilaterally take user funds without user sig."))
R.append(E("0xf4c27b8b002389864ac214cb13bfeef4cc5c4e8d", "ETHEN", "H-O",
  "withdrawEther() subtracts balances[msg.sender] and pays msg.sender; trading requires maker signature verified against signer.",
  ["verified Ethen source: withdrawEther() -> balances[msg.sender] sub then msg.sender.transfer",
   "getVerifiedHash requires ecrecover(...) == _signer (maker)"],
  "43.52 ETH user balances + feeCollector balance."))
R.append(E("0x3c020e014069df790d4f4e63fd297ba4e1c8e51f", "Bitcratic", "H-O",
  "EtherDelta clone: self withdraw.",
  ["verified 'Bitcratic' source = ED clone; admin()=0x71741d9f..."],
  "30.00 ETH user balances."))
R.append(E("0xd8d48e52f39ab2d169c8b562c53589e6c71ac4d3", "EtherC", "H-O",
  "EtherDelta clone with tradeTracker; self withdraw; trade requires ecrecover == maker.",
  ["verified ETHERCExchange source: withdraw() subtracts tokens[address(0)][msg.sender]",
   "trade() checks ecrecover(EIP-191 hash) == _maker and orderFills"],
  "4.81 ETH user balances; owner can only change fees/tracker."))
R.append(E("0xbf45f4280cfbe7c2d2515a7d984b8c71c15e82b7", "EnclavesDex (proxy)", "H-O",
  "Proxy → EnclavesDEX impl: withdraw() self-only; user balances. Admin can upgrade impl (2-week timelock).",
  ["verified EnclavesDEXProxy + EnclavesDEX impl sources", "getImplementation()=0xed06d46FFB309128C4458A270C99c824dc127f5D; admin()=0x0B2dF89a0f816144c50400Cac69f25DeD20e774F",
   "withdraw() -> withdrawUser(amount, msg.sender); impl source verified"],
  "INSOLVENT: live 7.096 ETH vs index-mapped 17.93 user balances (~10.8 ETH shortfall; rebalance pulls from dead EtherDelta). First-mover race among holders — flag for fork testing. Admin upgrade = P drain risk.",
  "medium"))
R.append(E("0x6090A6e47849629b7245Dfa1Ca21D94cd15878Ef", "ENS Old Registrar", "S",
  "0 ETH live. Historic bid ETH was held in per-bid Deed child contracts (newBid creates a Deed); unsealBid/releaseDeed/cancelBid operate on deeds.",
  [f"live 0.000 ETH (block {BLK}); mapped 8983.98 was never in the registrar itself",
   "verified Registrar source: newBid() deploys Deed holding msg.value; unsealBid self-only via sealedBids[msg.sender][seal]; releaseDeed onlyOwner(_hash); cancelBid is a permissionless 0.5% penalty on abandoned bids (pays caller 0.5%, burns 99.5% to ENS burn address)"],
  "No funds at this address. Deeds are separate child contracts (not in this segment's address list; children_from_descriptions has none). cancelBid cannot be exploited for the registrar balance (zero).", "high"))
R.append(E("0x22a97c80d7e0a9ae616737e3b8b531248f4ef91d", "Confideal", "H-O",
  "Failed crowdfunding campaign (stage=Failure): withdrawRefund() pays msg.sender's contributions[msg.sender] (nonReentrant); withdrawPayout only beneficiary at Success.",
  ["verified Campaign source", "stage()=3 (Failure); amountRaised=303.24 ETH vs goal 70,000 ETH; live 45.72 ETH = unclaimed refunds"],
  "Self-service refunds only."))
R.append(E("0x2f23228b905ceb4734eb42d9b42805296667c93b", "Coinchangex", "H-O",
  "EtherDelta clone with special fees; self withdraw; depositForUser credits the target user.",
  ["verified source; admin()=0xb2d2e17addbf654f7a9e4d65975ab715d3022355"],
  "17.35 ETH user balances."))
R.append(E("0xbeeb655808e3bdb83b6998f09dfe1e0f2c66a9be", "SwissCryptoExchange", "H-O",
  "EtherDelta clone with whitelists; self withdraw.",
  ["verified source; admin()=0xf909d2168d2623967e0e870c89576b0948dd32af"],
  "7.83 ETH user balances."))
R.append(E("0x3da70c70b9574ff185b31d70878a8e3094603c4c", "LSCX", "H-O",
  "EtherDelta-derived exchange with on-chain tiker order book; withdraw self-only (ED pattern); admin functions (changeStorageAddr/changeFeeMarket/deleteOrders/setOrders/tiker) revert for random callers.",
  ["unverified; selectors resolve to ED + tiker/order-book functions",
   "cast call changeStorageAddr(address), deleteOrders, setOrders, changeAdmin, changeFeeMarket from 0x1111... all revert (INVALID / guard)",
   "storageAddr()=0xb718339A3b090d68a91Ca80cEf7AdF8A69ff2421; admin()=0xCe0F7b59FC961dce6Ad236579eEB8Afb73D1A3cd; feeMarket=5e17"],
  "6.45 ETH user balances. Admin gated; no unguarded setter found.", "medium"))
R.append(E("0x232ba9f3b3643ab28d28ed7ee18600708d60e5fe", "Bitcratic v1", "H-O",
  "EtherDelta clone; self withdraw.",
  ["verified source; selectors = ED v2 exactly"],
  "3.06 ETH."))
R.append(E("0x2f13fa06c0efd2a5c4cf2175a0467084672e648b", "MarketPlace", "H-O",
  "ED/TokenStore-family escrow exchange; withdraw() subtracts tokens[0][msg.sender].",
  ["verified source: withdraw(uint) requires tokens[0][msg.sender] >= amount then transfer",
   "withdrawToken similar; owner-only fee setters"],
  "2.46 ETH."))
R.append(E("0xb5adb233f28c86cef693451b67e1f2d41da97d21", "Bitox", "H-O",
  "EtherDelta clone + feeAccount2; self withdraw.",
  ["verified BITOX source; extras changeFeeAccount2(address)/feeAccount2()"],
  "2.25 ETH."))
R.append(E("0xc5138d4bd0ec5c51b6b6bdfcb8528ad9c333af97", "ED Fork (0xc513)", "H-O",
  "EtherDelta v2 clone (identical selector set); self withdraw; admin()=0xdfD4b388...; withdraw(1) from random reverts.",
  ["unverified; selector set == EtherDelta v2 exactly", "admin()=0xdfD4b388467301EB592e41A5A2B9C3A9EB009B1f"],
  "6.92 ETH user balances.", "medium"))
R.append(E("0x499197314f9903a1ba9bed7ee54cd9eee5900e49", "Ethernext", "H-O",
  "EtherDelta v2 clone; self withdraw.",
  ["verified 'Amplbitcratic' source (ED clone); selectors == ED v2"],
  "1.32 ETH."))
R.append(E("0xd4cc0cda97ec567235b7019c655ec75cd361f712", "SeedDex v2", "H-O",
  "Escrow exchange; withdraw() subtracts tokens[0][msg.sender]; migrateFunds() only moves caller's own balance.",
  ["verified SEEDDEX source", "migrateFunds(newContract,tokens) uses tokens[0][msg.sender] and credits msg.sender on the target"],
  "1.27 ETH. Migration functions self-only."))
R.append(E("0xcf25ebd54120cf2e4137fab0a91a7f7403a5debf", "SeedDex v3", "H-O",
  "Escrow exchange; withdraw() self-only; migrateFunds() caller's own balance; setSuccessor onlyAdmin; changeManager isManager.",
  ["verified SEEDDEX source; withdraw() checks tokens[0][msg.sender]",
   "migrateFunds() zeroes caller's balance and calls newExchange.depositForUser{value}(msg.sender)"],
  "1.18 ETH."))
R.append(E("0x25066b77ae6174d372a9fe2b1d7886a2be150e9b", "PolarisDEX", "H-O",
  "EtherDelta v2 clone; self withdraw.",
  ["verified PolarisDEX source; selectors == ED v2"],
  "1.21 ETH."))
R.append(E("0x2b44d68555899dbc1ab0892e7330476183dbc932", "Ethmall", "H-O",
  "EtherDelta v2 clone; self withdraw.",
  ["verified Ethmall source; selectors == ED v2"],
  "1.04 ETH."))
R.append(E("0x97c9e0eccc27efef7330e89a8c9414623ba2ee0f", "ExToke", "H-O",
  "EtherDelta clone; withdraw() self-only; trade checks ecrecover==user.",
  ["verified source; owner/admin = 0xf7dc4e3fc9c7cb5be76717ed7877bf461dcdb1a7"],
  "0.91 ETH."))
R.append(E("0x4bc78f6619991b029b867b6d88d39c196332aba3", "AlgoDEX", "H-O",
  "EtherDelta v2 clone; self withdraw.",
  ["verified source; selectors == ED v2"],
  "0.87 ETH."))
R.append(E("0x51a2b1a38ec83b56009d5e28e6222dbb56c23c22", "nDEx", "H-O",
  "EtherDelta v2 clone; self withdraw.",
  ["verified nDEXMarket source; selectors == ED v2"],
  "0.64 ETH."))
R.append(E("0x4fbcfa90ac5a1f7f70b7ecc6dc1589bbe6904b02", "EDex", "H-O",
  "EtherDelta v2 clone; self withdraw.",
  ["verified EDex source; selectors == ED v2"],
  "0.54 ETH."))
R.append(E("0xc6b330df38d6ef288c953f1f2835723531073ce2", "Etheropt Old", "H-O",
  "Early EtherDelta (v0 family): deposit/withdraw self-only; no admin selector.",
  ["unverified; selectors = ED v0 set + order(); no admin() selector; withdraw(1) from random reverts"],
  "16.84 ETH user balances. Family-consistent; no admin surface.", "medium"))
R.append(E("0xc3c12a9e63e466a3ba99e07f3ef1f38b8b81ae1b", "SwitchDex", "H-O",
  "EtherDelta v2 fork + AccountLevels: per-user balances, self withdraw; extra admin functions (changeAccountLevels/changeFeeMake/changeFeeTake/changeAdmin) revert for random callers.",
  ["unverified; selector set = ED v2 + accountLevels(address) + changeAccountLevels(address)",
   "admin()=0x194AFBF7A5000eEF3e166E1771EfbAf5bf9f8611; feeMake=0; feeTake=2e15",
   "cast call withdraw(uint256), changeAdmin, changeFeeMake, changeFeeTake, changeAccountLevels from 0x1111... all revert (INVALID)"],
  "101.11 ETH user balances. No unguarded admin path found.", "medium"))

# ---------------- NFT / marketplaces ----------------
R.append(E("0x068696a3cf3c4676b65f1c9975dd094260109d02", "DADA Collectible", "H-O",
  "CryptoPunks-style market: buyCollectible/alt_buyCollectible pay seller via pendingWithdrawals; withdrawBidForCollectible/withdraw self-only.",
  ["verified DadaCollectible source: withdraw() zeroes pendingWithdrawals[msg.sender] then transfer; bid withdraw requires bid.bidder == msg.sender"],
  "11.21 ETH = active bids + pending seller withdrawals."))
R.append(E("0x60cd862c9c687a9de49aecdc3a99b74a4fc54ab6", "MoonCatRescue", "H-O",
  "Adoption escrow: transferCat credits pendingWithdrawals[seller] += price and refunds requester; withdraw() pays msg.sender's pendingWithdrawals; cancelAdoptionRequest self-only.",
  ["verified MoonCatRescue source: withdraw() -> pendingWithdrawals[msg.sender]=0 then msg.sender.transfer",
   "cancelAdoptionRequest requires existingRequest.requester == msg.sender; acceptAdoptionOffer requires offer.exists + buyer pays; nameCat is free (no ETH)"],
  "233.29 ETH = offer proceeds + adoption-request deposits + overpayment refunds. No non-holder path."))
R.append(E("0xd6c037be7fa60587e174db7a6710f7635d2971e7", "CryptoPhunks Marketplace", "H-O",
  "CryptoPunks-style: buyPhunk pays seller via pendingWithdrawals; acceptBidForPhunk only phunk owner; withdrawBidForPhunk/withdraw self-only.",
  ["verified CryptoPhunksMarket source: withdrawBidForPhunk requires bid.bidder == msg.sender; withdraw() zeroes pendingWithdrawals[msg.sender]"],
  "86.21 ETH = active bids + pending withdrawals."))
R.append(E("0x19c320b43744254ebdbcb1f1bd0e2a3dc08e01dc", "CryptoCats Marketplace", "H-O",
  "Cats market: buyCat credits seller pendingWithdrawals; getCat credits contract owner pendingWithdrawals; withdraw() pays msg.sender.",
  ["verified CryptoCatsMarket source", "getContractOwner()=0xd7148578159b87a9EFA2f0290531B44b0f9063D1; pendingWithdrawals(owner)=34.88 ETH; allCatsAssigned=false, catsRemainingToAssign=0"],
  "45.49 ETH live; ~34.88 is the owner's claimable mint proceeds (P), ~10.6 is sellers'/bidders' self-service. No non-holder path."))
R.append(E("0x19c10FFf96B80208f454034C046CCc4445Cd20ba", "Age of Dinos (AuctionMinter)", "H-O",
  "Sealed-bid auction: claimAndRefund() pays msg.sender's own refund/nftCount (hasClaimed guard); sendPayment() is permissionless but pays fixed paymentRecipient.",
  ["verified AuctionMinter source: claimInfo(msg.sender); hasClaimed[msg.sender]=true; refund to msg.sender",
   "sendPayment() requires auctionEnded and pays paymentRecipient (fixed)"],
  "24.99 ETH = bids/refunds. emergencyWithdraw onlyRole(DEFAULT_ADMIN_ROLE) = P risk."))
R.append(E("0xDe5D4949F445650325c7C8739610c3A979C7a6db", "PersonaBid (RaffleAuctionMinter)", "H-O",
  "Raffle auction: placeBid requires gateway signature; claimAndRefund() self-only with hasClaimed guard.",
  ["verified RaffleAuctionMinter source: _checkSigValidity(inputHash, sig, nftManager(nftAddress)); refund to msg.sender"],
  "15.04 ETH = bids/refunds."))
R.append(E("0x0c7060bf06a78aaaab3fac76941318a52a3f4613", "Fractional DEAD Vault", "H-O",
  "Tessera TokenVault (logic 0x7B0fCE54...): auctionState=ended → cash() burns caller's shares and pays pro-rata ETH; redeem() requires full supply; claimFees() mints to curator/gov only.",
  ["verified InitializedProxy + TokenVault sources", "auctionState=2 (ended), totalSupply=2.8419e22, balance=44.696 ETH, curator=0x...dEaD, winning=0xd2C1A013..."],
  "cash() is self-only; pro-rata exact (sum of claims == totalSupply share of balance). claimFees is permissionless but mints tokens to curator/governance, not caller."))
R.append(E("0xfe2a5b942083d92135c7fe364bb75218e547cc62", "Fractional SWEEP Vault", "H-O",
  "Same TokenVault logic; auctionState=ended; cash() self-only pro-rata.",
  ["auctionState=2, totalSupply=1.427e24, balance=19.746 ETH"],
  "No non-holder path."))
R.append(E("0xdb846f1cd31acc9a6db72a1c58dc1760485505f4", "Fractional ZCAT Vault", "H-O",
  "Same TokenVault logic; auctionState=ended; cash() self-only pro-rata.",
  ["auctionState=2, totalSupply=9.791e23, balance=10.476 ETH"],
  "No non-holder path."))
R.append(E("0x1d90d50d5dd04fa7c8bef89aa5872f0701be7982", "Meme Limited Collections", "H-O",
  "Staking pools + card redemption fees: redeem() credits pendingWithdrawals[controller]/[artist]; withdrawFee() pays msg.sender.",
  ["verified MemeLimitedCollections source: withdrawFee() -> pendingWithdrawals[msg.sender]=0 then transfer; rescuePineapples only rescuer"],
  "48.81 ETH = artist/controller pending fees (self-service). Pool staking rewards are MEME tokens, not ETH."))
R.append(E("0x49128CF8ABE9071ee24540a296b5DED3F9D50443", "Foundation FETH", "H-O",
  "Bid escrow: withdrawAvailableBalance() frees expired lockups and pays msg.sender's freedBalance; withdrawFrom/transferFrom require allowance; market functions onlyFoundationMarket.",
  ["verified TransparentUpgradeableProxy + FETH impl (0xCc446C3d...) sources",
   "totalSupply()=271793540543240936706 == contract balance 271.793540543240936706 ETH (fully backed)",
   "withdrawAvailableBalance() from random reverts FETH_No_Funds_To_Withdraw (0xb64cff25)",
   "_freeFromEscrow() is private, only called inside gated functions; uint96 balance accounting"],
  "No non-holder path; fully backed. Market 0xcDA72070... (AdminUpgradeabilityProxy) is a trusted dependency; EIP-1967 admin 0x72de36c8... can upgrade (P risk)."))
R.append(E("0xa46ed7080f0094306d354b9d22e084f1dfb1b074", "Futurists Auction Splitter", "H-O",
  "Combined NFT mint + OpenZeppelin PaymentSplitter: release(account) is permissionless and pays the registered payee; withdraw() onlyOwner loops release().",
  ["verified Futurists source", "ABI includes payee/shares/releasable/release/totalReleased"],
  "13.00 ETH = splitter balance for 4 payees (97/1/1/1). No non-holder path."))
R.append(E("0x3a56ab63c7ef4f07fe353beb132e0fd5ad270ca0", "Collective Canvas", "H-O",
  "Per-NFT mint-fee escrow: withdraw(tokenId,amount) requires ownerOf(tokenId)==msg.sender and amount <= balanceOfToken(tokenId); balanceOfToken sums funded_i/(i+1) for i>=tokenId minus withdrawn.",
  ["verified CollectiveCanvas source", "withdraw(0,1) from random reverts 'Attempt to withdraw more than balance'",
   "sum of all balanceOfToken == totalFunded exactly (no over-allocation)"],
  "57.77 ETH. Exact solvency; self-only."))
R.append(E("0x9abb7bddc43fa67c76a62d8c016513827f59be1b", "POW NFT", "H-O",
  "Proof-of-work NFT: mine() payable mints; withdraw(tokenId, until) requires ownerOf(tokenId)==msg.sender and pays BASE_COST*(until-withdrawFrom); WITHDRAWALS[tokenId] prevents re-claim.",
  ["verified POWNFTv3 source: _withdraw requires ownerOf(_tokenId) == msg.sender",
   "payout is bounded by existing token ids (isValidToken(_withdrawUntil))"],
  "77.30 ETH = mining pool (future miners' payments redistributed to earlier token owners). No non-holder path."))
R.append(E("0xe31763aad9294f073ddf18b36503ed037ae5e737", "Avastars", "H-O",
  "Franchise deposits: withdrawDepositorBalance() pays msg.sender's depositsByAddress[msg.sender] and decrements unspentDeposits; owner can only take balance - unspentDeposits.",
  ["verified source: withdrawDepositorBalance requires depositsByAddress[msg.sender]>0; withdrawFranchiseBalance onlyOwner takes balance.sub(unspentDeposits)"],
  "28.85 ETH = unspent depositor balances. Solvent by construction."))
R.append(E("0x2af47a65da8cd66729b4209c22017d6a5c2d2400", "Bounties Network", "H-O",
  "StandardBounties: issue/activate with escrow; fulfillBounty open to anyone; acceptFulfillment onlyIssuerOrArbiter (pays fulfiller); killBounty onlyIssuer; contribute open.",
  ["verified StandardBounties source: acceptFulfillment modifier onlyIssuerOrArbiter; killBounty onlyIssuer"],
  "83.25 ETH = active bounty escrow. Release gated by issuer/arbiter (P/H-O); no permissionless drain. Minor index gap: mapped 84.75 (−1.5 ETH); per-bounty balances are tracked in-contract and payouts are capped by them, so any shortfall would only hit the last fulfillers of under-collateralised bounties."))
R.append(E("0xc59b0e4de5f1248c1140964e0ff287b192407e0c", "Omen / ConditionalTokens", "H-O",
  "Canonical Gnosis CTF: redeemPositions()/mergePositions() pay msg.sender based on their position-token balances; splitPosition deposits collateral; reportPayouts only oracle.",
  ["verified ConditionalTokens source (canonical Gnosis deployment)", "holds 76.98 WETH + 93.0k USDC + 140.1k DAI (block 26111283) backing outstanding position tokens"],
  "0 ETH live; index mapped 161.2 (collateral). Self-only redemption; no non-holder path."))
R.append(E("0x6f400810b62df8e13fded51be75ff5393eaa841f", "Mesa / Gnosis Protocol v1", "H-O",
  "BatchExchange: requestWithdraw(token,amount) by user; withdraw(user,token) is permissionless to trigger but always pays the recorded `user` and only their own requested amount.",
  ["verified BatchExchange source: withdraw() -> SafeERC20.safeTransfer(IERC20(token), user, amount); requestFutureWithdraw uses msg.sender",
   "holds 144.69 WETH + 212.9k USDC + 19.7k DAI (block 26111283)"],
  "0 ETH live; index mapped 138.88 (WETH). No signature forgery path; no theft."))

# ---------------- prediction / funds ----------------
R.append(E("0xd5524179cB7AE012f5B642C1D6D700Bbaa76B96b", "Augur v1 (Cash)", "H-O",
  "Augur Delegator proxy (controllerLookupName='CashTarget' → impl 0x9B4Af4a3... Cash). Cash is a 1:1 ETH token: depositEther() mints; withdrawEther(amount) burns msg.sender's balance and pays msg.sender; withdrawEtherTo(to,amount) still burns only msg.sender's balance; transferFrom needs allowance.",
  ["verified Delegator source: setController onlyControllerCaller; controller 0xb3337164 lookup('CashTarget') = 0x9B4Af4a3295cF476a2b00736f7332f35BbEE960E",
   "verified Cash source: withdrawEtherInternal(_from=msg.sender,...) requires _amount <= balances[msg.sender]; no permissionless sweep",
   "totalSupply()=762064744189809847510 == contract balance 762064744189809847510 wei (fully backed, block 26111158)"],
  "The +332 ETH over index-mapped 429.8 is simply holder balances the index did not enumerate — NOT a shortfall. Controller registerContract is onlyOwnerCaller (owner = Augur governance). No E-U."))
R.append(E("0x0286f920F893513C7ec9FE35ba0A4760229a243e", "SingularX Fund (SingularDTVFund)", "H-O",
  "withdrawReward() pays calcReward(msg.sender)+owed[msg.sender] where calcReward = balanceOf(msg.sender)*(totalReward - rewardAtTimeOfWithdraw[msg.sender])/totalSupply; softWithdrawRewardFor(anyone) only credits that address's owed.",
  ["verified SingularDTVFund source", "totalReward()=684.198 ETH; balance=385.424 ETH; SNGX totalSupply=1e25; owner=0x3bB62BaD...",
   "SNGX (0x78774d1c...) has NO live DEX market: Uniswap v1 exchange 0x6E04C36E... is empty (0 ETH / 0 SNGX / 0 pool), no v2/v3/Sushi pairs",
   "withdrawReward() from random returns 0 (no value)"],
  "Broken accumulator: entitlement follows CURRENT balance with no transfer settlement, so tokens that change hands after a claim can be claimed again against the same pool → first-mover race among existing holders (mapped 385.6 ≈ live 385.42, so shortfall currently small). Not E-U because no permissionless way to acquire SNGX (market dead). Flag for fork testing holder enumeration."))
R.append(E("0xc8c3cc5be962b6d281e4a53dbcce1359f76a1b85", "X2Y2 Fee Sharing", "H-O",
  "MasterChef-style: deposit()/withdraw()/withdrawAll()/harvest() operate on userInfo[msg.sender]; rewards = shares*(rewardPerTokenStored-paid)+rewards; updateRewards is REWARD_UPDATE_ROLE, depositFor is DEPOSIT_ROLE.",
  ["verified FeeSharingSystem source", "harvest() from random reverts 'Harvest: Pending rewards must be > 0'; withdraw(1,false) from random reverts 'Shares equal to 0 or larger than user shares'",
   "tokenDistributor.harvestAndCompound() succeeds from a random caller (claim path live)",
   "WETH balance 520.2324 vs index-mapped 315.84 (surplus, no race)"],
  "No non-holder path. WETH surplus over mapped is unallocated/uncounted rewards."))
R.append(E("0xc2f44bc508b6b50047a2f3afb1984ed105070be1", "X2Y2 Presale", "H-O",
  "Presale participants only: harvest()/withdraw()/emergencyWithdraw() require userInfo[msg.sender].hasShare (sale closed; 1000 shares). Rewards = (totalReward/totalShareSold - rewardDebt) * tokensLeft/TOKENS_PER_SHARE.",
  ["verified Presale source", "currentPhase=2 (Staking); totalShareSold=1000; totalRewardDistributed=303.49 ETH; tokenRewardTreasuryWithdrawn=0; WETH balance 145.77",
   "harvest() from random reverts 'Harvest: User not eligible'",
   "treasuryWithdraw() onlyOwner (owner 0x5D7CcA9F... = Gnosis Safe) and is available now (block 26.1M > stakingEnd 16.55M + 195k buffer)"],
  "Broken tokensLeft accounting: users who withdraw X2Y2 forfeit future rewards, but the pool (T=449.26 ETH theoretical) can exceed the 145.77 WETH balance if many participants have stale debt → first-mover race among the 1000 participants. Owner can withdraw surplus (P). No E-U (hasShare can't be obtained now). Flag for fork testing."))
R.append(E("0xc7c9b856d33651cc2bcd9e0099efa85f59f78302", "R1Exchange", "H-O",
  "applyWithdraw(token,amount,channelId) records caller's application; after applyWait (1 day) or admin approveWithdraw, withdraw() pays msg.sender from tokenList[token][msg.sender][channelId]; withdrawNoLimit requires owner-enabled flag (currently false).",
  ["verified R1Exchange source", "withdrawEnabled=false; applyWait=1 day; withdraw(0,1,0) from random reverts (0 balance)",
   "adminWithdraw is onlyAdmin + user EIP-191 signature + nonce; refund() onlyAdmin but pays `user`; batchCancel onlyAdmin"],
  "149.04 ETH user balances. Admin can enable no-limit withdraw or refund users but cannot redirect funds to itself. No E-U."))
R.append(E("0x1ecb59aecf1fc5da695242c6e78c2007e775d40f", "Metadrop: Webaverse", "H-O",
  "Sealed-bid auction refunds via merkle tree: claimRefund(amount, proof) requires leaf keccak(amount,msg.sender) in owner-set root, amount <= sum of msg.sender's own bids, and one claim per address; pays msg.sender.",
  ["verified Auction source", "auctionStatus=(true,true); refundMerkleRoot=0x580d90a1...; paused=false",
   "claimRefund(0,[]) from random reverts 'Refund proof invalid'",
   "sendPayment not used here; withdrawContractBalance/withdrawETH are onlyOwner (owner 0xbf9f7E70... = Gnosis Safe)"],
  "103.35 ETH. Merkle leaf is address-bound and bid-capped; no non-bidder path. Owner can rug via withdrawContractBalance (P risk, no timelock)."))
R.append(E("0xe14ab3ee81abe340b45bb26b1b166a7d2df22585", "TweetMarket", "H-O",
  "Bids per tweetID: offer() outbids previous (refund or credit balances); cancel(tweetID) requires bid.bidder==msg.sender and lockup passed; withdraw() pays msg.sender's balances.",
  ["verified TweetMarket source", "cancel requires bid.bidder == msg.sender; withdraw zeroes balances[msg.sender] then pays",
   "admin=0x33d6B9f591C6B61949EA91Cb7CC8643D93d842C5; bidLockup=86400s; close() onlyDelegates (P)"],
  "85.54 ETH = high bids + stored refunds. No non-holder path."))
R.append(E("0xd3d2b5643e506c6d9b7099e9116d7aaa941114fe", "Kyber FeeHandler", "H-O",
  "Fees in via handleFees (onlyKyberNetwork); claimStakerReward(staker,epoch)/claimReserveRebate(wallet)/claimPlatformFee(wallet) are permissionless triggers but ALWAYS pay the recorded staker/rebate/platform wallet.",
  ["verified KyberFeeHandler source: transfers go to `staker`/`rebateWallet`/`platformWallet`, not msg.sender",
   "totalPayoutBalance()=51601161897003249125 == contract balance 51.601161897003244 ETH (fully allocated)",
   "kyberDao=0x49bdd885...; daoSetter=0x0 (set once)"],
  "51.60 ETH. Claim amounts bounded by rewardsPerEpoch/rebate/fee mappings; no theft. If kyberDao is bricked, staker claims return 0 (S-risk for that slice)."))
R.append(E("0x0286f920F893513C7ec9FE35ba0A4760229a243e", "SingularX Fund", "H-O",
  "See entry above (duplicate guard).",
  ["see 0x0286f920 entry"],
  "duplicate", "low"))

# Remove accidental duplicate
R = [r for r in R if not (r["address"].lower() == "0x0286f920f893513c7ec9fe35ba0a4760229a243e" and r["notes"] == "duplicate")]

# Final JSON
out = {
    "segment": "seg-C",
    "reviewed_at_block": BLK,
    "eth_balances_block": BLK,
    "weth_stable_block": 26111283,
    "summary": {
        "contracts": len(R),
        "eu_candidates": sum(1 for r in R if r["eu_candidate"]),
        "class_counts": {},
    },
    "results": R,
}
from collections import Counter
out["summary"]["class_counts"] = dict(Counter(r["classification"] for r in R))
path = f"{BASE}/seg-C/results.json"
json.dump(out, open(path, "w"), indent=1)
print("wrote", path, "n=", len(R))
print(out["summary"])
