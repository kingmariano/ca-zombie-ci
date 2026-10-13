# AutoShark — negative results, dead ends, and corrections (Phase 2)

All items re-checked live on BSC (pinned block 127,400,000 or latest where noted). Addresses/values are in
`live_state_pinned.json`, `pairs_raw.json`, `farm_pools.json`, `ci-out/autoshark_ci_facts.json`.

## Negative results (do not re-investigate)

1. **AMM skim / excess balances — $0.00.**
   23 pairs showed `balanceOf(pair) > reserves` at block 127,432,152 (6–23 across sampled blocks). All excesses are
   unpriced zombie tokens: largest = 10,882.26 "Mousey" (pair 0x07c647a0…), 820.28 Mousey (pair 0x3403b2d8…),
   0.40 NFTART / 19.24 "Kitty" etc. No WBNB/USDT/BUSD/ETH/BTCB excess anywhere. The 4 value pairs
   (WETH/BTCB, DAI/USDT, USDT/BUSD, FINS/WBNB) have `balance == reserve` exactly. `skim()` itself works but pays dust;
   NFTART also charges ~10% transfer tax (measured: nominal 400.8667e15 → received 360.7800e15 = 90%).
   → E-U from skim ≈ $0.00.

2. **Token minting — all gated.** `FinsToken.mint(uint256)` onlyOwner (owner 0x0ff4436a…); `mint(address,uint256)`
   onlyMinter (isMinter: MasterOcean=true); `SquidToken` same (isMinter: MasterSquid=true); `JawsToken.mint(address,uint256)`
   onlyOwner (0x342afF01…). All probed from a fresh EOA → revert. FINS cap is reached (499,999,997.1/500,000,000) and the
   farm's FINS balance is 0 → even the farm's `fins.mint` calls are no-ops (`_mint` returns false; outer `mint` returns true).

3. **Both fee collectors are role-gated.** `feeTo` FeeDistributor (impl 0xe1f153c3) and squid fee vault (impl 0x45948ce5)
   gate `distribute`/`distributeSingle`/`burn` on `msg.sender == keeper || owner`; `setRouter`/`withdrawBEP20`/
   `transferOwnership` are owner-only. Live probes from a fresh EOA revert; balances unmoved. Owners/keepers are team EOAs
   (0xD9ebB6d9…, 0xa3B33022…, 0xbf00B8b5…, 0xc41E861E…).

4. **jawsPool is an empty shell.** 69,837,390.478 outstanding shares, but JAWS balance = 0, rewards-LP balance = 0, BNB = 0,
   rewards ended Jan-2024. Even the rewards token (WBNB/JAWS LP) is worth ~$105 of WBNB total. `getReward()` does not revert
   but pays nothing (pool empty). JAWS itself: implied price ≈ $2.74e-6 (only 0.141 WBNB + 38.34M JAWS in its one pair).

5. **Launchpad/IFO (0xa9f48fee…).** All 753 depositors enumerated from 860 `Deposit` logs: 751 already `hasHarvest=true`;
   2 remaining can still harvest tiny ATLAS (e.g., 14.6 ATLAS raw 1.46e10 @9 dec; ATLAS unpriced, no market).
   `harvest()` pays the offering token, never the LP. The 3,354.1 LP (~$479) left in the contract is raising proceeds,
   withdrawable only by admin `finalWithdraw`. Note: my first decompile-based reading suggested participants' claims were
   blocked — **corrected**: the claim path works for the 2 unharvested users (live `eth_call`).

6. **v1-era (SHARK) contracts are empty.** SharkPool 0x5F7de53f, Zap 0xA96CeA60, Panther vault 0x9e7aEbAE, helper
   0xBd17385A, sharkChef 0x115BebB4, NFTController 0xc404446f → all $0 token balances; SHARK token 0xf7321385 holds
   $0.08 dust. The "SHARK-BNB Pool" address in the old README (0x1fd789Fa) is actually a PantherSwap `PantherPair`
   (SHARK/WBNB LP) holding 2.12 WBNB ($1,577) — its LP is held by EOAs (top holder 0x058451c6… 2,544/8,760); it is not
   AutoShark custody.

7. **MasterSquid farm paths work (correction).** My decompile-based hypothesis that `controller == address(0)` bricks
   reward-claiming withdrawals was **tested and refuted**: `getBoost(any, pid)` returns 0 (no revert), so
   `safeSquidTransfer` completes; fork tests show deposit/withdraw/emergencyWithdraw all work for a fresh user
   (only the NFT boost is inert). SQUID rewards are therefore claimable but essentially worthless
   (farm balance 80,902 SQUID ≈ $6; only market = one pair with ~$890 WBNB side).

8. **FINS rewards are dead.** MasterOcean `updatePool` still raises `accFinsPerShare`, but `fins.mint` cannot mint
   (cap reached) and the farm holds 0 FINS; `safeFinsTransfer` transfers 0 and boost is 0 → claims succeed paying nothing.

9. **No unknown LP-holding vaults found.** Top holders of the 5 most valuable pairs are known protocol contracts
   (MasterOcean, MasterSquid, both fee vaults) or EOAs. Top JAWS holders that are contracts hold only ~$130 of loose
   tokens and no finsFactory LP. The NFTController proxy (0xc404446f) is admin-controlled (team ProxyAdmin) and holds $0.

10. **No factory migrator.** FinsFactory has no `migrator`/`migrate` functions (checked verified source); only
    `setFeeTo`/`setFeeToSetter` (feeToSetter-gated) and permissionless `createPair`.

## Corrigenda log (things I got wrong and fixed)

- "MasterSquid withdraw bricked" → refuted by live `getBoost` returning 0 and by the fork test (withdraw succeeded).
- "Launchpad participants blocked by oversubscription" → refuted by live harvest simulation for the 2 unharvested users.
- Initial value attributions used a stale snapshot (95.42% top-pair LP) → corrected to 97.08% @127,400,000.
- feeTo DAI/USDT LP assert initially mis-scaled (7,000 vs 7.61 LP) → fixed.

## Independent adversarial review (subagent) + its corrections

An independent reviewer re-probed every permissionless payout path from a fresh EOA (fee vault
initialize/distribute/burn/withdrawBEP20; jawsPool getReward/withdraw/withdrawAll/recoverBEP20/notifyRewardAmount;
launchpad harvest/finalWithdraw/flipAllowClaim/setRaisingAmount; MasterOcean update/massUpdate/emergency;
MasterSquid update/massUpdate; pair skim/sync; farm/vault/team allowances to routers; selector-dispatch scans of the
unverified impls). **Verdict: the $0 claim is NOT refuted — no material (> $100) fresh-attacker path.**
Full report: `child-adversarial-review.md`.

Corrections it surfaced (both re-verified by me on-chain before patching the report):
- **MasterSquid SQUID balance units error:** it is **80,902 wei ≈ $0** (not 80,902 tokens ≈ $6). Fixed in README/summary.
- **MasterSquid `massUpdatePools()` is bricked:** reverts `SafeMath: subtraction overflow` because
  `updatePool(0)` computes `balanceOf(farm) - squidStaked` = 80,902 wei - 1.7996e24. Individual `updatePool(pid>0)`
  works. Consequence: pid 0 (SQUID single-stake) deposits/withdraws revert and `emergencyWithdraw(0)` cannot pay
  (insufficient SQUID) — **1,799,636 SQUID of pid-0 staker claims are unbacked/unrecoverable (~$130 at the
  pair-implied price; outside the $147k pair TVL scope).**
- Latent candidate it found and bounded: pid 15 of MasterSquid receives ~100% of SQUID emissions
  (`allocPoint = 1e25` of 1e25+16,000) and `updatePool(15)` is permissionless, but the stake token SQUIDY
  (0x15c51300…) is held 99.998% by the team EOA, with no permissionless mint and no market found
  (Fins, Pancake v2/v3 all tiers, Ape, Bakery, MDEX, BiSwap, BabySwap, Thena) → team-only (P), and bounded by
  the ~$890 SQUID/WBNB exit liquidity anyway.
