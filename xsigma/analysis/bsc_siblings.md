# H-11 xSigma — BSC & sibling-chain sweep (child report)

**Bottom line: NO unprivileged extraction path (E-U) ≥ $100 exists on BSC or any other sibling chain.**

- BSC is the **only** sibling chain with xSigma deployments. The same vanity addresses have **no code** on Polygon (137), Arbitrum, Optimism, Base, Avalanche, Gnosis. BSC testnet (97) has a worthless mirror (code present, 0 tBNB).
- Total live stablecoin value on BSC: **$522.08** in `SigThreePoolProxyBsc` (~$0.56 of it admin fees). It is redeemable **only by SIG-LP1 holders**; the LP minter is the proxy itself and `mint()` from an EOA reverts.
- The BSC MasterChef holds **742,084.488 SIG** (~$728 spot; **~$416.6** if the whole balance were dumped into its only SIG/WBNB pair). SIG minters are only the owner EOA and the MasterChef; `mint()` from a random EOA reverts `caller is not a minter`.
- Public functions exist (`withdraw_admin_fees_to_auction`, `donate_admin_fees2`, `exchange2`, `updatePool`, `massUpdatePools`) but none sends value to the caller out of proportion: the only "anyone-callable" leakage is the **$0.56** admin fee transfer into the Dutch auction (which holds no SIG, so the auction can't even sell anything).
- Everything else found is dust: auction ~6 wei stablecoins; CashBackBSC 0 balance; L1 late tokens (xSIG / xSigma Rabbit / $SIG) Uniswap pairs hold **1 / 6 / 2 wei WETH**; SIG3/WETH pair holds 0.00584 WETH (~$15.6, below threshold).

Verdict legend (matches campaign taxonomy): **E-U** = extractable by unprivileged attacker; **H-O** = value idle / behind hidden-owner or LP claims, no unprivileged path; **P** = privileged (owner) only; **S** = safe/empty/no value.

## Address table (all chains probed)

| Chain | Address | Name | Code? | Balances (live) | Roles / gates | USD | Verdict |
|---|---|---|---|---|---|---|---|
| BSC 56 | `0x33333333420360CBa0e3D760182cBb3faFADceDd` | SigThreePoolProxyBsc (BscScan: proxy → `0x160CAed…`; `DELEGATION_TARGET()` = same) | yes | 90.468585 BUSD + 223.016558 USDC + 208.595551 USDT = **522.080694** stables; no SIG/LP | owner `0x99806391e326291ED138C766e32Aaf765D5f3d74`; dutchAuction `0xdDdDddd4…`; cashBack `0xDa59F5Ca…`(0); SIG_TOKEN `0x7777…6517`; `withdraw_admin_fees_to_auction` **public** but sends only fees (0.557354) to auction; `exchange2` public swap | **$522.08** | **H-O** (LP-backed; `remove_liquidity` only for SIG-LP1 holders; no free swap/withdraw) |
| BSC 56 | `0xFFfFfffff3471BacB75460D390474fCE40B7de42` | SigMasterChefBsc | yes | **742,084.488278 SIG**; no BNB/BUSD/USDC/USDT | owner `0x9980…`; pools: [0] SIG-LP1 alloc 300, [1] SIG/WBNB pair alloc 300 (0 staked), [2] SIG alloc 60; totalAllocPoint 660; startBscBlock 5,118,738; bscMintFraction1000 420 | $728.5 spot / ~$416.6 realizable | **H-O** (rewards only to stakers; SIG minters = owner + MC only) |
| BSC 56 | `0x7777777777697cFEECF846A76326dA79CC606517` | SigTokenBsc ("xSigma", SIG) | yes | totalSupply 2,312,465.472817; MC holds 742,084.488 | owner `0x9980…`; `isMinter(MC)=true`, `isMinter(owner)=true`, `isMinter(dead)=false`; `mint()` from EOA reverts | — | **P/S** |
| BSC 56 | `0x78d40aa1f5Aa698B53d2A9e1f58825B0Fc4165bd` | SIG-LP1 "xSigmaDEX BUSD/USDC/USDT" | yes | totalSupply 521.493963; MasterChef 516.271734; proxy 0; rest ~5.22 | storage slot 6 (minter) = `0x33333333420360CBa0e3D760182cBb3faFADceDd` (the proxy); `mint(address,uint256)` from EOA reverts | — | **S** |
| BSC 56 | `0xdDdDddd4F7280e91AA5eD57d937413451CFd0946` | PeriodicDutchAuctionBsc | yes | 2 wei BUSD + 1 wei USDC + 3 wei USDT; 0 SIG | owner `0x9980…`; `sellSigForStablecoin` public but holds no SIG | $0 | **S** |
| BSC 56 | `0xDa59F5Ca1465D989B223e6eC4244ee1da5ed24dC` | CashBackBSC | yes | 0 BNB, 0 BUSD/USDC/USDT/SIG | owner `0x9980…`; cashback reserve empty | $0 | **S** |
| BSC 56 | `0x160CAed03795365F3A589f10C379FfA7d75d4E76` | Ellipsis-style 3pool (the delegation target; **third-party**) | yes (Vyper) | 149,209.32 BUSD + 186,855.97 USDC + 336,946.26 USDT (~$673k) — belongs to Ellipsis 3EPS holders, LP `0xaf4de8e8…` supply 602,614.90, owner `0xABc00210…` | not xSigma-owned | $0 to xSigma | **S** |
| BSC-testnet 97 | `0x33333333420360CBa0e3D760182cBb3faFADceDd`, `0x7777777777697cFEECF846A76326dA79CC606517` | mirrors | yes | 0 tBNB | — | $0 | **S** |
| Polygon/Arbitrum/OP/Base/Avax/Gnosis | all xSigma vanity addresses | — | **no code** | — | — | $0 | **S** |

### Ethereum deployer EOA enumeration (task 3)

| Deployer EOA | Creations | New / notable |
|---|---|---|
| `0x02280165B29B8e2fFE23eA7ff15e3ba6F1b0429f` (8 txs) | `0x3333333ACdEd…` (ETH SigThreePoolProxy) | none new |
| `0xf74d2eca7a47e5e0348541e47e9c4532c2bd5628` (4 txs) | `0x77777777778E9F…` (SIG#2) | none new |
| `0x2a7d2665955c1cdb7f41aea9c3f4cce74b835b0a` (43 txs) | `0x7777777777697c…` (SIG#1) + 3 late tokens | **0xb82a2e5871b146e8b903b342c9c0c72c6b0fc757** "xSIG" (2.2e27; UniV2 pair WETH side = **1 wei**), **0x16b910dcd628c75f7447b8922a81d3a94b6ae438** "xSigma Rabbit" (1.5e25; **6 wei** WETH), **0x79ef38d19ea4167703ccd7c41fb1ece2b2521a02** "$SIG" (1.2e25; **2 wei** WETH) — all worthless, owners are unrelated EOAs |
| `0xdde553b4fc83eaa9802ecf7fe35f7701bfc7ce56` (217 txs) | 12 creations: known proxy/devVault/SharedVault/auction/SIG-LP/2× MasterChef | **0x76d688af…**, **0x0316d18b…**, **0xcfd695d8…** = Truffle `Migrations` contracts (`last_completed_migration`/`setCompleted`), 0 balance; **0x73d5e967704c29a7034ee65b2ee841a3e7d8ea1c** = verified late "SigMasterChef" (`sushi()` = SIG3 `0x77777777777b3d7f5Fd4287061BCb39c3A237366`, totalAllocPoint 0, startBlock 11,921,500, 0 balance, owner `0xd730D6e5…`); **0x71566073…** = verified `TokenMock` "xsig-mock-lp" (junk) |

**SIG3** `0x77777777777b3d7f5Fd4287061BCb39c3A237366` ("xSigma"/SIG, total 1,724, owner = late MasterChef 0x73d5e967, 1,700 held by `0xd730D6e5…`): its UniV2 WETH pair `0xb117fAE1A0184b74697A181273233D1934F7b11D` holds 0.0989 SIG3 + 0.0058375 WETH ≈ **$15.65** — under the $100 bar. **S**.

### Why no E-U — exact mechanics checked

- LP-free mint: `mint(address,uint256)` on SIG-LP1 from `0x…dEaD` reverts; minter slot = proxy only. `set_minter` requires current minter.
- Free SIG mint: `SigTokenBsc.mint()` from EOA reverts `caller is not a minter`.
- Reward sniping: MasterChef `updatePool()` runs **before** deposits are transferred, so a new depositor cannot capture stale accrual (pool[0] has ~405k SIG already accrued + ~85.9k SIG on next update, but it belongs to the 516.27-LP staker; pool[1] has 0 staked and its stale window is discarded; pool[2] owner pending 0.75 SIG).
- Auction: `sellSigForStablecoin` requires SIG, contract holds 0; received admin fees ($0.56) are inert.
- CashBackBSC: 0 balance.

**Block numbers / data freshness:** BSC mainnet block **125,511,031**; Ethereum block **26,112,866**; BSC testnet via `data-seed-prebsc-1-s1` (code presence only). Prices: DefiLlama ts 1791042220 (WBNB $777.13) and 1791043130 (WETH $2681.62). Sources: Wayback CDX + `app.xsigma.fi/js/app.05a8027a.js` (2022-09-15 snapshot) & `app.533def49.js` (2021-05-16); HashEx audit PDF `sources/15022021_xSigma_Audit.pdf`; BscScan/Etherscan V2 (free tier: `getsourcecode` only on 56, no token/creator modules); public RPCs `bsc-rpc.publicnode.com`, `ethereum-rpc.publicnode.com`.

## Child report (methods, exact calls)

- Wayback CDX (`app.xsigma.fi*`, js/json) → extracted chain config from `app_2022.js`: BSC chainId 56 block (`dai/usdc/usdt/sigToken/periodicDutchAuction/curveLpToken/curve3pool/xsigmaLpToken/xsigma3poolDelegator/sigMasterChef`), plus artifacts for `SigMasterChefBsc`, `SigThreePoolProxyBsc`, `PeriodicDutchAuctionBsc` (ABIs) embedded in the bundle.
- On-chain reads (all `eth_call`/`eth_getCode`, read-only): `cast call` for `coins/balances/admin_balances/fee/admin_fee/owner/dutchAuction/cashBack/DELEGATION_TARGET/SIG_TOKEN`, `poolLength`, `poolInfo`, `userInfo`, `pendingSushi`, `totalRewardAtBlock`, `lpTokenToPoolId`, `amountOfBscMint`, `balanceOf`, `totalSupply`; `cast storage` slot 6 for LP minter; `cast selectors`; `cast call --from 0x…dEaD` simulations of `mint` (revert = gated).
- BSC totalRewardAtBlock(125511031)=1.009008e25; (26219753)=9.901112e24 → pool-0 stale window ≈ 85,894 SIG × 300/660.
- L1 deployer sweep: Etherscan V2 `module=account&action=txlist` on chainid=1 for the 4 EOAs; `to==""` creations listed above; balances/code re-checked on `ethereum-rpc.publicnode.com`.
- Writes confined to `/home/heisenberg/CA/xsigma/analysis/`. No transactions were signed or sent; no .env values printed.
