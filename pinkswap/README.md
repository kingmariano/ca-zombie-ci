# PinkSwap (BSC) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** BSC (chain id 56) · **Status:** read-only analysis; PoC fork-verified only; **no mainnet transactions were sent**.
**Triage row:** L2-Triage-A #17 — "LIVE-FUNDED, $275,306, medium confidence, BSC factory 0x7d2ce25c28334e40f37b2a068ec8d5a59f11ea54 (167 pairs)".

---

## 1. TL;DR

| Target | Live value (llama-priced) | Unprivileged-extractable (E-U) | Why closed/open | Latent risk |
|---|---|---:|---|---|
| Factory `0x7d2ce2…ea54` (167 UniV2-fork pairs) | **$276,482.94** in reserves | **$0.00** | Pair liquidity is LP-owned (ERC-20 LP, H-O); no mint/drain path exists; `feeTo` is an EOA (P); `skim()` excess is junk tokens only | none live |
| `skim()` excess in 12 pairs (PinkE/PinkS/PinkM/COG/SAFEHOLD/SFT/TRIII/WB3/SAFEMOON) | ~$0.00 at market (no DEX markets) | **$0.00** (11 pairs skim-able in junk tokens; 1 pair permanently stuck) | Excess tokens are illiquid memecoins; DexScreener: no pairs for PinkE/COG/SFT/TRIII/WB3/SAFEMOON; PinkM $0.0033 | none |
| MasterChef `0xe9816766…c595` (farm, 7 pools) | LP custody is user deposits (H-O) | **$0.00** | `migrator()==0` (migrate() reverts); emission cap reached → deposits blocked; `updatePool()` mints nothing and pays the caller nothing; owner is an EOA (P) | P-rug: owner could `setMigrator` → `migrate()` pulls pool LP (privileged) |
| PINK token `0x702b3f41…125d` | 0 (no market price; ~$8.7k total exit liquidity in its PinkS/WBNB pair) | **$0.00** | `mint` is `onlyOwner` (owner = MasterChef); MasterChef has no arbitrary-call path; supply == cap 7e32 | none live |
| `feeTo` accrued LP (68 pairs) | $3,949.70 | **$0.00** | `feeTo` = EOA `0xCF6A86…C4d5` (P — team-controlled) | none for attackers |
| PinkLock02 / PinkLock v1 locked LP | MEV/WBNB $35.3k (expired 2024-06-16, H-O); ERODE/WBNB $2.7k (locked to 2122, S); Infi/WBNB $1.6k, McDOGE/WBNB $1.2k (PinkLock v1, owner renounced, expired 2022) | **$0.00** | `unlock()` requires `lock.owner == msg.sender` | none live |

## 2. Total live extractable now: **$0.00** (E-U) — confidence: **high**

The headline triage number ($275,306) is **LP-owned pool liquidity** (holder-recoverable, H-O), not attacker-extractable value. The only unprivileged value-movement primitive that exists (`skim()`) yields **illiquid junk tokens worth ~$0** and is even **revert-blocked on one pair** (COG/SAFEHOLD). Every other candidate path is gated and was fork-verified closed.

Classification at the final CI run block (see `ci-out/SUMMARY.txt` / `live_state.json`):

```
E-U = $0.00
H-O = $269,866.42   (LP holders / MasterChef depositors / lock owners)
P   = $3,949.70     (feeTo EOA accrued LP)
S   = $2,666.82     (ERODE/WBNB LP locked until 2122-07-06)
```

---

## 3. The mechanism in exact terms (what "skim" is, and why it is worth $0)

`PinkswapPair` (verified source, solc 0.5.16) is a faithful UniswapV2 fork (`Pinkswap:` error strings, `pinkswapCall` callback). The only permissionless value-moving function is:

```solidity
// PinkswapPair_top.sol (deployed at every pair)
function skim(address to) external lock {
    address _token0 = token0;
    address _token1 = token1;
    _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
    _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
}
```

`to` is caller-chosen, so **anyone can take `balance - reserve`** of both tokens of any pair. Live scan of all 167 pairs (block 127,138,804 local / 127,142,452 CI) found:

- **12 pairs** with a positive excess;
- **0** pairs with excess of any priced token (WBNB/BUSD/USDT/ETH/BTCB);
- the excess is entirely in **PinkE (PinkElon), PinkS, PinkM, COG, SAFEHOLD, SFT, TRIII, WB3, SAFEMOON** — DexScreener shows **no DEX pairs** for all of them except PinkM (`$1.317e-9`, excess = 2.52M PinkM = **$0.0033**) and SAFEMOON (excess = 227.4 tokens ≈ **$6e-8**);
- **COG/SAFEHOLD pair `0x76f33b7b…b58a`: `skim()` always reverts** (`Pinkswap: TRANSFER_FAILED`) because SAFEHOLD's `transfer` reverts on zero-amount transfers — the pair always calls `_safeTransfer` on both tokens. Its 13.3 COG excess is **permanently stuck (S)**.
- PinkE is fee-on-transfer (10% tax): a skim of 1,209,887 PinkE yields ~1,088,899 PinkE to the attacker; still $0.
- Total skimmable dust at best-effort (pair-implied) prices: **≈$0.005** (PinkM $0.0034 + PinkE $0.0004 + SAFEMOON/COG dust; the COG piece is on the stuck pair) — far below the ~$0.05–0.15 gas cost per skim. Independently re-verified by the child audit (`analysis/child-audit-1/REPORT.md`, which also diffed `PinkswapPair` against canonical UniswapV2Pair and found no semantic deviation).

Other gated surfaces (all fork-verified closed in `poc/test/PinkSwap.t.sol`):

| Path | Live gate (block 127,145,004) | Result |
|---|---|---|
| `PinkswapFactory.setFeeTo/setFeeToSetter` | `feeToSetter = 0xCF6A86…C4d5` (EOA) | privileged only |
| `PinkSwapToken.mint` | `owner() = MasterChef`; `onlyOwner` | attacker call reverts `Ownable: caller is not the owner` |
| `MasterChef.migrate(pid)` | `migrator() == 0x0` | reverts `migrate: no migrator` |
| `MasterChef.deposit(pid,amt)` | `pinks.totalSupply() == totalPinksReward == 7e32` | reverts `Masterchief no more rewards` |
| `MasterChef.updatePool(pid)` | cap reached | caller receives nothing; no mint |
| `MasterChef.emergencyWithdraw/withdraw` | msg.sender-scoped `userInfo` | only own deposit |
| `PinkLock02.unlock(lockId)` | `lock.owner == msg.sender` required | attacker reverts `You are not the owner of this lock` |
| `PinkswapPair.burn(to)` | burns `balanceOf[address(this)]` (own LP only) | attacker with 0 LP reverts |

`feeTo` (EOA) redemption is real but **privileged (P)**: at the final CI block the EOA had accrued LP in 68 pairs worth **$3,949.70** (largest: PinkS/WBNB $1,648, WBNB/BUSD $1,375, PinkE/WBNB $245). The fork test demonstrates the redemption works (`test_feeTo_redeem_privileged_only`).

## 4. Live-state assessment (addresses, roles, blocks)

Block numbers used: local enumeration **127,138,804**; CI run 1 **127,142,452**; final CI run 2 **127,145,004** (Oct 12 2026). All reads via public RPC / CI BSC RPC; no keyed URLs stored.

- **Factory** `0x7D2Ce25C28334E40f37b2A068ec8d5a59F11Ea54` — verified `PinkswapFactory` (solc 0.5.16). `allPairsLength()=167`; `feeTo()=feeToSetter()=0xCF6A864b0d705242BF1B916Bf8c097aE503BC4d5` (**EOA**, 0 code bytes). No `owner()`/`migrator()`.
- **Pairs** — verified `PinkswapPair`; 167/167 read; `factory()` on pairs = PinkSwap factory. Reserves total **$276,482.94** (llama prices). Top pairs:
  1. `0xB9eFbD2Bb41f7A2136BF2B21e8B26641651adef9` PinkE/WBNB — 279.36 WBNB + 647.5B PinkE → $209,282; LP: EOAs + PinkE owner + MasterChef 0.91% + feeTo 0.12%.
  2. `0xf4e58b13f7e847111c120a7258e8e2164294c261` MEV/WBNB — 47.17 WBNB → $35,339; LP 100% in **PinkLock02** lock #1112062 (owner EOA `0x47eb34dd…2c6`, **unlockable since 2024-06-16** → H-O).
  3. `0x61c960d0337f1efe46bc7b1110ba8c4e60dd2017` PinkS/WBNB — $8,670; LP: MasterChef 72.9%, feeTo 19.0%, EOAs.
  4. `0x2e4bae64cc33ec8a7608930e8bd32f592e8a9968` WBNB/BUSD — $6,182; LP: MasterChef 46.8%, feeTo 22.2%, EOAs. (CoinGecko shows this pair still has ~$124/24h volume — the last barely-alive pair.)
  5. `0xa6e72521f19babeb1defff1f5a36024302303897` ARS/WBNB — $3,734; 100% LP held by EOA `0x5bb6eb32…9234`.
  6. `0x5cce01ada9aa19552571be68204126cc00576b3d` ERODE/WBNB — $2,667; LP 100% in PinkLock02 lock #1022053 (unlock date **2122-07-06** → S).
  7. `0x1c02a798ea49d78eeb35840b481992a871608feb` Infi/WBNB — $1,551; PinkLock v1 lock #17881 (owner EOA, expired 2022-07-29 → H-O).
  8. `0xd948d34ce937d9d6b7d54741e33030d4dae3f700` PinkM/WBNB — $1,589; feeTo 0.15%, rest EOAs.
- **MasterChef** `0xe981676633dCf0256Aa512f4923A7e8DA180C595` — verified. 7 pools (PinkS/WBNB 4000 alloc, WBNB/BUSD 800, PinkE/WBNB 400, USDT/BUSD 200, ETH/WBNB 200, BTCB/WBNB 200, USDT/WBNB 200; totalAllocPoint 3600). `migrator()=0x0`; `owner()=0x169faCB54F3e1dD49EB61BD5F44c96EBD7156c36` (EOA); `devaddr()=0xd855e3f4D3F9e443afC84b4FCFC7Cf495eB18699` (EOA); `pinksPerBlock=1.664764e24`; `totalPinksReward=7e32`; `pinks.totalSupply()=7e32` → cap reached, deposits blocked. MasterChef holds 240.02T PINK (2.4e32) as unclaimed rewards, worth ~$17k at the thin PinkS pair price (realistically near-zero exit liquidity).
- **PINK token** `0x702b3f41772e321aacCdea91e1FCEF682D21125D` — verified `PinkSwapToken` (v0.6.12); `owner()=MasterChef`; `mint(address,uint256) onlyOwner`; no burn; supply 7e32.
- **PinkLock02** `0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE` — verified, non-upgradeable Unicrypt-style locker; 1,068,202 total locks; no `owner()`. PinkSwap-pair locks: MEV/WBNB (expired → H-O), ERODE/WBNB (2122 → S).
- **PinkLock v1** `0x7ee058420e5937496f5a2096f04caa7721cf70cc` — verified UUPS proxy, **`owner() = 0x0` (renounced; cannot be upgraded)**, 58,706 locks; Infi/WBNB + McDOGE/WBNB locks.
- **Other triage "factory" addresses**: `0x702b3f41…125d` = PINK token (not a factory); `0xe9816766…c595` = MasterChef (not a factory). Only one factory exists.

## 5. What an attacker can / cannot do (exact call paths)

**Can (E-U, worth ≈$0.005 total):**
1. `pair.skim(attacker)` on 11 of the 12 excess pairs → receives junk tokens (PinkE 10%-tax, PinkS, PinkM $0.0034, SAFEMOON dust, SFT/TRIII/WB3 dust). Cost: ~60–150k gas per pair on BSC (~$0.05–0.15). Net: **negative after gas** for everything (the sole non-zero piece, PinkM, is $0.0034 at best-effort prices).
2. Trade against the pair set (normal AMM arbitrage; profits come from LP holders, not from a protocol bug).

**Cannot (verified closed):**
1. Extract WBNB/BUSD/USDT/ETH/BTCB via `skim()` — zero priced-token excess exists (full 167-pair fork scan, `priced-token excess wei: 0`).
2. Mint any paired token and dump it into a pair: all top paired tokens (PinkE/PinkElon, MEV, ARS, ERODE, PinkM, Infi, McDOGE, SAFEHOLD, BNBC) are fixed-supply dxsale/safemoon templates with no public mint.
3. Mint PINK (`onlyOwner`; owner is MasterChef; MasterChef cannot be made to mint to an attacker).
4. Pull MasterChef LP via `migrate()` (`migrator()==0`), or deposit to farm more (cap reached), or gain from `updatePool()`.
5. Unlock PinkLock02/PinkLock v1 locks (`owner`-gated).
6. Burn or transfer anyone else's LP.

## 6. PoC / fork verification

- Project: `poc/` (Foundry, solc 0.8.24, fork of BSC latest via `BSC_RPC_URL`/`FORK_RPC_URL` with public fallback).
- Tests: `poc/test/PinkSwap.t.sol` — **8 tests**:
  1. `test_skim_top_pair_yields_no_wbnb` — skim of the $209k pair yields **0 WBNB** and only PinkE dust.
  2. `test_skim_all_excess_pairs_no_priced_tokens` — skims all live-excess pairs; **0 priced tokens**; counts revert-stuck pairs.
  3. `test_full_factory_scan_no_priced_excess` — all 167 pairs scanned on fork; **priced-token excess wei: 0**.
  4. `test_pink_mint_not_public` — reverts for attacker.
  5. `test_masterchef_migrate_closed` — reverts `migrate: no migrator`.
  6. `test_masterchef_cap_reached_no_caller_gain` — deposit reverts; `updatePool` gives caller nothing.
  7. `test_pinklock_unlock_gated` — reverts `You are not the owner of this lock`.
  8. `test_feeTo_redeem_privileged_only` — attacker can't burn others' LP; feeTo (pranked on fork) redeems its accrued WBNB (P demonstration).
- CI runs (GitHub Actions, public repo `kingmariano/ca-zombie-ci`):
  - Run 1: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38201588498 — custom live-state job PASS; forge 7/8 (1 over-strict equality assertion vs fee-on-transfer tokens; fixed).
  - **Run 2 (final): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38202891878 — custom job PASS; forge 8/8 PASS** (167-pair scan: `priced-token excess wei: 0`; 12 excess pairs, 1 stuck; block 127,145,004).
- The CI custom job (`ci/run.py` via `ci/run.sh`) re-reads the whole live state at a fresh block and writes `ci-out/live_state.json` + `ci-out/SUMMARY.txt` (uploaded as the `result-pinkswap` artifact) — this is the canonical machine evidence for the numbers above. Gate simulations from the attacker address confirm the reverts: `Ownable: caller is not the owner`, `Masterchief no more rewards`, `migrate: no migrator`, `You are not the owner of this lock`; `skim()` simulation succeeds (mechanism live) but yields junk only.

## 7. Verdict and residual / latent risk

- **E-U now: $0.00 (high confidence).** The triage's $275,306 is LP-owned liquidity (H-O $269,866) plus team-owned accrued fees (P $3,950) and one dead-locked LP position (S $2,667).
- Latent (not live, not E-U):
  - **P-rug surface**: the MasterChef owner EOA can `setMigrator` and then *anyone* can call `migrate()` to move all pool LP through a malicious migrator. This requires the owner key (privileged). The PinkSwap team appears inactive, but the key exists.
  - **P**: `feeTo`/`feeToSetter` EOA can redirect future protocol fees and (via `setFeeTo` on a pair's next liquidity event) mint fee-LP; the EOA can also redeem its $3,950 of accrued LP at any time.
  - **Dead-token gravity**: ~$210k of WBNB sits against PinkE (no market). LP holders can still redeem pro-rata, but the WBNB cannot be swapped out at fair value.
  - PinkE/SAFEHOLD-style tokens can change tax/limits (owner-controlled) — irrelevant to extraction.
- Blockers/caveats: (i) llama prices omit 148/177 pair tokens (all illiquid), so "reserves USD" is a lower bound on paper value but the only realizable-value measure; (ii) DexScreener "no pairs" checks were done locally at 2026-10-12; (iii) the CoinGecko-listed WBNB/BUSD and USDT/WBNB pairs still see ~$124/day volume, so the DEX is not 100% dead — but that flow does not create an extraction path; (iv) independent-audit limits: deployed-code≡source equality was not byte-verified (mitigated by a 100% ABI-selector match and live gate simulations), PINK's deploy-time constructor mint could not be read (archive RPC unavailable), and tokens in pairs with <$30 reserves were not individually audited (a public-mint token there could at most drain its own tiny pair); (v) PinkLock02/v1 hold third-party locked assets in total (≈333 WBNB in PinkLock02 across all its locks, owner-gated) — these belong to their lock owners, not to PinkSwap, and are out of scope for this finding.

## 8. Methodology & sources

- Corpus: `zombie_hunt/FINDINGS.md` (row: PinkSwap, Binance, $0.550M, deadUrl), `l2-triage-a/summary.json` (#17, $275,306, 167-pair enumeration), DefiLlama adapter registry (`registries/uniswapV2.js` → `pinkswap` factory + staking entries).
- On-chain: BSC via public RPCs (`bsc-rpc.publicnode.com`, `bsc.drpc.org`, `1rpc.io/bnb`) + CI BSC RPC; `cast`, stdlib Python (`analysis/enumerate.py`, `ci/run.py`); Etherscan V2 for verified sources; DefiLlama prices; DexScreener market checks; GoldRush token holders.
- Verified sources saved under `analysis/sources/` (PinkswapFactory, PinkswapPair, MasterChef, PinkSwapToken, PinkLock02, PinkLock v1 impl, plus the top paired tokens).
- Read-only: no transactions, no signatures, no keys; CI runs on forks only.
- Independent child audit (`analysis/child-audit-1/REPORT.md`): adversarial falsification check of the headline claim; attempted (read-only simulations) locker drains, PINK mint-and-dump, `setFeeTo(attacker)`, MasterChef LP theft, allowance-free `transferFrom`, `skim()` for value — all closed. ABI-selector cross-checks vs deployed bytecode (MasterChef/Factory/Pair/PINK + 25 tokens), live re-measurement of the 12 excess pairs + top-10 reserve pairs (exact match to the parent scan at blocks 127,141,159/127,144,638). Verdict: **claim confirmed, not falsified**.

### Files index

```
pinkswap/
├── README.md                     (this file)
├── summary.json                  (machine-readable)
├── analysis/
│   ├── enumerate.py              (167-pair live enumeration script)
│   ├── enumerate.log, enumeration_127138804.json
│   ├── feeTo_lp.json             (68 feeTo LP positions, $3,957.54 at local block 127,138,804)
│   ├── excess_tokens.json        (12 excess pairs + token addresses)
│   ├── lp_holders_goldrush.json  (top LP holders of key pairs)
│   ├── child-audit-1/            (independent falsification audit + evidence + REPORT.md)
│   └── sources/                  (verified contract sources)
├── poc/                          (Foundry project; test/PinkSwap.t.sol)
├── ci/                           (run.sh + run.py — fresh live state + gate sims)
├── ci-out/                       (CI artifacts: live_state.json, SUMMARY.txt)
├── ci-log.txt                    (CI run log, run 2)
└── ci-artifacts/                 (downloaded artifacts; run2/ = final run)
```
