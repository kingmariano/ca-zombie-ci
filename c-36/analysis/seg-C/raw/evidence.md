# seg-C raw evidence (read-only calls)

RPC: https://ethereum-rpc.publicnode.com
Balances block: 26,111,158 (ETH); 26,111,283 (WETH/USDC/DAI).

## Augur v1 (0xd5524179cB7AE012f5B642C1D6D700Bbaa76B96b)
- getController() = 0xb3337164E91B9F05C87C7662C7AC684E8e0ff3E7
- controllerLookupName() = 0x4361736854617267657400… ("CashTarget")
- Controller.lookup(CashTarget) = 0x9B4Af4a3295cF476a2b00736f7332f35BbEE960E (verified "Cash")
- totalSupply() = 762064744189809847510
- eth_getBalance = 762064744189809847510 wei  → fully backed
- Delegator source: setController is onlyControllerCaller; Cash.withdrawEtherInternal requires _amount <= balances[msg.sender]

## X2Y2 Fee Sharing (0xc8c3cc5be962b6d281e4a53dbcce1359f76a1b85)
- x2y2Token = 0x1E4EDE388cbc9F4b5c79681B7f94d36a11ABEBC9; rewardToken = WETH; tokenDistributor = 0xB329e39Ebefd16f40d38f07643652cE17Ca5Bac1
- totalShares = 23503434983772591705474411; rewardPerTokenStored = 474682116701781; periodEndBlock = lastUpdateBlock = 22420924
- WETH.balanceOf = 520232429628635731844
- cast call harvest() from 0x1111… → revert "Harvest: Pending rewards must be > 0"
- cast call withdraw(1,false) from 0x1111… → revert "Withdraw: Shares equal to 0 or larger than user shares"
- cast call tokenDistributor.harvestAndCompound() from 0x1111… → success (claim path live)

## X2Y2 Presale (0xc2f44bc508b6b50047a2f3afb1984ed105070be1)
- currentPhase = 2 (Staking); totalShareSold = 1000; totalTokensSold = 1.5e25
- totalRewardDistributed = 303491839679500059503; tokenRewardTreasuryWithdrawn = 0
- WETH.balanceOf = 1457718… (145.7718); stakingEndBlock = 16553224; safetyBufferInBlocks = 195000; owner = 0x5D7CcA9Fb832BBD99C8bD720EbdA39B028648301 (Gnosis Safe proxy code)
- cast call harvest() from 0x1111… → revert "Harvest: User not eligible"
- treasuryWithdraw() onlyOwner; threshold block 16,748,224 < current 26.1M → owner can withdraw now

## Foundation FETH (0x49128CF8ABE9071ee24540a296b5DED3F9D50443)
- EIP-1967 impl slot = 0xCc446C3d1738A6e66D366446C37a942c5e750250 (FETH); admin slot = 0x72de36c8ebeacb6100c36249552e35feff0ee099 (ProxyAdmin)
- totalSupply() = 271793540543240936706 = balance → fully backed
- withdrawAvailableBalance() from random → revert 0xb64cff25 (FETH_No_Funds_To_Withdraw)
- market = 0xcDA72070E455bb31C7690a170224Ce43623d0B6f (AdminUpgradeabilityProxy)

## SingularX Fund (0x0286f920F893513C7ec9FE35ba0A4760229a243e)
- totalReward() = 684198405921098258634; balance = 385.423648273041230735; owner = 0x3bB62BaDa8F9921Dcf0b1be5d2C972D69C064D84
- SNGX token 0x78774d1c… totalSupply = 1e25; name "SingularX"
- Uniswap v1 exchange 0x6E04C36EA43567FdcA1624Dc510404ee8c0320bB: ETH=0, SNGX=0, totalSupply=0
- Uniswap v2 getPair = 0x0; Sushi getPair = 0x0; Uni v3 getPool = 0x0
- withdrawReward() from random → returns 0

## Kyber FeeHandler (0xd3d2b5643e506c6d9b7099e9116d7aaa941114fe)
- totalPayoutBalance() = 51601161897003249125 = balance 51.601161897003244 ETH
- kyberDao = 0x49bdd8854481005bBa4aCEbaBF6e06cD5F6312e9; daoSetter = 0x0
- claim* functions transfer to recorded staker/rebate/platform wallet (source verified)

## Metadrop Webaverse (0x1ecb59aecf1fc5da695242c6e78c2007e775d40f)
- auctionStatus = (true,true); refundMerkleRoot = 0x580d90a13c95a59d927e9816ff636ac1b0d62f7a54616397b3e9d9c29999bf03; paused = false
- numberOfAuctions = 1; itemsPerAuction = 7870; beneficiary = 0x0B4E6f5c38A5E0fa2Ea528BaC2055E7304f82feF
- claimRefund(0,[]) from random → revert "Refund proof invalid"
- withdrawContractBalance/withdrawETH onlyOwner (owner = 0xbf9f7E70… Gnosis Safe proxy code)

## CryptoCats Marketplace (0x19c320b43744254ebdbcb1f1bd0e2a3dc08e01dc)
- getContractOwner() = 0xd7148578159b87a9EFA2f0290531B44b0f9063D1; pendingWithdrawals(owner) = 34880000000000000000
- allCatsAssigned = false; catsRemainingToAssign = 0

## EnclavesDex (0xbf45f4280cfbe7c2d2515a7d984b8c71c15e82b7)
- getImplementation() = 0xed06d46FFB309128C4458A270C99c824dc127f5D; admin() = 0x0B2dF89a0f816144c50400Cac69f25DeD20e774F
- balance 7.096190481565161 ETH; index-mapped 17.93
- impl withdraw() → withdrawUser(amount, msg.sender); rebalanceEnclaves pulls from dead etherDelta

## Unverified-family guard simulations (all from 0x1111…1111)
SwitchDex 0xc3c12a9e…: admin()=0x194AFBF7…; changeAdmin/changeFeeMake/changeFeeTake/changeAccountLevels/withdraw all revert (INVALID).
LSCX 0x3da70c70…: admin()=0xCe0F7b59…; changeStorageAddr/changeFeeMarket/changeAdmin/deleteOrders/setOrders/tiker/concatTiker/withdraw all revert (INVALID); storageAddr()=0xb718339A…; feeMarket=5e17.
ED Fork 0xc5138d4b…: admin()=0xdfD4b388…; withdraw(1) reverts; selectors == ED v2 exactly.
Etheropt Old 0xc6b330df…: no admin() selector; withdraw(1) reverts; selectors = ED v0 + order().
EtherDelta v0 0x4aea7cf5…: no admin() selector; withdraw(1) reverts.

## ETHEN / R1 / TweetMarket / others
- ETHEN: owner=feeCollector=0x8A1fF1F8…; signer=0xf2C24291…
- R1Exchange: owner=0xFe2d982f…; withdrawEnabled=false
- TweetMarket: admin=0x33d6B9f5… (contract); delegate history [0x19999C22…]; bidLockup=86400
- Confideal: stage()=3 (Failure); amountRaised=303.244 ETH; goal=70000 ETH
- Fractional vaults: all auctionState=2 (ended); balances 44.696/19.746/10.476 ETH
- MoonCatRescue withdraw() pays pendingWithdrawals[msg.sender]; adoption escrow verified in source
- Collective Canvas withdraw() requires ownerOf(tokenId)==msg.sender
- POW NFT _withdraw requires ownerOf(_tokenId)==msg.sender
