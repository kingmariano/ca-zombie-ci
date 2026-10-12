# jet-v1 PoC — LiteSVM reproduction attempt + block proof (Solana)

Local, read-only reproduction against the deployed mainnet program
`JPv1rCqrhagNNmJVM5J1he7msQ5ybtvE1nNuHpDHMNU` (Jet Protocol v1).

**Nothing is ever sent to a real chain.** The test loads cloned mainnet accounts
(`../analysis/accounts.json`, dumped at slot 456,071,544) and the deployed
program ELF (`../analysis/jet_program.so`) into an in-process LiteSVM.

## What the attack would have been

The market's Pyth feeds are frozen at early-2024 values (solETH $2,304.09, SOL
$119.23378, USDC $1.00) while solETH's real market value collapsed after the
sollet bridge died. An external attacker could buy ~91.24 solETH cheaply, deposit
it as collateral (oracle value ≈ $210,224.94), and borrow the entire USDC vault
(16,246.540570 USDC) plus the entire SOL vault (1,274.172220813 SOL) — together
≈ **$168,170.91** at oracle prices — staying just inside the 1.25x minimum
collateral ratio, then never repay.

## Result: the deploy blocks it

The PoC executes the full path on cloned state and shows:

1. `refresh_reserve` is iterative (max one week of interest per call; the reserves
   are ~15 days behind, so 3 calls each). After looping to a valid cache, the
   frozen oracle prices are live in the market cache.
2. `init_obligation`, `init_deposit_account`, `deposit` (91.24 solETH),
   `init_collateral_account`, `deposit_collateral` (all 91,076,163 notes) and both
   `init_loan_account`s **succeed** — the attacker really can book ~$210k of
   oracle-priced collateral on today's chain state.
3. **Every `borrow` instruction reverts** with
   `Program log: panicked at src/instructions/borrow.rs:110:5` →
   `ProgramFailedToComplete`. This holds for the full vault amounts, for
   amount 0 and 1, for both reserves, with/without `refresh_reserve` in the same
   transaction, and with a writable market account — i.e. it is unconditional.
4. The vaults are unchanged (USDC 16,246.540570, SOL 1,274.172220813) and the
   attacker receives nothing.

**Diagnosis.** The deployed program was last upgraded at slot 160,301,534 =
**2022-11-10 12:43:29 UTC**, ~7 hours after jet-v1 commit `66991f4c8f14`
("disable borrows", 2022-11-10 05:19:06 UTC), which inserts `panic!("disabled");`
as the **first statement of the borrow handler** — exactly
`src/instructions/borrow.rs:110:5`. The deployed ELF confirms this: the panic
`Location` struct for that line is present in rodata, while borrow-handler body
strings (e.g. `Requested a debt that would exceed the maximum potential supply
for a token.`) have been eliminated as unreachable code.

So the vaults (~$168k at oracle prices) are still there but **cannot be extracted
through the borrow path**; the max-debt side of the market is disabled since
November 2022. This test exits 0 with `status = "blocked_borrow_disabled"`.

## Run

```bash
# from jet-v1/poc-svm
cargo run --release          # results -> ../ci-out/poc_results.json + poc_log.txt
```

CI: `jet-v1/ci/run.sh` (invoked by the poc.yml workflow with cwd = `jet-v1/`).

## Layout

- `src/main.rs` — the whole PoC (account loading, instruction encoding with
  Anchor discriminators, PDA derivation, tx sequencing, result reporting).
- `Cargo.lock` — pinned dependency graph (litesvm 0.18, solana modular crates).
- `.cargo/config.toml` — keeps `target/` in `/tmp` so it is never committed.

## Evidence notes

- Anchor discriminators re-derived from `sha256("global:<snake_case>")[:8]` and
  matched against IDL v0.2.0 for all 8 used instructions.
- PDA seeds verified against live on-chain data: 1,200/1,200 obligations derive
  from `[b"obligation", market, owner]`; 1,407/1,407 collateral positions from
  `[b"collateral", reserve, obligation, owner]`; 725/725 loans from
  `[b"loan", reserve, obligation, owner]`. The `deposits` prefix is present in
  the program binary and follows the same canonical Anchor pattern.
- Account metas (writable/signer flags) replicate the deployed program's
  `ToAccountMetas` as published in `jet-proto-v1-cpi` 0.23.0 (identical
  discriminators).
- Disable-borrows evidence: commit `66991f4c8f14` on the `no-borrows` branch of
  the jet-v1 mirror (judithjr/jet-v1); on-chain programdata upgrade slot
  160,301,534 (block time 2022-11-10T12:43:29Z) read from the deployed
  programdata account.
