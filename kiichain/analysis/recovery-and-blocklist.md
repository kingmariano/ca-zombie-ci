# KiiChain incident recovery and blocklist (verified live)

Source of truth: public KiiChain source at tag `v7.4.0`
(`app/upgrades/v7_4/upgrade.go`, `app/blockedaddrs/*`, `ante/vesting_ante.go`)
plus live LCD/RPC balances on 2026-10-04.

## What the v7.4.0 upgrade did (ran when the chain resumed, 2026-08-27)

1. `sweepAttackerFunds`: moved the **spendable** `akii` balance of every address
   in `blockedaddrs.AttackerAddrs` into the `evm` module staging account
   (`kii1vqu8rska6swzdmnhf90zuv0xmelej4lq5el7zh`). Locked vesting remainders
   are untouched by design (`SpendableCoin`, not `GetBalance`).
2. Paid a fixed 16-recipient list from staging (victims), then sent the
   remainder to `kii1c6cgjmsx0ewl6j552sp06musutmfcvxcaq4n9h`.
3. Verified supply-neutrality and exact balances, then permanently enabled the
   bank send restriction for incident addresses (`blockedaddrs.Enable`).

The 22 blocked addresses (`AttackerAddrs`, bech32 → hex) are two attacker EOAs
(`0x0e7a9622…`, `0x631dc2c6…`) plus 20 vesting/helper accounts, including the 19
delayed-vesting accounts mapped in `analysis/raw/vesting_evm.json`.

## Live accounting (2026-10-04)

| Item | Amount (KII) | USD @ $0.088334 |
|---|---|---|
| Fixed payouts to 16 victims (planned) | 67,598,126.149227 | $5,971,212.88 |
| Recovery remainder wallet `kii1c6cgjmsx0ewl6j552sp06musutmfcvxcaq4n9h` | 37,999,990.096889 | $3,356,691.13 |
| Recovery staging account `kii1vqu8rska6swzdmnhf90zuv0xmelej4lq5el7zh` | 0 | $0 |
| Attacker EOAs `kii1peafvgn…`, `kii1vvwu93…` | 0 | $0 |
| 18 fully-delegated exploit vesting accounts | 0 spendable | $0 |
| `kii13ndtp…` (2 KII locked, blocklisted, never swept) | 2.0 locked | $0.18 |
| Chain supply | 1,799,758,910.6 | — |

Victim balances were individually verified (`analysis/raw/live_probes.json`);
most recipients still hold the exact payout amount; two have spent part.

Note: the recovery swept ≈105.6M KII in total (payouts + remainder), more than
the ~80.7M the Cosmos post-mortem said remained on-chain at halt time — the
sweep also captured later-arriving and helper-account balances. Total incident
loss was 148,326,583.15 KII; 67,597,997.87 KII had already been bridged to BNB
Chain (outside this assessment, attacker-controlled / partly CEX-frozen).

## Effect on extractability

- Every attacker-controlled spendable balance is zero; the recovery remainder
  sits in a plain `BaseAccount` (EOA) controlled by the team (privileged, P).
- The bank send restriction blocks both `from` and `to` for all 22 incident
  addresses, permanently (`enabledKey` once set).
- The only value still associated with an incident address is 2 KII locked in
  `kii13ndtp…` until `end_time` 1,818,972,718 (≈2027-08-19). It is blocklisted
  (no bank send) and its delegation path is guarded; effectively stuck (S).
- Attacker contracts remain deployed but owner-gated (`sweep` requires
  `msg.sender == 0x0e7a9622…`) and empty; the `delegate` helper path reverts at
  the node level.

Files: `analysis/raw/upgrade_v7_4_v7.4.0.go`,
`analysis/raw/blockedaddrs_addrs_v7.4.0.go`,
`analysis/raw/vesting_ante_v7.4.0.go`.
