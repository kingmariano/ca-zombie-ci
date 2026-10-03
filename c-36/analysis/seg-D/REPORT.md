# C-36 seg-D REPORT — DeFi / vaults / token-source / lending / options / payment channels

Scope: 52 contracts, ~3,889.5 ETH live (worklist measurement, block 26,111,001; token balances block 26,111,067).
All source reads: Blockscout `/api/v2/smart-contracts`, verified sources saved in `seg-D/raw/src/`.
Live reads: publicnode RPC, block **26,111,303–26,111,316** unless noted.
**Result: 0 E-U candidates. 52/52 are H-O (holder/self-service), with a few privileged (P) tails. No permissionless sweep, no share-inflation, no cross-account claim, no broken merkle path found.**

## Summary table

| # | Address | Name | live ETH | mapped | Class | One-line reason |
|---|---------|------|---------:|-------:|-------|-----------------|
| 1 | 0x229cc0a8… | PandaDAO Farewell | 67.99 | 50.25 | H-O | `redeem` burns caller's PANDA, pays caller pro-rata; owner = 0xdEaD; market ≈ fair |
| 2 | 0x3a3A65aA… | Aave v1 aETH | 0 | 926.00 | H-O | **PRIOR** (Aave v1 core) — one-line recheck |
| 3 | 0x35fFd6E2… | KeeperDAO / Rook | 359.12 | 372.40 | H-O | **PRIOR** (Rook) — one-line recheck |
| 4 | 0x6b1803a2… | Pop Finance | 0 (10.34 WETH) | 49.28 | H-O | StakingRewards fork; `withdraw` per `_balances[msg.sender]` |
| 5 | 0xf1d29a12… | Gnosis DutchX DxMgnPool | 0 (158.83 WETH) | 158.83 | H-O | `withdrawDeposit` pays own shares; unlock fns are state-only |
| 6 | 0x878F15ff… | Hegic V1 ETH Pool | 60.23 | 59.19 | H-O | **PRIOR** (Hegic ETH) — one-line recheck |
| 7 | 0x20dd9e22… | Hegic WBTC Pool | 0 (9.69 WBTC) | 125.92 | H-O | `withdraw(amount,maxBurn)` own writeWBTC; 3.35/9.51 WBTC available race |
| 8 | 0x7127ee43… | Shrimp Finance | 0 (40.81 WETH) | 41.81 | H-O | CurveRewards fork; per-user withdraw |
| 9 | 0x3e63e6f0… | Bee2 Finance | 0 (30.41 WETH) | 30.41 | H-O | CurveRewards fork; `getHoney` staker-only |
| 10 | 0x587a07ce… | Yam Finance v1 | 0 (136.24 WETH) | 136.24 | H-O | CurveRewards fork |
| 11 | 0x4547a86c… | Spaghetti Money | 0 (48.47 WETH) | 48.47 | H-O | CurveRewards fork |
| 12 | 0xde846827… | Doki Doki Finance | 0 (57.12 WETH) | 57.12 | H-O | `withdraw`/`claim` per `_lpBalances`/`rewards` |
| 13 | 0x0061c527… | CoFiX Staking | 0 (49.02 WETH) | 48.68 | H-O | `getReward` per user; `withdrawSavingByGov` only governance |
| 14 | 0xa17a8883… | Pickle v1 Staking | 0 (52.90 WETH) | 53.06 | H-O | StakingRewards; per-user |
| 15 | 0x4ccc2339… | Opyn v2 Gamma Controller | 0 | 368.37 | H-O | `operate([Redeem])` burns caller's oTokens; MarginPool 395.6 WETH fully accounted |
| 16 | 0xb529964f… | Opyn v1 OptionsFactory | 0 | 21.63 | H-O | per-oToken `redeemVaultBalance` requires vault of caller |
| 17 | 0xe1ee8d4c… | UMA Yield Dollar EMP | 0 (177.14 WETH) | 213.30 | H-O | `settleExpired` reads caller's token balance; state=2, price set |
| 18 | 0x77607588… | Unagii ETH Vault | 11.71 | 11.71 | H-O | `withdraw(shares,min)` pro-rata; solvent (PPS 1.1155) |
| 19 | 0x53b04999… | Veil Ether | 54.59 | 55.60 | H-O | WETH-like; **supply == balance exactly** at block 26,111,303 |
| 20 | 0x0b8d56c2… | GavCoin | 41.05 | 18.58 | H-O | `refund` needs own active receipt+balance; ~22 ETH orphaned by design |
| 21 | 0xa6cd930f… | Celer Payment Channels | 382.98 | 150.77 | H-O | **PRIOR** (Celer channels) — one-line recheck |
| 22 | 0xf5644345… | Vader Protocol Merkle | 0 (224.76 WETH) | 225.38 | H-O | claim pays leaf `account`, not caller; owner sweep (P) |
| 23 | 0xe1237aA7… | Yearn v1 yWETH | 0 (430.91 WETH) | 430.97 | H-O | `withdraw` burns own shares; assets > supply (PPS 1.0139) |
| 24 | 0xbc802101… | Euler Redemptions | 0 (137.57 WETH) | 137.49 | H-O | merkle leaf bound to `msg.sender`; per-index nullifier |
| 25 | 0xd3d13a57… | Tokemak v1 tWETH | 0 (274.16 WETH) | 274.14 | H-O | request→cycle→withdraw; cycles still rolling weekly |
| 26 | 0x0b7ffc1f… | Gnosis EasyAuction | 0 (86.21 WETH) | 235.05 | H-O | claims pay order's `userId`, not caller |
| 27 | 0xa4B86Bcb… | Nomad Bridge Recovery | 0 (97.09 WETH) | 44.93 | H-O | `recover` needs allowlist + NFT ownership |
| 28 | 0x220a9f0d… | MCDEX ETH-PERP | 555.24 | 453.69 | H-O | **PRIOR** (MCDEX) — one-line recheck |
| 29 | 0xd1847552… | Quantfury QDT | 306.26 | 296.98 | H-O | `sellTokens` fixed price; only 13.5 % of nominal supply covered → FIFO race; no market |
| 30 | 0x24f0bb6c… | Monolith TKN Holder | 152.33 | 152.38 | H-O | TKN `burn` pays caller pro-rata (ETH+stables); market ≈ fair |
| 31 | 0xe01e2a3c… | EKS | 82.97 | 74.79 | H-O | `exit`/`withdraw` own tokens/dividends; solvent |
| 32 | 0x25a06d4e… | Treasure | 94.98 | 94.98 | H-O | `exit`/`sellingWithdraw`/`withdraw` own balances; solvent |
| 33 | 0x44e081ca… | Celer EthPool | 70.26 | 70.26 | H-O | `withdraw` = own balance; transferFrom needs allowance |
| 34 | 0xa383c839… | ETH Staking Rewards | 59.67 | 54.84 | H-O | `receiveReward(0)` pays own term rewards; MAX_TERM multi-call caveat |
| 35 | 0x59accd27… | EpikStaking | 8.17 | 8.13 | H-O | `claimReward` own rewards; withdraw request/cooldown |
| 36 | 0xf786c341… | FEG Wrapped ETH | 386.60 | 34.48 | H-O | **PRIOR** (FEG) — one-line recheck; feesAccrued stranded |
| 37 | 0xbc5cef43… | WETH10 | 7.55 | 7.49 | H-O | wrapper; `flashLoan` cannot leave unbacked tokens |
| 38 | 0xbb7be7cc… | MicroETH | 20.44 | 5.53 | H-O | 1:1e-6 exact; ~73 % of supply unreachable (lost keys/contracts) |
| 39 | 0x629178c9… | Confinale Token | 8.84 | 8.84 | H-O | `withdraw` burns caller tokens after proportional payout |
| 40 | 0x3b960e47… | Opyn Crab Strategy V2 | 86.09 | 87.91 | H-O | **PRIOR** (Opyn Crab) — one-line recheck |
| 41 | 0x27321f84… | Keep Network Bonding | 234.42 | 234.42 | H-O | **PRIOR** (Keep) — one-line recheck |
| 42 | 0xd216153c… | OpenGSN RelayHub v1 | 11.89 | 512.35 | H-O | `withdraw` pays caller's own balance; mapped stale (already withdrawn) |
| 43 | 0xA2F987A5… | Lido AnchorVault | 0 (745.47 stETH) | 232.83 | H-O | burn own bETH; rate capped 1:1; remaining 569.86 bETH fully covered |
| 44 | 0x0feccb11… | MarketingMining | 23.42 | 0 | H-O | per-user `withdraw`/`withdrawETH`; admin = Timelock (P) |
| 45 | 0xf7686cf0… | PledgeDeposit ETH Pool | 25.64 | 25.64 | H-O | per (pool,user,depositId) matured withdraw |
| 46 | 0xb9812e2f… | DutchX dx_2 (proxy) | 0 (113.75 WETH) | 106.74 | H-O | claim credits `user`; withdraw own balance |
| 47 | 0xaf1745c0… | DutchX dx_3 (proxy) | 0 (70.97 WETH) | 47.97 | H-O | same model |
| 48 | 0x1E0447b1… | dYdX Solo Margin | 0 (1,615.8 WETH) | 1,648.57 | H-O | **PRIOR** (≤$16–18M) — one-line recheck |
| 49 | 0x5b67871c… | Set Protocol Vault | 0 (497.22 WETH) | 523.84 | H-O | `withdrawTo` onlyAuthorized (SetToken redeem) |
| 50 | 0x02b15c47… | 0x0 Rewards | 735.86 | 735.51 | H-O | **PRIOR** — one-line recheck |
| 51 | 0x4d37ef04… | ProtoRAI GlobalSettlement | 0 | 30.21 | H-O | shutdown executed 2021; `redeemCollateral` uses own coinBag |
| 52 | 0xa6b658ce… | Nsure CapitalConverter | 41.18 | — | H-O | `exit` burns own shares; `payouts` onlyOperator (P) |

## E-U candidates

**None.** Every ETH/token-moving function found in this segment is one of:
1. keyed to `msg.sender`/caller-recorded position (withdraw/exit/redeem/claim/settle), or
2. a merkle/proof claim whose leaf or payout address is bound to the beneficiary (Euler: leaf includes `msg.sender`; Vader: pays leaf `account`; Gnosis Auction: pays order `userId`; DutchX: credits `user` argument), or
3. owner/admin/operator/governance-gated (P tail), or
4. a permissionless state transition that moves no value to the caller (DxMgnPool unlock, GlobalSettlement process/free, EMP `expire`, Gamma `sync`/`donate`, Treasure `distribute`, CoFiX `addETHReward`).

Specific bug classes checked and cleared:
- **Permissionless sweep/rescue/collect:** none present except owner-gated (`Vader.withdraw`, `Euler.recoverTokens/recoverEth`, `Nomad.remove/collect`, `Set Vault.addAuthorizedAddress`, `CoFiX.withdrawSavingByGov`, `EpikStaking.withdrawStoredFee`, `Nsure.payouts`, `QDT.withdraw`, `CoFiX/others`).
- **Share-price/donation inflation:** Unagii/Yearn/Confinale/MicroETH/WETH10/Veil all price shares off total assets and have large existing supplies; direct donation only raises existing holders' share price (no attacker profit). GavCoin/Opyn/EMP/etc. are not share vaults.
- **Redeem/claim paying a caller-supplied address:** Gamma `_redeem` has an arbitrary `_receiver`, but `otoken.burnOtoken(msg.sender,…)` burns only the caller's oTokens — no theft. Veil `withdrawAndTransfer` sends the caller's own ETH to a chosen target.
- **Merkle flaws:** Euler/Vader/Nomad/0x0 — leaves beneficiary-bound and/or nullified; no double claim found. Gnosis EasyAuction removes orders before paying.
- **First-mover races (H-O, noted):** QDT (13.5 % covered), Hegic WBTC (3.35 of 9.51 available), Treasure `sellingWithdraw` FIFO if curve liabilities ever exceed balance (index says 100 % backed), ETH Staking Rewards term-lag, FEG feesAccrued permanently stranded. AnchorVault race in the brief is **resolved**: 443.56 bETH already refunded, remaining 569.86 bETH fully backed 1:1 (745.47 stETH), rate capped at 1e18.
- **Broken withdrawAll/emergencyWithdraw:** none broken; all per-user.
- **Unprotected proxies:** Gamma implementation `0xCc2Fd…` is uninitialized (`owner()=0`) but holds no funds and is not delegatecallable by outsiders; AnchorVault impl is ossified (`version=MAX_UINT256`, `admin=0`); other proxies initialized. No EIP-1967 admin takeover path found.

## Notable races / caveats (H-O detail)

- **QDT `0xd1847552…` (306.26 ETH live).** `_tokenPrice=4,715,436` wei per raw unit ⇒ 0.0004715436 ETH per whole QDT; `_ethPayoutPool == address(this).balance == 306.2630 ETH`; totalSupply 4,816,546 QDT ⇒ nominal 2,271 ETH (13.48 % covered). `sellTokens` pays FIFO until the pool empties. No DEX pair on Uni v2/v3 or Sushi (all `getPair`/`getPool` = 0x0), so no cheap acquisition path. Owner can `withdraw(receiver,weiAmount)` up to pool (P).
- **Monolith TKN `0x24f0bb6c…`.** `TKN.burn` (selector `42966c68`) burns only `msg.sender`; Holder pays `balance*amount/(currentSupply+amount)` across an ENS-resolved whitelist that includes `0x0`=ETH. TKN/WETH pair `0x050397956e1FC8A0a2e62Af035275f8A415B85a7` = 10,689.7 TKN / 0.12586 WETH ⇒ 1.177e-5 ETH/TKN vs backing ≈1.20e-5 (fair). No allowance/`burnFrom` path.
- **Hegic WBTC `0x20dd9e22…`.** `availableBalance()=3.3465` vs `totalBalance()=9.5065` WBTC; `burn=ceil(amount*totalSupply/totalBalance)` so exit is share-proportional, but only unlocked WBTC is withdrawable — FIFO while options lock the rest.
- **Treasure `0x25a06d4e…`.** `profitPerShareAsPerHoldings` loops the unbounded `contractTokenHolderAddresses_` array on every buy/sell/transfer — gas-griefing vector as holders grow (211 now), no value extraction. `withdraw()` skims 20 % to two hardcoded wallets.
- **ETH Staking Rewards `0xa383c839…`.** `updateReward` processes at most `MAX_TERM=1000` terms per call; users lagging >1000 terms must call repeatedly (silent no-op returns). No theft.
- **MarketingMining `0x0feccb11…`.** `withdraw` transfers the pool token *before* `updateAfterwithdraw`'s `require(user.amount >= amount)` — safe only because the require reverts the whole tx and pool tokens are plain ERC20s (no callback). Flagged as CEI smell, not exploitable.
- **FEG `0xf786c341…` (prior).** feesAccrued (0.9 % deposits + 7/8 withdraw fee + burns) is unredeemable by design; index's 7× overstatement is correct.

## Prior-verdict addresses (one-line recheck only)

| Address | Name | live at block 26,111,001 | Prior | Verdict |
|---|---|---:|---|---|
| 0x3a3A65aA… | Aave v1 aETH | 0 ETH (mapped 926 aETH) | Aave v1 core $0 | no new surface |
| 0x35fFd6E2… | KeeperDAO / Rook | 359.12 ETH + 64.1k USDC + 77.1k DAI | Rook $0 | no new surface |
| 0x878F15ff… | Hegic V1 ETH Pool | 60.23 ETH | Hegic ETH $0 | no new surface; available==total |
| 0xa6cd930f… | Celer Payment Channels | 382.98 ETH | Celer $0 | no new surface |
| 0x3b960e47… | Opyn Crab V2 | 86.09 ETH | Opyn Crab $0 | no new surface |
| 0x27321f84… | Keep Bonding | 234.42 ETH | Keep $0 | no new surface |
| 0xf786c341… | FEG fETH | 386.60 ETH | FEG $0 | no new surface |
| 0x220a9f0d… | MCDEX ETH-PERP | 555.24 ETH | MCDEX $0 | no new surface |
| 0x1E0447b1… | dYdX Solo | 1,615.8 WETH + $2.4M stables | ≤$16–18M | no new surface |
| 0x02b15c47… | 0x0 Rewards | 735.86 ETH | $0 | no new surface |

## Evidence files

- `results.json` — 52 entries (schema per KIT).
- `raw/segD_summary.txt` — worklist + token balances per address.
- `raw/segD_funcs.txt` — extracted function sets for all fetched sources.
- `raw/src/*.json` — saved Blockscout sources (52 targets + implementations: Gamma Controller `0xCc2Fd…`, MarginPool `0x5934…`, Tokemak EthPool `0xb104…`, AnchorVault `0x9530…`, MarketingMining `0xab2c…`, DutchX masters `0x2bae…`/`0x039f…`, Nomad impl `0x6A16…`, TKN/whitelist, Juicebox terminal).
