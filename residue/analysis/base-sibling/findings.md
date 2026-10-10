# Base vault sibling `0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23` — live-state re-verification

**Date:** 2026-10-10 · **Chain:** Base (8453) · **Latest block:** 52,424,899
**Status:** read-only; eth_call only; no transactions.

Related prior work: C2-02 (branch `base-vault-d189` of `kingmariano/ca-zombie-ci`) covers this
sibling's history and whitelist enumeration. This file is the H2-03 fresh re-verification at the
latest block.

## 1. Identity

| Field | Value |
|---|---|
| Proxy | `0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23` (TransparentUpgradeableProxy, ~1.9 KB) |
| Implementation (EIP-1967 slot `0x360894…bbc`) | `0x67ed441b2444e055376F4acaBddA969F8926e4EA` |
| ProxyAdmin (EIP-1967 slot `0xb5312…6103`) | `0x490ca969b43b1ab869b5959a7b3919cc2c37c4e6`; admin owner `0x47a60e3D6121B216cD22984df5976a41e15baF77` |
| Owner | `0x6b27512a5943Ed327f6cb6C3EC1f0398229f42C4` (same 3-of-7 Safe as the C2-02 vault) |
| Native balance | 0 |

## 2. Holdings at block 52,424,899 (DefiLlama prices, 2026-10-10)

| Token | Balance | Price | USD |
|---|---|---|---|
| AERO `0x940181a9…` | 4,508,069.472727 | $0.893756 | $4,029,114.17 |
| VIRTUAL `0x0b3e3284…` | 1,319,234.039255 | $0.734489 | $968,962.47 |
| USDT `0xfde4C96c…` | 161,813.101173 | $0.999241 | $161,690.23 |
| cbBTC `0xcbB7C000…` | 1.689000 | $82,783.36 | $139,821.10 |
| WETH `0x4200…0006` | 4.416122 | $2,496.11 | $11,023.14 |
| USDC `0x833589fC…` | 1,503.000000 | $0.999721 | $1,502.58 |
| USDbC | 0 | — | 0 |
| **Total** | | | **$5,312,113.68** |

No aTokens held (aWETH = 0, aBasUSDC = 0): the assets sit in the contract, not supplied to Aave.

## 3. Gates re-verified at the latest block (eth_call, from = fresh EOA `0x2222…2222`)

| Call | Result |
|---|---|
| `borrow(aWETH,1,2,0,fresh)` | **revert `!W`** (whitelist gate on `msg.sender`) |
| `withdraw(aWETH,1,fresh)` | **revert `!W`** (gate) |
| `repay(aWETH,1,2,fresh)` | **revert `!W`** |
| `whitelist(0xcdFE91301356da873562EF513828a60dba1F569d)` (the C2-02 attacker helper) | **false** — the helper is NOT whitelisted on the sibling |
| `borrow(aWETH,1,2,0,ownerSafe)` from the owner Safe `0x6b27512a…` | **success (`0x`)** — owner exemption confirmed (privileged, P) |
| `withdraw(aWETH,1,ownerSafe)` from the owner Safe | **revert `!WWE`** — no owner withdrawal route either |
| allowance(sibling → C2-02 attacker helper) for AERO / USDT | 0 / 0 |

The sibling's whitelist was enumerated by C2-02: **92 contracts, 0 EOAs** (all protocol account
contracts; every nonpayable function probed from a fresh caller reverts `Ownable`/`!G`). No
value-moving entry point exists for an unprivileged caller.

## 4. Verdict

- **E-U (fresh, unprivileged): $0.00 — high confidence.**
- **P: $5,312,113.68** — owner Safe (3-of-7) can `borrow` (owner-exempt, eth_call-proven) and can
  re-grant the whitelist; ProxyAdmin `0x490ca969` (owner `0x47a60e3D…`) can upgrade the impl.
- **S / H-O: $0.**
- **Latent:** none identified for fresh callers; the only state flips are owner/ProxyAdmin actions.
- **Comparison with the mission lead:** the corpus said "whitelist path closed, no proven drain" —
  confirmed. The C2-02 helper whitelist applies to the *main* vault `0xD1895f20…`, not to this
  sibling.

## 5. Evidence files

- `sibling_source.json` — verified proxy source (TransparentUpgradeableProxy, solc 0.8.15).
- Raw reads above were taken with `cast` against `https://base-rpc.publicnode.com` and
  `https://base.drpc.org` at block 52,424,899 (latest) on 2026-10-10.
