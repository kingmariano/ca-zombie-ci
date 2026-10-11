# Powercity Flex Protocol — live state (PulseChain, chain 369)

All reads read-only via keyless public RPC (`https://pulsechain-rpc.publicnode.com`) +
PulseScan API (`api.scan.pulsechain.com`). Block numbers: 27,769,393 (triage) → 27,771,631
(baseline fork test) → 27,771,670 (PoC tests). State consistent across those blocks.

## System

| item | value (block 27,771,631) |
|---|---|
| Oracle `fetchPrice()` | 240,930 (1e8) = $0.0024093 per HEX |
| Troves (active) | 21 |
| Total debt | 49,959.028 HEXDC (8 dec) |
| Total collateral | 265,923,978.026 HEX (8 dec) |
| System TCR | 1282.4 % |
| Min trove ICR | 138.15 % (trove #20) |
| ActivePool HEX | 265,923,978.026 (== total collateral) |
| StabilityPool deposits | 7,719.327 HEXDC |
| HEXDC total supply | 49,959.028 |
| MCR / CCR | 110 % / 150 % |
| baseRate / redemption rate | 0 / 0.5 % |

No trove below 110 % → **no liquidations possible at the live oracle price**.

## Core contracts

| role | address | code | owner |
|---|---|---|---|
| TroveManager | `0xC2D0720721d48cE85e20Dc9E01B8449D7eDd14CE` | verified (solc 0.6.11) | 0x0 (renounced) |
| BorrowerOperations | `0x5b8575BD870a06a88FD6a2E4C68A66b2F74628Cb` | verified | 0x0 (renounced) |
| StabilityPool | `0x271F576fD6DE465231320a0F9997ACb0C8b97e07` | verified | (renounced pattern) |
| ActivePool | `0xE4FD443B26fA809A48EB658eA7edeB31E95c2144` | verified | — |
| DefaultPool | `0xC1C8A7F32E9D5142A77A05F8969B28B58fA10F63` | verified | — |
| SortedTroves | `0x3de0068B6a9c11bA93805974F6402f0Fab795394` | verified | — |
| PriceFeed | `0x5f2529BC80bB9C0Bd7C417EA78CE2Cd6114B112C` | **UNVERIFIED** | EOA 0x7510… (admin) |
| HEXDC (LUSDToken) | `0x1FE0319440A672526916C232EAEe4808254Bdb00` | verified; minters immutable (TM/SP/BO) | — |
| HEX (collateral) | `0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39` | 8 decimals | — |
| FLEX (LQTY) | `0x9c6fA17D92898B684676993828143596894AA2A6` | 8 decimals | — |
| LQTYStaking | `0xCeC2c718ceFdb3A515D3CC22e430b46933922CE4` | verified | — |
| Timelock | `0x16986F263b9AcC844Ae3bB903155352F415CD9DC` | OZ TimelockController, minDelay 10 s | — |
| GasPool | `0xE29b73f9262b42B44287102fB976426A7247B0Fa` | holds 1,050 HEXDC (21 × 50 reserve) | — |
| CollSurplusPool | `0xCdEc6212560C03e62D7e2a74dE22af70DEa9a288` | holds 839,729.937 HEX (~$2.08k) | borrower-claimable |

## Secondary balances (non-core)

| holder | balance | classification |
|---|---|---|
| StabilityPool | 7,719.33 HEXDC | H-O (depositor withdrawals) |
| LQTYStaking | 80,176,596.28 FLEX (~$62.0k) | H-O (staked principal) |
| LQTYStaking fees | 3,063.46 HEXDC + 87,628.77 HEX (~$3.4k) | H-O (staker rewards) |
| Farms `0x63D134B4…`, `0x74F8A9dF…` | LP tokens ~$23.6k (Synthetix-style staking) | H-O (user stake) |
| CollSurplusPool | 839,729.937 HEX (~$2.08k) | H-O (borrower claims) |

## Oracle pair reserves (block 27,771,631; raw)

| pair | reserve0 | reserve1 |
|---|---|---|
| HEX/WPLS V1 | 11,150,690,852,945,160 (HEX, 8d) | 28,805,187,508,032,288,820,803,290,922 (WPLS, 18d) |
| HEX/WPLS V2 | 13,918,691,234,640,858 (HEX, 8d) | 35,955,457,380,859,715,511,415,780,237 (WPLS, 18d) |
| WPLS/DAI | 44,233,729,434,912,280,216,550,644,593 (WPLS) | 432,634,250,786,301,579,324,587 (DAI) |
| USDC/WPLS | 418,452,572,995 (USDC, 6d) | 42,786,326,923,816,493,274,370,443,491 (WPLS) |

## Market prices (DefiLlama, 2026-10-11)

- HEX (pulsechain) $0.0024815; HEXDC $1.0381; FLEX $0.0007735; WPLS $9.5436e-6.
- HEXDC/HEX PulseX pool: 15,550.86 HEXDC vs 6,489,649.97 HEX → HEXDC ≈ $1.036.
- Oracle lags market by ~2.9 % (TWAP vs spot), no exploitable edge (HEXDC trades above the
  oracle redemption value of $1.0308).
