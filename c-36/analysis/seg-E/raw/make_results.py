import json

BLOCK = 26111147
BLOCK_END = 26111377
R = []

def E(addr,name,live,mapped,cls,claim,ev,conf,notes,eu=None):
    R.append({"address":addr,"name":name,"live_eth":live,"mapped":mapped,
              "classification":cls,"claim_model":claim,"evidence":ev,
              "eu_candidate":eu,"confidence":conf,"notes":notes})

# ---------------- SEG-E deep-dive (7) ----------------
E("0xDd9fd6b6F8f7ea932997992bbE67EabB3e316f3C","Last Winner",2425.427564,2424.763769,"S",
  "No working claim path. Prior zombie-deep verdict: only a probabilistic airdrop selector worth <=0.29 ETH total, negative EV.",
  ["cast balance 2425.427564 ETH at block 26111147 (unchanged since index measurement)",
   "bytecode selectors identical to worklist (immutable, no new selector added)",
   "PRIOR: zombie-deep proved $0 for Last Winner 0xdd9fd6b..."],
  "high","47,685 addresses with recorded balances; no permissionless sweep; prior verdict not re-litigated. No new surface.")

E("0x87ae4928f6582376a0489e9f70750334bbc2eb35","ChickenChef",0.0,48.20481881476927,"H-O",
  "Stakers self-withdraw staked WETH via emergencyWithdraw(0) or withdraw(0,amount); no non-staker path.",
  ["verified source ChickenChef (Blockscout) - standard MasterChef; pool 0 lpToken=WETH, contract WETH balance 48204818814769265174 wei (48.2048188)",
   "userInfo(0,*) for all 107 WETH counterparties: 7 non-zero stakers, sum=48.20481881476927 == contract WETH balance exactly",
   "cast call --from staker emergencyWithdraw(0) succeeds; withdraw(0,amount) succeeds; non-staker userInfo=0",
   "updatePool/massUpdatePools permissionless but only mint/account CHIFI (dead token); updatePool returns early (blockReward=0, halving>40) without state change"],
  "high","Rewards are CHIFI mint (not WETH). Note: _chickenHalving() 2**parseHalving will wrap to 0 at parseHalving>=256 (approx block 32.0M, ~2 years), making getChickenBlockReward div-by-zero and bricking withdraw/deposit; emergencyWithdraw is unaffected. No E-U.")

E("0x4dac3e07316d2a31baabb252d89663dee8f76f09","GovTreasurer",0.0,18.99736196605838,"H-O",
  "Stakers self-withdraw via withdraw(2,amount) (works). emergencyWithdraw(2) is broken and destructive: it zeroes user.amount BEFORE transferring, so it pays 0 and destroys the claim.",
  ["verified source GovTreasurer; pool 2 = WETH; contract WETH balance 18997361966058381030 (18.997361966)",
   "userInfo(2,*) for 86 WETH counterparties: 21 non-zero stakers, sum=18.99736196605838 == contract WETH balance exactly",
   "cast call --from 0xBd786740... withdraw(2,1e18) -> success (0x); cast call --from same emergencyWithdraw(2) -> success but source transfers user.amount after setting it to 0 => 0 wei paid",
   "updatePool calls safeGDAOTransfer(address(this),reward) = self-transfer no-op; GDAO rewards accounted but not reserved"],
  "high","DO NOT call emergencyWithdraw(2): it permanently forfeits the position (funds stay in contract, claim wiped). Only withdraw(2,amount) is safe. No E-U (non-staker cannot call for another user; userInfo keyed by msg.sender).")

E("0x07261a6e37adbfab11e6474bca54634c7782b195","MysteryMan",0.0,4.0,"H-O",
  "Stakers self-withdraw staked WETH via emergencyWithdraw(0) or withdraw(0,amount).",
  ["verified source MysteryMan; pool 0 = WETH; contract WETH balance 4000000000000000000 (4.0)",
   "userInfo(0,*) for 5 WETH counterparties: 2 stakers x 2.0 WETH, sum=4.0 == contract balance exactly",
   "cast call --from 0x8A0E28... withdraw(0,1e18) -> success; emergencyWithdraw order is correct (transfer then zero)"],
  "high","Standard MasterChef; rewards are MYSTERY mint (5.38e24 held, no ETH relevance). No E-U.")

E("0xb60c12d2a4069d339f49943fc45df6785b436096","MasterStar",0.0,3.0,"H-O",
  "Single staker self-withdraws 3.0 WETH via emergencyWithdraw(0) or withdraw(0,amount). Extra 0.1 WETH in contract is an unaccounted donation, stuck.",
  ["verified source MasterStar; pool 0 = WETH allocPoint 0; contract WETH balance 3100000000000000000 (3.1)",
   "userInfo(0,0xb156d84E...) = 3.0e18; sum over all 348 WETH counterparties = 3.0 == 1 staker; 0.1 WETH surplus (donation, no sweep => stuck)",
   "cast call --from 0xb156... withdraw(0,1e18) -> success; emergencyWithdraw(0) -> success",
   "migrate(0) permissionless but reverts: migratePoolAddrs(0)=0x0 (migrator set to 0xAaBc605b...); tokenConvert(pid,to) only moves caller's own amount"],
  "high","No E-U: migrate() cannot move pool-0 WETH (no cmoon addr); tokenConvert self-only. 0.1 WETH surplus unrecoverable (S for that dust).")

E("0x0de845955e2bf089012f682fe9bc81dd5f11b372","BDPMaster",0.0,1.743,"H-O",
  "Stakers self-withdraw staked WETH ONLY via emergencyWithdraw(1). withdraw/deposit/claimReward are BROKEN (revert) but funds are not stranded.",
  ["verified source BDPMaster; pool 1 = WETH; contract WETH balance 1743000000000000000 (1.743)",
   "userInfo(1,*) for 1454 WETH counterparties: 8 stakers, sum=1.743 == contract balance exactly",
   "BDP.seedPoolAmount()=0; cast call --from staker withdraw(1,0.1e18) -> revert 'BDPToken: cannot mint for pool'; claimReward(1) same revert; deposit(1,0) same revert",
   "cast call --from 0x20957291... emergencyWithdraw(1) -> success (does not call updatePool, so no BDP.mint)"],
  "high","Index note 'withdraw() BROKEN' confirmed: updatePool->BDP.mint reverts when seedPoolAmount==0, bricking withdraw/deposit/claimReward. emergencyWithdraw(1) still pays full stake. No E-U.")

E("0x9465A32618a9172b3c14d82cecdCa788dE1ef878","P4RTY DAO Vault",0.430478,0.43342334,"H-O",
  "Stakers self-withdraw accrued ETH dividends via withdraw() (requires myDividends()>0). No unstake exists; P4RTY is permanently locked once staked.",
  ["verified source P4RTYDaoVault; contract balance 430478168407513971 wei",
   "dividendsOf() summed over all 92 stakers from onStake logs: 54 non-zero, sum=0.43047816840578185 == contract balance exactly",
   "withdraw() updates payoutsTo_ before .transfer; reentrancy yields 0 dividends (onlyDivis reverts)",
   "no sweep function; owner can only manage whitelist; reinvestByProxy is onlyWhitelisted (no whitelisted address found among sampled accounts); stake() requires holding P4RTY and sets payoutsTo_ so new stakers get no past dividends"],
  "high","H-O: existing stakers claim own dividends. Buying P4RTY and staking now yields zero past dividends (payoutsTo_ reset at stake). No E-U.")

# ---------------- child_extra re-checks (7) ----------------
E("0xbf4ed7b27f1d666546e30d74d50d173d20bca754","The DAO WithdrawDAO",81399.811926,81399.81,"H-O",
  "DAO token holders self-withdraw via withdraw() (self-only). trusteeWithdraw() is a no-op (underflow).",
  ["cast balance 81399.811926 ETH at block 26111147","PRIOR child note: verified source; withdraw() self-only; trusteeWithdraw() underflow no-op"],
  "high","Live balance unchanged vs index. Prior $0 for unprivileged attacker - cited, not re-litigated.")

E("0x23ea10cc1e6ebdb499d24e45369a35f43627062f","DigixDAO Acid",11681.827614,11681.83,"H-O",
  "DGD holder-only burn/redemption (Acid.burn()).",
  ["cast balance 11681.827614 ETH at block 26111147","PRIOR child note: Acid.burn() holder-only"],
  "high","Live balance unchanged. Cited prior.")

E("0x707f9118e33a9b8998bea41dd0d46f38bb963fc8","Lido bETH",0.0,0.0,"H-O",
  "bETH holders redeem against AnchorVault's stETH pro-rata. bETH supply 1013.43 vs 745.47 stETH backing => ~26% shortfall, first-mover race among bETH holders.",
  ["cast balance 0 ETH; bETH.totalSupply()=1013425683039695139443 (1013.43)",
   "AnchorVault stETH balance=745468272457990202737 (745.468) at block 26111147",
   "PRIOR child note: AnchorVault share token"],
  "high","H-O with race: claims (1013.43 bETH) exceed assets (745.47 stETH). Holder-only; no non-holder entry without market. Cited prior + live re-check.")

E("0xa2f987a546d4cd1c607ee8141276876c26b72bdf","Lido AnchorVault",0.0,0.0,"H-O",
  "Vault backing contract for bETH; pays stETH only to bETH burners (pro-rata).",
  ["cast balance 0 ETH; holds 745468272457990202737 stETH (745.468) at block 26111147","PRIOR child note: holds 745.47 stETH"],
  "high","Backing contract of bETH entry; same shortfall race. No E-U.")

E("0x3dfd23a6c5e8bbcfc9581d2e864a68feb6a076d3","Aave v1 LendingPoolCore",926.001454,926.0,"H-O",
  "Aave v1 depositors withdraw their own reserves (aToken redeem).",
  ["cast balance 926.001454 ETH at block 26111147","PRIOR: zombie-deep proved $0 for Aave v1 core 0x3dfd23a... (holder-only)"],
  "high","Live balance ~unchanged. Cited prior.")

E("0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e","dYdX Solo Margin",0.0,0.0,"S",
  "No unprivileged extraction; only residual liquidation-spread value ($16-18 max per prior).",
  ["cast balance 0 ETH at block 26111147","PRIOR: zombie-deep proved <=$16-18 liquidation spread only"],
  "high","Cited prior; live balance 0. No new surface.")

E("0x0a14b696350546110a0d8acdb86226983af9d2a0","zkSync Lite L1 exit",10775.085193,10926.66,"H-O",
  "zkSync account owners exit via Merkle-proof claim (self-only, root immutable).",
  ["cast balance 10775.085193 ETH at block 26111147 (was 10926.66 at prior measurement; -151.6 ETH of legitimate self-claims since)",
   "PRIOR: zombie-deep proved $0 (root immutable, claims self-only)"],
  "high","Balance declined by ~151.6 ETH since index scan - consistent with users self-exiting; no unprivileged path. Cited prior.")

# ---------------- unassigned dust (37) ----------------
E("0x347e3513ca6d5118cb2df3bc386eade1e8f25ceb","SAW Games Pass",0.0,0.0,"S",
  "NFT contract; mint ETH was withdrawn by owner (withdraw() onlyOwner). No claimable value.",
  ["verified source SAWGamesPass; cast balance 0; totalSupply 3397; mintPrice 0.04 ETH; withdraw() onlyOwner"],
  "high","No ETH/token value. Dust.")

E("0xf61a285edf078536a410a5fbc28013f9660e54a8","TradexOne",0.47122565,0.47122565,"H-O",
  "EtherDelta fork: depositors withdraw their own recorded balance via withdraw(amount)/withdrawToken().",
  ["verified source TradexOne (EtherDelta fork); admin()=0x35509562..., feeAccount()=0x3E2cd610...",
   "all admin setters guarded by msg.sender!=admin; no admin sweep of user balances; withdraw() checks tokens[0][msg.sender] and updates state before call",
   "contract holds 0.47122565 ETH (user balances)"],
  "high","Fee account can only withdraw its own fee balance. No E-U.")

E("0xe8fff15bb5e14095bfdfa8bb85d83cc900c23c56","Afrodex",0.4517076590505233,0.4517076590505233,"H-O",
  "EtherDelta fork: depositors withdraw their own recorded balance via withdraw(amount)/withdrawToken().",
  ["verified source Afrodex; admin()=feeAccount()=0x56D2550b...; admin setters guarded; withdraw self-only",
   "contract holds 0.4517076590505233 ETH (user balances)"],
  "high","No E-U.")

E("0x96a4ed03206667017777f010dea4445823acb0fc","P4D",1e-18,7.63688338,"S",
  "Mapped 7.64 ETH is PHANTOM: contract holds 1 wei. withdrawSubdivs()/withdrawSubdivsAmount() revert (INVALID) for real holders due to broken lastContractBalance_ accounting.",
  ["verified source P4D (P3D v2 fork); cast balance = 1 wei; P3D.dividendsOf(P4D)=13323748237178983 (0.0133 ETH) is the only real backing",
   "sum subdividendsOf() over top-50 holders = 83.7 ETH (top holder alone 16.68) vs 1 wei actual => over-committed accounting",
   "cast call --from 0xE2B9f5ca... withdrawSubdivs(false) -> invalid opcode; withdrawSubdivsAmount(1e18) -> invalid opcode (SafeMath underflow on lastContractBalance_)",
   "updateSubdivsFor pulls P3D dividends (0.0133 ETH max) and distributes only balance deltas"],
  "high","Index over-mapped by ~7.63 ETH. Only ~0.0133 ETH (P3D dividends) is physically present for a small holder first-mover race; mapped amount unbacked. Not E-U (holders only, tiny real value).")

vaults = [
("0xdea2bc436d38d4f8ee6f9e63b63b72a399c24e2c","VLB / Lino","0x2CbC6812CfF0B1113BF2808fFCe6D83B97Afd345",17.28),
("0x7c33f3d417ef65a5299998bf7bbd35921963336c","Friend Network Token","0x62BbB9FFfd33d70A39feD4E7874163E8B97eA41b",16.450310367),
("0xd005c3dccd6e7056883dc612770021bc09837098","Global ICO Token (GLIF)","0x91BF99CA34268d407f3CC8d6525CE83c6eA7Bcf5",16.126694288),
("0xb8f1437c742dc042af73d5bd18c8fc985ec8e3b4","CryptoHunt (CH)","0xebc7E601f7DaF56b602334D6a3b081BB4d7D86E4",10.33265),
("0x12c33d513d4534e6cb5dc06c56683be52a936d24","Alttradex (ATXT)","0xE84E9f28a721010B8a2934810ce22975B15de46F",5.163656609),
("0xc49e03bdd6809fd168565b26d27d5cf72f9e9525","Etcetera (ERA)","0x17bE2C0acA46dd60CfC58DBb13F0b1c6c1921dB8",4.884108742851736),
("0xda3fa12b3d41cd9948db6437f27c0c9978c55cbb","Enkronos Token (ENK)","0xfe911bD81E9e7295dCd997973036F723d3E02300",0.13),
("0x6e776e93291620dac8f3dde4a0b98c42a5359293","DeskBell (DBT)","0x5A08600CbB2a6dD073A62CDdb07861Efe59D40f5",3.82),
("0xc86554bee96fdb3c85f85b576ed52d5e1eacc3a6","Quintessence (QST)","0xc178d4Fe4451d863cd01FD3E240D17194FD178BC",1.529),
("0xcb7f070fda083e8e5f40559376c360f0709e985c","Deck Coin (DEK)","0x05B3aBD9031A31a45121bda59c7bb52fc7dB2590",1.217727526),
("0x5e6a22ef928d09e9159737393ca155e9eb021d54","Tokpie (TKP)","0x7D7417ED0748018f540aA0F68DF31d8f44A342F7",1.154832441),
("0x05711090b4d375431e841ea79e52666f623d3353","GlobalSpy (SPY)","0xAae985547c1512ffCCEe43Ce5F55d73D5Df6eDca",0.969807447),
("0x2f4330e833c76860ea54f15b0195ff80a2c519c4","BigToken (BTK)","0xbAd9B65CFB0c2E89bc9543B86849780Baa52C605",4.4064455),
("0x3448295659daad4c834e5ce1c18c4e4ef73c7f06","WINiota (WIT)","0x028857f9E565D7E3e1d84B5F5736B53651C2778F",4.991631624),
("0xea864a114c648eff4f92e55b870fe1e71fd60083","Grapevine (GVINE)","0x57d1FbC0404eC7b431914cdEa7A040953eAf925d",0.9768),
("0x269b4c23ddab676e2869ae72cd6ae4f24bdfea45","IRB Tokens (IRB)","0xCbE98a2b1f756bEbe53d41Eb3b94e566A0777EDe",5.2961),
("0xa785ecdc8f166d0644b853f29732ae128c5d775b","CamToken (CAM)","0x59450e7A13bb0Ff6D6D58f60E3E6b3e07b7A32E1",3.453017621),
("0x8519f68a987048b879bed6afab25a0414828c236","LINDA Token (Presale)","0xd782aE82c167De179DEc25278d855375D8174B60",2.92692333),
("0xfcbc3a54c5663295d075b086441ee51c32ad152c","LINDA Token (Main Sale)","0x551Ccb65f02a5dddA909f181b1eB67c9226c6A2E",2.74850272),
("0x65320b9aeac77e45369e4892da896b7a987a97f3","Monoreto (MNR)","0xf671ab8f66212917D122e7Cf52094440D6aedc82",2.5553377429999995),
("0x79c59c24465fc3cc92e6419d4b59fdd285d874cf","Unverified ICO Refund (79c5)","0xe853148ef66505508b46b30511eeb4c7a4eAa370",1.541439442),
("0xf36358e9c7f6bf26d9cff44f95bf9521fc3feed4","TREECHAIN NETWORK (TREECOIN)","0x1394D3612343D05d57e482E0Cf4C8E9B0dF626b0",1.0),
("0x3adf5ee8777f471407e04a7453133477a2dc0c2c","Lendsbay Token (LBT)","0x4539d820C582c8A196891CD03Ed0967dc3823656",0.845),
("0xf563549daf64f684858e863e2731f19633d1acb1","FURT COIN (FRT)","0xc2a1BFc612aDdee098c723f5deDB298D44F49EbB",0.694374789862119),
("0x09b8aaa7a883e60c23c6a0635940000c6e2e7560","Kryptopy Token (KPY)","0x1bd8C0ed1Cd007B7C7fbE092569905B6cc854bAF",0.59),
("0x9527551ca444f6e5d9a0b281116586427366862a","DigitizeCoin Presale (DTZ)","0x0547D2Aa5a072f7e8281fF7C422b43C9168EA2f3",1.1),
("0x77b275827eb3cf1792852b128a6dbc7a699bbd91","PallyCoin Fork (PAL2)","0xAD256F5183b2479A63fe06974485104DdAd1b8Ce",3.77),
]
for addr,name,v,bal in vaults:
    E(addr,name,0.0,bal,"H-O",
      "OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via crowdsale claimRefund() or vault refund(investor); payments go to the recorded depositor only.",
      [f"crowdsale.vault() = {v}; vault.state() = 1 (Refunding); vault balance = {bal} ETH at blocks ~26111147",
       "verified RefundVault sources: 0x91BF99CA... (OZ) and 0x2CbC6812... (VLB) both have public refund(address investor) requiring state==Refunding and paying investor.transfer(deposited[investor])",
       "crowdsale isFinalized=true, goalReached=false (refunds enabled); claimRefund() selector 0xb5545a3c present on all 27 crowdsales"],
      "high",
      "Third party may trigger refund(investor) but ETH always goes to the depositor - no redirect. 27 vaults hold ~112.5 ETH total in unclaimed ICO refunds. No E-U.")

E("0xb9ed94c6d594b2517c4296e24a8c517ff133fb6d","Hegic V1 Call",0.0,2.302797,"H-O",
  "LP tranche owners (ERC-721) withdraw principal via withdraw(trancheID)/withdrawWithoutHedge(trancheID). unlock(id) is permissionless but only releases expired-option accounting.",
  ["verified source HegicCALL + HegicPool; token()=WETH; contract WETH balance=2302796914471849637 (2.302797)",
   "HegicPool._withdraw has require(_isApprovedOrOwner(_msgSender(), trancheID)) - only tranche owner/approved",
   "unlock(id) external, no auth, but only flips Active->Expired accounting for an expired option; funds go to the pool"],
  "high","No E-U. WETH == LP principal; only tranche owners can withdraw.")

E("0xb1236770ed9015e331c021347e005b00c8b8a01b","Kitten Finance",0.0,19.626407,"H-O",
  "Stakers exit own WETH via withdraw(amount)/exit() (Synthetix StakingRewards); owner renounced.",
  ["verified source KittenRewards (Synthetix StakingRewards fork); contract WETH balance=19626406829598170938 == totalSupply() exactly",
   "owner()=0x0 (renounced); no recoverERC20/sweep selector; stake/withdraw/exit/getReward are self-service",
   "rewardRate()=1576842454 (KITTEN rewards, negligible)"],
  "high","No E-U. 19.6264 WETH is staker principal, fully backed by totalSupply.")

E("0x4d9629e80118082b939e3d59e69c82a2ec08b4d5","Tribe Redeemer",0.0,0.0,"H-O",
  "TRIBE holders call redeem(to, amountIn): transfer TRIBE in, receive pro-rata basket [stETH, LQTY, FOX, DAI]. redeemBase decrements by amountIn.",
  ["verified source TribeRedeemer; redeemBase()=24992277239836591066637131 (~24.99M TRIBE left to redeem)",
   "basket balances at block 26111147: stETH 3141.109, LQTY 59969.7, FOX 834049.6, DAI 1788335.6 (basket value roughly $14M+ vs 24.99M TRIBE base)",
   "previewRedeem uses amountIn*balance/base; redeem decrements base by amountIn - pro-rata consistent (no rounding profit)"],
  "high","Only TRIBE holders can redeem (H-O). No contract bug; any market arb is an off-contract price question (TRIBE price vs redemption value), not an E-U path in the contract.")

E("0x02c133b9fbffb8d2e8cb7b7a94c7c880b331c720","Gro UST Compensation",0.0,0.0,"H-O",
  "Compensation beneficiaries claim via initialClaim(proof, amount) then claim() on a 2-year vesting schedule (ended 2024-05-31). Merkle proof required.",
  ["verified source GMerkleVestor; token()=PWRD 0xF0a93d49...; contract PWRD balance=996759093702560061263482 (996,759 PWRD, ~$1M) at block 26111147",
   "initialClaim(bytes32[] proof, uint256 amount) verifies merkle leaf; claim() pays msg.sender vested amount",
   "sweep(uint256) is onlyOwner (owner 0x359F4fe8...) - privileged path"],
  "high","H-O for beneficiaries (proof-gated); owner sweep exists (P). No E-U. Index mapped 0 (only tracked DAI).")

E("0x090D4613473dEE047c3f2706764f49E0821D256e","Uniswap UNI Airdrop",0.0,0.0,"H-O",
  "UNI genesis MerkleDistributor: claim(index, account, amount, merkleProof) pays the leaf `account` (not msg.sender). Proof-gated.",
  ["verified source MerkleDistributor; UNI balance=12499565688379843000000000 (12,499,565.7 UNI) at block 26111147",
   "claim verifies keccak256(index,account,amount) against immutable merkleRoot; transfer goes to `account`; claimedBitMap prevents double-claim",
   "no owner function (owner() reverts)"],
  "high","Notable H-O pool: ~12.5M UNI still unclaimed by airdrop recipients (proofs are public in the Uniswap merkle repo). No E-U: proof required and payment cannot be redirected.")

E("0x0c48250eb1f29491f1efbeec0261eb556f0973c7","AimBot",0.0,None,"H-O",
  "AIMBOT holders claim own dividends via AimBot.claim() -> AimBotDividends.claim(msg.sender) -> pays withdrawableDividendOf(msg.sender).",
  ["AimBotDividends child 0x93314Ee69BF8F943504654f9a8ECed0071526439 holds 67458694474256203200 wei (67.4586 ETH) at block 26111147 - index mapped None (missed)",
   "verified AimBot source includes contracts/AimBotDividends.sol: withdrawDividend() reverts ('disabled'), claim(address) onlyOwner (owner = AimBot token), takeFunds() onlyOwner and unreachable (token has no forwarding call)",
   "public AimBot.claim() calls dividends.claim(msg.sender); _withdrawDividendOfUser pays user.call{value: withdrawable}",
   "scan of first 3000 AIMBOT holders: 1347 with positive withdrawable, sum=35.81 ETH (remaining unclaimed across further holders)",
   "updateBalance(address) public only syncs shares to current token balance with magnifiedDividendCorrection = -mpps*delta => buyers after distributions get 0 past dividends"],
  "high","Notable H-O: 67.46 ETH of unclaimed AIMBOT dividends claimable by holders (self-only). Non-holder cannot extract (correction math cancels past dividends on sync). Index missed the child entirely.")

json.dump(R, open('results.json','w'), indent=1)
print('entries', len(R))
tot_vault = sum(b for _,_,_,b in vaults)
print('vault total ETH', tot_vault)
