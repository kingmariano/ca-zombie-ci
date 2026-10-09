# C2-25 — Larix (Solana, Solend fork): the 2021 `UpdateReserveConfig` missing-check hypothesis is **refuted** — config-update path is fully gated

**Date:** 2026-10-09 · **Chain:** Solana (mainnet-beta) · **Status:** read-only; live-RPC simulation only; **no transactions signed or sent**; no secrets.

**Programs:**
`7Zb1bGi32pfsrBkzWdqd4dFhUXwp5Nybr1zuaEwN34hy` (main) and `3cKREQ3Z7ioCQ4oa23uGEuzekhQWPxKiBEZ87WfaAZ5p` (aux/isolated markets).

---

## 1. TL;DR

| target | live extractable (unprivileged) | why closed | latent risk |
|---|---|---|---|
| Larix SetConfig reserve-config path (both programs) | **$0** | Deployed binaries enforce **market-owner signature + `reserve.lending_market == market.key` + reserve-freshness + config validation** before any write. The reserve↔market check (the exact 2021 Solend patch) **is present** in both live binaries and rejects mismatched markets (RPC-proven). | Program is upgradeable by a single EOA (`Gwqwy…`, still active); market owner is a single EOA (`Eknz…`). Key compromise ⇒ privileged config changes (P). |
| Protocol liquidity ($1.271M available) | $0 E-U | Held in reserves; redeemable by collateral holders (H-O). All top reserves refreshable today (live Pyth/Larix oracle feeds). | Oracle feeds controlled via market config; upgrade authority; wind-down ops. |

## 2. Total live extractable now

- **E-U (external unprivileged): $0.00** — confidence **high** (RPC-simulated against the live programs; static check verified in both deployed ELFs).
- **H-O (holder self-service): $1,271,380.20** available across 74 reserves (main $1,170,428 + aux $100,952), 100% of the ≥$100 reserves refreshable/redeemable today. Live redeems are occurring (e.g. tx `2138pB7f…` slot 454,577,737).
- **P (privileged): $0 incremental** — the same $1.271M is also subject to market-owner config changes and program upgrade authority (single EOAs); not double-counted.
- **S (stuck): ~$0** — remaining dust is <$100 per reserve (unpriced LP tokens).

## 3. The bug / mechanism in exact terms

The finding hypothesized that Larix, a Solend fork, never merged Solend's 2021-08-19 fix to
`process_update_reserve_config` (missing `reserve.lending_market == market` check → attacker-created
market → collateral-factor/oracle manipulation → over-borrow).

Solend's patch (`solendprotocol/solana-program-library` commit
`132d74cf171dac66f896c4009ad6836f8c0b3799`) added:

```rust
if &reserve.lending_market != lending_market_info.key {
    msg!("Reserve lending market does not match the lending market provided");
    return Err(LendingError::InvalidAccountInput.into());
}
```

**What the deployed Larix binaries actually do** (instruction tag 14 = `SetConfig`; handler at file
offset `0x3BF38..0x3F4C0`, outlined from the dispatcher; see `analysis/static-analysis.md`):

1. market account owned by program → 2. market owner matches provided owner **and is a signer**
→ 3. **32-byte equality check at `0x3D210` (market vs reserve binding; failure ⇒ error 5
`"Reserve provided is not owned by the lending program"`)** → 4. reserve owned by program
→ 5. reserve must be fresh → 6. oracle-config + config-value validation → write.

The check at `0x3D210` is the only branch into that error block; the reserve↔market relationship is
therefore enforced. The `"Reserve lending market does not match…"` string exists in the binaries but
is referenced only by other instruction handlers (deposit/withdraw/borrow/repay/redeem), not by the
SetConfig handler (exact-address xrefs `0x4010`, `0x25E48`, `0x28578`).

## 4. Live-state assessment (slot ≈ 454,765,700, 2026-10-09)

| item | value | evidence |
|---|---|---|
| main program / programdata | `7Zb1…` / `8cKUEdb9TSSdhA8TVUEWMmQ9hTqYZZBteyCvhsh4721v` | `getAccountInfo` |
| main ELF sha256 | `435230e5…f598a7` (1,417,360 B) | programdata fetch |
| main last deploy | slot 127,725,622 = 2022-04-01 15:27:56Z | `getBlockTime` |
| aux program / programdata | `3cKR…` / `EZro8f37oGDXDyr979q7iByuCk26VSnCxvBp8gpymPjL` | `getAccountInfo` |
| aux ELF sha256 | `4650233e…bbc3049` (1,305,152 B) | programdata fetch |
| aux last deploy | slot 130,433,115 = 2022-04-19 15:04:56Z | `getBlockTime` |
| upgrade authority (both) | `GwqwyQqJ5kr3X7iUDQKgJ1FJYjxmCieiY5PikmMbsL1Q` — **single system account, 4.99 SOL** | programdata header |
| markets | main: 1 (`5geyZJd…`); aux: 16 (5 owner `Eknz…`, 11 owner `HmzDqZ…`) | `getProgramAccounts` dataSize=418 |
| market owner | `EknzKAAkFzbD1mY7ovWZVtuFptgetn5yw99LSqfE6XH9` — single system account, 321.5 SOL | market decode |
| reserves | main 45 (23 live), aux 29 (21 live) | `getProgramAccounts` dataSize=873 |
| available liquidity | main $1,170,428 + aux $100,952 = **$1,271,380** | reserve decode + DefiLlama prices |
| obligations (main market) | 10,163 accounts, 3,113 with debt; **stale** nominal values $138.4M deposited / $12.1M borrowed (frozen at 2021-22 refreshes) | `getProgramAccounts` dataSize=1092 |
| refreshability | all 20 reserves ≥$100 refresh successfully today (Pyth + Larix oracles live) | `simulateTransaction` RefreshReserve |
| pause state | most main reserves deposit/borrow-paused (wind-down); aux mostly open; **redeem works** (live txs) | reserve config bytes |

## 5. What an attacker can / cannot do

**Cannot (proven by simulation, `ci/run_sims.py`):**

- Change a reserve's config using a different market of the same program
  (`aux-mismatch-market`: `Custom 5` — reserve↔market check).
- Change a reserve's config without the market owner's signature
  (`aux-owner-not-signer`, neutral fee payer: `Custom 12` — owner must sign).
- Create a market and use it against another market's reserves (same check; main program has only
  one market anyway).
- Skip unpacking (`[14]` alone → `"Failed to unpack instruction data"`), or reach a config write
  with invalid values (zero-config stops at oracle-config validation, `Custom 42`).

**Can (observed live):** redeem reserve collateral (holders withdrawing today); call permissionless
instructions (refresh, deposit where unpaused, redeem, repay). Creating markets appears
permissionless (16 markets on aux incl. a third-party owner), but this does not help: config writes
are bound to each reserve's own market owner.

**Cost of the attempted attack:** ~0.00002 SOL per tx — irrelevant; the path simply reverts.

## 6. Verification / PoC (read-only, live RPC)

Files: `ci/run_sims.py` (harness), `ci-out/sim-results.json`, `ci-out/local-run.log`,
`analysis/simulation-evidence.md`, `analysis/static-analysis.md`.

| case | result |
|---|---|
| `main-baseline` (own market, refreshed mSOL reserve, $900k) | `Custom 42` — passed all gates, stops at oracle-config validation |
| `aux-baseline` (own market, refreshed USDC reserve, $92.5k) | `Custom 42` — same |
| `aux-mismatch-market` (different market, same program/owner) | **`Custom 5` — rejected by reserve↔market check** |
| `aux-owner-not-signer` (neutral payer, owner not signer) | **`Custom 12` — owner signature required** |

Additional controls (both directions of the swap, market-config variant, stale-reserve gate) are in
`analysis/simulation-evidence.md`. The check region is byte-identical between the main and aux
binaries (`.text` diff 0.26%, only embedded constants), so the aux behavioral proof applies to main.

**CI:** GitHub Actions run(s) — see `ci-log.txt` / `ci-artifacts/`; URLs recorded below.

- CI run URL: `<<FILLED_AFTER_CI>>`

## 7. Verdict and residual/latent risk

- **Verdict: CLOSED for E-U. C2-25 hypothesis refuted.** The unpatched 2021 config-update path is
  not live; the deployed April-2022 binaries contain the reserve↔market check plus owner-signature
  gating. Live extractable by an external unprivileged attacker: **$0** (high confidence).
- **Residual/latent (not E-U):**
  - Upgrade authority `Gwqwy…` is a single EOA (5 SOL) — can upgrade both programs (P).
  - Market owner `Eknz…` is a single EOA (321 SOL) — can change reserve configs, including oracle
    parameters (P). No multisig observed on-chain for these roles.
  - Custom oracle stack (Pyth + Larix oracle program `GMjB…`) is a trust point for pricing.
  - Wind-down risk: paused markets + bad-debt reserves; holders should redeem (H-O).
- **Blockers to any exploit:** market-owner signature; reserve↔market equality; freshness; config
  validation. None of these are bypassable with unprivileged accounts.

## 8. Methodology & sources

- Live state: Solana RPC (`solana-rpc.publicnode.com`, `api.mainnet-beta.solana.com`), keyless;
  slot numbers recorded (deploys, reads at ≈454.7M).
- Binary analysis: on-chain ELF fetch + custom eBPF/SBF disassembler (`analysis/static-analysis.md`).
- Behavioral: `simulateTransaction` with `sigVerify=false` + `replaceRecentBlockhash=true` (no keys,
  no sends).
- Prices: DefiLlama `coins.llama.fi` at 2026-10-09.
- Bug lineage: Solend 2021-08-19 incident (patch commit `132d74cf…`); Larix repos
  `ProjectLarix/larix-lending` (instruction.rs tag map), `@projectlarix/larix-sdk` (state layouts).
- **Caveats:** Solana has no public state-override simulation; the market-mismatch proof therefore
  uses two real markets on the aux program (same code as main). Obligation values are stale
  (2021-22); current-priced liquidity is the reserve figure. No full audit of unrelated
  instructions was performed. The $1.271M is a point-in-time read.

## 9. Files index

```
larix/
├── README.md                     (this file)
├── summary.json                  (machine-readable verdict)
├── analysis/
│   ├── program-map.json          (programs, programdata, authority, deploys, hashes)
│   ├── markets.json              (all 17 market accounts + owners)
│   ├── reserves-main.json        (45 decoded reserves)
│   ├── reserves-aux.json         (29 decoded reserves)
│   ├── funds-summary.json        (available liquidity + USD, pause flags)
│   ├── refreshability.json       (RefreshReserve sim results per reserve)
│   ├── obligations-main-summary.json (10,163 obligations, stale aggregates)
│   ├── static-analysis.md        (ELF/disassembly evidence)
│   └── simulation-evidence.md    (all simulation logs/controls)
├── ci/run.sh                     (CI job: pip install solders; run sims)
├── ci/run_sims.py                (harness, keyless RPC)
├── ci-out/                       (sim logs + results; uploaded as CI artifacts)
└── ci-log.txt, ci-artifacts/     (downloaded by ci-run.sh)
```
