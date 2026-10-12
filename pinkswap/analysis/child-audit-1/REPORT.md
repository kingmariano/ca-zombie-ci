# Child Audit 1 — Falsification check: "no unprivileged attacker can extract value from PinkSwap contracts beyond worthless-token skim dust"

Parent session: PinkSwap (BSC) L2 Phase-2 deep-dive.
Auditor: child verification subagent (read-only; no tx signed/sent; public RPCs only).
Chain/data: BSC mainnet. Live checks at blocks 127,138,804 (parent), 127,141,159, 127,141,249, 127,144,638 (this audit).
Evidence files (this dir): `core_state_evidence.txt`, `live_excess_check.out`, `abi_vs_code.out`, `probe_selectors.out`, `locker_v1_PinkLock_full.sol`, `COG_source.sol` (not retrieved — see §8).

## VERDICT: claim CONFIRMED (not falsified)

No unprivileged extraction path to material value found. Strongest value actually at risk is inside the lockers (~$250k WBNB in PinkLock02), but every transfer-out path there is strictly lock-owner-gated and was verified live. The only unprivileged value transfer found is `skim()` of pre-existing excess balances in 12 pairs, total market value ≈ **$0.0052** at best-effort (pair-implied) prices; all on junk-token sides; no WBNB/BUSD/USDT/ETH/BTCB excess anywhere sampled. This is "worthless-token skim dust" as claimed.

## 1. PinkswapPair_top.sol (UniV2 fork, solc 0.5.16) — CLOSED. Confidence: High

Mental diff vs canonical UniswapV2Pair: **no semantic deviation found** in
`swap` (L454–482), `skim` (L485–490), `sync` (L493–495), `mint` (L405–426), `burn` (L429–451), `_mintFee` (L384–402), `permit` (L226–238), `initialize` (L361–365), `_update` (L368–381), ERC20 `transferFrom` (L218–224), `lock` modifier (L326–331).
Checked specifics:
- k-check formula, `amount{0,1}In` deltas, `_update` uint112 bounds, MINIMUM_LIQUIDITY lock, `_mintFee` denominator `rootK*5+rootKLast`, callback `pinkswapCall` under `lock`, `to != token0/token1` — all canonical.
- Reentrancy/callback abuse: only same-pair re-entry is blocked by `lock`; cross-pair is canonical behavior; no deviation to exploit.
- Fee-on-transfer tokens: K-check uses post-transfer balances; no extraction.
- uint112 overflow: `_update` reverts (DoS possible for >2^112 supplies; not extraction; not present for any current pair).
- Runtime code identical (keccak `0x6f9e…72fb`) across all 3 pairs sampled; `factory()` = PinkSwap factory; `initialize` replay → `Pinkswap: FORBIDDEN`; bad `permit` sig → `INVALID_SIGNATURE`.
- `skim(to)` is callable by anyone (by design): sends `balance - reserve` of BOTH tokens to any `to`. This is the only unprivileged transfer-out; quantified in §7.

## 2. MasterChef.sol — CLOSED. Confidence: High

All 28 ABI functions present in deployed bytecode; none hidden (watchlist of rescue/sweep/claim/drain/upgrade selectors: only `mint(address,uint256)` byte-string present, which is the call-site constant for `pinks.mint` — full ABI cross-check in `abi_vs_code.out`).
- `migrate(uint256)` L1383–1392: reverts `migrate: no migrator` (migrator = 0, verified live; sim from 0xdead).
- `updatePool` L1422–1453 (public): at cap, early-returns (`currentSupply >= totalPinksReward`); below cap it mints only to `address(this)` and `devaddr` per fixed schedule. No arbitrary recipient.
- `deposit` L1456–1472: `totalRewardNotReached` L1325; currently reverts `Masterchief no more rewards` (totalSupply == cap). LP in, PINK out only to `msg.sender`'s own pending.
- `withdraw` L1475–1490, `emergencyWithdraw` L1493–1500: only `msg.sender`'s own `user.amount`/pending; sim from non-depositor reverts/transfers 0.
- `safePinksTransfer` L1503–1510: internal; recipient is always `msg.sender` of deposit/withdraw.
- `dev` L1513–1516: only current `devaddr`; `setMigrator`/`updateEmissionRate`/`updatePool`-owner funcs `onlyOwner`.
- Invariant: `pinks.totalSupply() == totalPinksReward == 7e32` (live). No live mint remains; see §3 for no-burn.
- Note (informational, historical): when the cap was crossed, the `remaining` mint went wholly to the pool that triggered `updatePool` (L1442–1445) — one-time fairness quirk, not an extraction path.
- Liveness note (not security): `deposit()` is now permanently blocked by the cap check; users' `withdraw`/`emergencyWithdraw` still work; 2.4e32 PINK remains in MasterChef for pending claims.

## 3. PinkSwapToken.sol (PINK) — CLOSED. Confidence: High

- `mint(address,uint256)` L901–904 `onlyOwner`; inherited `BEP20.mint(uint256)` L782–785 `onlyOwner`. Owner = MasterChef (live). Both selectors present in bytecode; both gated sims revert `Ownable: caller is not the owner` from a random sender.
- No `burn`/`burnFrom` selectors in runtime code; no burn path in source; transfers to address(0) blocked → `totalSupply` cannot be lowered below `totalPinksReward`; cap cannot be circumvented.
- No transfer hooks/blacklist; `delegateBySig` (L971–1012) standard EIP-712 (nonce+expiry, domain-bound) — no signature replay beyond own delegation.
- Functions MasterChef can call on PINK (complete enumeration from MasterChef source): `totalSupply()` (L1326, L1432), `balanceOf(address(this))` (L1504), `mint(address,uint256)` (L1444/1447/1448), `transfer(address,uint256)` (L1506/1508). No path takes an attacker-controlled recipient.
- `transferOwnership`/`renounceOwnership` on PINK are `onlyOwner` (MasterChef); MasterChef has no code path invoking them → owner is effectively immutable.
- Unverified nuance: the verified-source bundle `PinkSwapToken.sol` shows a deploy-time `mint(3e32)` in the BEP20 constructor (L627–632), while the bundle saved inside `MasterChef.sol` shows the same BEP20 without it (L731–735). Could not settle which bytecode was deployed (archive state unavailable). Historical, privileged allocation only; no impact on live unprivileged paths.

## 4. PinkswapFactory.sol — CLOSED. Confidence: High

- `setFeeTo` L541–544 / `setFeeToSetter` L546–549 gated by `msg.sender == feeToSetter`; live feeToSetter = feeTo = 0xCF6A…4d5 (EOA). Sims from 0xdead revert `Pinkswap: FORBIDDEN`.
- `createPair` L524–539 canonical: identical-address/zero checks, `getPair` duplicate guard (sim for existing pair → `PAIR_EXISTS`), CREATE2, `initialize` guarded by `msg.sender == factory` (pair sim → `FORBIDDEN`). No reentrancy surface (no external calls before state writes beyond deployment).
- feeTo is an EOA (privileged LP-fee recipient via `_mintFee` in pairs) — out of scope of the "unprivileged attacker" claim; noted.

## 5. Lockers — CLOSED. Confidence: High (this is where the real value sits)

Value held live: PinkLock v1 proxy holds **2.802 WBNB**; PinkLock02 holds **332.92 WBNB** (~$250k). These are lock-owner funds.

### PinkLock02 (`0x407993575c91ce7643a4d4ccacc9a98c36ee1bbe`, no Ownable/admin)
- `unlock` L389–401 requires `userLock.owner == msg.sender`; sim `unlock(1000000)` from 0xdead → `You are not the owner of this lock`.
- `_normalUnlock` L403–450 / `_vestingUnlock` L452–506: only transfer-out paths; each guarded by the same owner check in `unlock`. `_withdrawableTokens` L517–551 uses floor division (`FullMath.mulDiv`, truncation favors the locker) and caps at `amount - unlockedAmount` — no over-release.
- `editLock` L553–604 requires owner; can only **increase** amount (funds in) and only **extend** dates (`newUnlockDate >= tgeDate && > now`); re-checked post-settlement by `newTotalUnlockAmount <= userLock.amount` (L456).
- `transferLockOwnership`/`renounceLockOwnership` L619–651: owner-only; renounced lock (owner 0) is unreachable (no path passes `owner == msg.sender == 0`).
- ID_PADDING L43/L838–845: ids < 1,000,000 rejected (`unlock(999999)` → `Invalid lock id`); v2 live count 1,068,214 ids (≥ 1,000,000 + n). v1 count 58,706 — no id-space collision (both contracts are separate anyway). No index/owner confusion found.
- `_safeTransferFromEnsureExactAmount` L653–666 prevents FoT accounting tricks on deposits.
- Verdict: no unprivileged withdraw path; 332.9 WBNB not extractable.

### PinkLock v1 proxy (`0x7ee058420e5937496f5a2096f04caa7721cf70cc`, UUPS, impl `0xb9abf98cab2c8bd2adf8282e52bf659adb0260fe`)
- `unlock` (impl L205–248) requires `owner == msg.sender`, `now >= unlockDate`, `amount > 0`; state zeroed before transfer (L235). Sim `unlock(0)` from 0xdead → `You are not the owner of this lock` (live lock[0] owner = 0x02F3…1a57).
- `editLock` L250–298 owner-only, increase-only/extend-only.
- Proxy `owner()` = 0 (renounced, live): `setPoolManager`/`setFee`/`withdrawFee` and UUPS `upgradeTo` all revert `Ownable: caller is not the owner` (sims). `initialize` replay → `Initializable: contract is already initialized`. No upgrade path; 58,706 locks frozen to their owners' keys.
- Verdict: no unprivileged withdraw path; 2.8 WBNB not extractable.

## 6. Paired tokens — CLOSED (mint/dump vector absent). Confidence: High for saved-source tokens, Medium for COG internals

Bytecode selector scan (mint/burn) + live `owner()` for the named set:

| token | addr | mint/burn selectors | live owner | notes |
|---|---|---|---|---|
| PinkE (PinkElon) | 0x8DA0…4B5a | none | 0xEF4b…7ba4 (EOA) | reflection token; no mint; owner funcs fee/exclusion only (source L1171–1179) |
| MEV | 0x0d51…d9c7 | none | 0xab47…b54a (EOA) | LiquidityGeneratorToken; supply fixed in constructor |
| ARS | 0x05a0…1d1F | none | 0x5bB6…9234 (EOA) | same template |
| ERODE | 0x35Eb…A6CB | none | 0 (renounced) | AntiBot variant |
| PinkM (PinkMoon) | 0xb609…060A | none | 0 (renounced) | |
| Infi | 0x6fe7…d2af | none | 0xEb8c…132e (EOA) | AntiBotBABYTOKEN; no public mint; `claim()` is own-dividends only |
| McDOGE | 0x65D0…D37A | none | 0xBb33…F5cA (EOA) | BABYTOKEN template |
| SAFEHOLD | 0xEce5…e421 | none | 0x1666…7E52 (EOA) | BEP20 fork, no mint |
| COG | 0xCE1d…26f8 | none | 0 (renounced) | verified as `CoinToken.sol` (SafeMoon-style); admin funcs revert `Ownable: caller is not the owner` from random sender (sims: updateFee/setAsCharityAccount/excludeAccount/includeAccount) |
| BNBC | 0x64F6…73cC | none | 0x910a…b597 (EOA) | same template as MEV |

- PINK is the only token in the ecosystem with `mint` selectors; both gates verified (§3).
- `transferFrom` without allowance simulated from 0xdead against a pair-holder for all 10 named tokens + PINK → all revert with allowance/transfer errors. No ownerless `transferFrom`/`approve` abuse.
- Extra top-reserve tokens checked (bytecode selectors + owner): ADOGE, PCW, BDC, 2030Floki, TP, SAFEMOON, CCC, TRIII, BAKU, Inu, KNOO, MLEM, AAA = no public mint/burn; TP has `mint(address,uint256)` **onlyOwner** (sim → `Ownable: caller is not the owner`; owner EOA). YMPA pair's other side is BUSD (real stablecoin).
- `deliver(uint256)` on reflection tokens is public but only burns the caller's own reflected value (sim on COG → underflow for empty wallet) — not global extraction.

## 7. Live skim-excess quantification (block 0x7940B27 / 127,141,159)

Re-measured `balanceOf(pair) - reserves` for the 12 excess pairs + top-10 reserve pairs (`live_excess_check.out`): matches parent's JSON exactly. Valuable-side excess = **0** in every pair (WBNB/BUSD/USDT/ETH/BTCB/PINK); all excess sits on junk-token sides.

Implied prices from live pair reserves (best-effort marginal): PinkE ≈ $3.24e-10 (WBNB pool; BUSD pool implies $3.11e-10 — consistent), PinkM ≈ $1.356e-9 (Llama: $1.325e-9), COG ≈ $2.09e-5, SAFEMOON ≈ $8.96e-7. Total skimmable value:

| pair | token | excess | ≈USD |
|---|---|---|---|
| 0xd948…f700 | PinkM | 2,522,722.66 | $0.00342 |
| 0xb9ef…def9 | PinkE | 1,209,887.28 | $0.00039 |
| 0x76f3…b58a | COG | 13.3049 | $0.00028 |
| 0x510f…4d77 | PinkE | 768,230.23 | $0.00025 |
| 0xa489…9fa6 | COG | 11.8398 | $0.00025 |
| 0x299c…1246 | SAFEMOON | 227.4428 | $0.00020 |
| 0x510f…4d77 | COG | 9.1302 | $0.00019 |
| 0xb153…fcdd | COG | 4.5363 | $0.00010 |
| 0x9a46…b0c8 | PinkE | 206,856.63 | $0.00007 |
| 0x030e…7ce0 | PinkE | 65,388.14 | $0.00002 |
| 0x4e5f…5788 / 0x05e8…d67a / 0x6c72…eac2 | SFT/TRIII/WB3 | 0.000184 / 4e-9 / 8e-18 | ~$0 |
| **TOTAL** | | | **≈ $0.0052** |

Claim's "worthless-token skim dust" is quantitatively accurate (and below the gas cost of skimming).

## 8. Counterexample sequences attempted (all read-only descriptions; no tx sent)

Strongest hypothetical extraction paths and the exact gate that closes them (each verified by eth_call simulation; none executable):
1. Drain PinkLock02: `unlock(1000000)` as attacker → req owner==msg.sender → reverts. (L390–394)
2. Drain PinkLock v1: `unlock(0)` as attacker → reverts; `upgradeTo(malicious)` → owner renounced, reverts.
3. Mint PINK and dump into PINK/WBNB pair: `PINK.mint(attacker, x)` → onlyOwner (MasterChef) → reverts. `MasterChef.updatePool` cannot take a recipient argument.
4. Redirect LP fees: `Factory.setFeeTo(attacker)` → `Pinkswap: FORBIDDEN`.
5. Steal pool LP via `MasterChef.migrate` → `migrate: no migrator`.
6. Take pool tokens via `transferFrom(pair, attacker, x)` on any named token → allowance error.
7. Skim valuable tokens from pairs → no valuable-side excess exists (all 22 sampled pairs; parent's full 167-pair scan).

## 9. What I could NOT verify

1. **Byte-for-byte deployed-code ≙ verified source**: no recompilation with the explorers' exact solc/optimizer/metadata settings. Mitigation used: ABI-selector presence cross-check (100% match for MasterChef/Factory/Pair/PINK + 25 tokens), source review, and live gating sims. Residual risk: low.
2. **PINK deploy-time constructor mint** (two saved BEP20 variants disagree; archive state unavailable on public RPCs — no historical `eth_getCode`/logs). No live impact.
3. **Full live re-scan of all 167 pairs**: parent scanned all at 127,138,804; I re-verified 22 pairs at 127,141,159 (exact match). Pairs outside the sample could in principle have received donations since — any change requires a transfer to the pair; sampled set matched exactly.
4. **Every one of the ~150 remaining paired tokens**: checked bytecode selectors+owner for 14 additional higher-reserve tokens; tokens in pairs with < ~$30 reserves were not individually reviewed. A public-mint token there could at most drain its own pair's small WBNB side (~$30), not the core contracts.
5. **COG full source text** (BscScan code tab not retrievable via scrape; BSC absent from Blockscout MCP). Verified instead: no mint/burn/withdraw selectors, admin funcs owner-gated and owner renounced, transferFrom allowance enforced, `deliver` self-only.
6. **Fork-execution of suggested regression tests** (not run per instructions — no anvil forks). Suggestion: `child-audit-1/suggested_fork_test.t.sol.txt` for CI.

## 10. Method notes

- Read-only calls only (`cast call`, `cast call --from`, batch `eth_call` via public RPCs: publicnode/drpc/1rpc). No tx, keys, or keyed URLs.
- Gating simulations run as `eth_call` (state discarded); they prove/deny `require` behavior, not state persistence.
- Files written only under `/home/heisenberg/CA/pinkswap/analysis/child-audit-1/`.
