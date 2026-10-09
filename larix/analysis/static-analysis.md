# C2-25 — Larix static analysis (deployed binaries)

Read-only analysis of the two deployed Solana programs. No keys, no transactions.

## Targets

| | program | programdata | ELF sha256 | last deploy (slot / UTC) | upgrade authority |
|---|---|---|---|---|---|
| main | `7Zb1bGi32pfsrBkzWdqd4dFhUXwp5Nybr1zuaEwN34hy` | `8cKUEdb9TSSdhA8TVUEWMmQ9hTqYZZBteyCvhsh4721v` | `435230e5…f598a7` | 127,725,622 / 2022-04-01 15:27:56Z | `GwqwyQqJ5kr3X7iUDQKgJ1FJYjxmCieiY5PikmMbsL1Q` |
| aux  | `3cKREQ3Z7ioCQ4oa23uGEuzekhQWPxKiBEZ87WfaAZ5p` | `EZro8f37oGDXDyr979q7iByuCk26VSnCxvBp8gpymPjL` | `4650233e…bbc3049` | 130,433,115 / 2022-04-19 15:04:56Z | `GwqwyQqJ5kr3X7iUDQKgJ1FJYjxmCieiY5PikmMbsL1Q` |

Both are upgradeable (BPFLoaderUpgradeab1e) and **still have an active single-EOA upgrade authority**
(`Gwqwy…`, a plain system account, 4.99 SOL at slot 454,765,693).

## The 2021 Solend bug this finding hypothesized

Solend incident 2021-08-19: `process_update_reserve_config` authenticated the *supplied* lending
market but did not verify that it was the market bound to the target reserve. An attacker created
their own lending market and passed it, satisfying the owner check, then edited victim reserve
configs (lowered liquidation thresholds, raised bonuses, set 250% borrow rates) to wrongfully
liquidate positions. Patch (solendprotocol/solana-program-library commit `132d74cf171dac66f896c4009ad6836f8c0b3799`,
2021-08-19) adds:

```rust
if &reserve.lending_market != lending_market_info.key {
    msg!("Reserve lending market does not match the lending market provided");
    return Err(LendingError::InvalidAccountInput.into());
}
```

Larix's first public commit is dated **2021-08-21** ("The instruction after round 1 audit") — i.e.
after the patch was public.

## Deployed binary analysis (BPF disassembly of the on-chain ELFs)

Instruction dispatch (deployed binary): `Instruction: Set Config` is instruction tag **14**;
payload is a `ConfigType` (2-variant nested enum: market-level config / reserve config).
The handler is an outlined function at file offset `0x3BF38..0x3F4C0` (main; aux is the same
code at the same offsets).

**Complete message list emitted by the SetConfig handler** (extracted from resolved `sol_log_`
call sites; exact strings, in code order):

```
Lending market provided is not owned by the lending program
Lending market owner does not match the lending market owner provided
Lending market owner provided must be a signer
New mine mint provided is executable
New larix oracle program provided is not executable
Reserve provided is not owned by the lending program
New owner provided is not owned by the system program
New owner provided is executable
New oracle program provided is not executable
New token program provided is not executable
New mine mint provided is not owner by token program
New mine supply provided is not owner by token program
Reserve is stale and must be refreshed in the current slot
New owner provided is owned by the spl-token program
New owner provided 's data is not equals zero
New mine supply provided is not an account of mine mint
Flash loan fee wad must be in range [0, 1_000_000_000_000_000_000)
New mine supply provided is not owner by derived lending market authority.
Borrow fee must be in range [0, 1_000_000_000_000_000_000)
Host fee percentage must be in range [0, 100]
Host fee receiver is full
Liquidation threshold must be in range (LTV, 100]
Optimal borrow rate must be <= max borrow rate
New receiver provided is executable
The larix oracle price account provided is not match the larix oracle program in lending market
Reserve liquidity fee receiver is not a token account of reserve liquidity
```

The reserve-config path checks (in order): market owned by program → market owner matches and is a
signer → **32-byte pubkey equality check (see below)** → reserve owned by program → reserve fresh →
oracle-config validation → config value validation.

### The reserve↔market check is present

At code offset `0x3D210` the handler calls a 32-byte equality helper (`pubkey_eq`), and the *only*
branch to the error block `"Reserve provided is not owned by the lending program"` (error 5) is the
failure of that comparison (`0x3D218: if !eq goto error`). This is the same message/error the
Solend patch reused. The check's second operand is market-derived; the first is derived from the
reserve account copy. Changing only the market account in the simulations flips pass/fail (see
`simulation-evidence.md`).

### The `"Reserve lending market does not match…"` string

The binary *contains* this string, but exact-address xref analysis shows it is referenced only at
code offsets `0x4010`, `0x25E48`, `0x28578` — all inside the giant inlined `process` function used
by deposit/withdraw/borrow/repay/redeem handlers. It is **not referenced by the SetConfig handler or
any of its callees**. Larix's config path implements the same check with the message
`"Reserve provided is not owned by the lending program"` (message reuse), as proven behaviorally.

### main vs aux binaries

`.text` sections are 566,888 bytes and differ in 1,492 bytes (0.26%). The differences are 1-byte
immediates and 32-byte embedded constants (different program id / string-table addresses). The
reserve-check region `0x3D180..0x3D270` is byte-identical between main and aux except the 2 bytes of
the error-message pointer. All four behavioral tests below were run against **both** programs
(baseline) and aux (mismatch / no-signer); the shared code makes the results transferable.

### Market ownership / creation

- main program: exactly **1** market (`5geyZJd…`, owner `Eknz…`).
- aux program: **16** markets — 5 owned by `Eknz…`, **11 owned by a different key**
  (`HmzDqZExUUQo4hazRsvnEHvhQfzFqziDYuUAJfRas48J`), i.e. market creation by third parties is
  observed on-chain (InitLendingMarket is effectively permissionless). This does not open the
  config path: the reserve↔market check plus the *market-owner signature* requirement bind config
  changes to the owner of each reserve's own market.
