# H-22 / Serum · OpenBook v1 — Independent Source Audit (deployed v0.5.10)

**Date:** 2026-10-04 · **Chains:** Solana mainnet-beta · **Mode:** read-only; no transactions; no keys used; no CI.
**Auditor role:** child subagent of H-22 (“zombie hunt”); this file is the source-audit deliverable.
**Verdict headline:** no external-unprivileged value-extraction path (E-U) found in the deployed OpenBook v1
program; several latent, code-real but $0-today primitives (documented below). Matches the parent H-22 result
($0, medium-high).

---

## 0. Target / deployed-build verification (read-only)

| Item | Value | Source |
|---|---|---|
| OpenBook v1 program | `srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX` | on-chain |
| Program account owner | `BPFLoaderUpgradeab1e11111111111111111111111` (executable) | `getAccountInfo`, slot 453,191,278 |
| ProgramData | `9K32VSPTg4PHY7Hb2QZq26e5CujwMgt8Bqq4kJrp5zp8` (468,941 B) | idem |
| Last deploy slot | 168,006,653 (≈2022-12-20) | ProgramData slot field |
| **Embedded security.txt** | `source_revision 546e5fe0f366ce7414424eaf5a481a917b8b5210` `source_release v0.5.10` | ELF in ProgramData, offsets ~211.5k |
| Upgrade authority | `8xYs2tGXPayMtgsqs4NuMy7bnWr7DM9tnnkbY2SHVbys` — off-curve, owned by SPL Governance `GovER5Lthms3bLBqWub97yVrMmEogzX7xNjdXpPPCVZw`, data_len 236 | idem + ed25519 curve test |
| Local clone used | `/tmp/opencode/ob-program` @ `c85e56d` (master) = tag `v0.5.10` (`546e5fe`) + CI/deps only | `git diff --stat 546e5fe c85e56d` → no `dex/src` changes |
| Fee sweeper / disable authority | `GTgd6NaobHDLSFAh2kG5DTNsL4SBJH42Qq11jpjWCfXA` — **off-curve PDA**, not an EOA (see §4) | `instruction.rs:32-40`; curve test |
| Live market flags (OpenBook) | flags=3: **727,164**; disabled(131): 0; V2(515): 0; V2+disabled(643): 0 | `getProgramAccounts`, slot 453,191,278 |
| Initialized OpenOrders | 802,133 (flags=5); closed(261): 0; **zeroed(0): 0** | `getProgramAccounts` (positive control: flags=5 count) |
| Overflow checks | **DISABLED** in deployed ELF (see §6) | string analysis of ProgramData |

Programs are still actively used: `getSignaturesForAddress` shows invocations at slot ≈453,204,xxx (Oct 2026)
for both OpenBook v1 and Serum v3.

**Conclusion of build check:** auditing repo `dex/src/*` at tag v0.5.10 is equivalent to auditing the deployed
bytecode (master adds only `.github/`, `Cargo.lock`, `Cargo.toml` bumps). All line references below are
`/tmp/opencode/ob-program/dex/src/*` @ `v0.5.10`.

---

## 1. Instruction surface (reachability)

Reachable (`state.rs:2587-2717`): `InitializeMarket`, `NewOrderV3`, `ReplaceOrderByClientId(s)`,
`ConsumeEvents`, `ConsumeEventsPermissioned`, `CancelOrderV2`, `SettleFunds`, `CancelOrderByClientIdV2`,
`CancelOrdersByClientIds`, `DisableMarket`, `SweepFees`, `CloseOpenOrders`, `InitOpenOrders`, `Prune`.

Unreachable / inert: `NewOrder`/`NewOrderV2`/`CancelOrder`/`CancelOrderByClientId` → `unimplemented!()`
(panic → tx abort); `MatchOrders` → empty arm (`state.rs:2623`); `SendTake` → `unimplemented!()`
(`state.rs:2720`) — **SendTake never runs on OpenBook v0.5.10**. No instruction writes the request queue in
v0.5.10 (only `req_q.gen_order_id`, which bumps `next_seq_num`), so the queue is always empty and
`check_assert_eq!(req_q.header.count(), 0)` (`state.rs:3167`) always holds.

---

## 2. Ranked candidate table

| # | Path | Verdict | Value today | Conf. | Key code refs |
|---|---|---|---|---|---|
| 1 | Forge/cross-bind ConsumeEvents to credit/debit a victim OpenOrders | **closed** | $0 | high | `state.rs:2975-3135` (lookup 2992-3010), `matching.rs` all `Event::new` sites |
| 2 | Drain a market vault via SettleFunds/SweepFees recipient redirection | **closed** | $0 | high | `state.rs:1450-1476`, `2795-2877`, `2262-2335`, vault/PDA checks `1602-1611`, `504-534` |
| 3 | Non-owner SettleFunds / CloseOpenOrders / Cancel | **closed** | $0 | high | `state.rs:194-197`, `2294-2320`, `2427-2435`, `2099-2106` |
| 4 | SweepFees / DisableMarket by unprivileged caller | **P** (DAO-governance PDA) | fees in vaults, not reachable | high | `state.rs:1566-1570`, `1572-1576`, `3357-3390`; PDA fact §4 |
| 5 | Prune (V1) / consume-events-authority bypass | **closed** (dead code on all live markets) | $0 | high | `state.rs:137-156`, `2538-2540`, `2024`, `2054-2058`; 0 V2 markets on-chain |
| 6 | Rent capture on zeroed OpenOrders (init → close) | **E-U (latent)** | **$0** (0 accounts) | high | `state.rs:174-189`, `2769-2791`; on-chain count = 0 |
| 7 | Value creation via arithmetic wrap/rounding in NewOrderV3/matching | **closed** | $0 | med-high | `matching.rs:497-532, 813-850`, `fees.rs:81-119`, `state.rs:3242-3278`; §6 |
| 8 | Vault redirection via InitializeMarket / PDA collision | **closed** | $0 | high | `state.rs:1653-1740` (owner-PDA check 1710-1713) |
| 9 | ReplaceOrder / CancelOrdersByClientIds account-index or partial-state abuse | **closed** | $0 | high | `state.rs:1962-1996`, `2925-2949`, `3327-3355` |
| 10 | Cross-version fee mismatch (v0.5.9→v0.5.10) | **historical (S/small leak)** | not reproducible | med | §7; scar market `DMLq…` = `2^64-2` |
| 11 | Market/queue/bids/asks rent | **S** (no CloseMarket) | ~672.8k SOL per parent | high | no close instruction exists |
| 12 | Program upgrade to malicious code | **P** (SPL Governance) | all TVL, but governance-gated | high | §4 |

`E-U` = extractable by external unprivileged attacker · `H-O` = holder-only recovery · `P` = privileged ·
`S` = stuck · `closed` = check blocks the path.

---

## 3. Detailed audit — ConsumeEvents (checklist #1)

`process_consume_events` (`state.rs:2975-3135`):

1. **Binding.** For each event, the account is found by `binary_search_by_key(&event.owner, key)` over the
   caller-supplied account list (`2992-2993`). `Ok(i)` is returned only when the account key bytes equal
   `event.owner` (the comparator is the key itself, so unsorted input can only cause *misses*, not
   mismatches). The found account is then loaded with `load_orders_mut(..., owner_account=None, ...)`
   which enforces: program-owned (`state.rs:166`), `flags==Initialized|OpenOrders` (`191`), and
   `open_orders.market == this market` (`192-193`). **No owner-field check is needed**: since events are
   only ever written by the program with `owner` = the OpenOrders account address supplied at order
   creation, and an account address identifies exactly one account, an event cannot be applied to an
   OpenOrders it was not created for.
2. **State consistency.** `event.owner_slot < 128`; `slot_side(owner_slot) == event.side`;
   `open_orders.orders[owner_slot] == event.order_id` (`3005-3010`). `order_id` embeds the market-global
   `seq_num` from `RequestQueue::gen_order_id` (`state.rs:908-922`, `matching.rs:251`), so two live orders
   can never share an id.
3. **Event provenance.** Every `Event::new` call in `matching.rs` uses a validated owner: slab-leaf owners
   (set from a request whose OpenOrders was signature-verified at `state.rs:194-197`,
   `NewOrderV3Args:1930-1937`) or the taker's own OpenOrders address (`state.rs:3226`). Events are pushed
   only into the market's own event queue (`load_event_queue_mut` key+flags checks, `state.rs:490-501`).
   There is no instruction that lets a caller write an event with arbitrary fields.
4. **Fill accounting.** Maker bid: `native_pc_total -= native_qty_paid; native_coin_total/free +=
   native_qty_received; native_pc_free += native_fee_or_rebate` (`3026-3031`). Maker ask symmetric
   (`3032-3036`). Takers are no-ops (already settled inline in `process_new_order_v3`, `3268-3277`).
   Referrer rebate recomputed at consume time (`3040-3046`); see §7 for why this is a latent landmine.
5. **Out events.** `release_funds=true` adds to free with `free <= total` assert (`3105-3116`);
   `release_funds=false` changes nothing (the unlock was already done inline), and `fully_out` removes the
   slot (`3124-3126`).
6. **Crafting in an attacker’s own market targeting another market’s OpenOrders is impossible:** the OO
   `market` field is immutable after init and checked at load; an attacker cannot create an account at a
   victim’s OO address (address already in use and requires the victim’s signature), nor set a foreign
   owner at init (owner = signer, `state.rs:185-188`).

Verdict: **closed** (no forged-credit/debit, no cross-market movement).

---

## 4. SettleFunds / CloseOpenOrders / InitOpenOrders (checklists #2, #3)

**SettleFunds** (`2262-2335`, `2795-2877`): `owner` must sign and equal `open_orders.owner` via
`load_orders_mut(..., Some(owner), ...)` (`2314-2320` + `194-197`). Vaults must equal the market’s vaults
(`check_coin_vault/check_pc_vault`, `504-517`); wallets must be SPL token accounts of the market mints
(`check_coin_payer/check_pc_payer`, `519-534`) — the *recipient owner* is not constrained, but it is chosen
by the legitimate OO owner for their own free balance. The optional referrer must merely be a pc-mint token
account (`2304-2310`); the OO owner directs their *own* accrued rebates. No path moves another account’s
funds. `send_from_vault` (`1450-1476`) signs only with the vault-signer PDA
(`gen_vault_signer_key(nonce, market)`, `1390-1403`) which is verified against the supplied account
(`1602-1611`) and is unique per market — vaults of other markets cannot be addressed.

**CloseOpenOrders** (`2773-2791`): owner signature required (as above); only closes accounts with no orders
and zero totals (`2438-2452`); lamports go to a caller-chosen destination (owner’s choice); flags are set to
`Closed` (`2789`) so the account cannot be re-initialized or used (`611-619` rejects non-exact flags).

**InitOpenOrders** (`2463-2508`): uninitialized (flags==0) program-owned OO accounts are initialized with
`owner = the signer` (`state.rs:174-189`). For V1 markets the optional authority must be absent
(`None == None`); V2 needs the market’s `open_orders_authority` signer. **Rent-capture primitive:** a zeroed
program-owned OO account with lamports can be initialized by anyone and immediately closed to that person
(`InitOpenOrders` + `CloseOpenOrders` in one tx, or `NewOrderV3` first). On-chain today: **0 zeroed
OpenOrders accounts** (and 0 closed ones), so value = $0. Positive control for the query: 802,133 accounts
with flags=5.

**Authority keys (correcting the premise that GTgd… is a system EOA):** curve test says
`GTgd6NaobHDLSFAh2kG5DTNsL4SBJH42Qq11jpjWCfXA` is **not a valid ed25519 point → off-curve → a PDA**. Its
creation transaction (oldest signature of the address, slot 160,667,156) is an SPL Governance
`CreateRealm`:

```
Program GovER5Lthms3bLBqWub97yVrMmEogzX7xNjdXpPPCVZw invoke [1]
Program log: VERSION:"2.2.5"
Program log: GOVERNANCE-INSTRUCTION: CreateRealm { name: "Serum Community Fork",
  config_args: RealmConfigArgs { use_council_mint: true,
    min_community_weight_to_create_governance: 18446744073709551615,
    community_mint_max_vote_weight_source: SupplyFraction(10000000000), ... } }
Program 11111111111111111111111111111111 invoke [2]
```

It is the realm’s **native treasury PDA**: only an executed proposal in the “Serum Community Fork” realm can
sign for it (`SweepFees` / `DisableMarket`). Note the realm config forbids community governance creation
(`u64::MAX` threshold); the council path (`use_council_mint: true`) is the only potential signer. No sweep
execution was observed in the address’s 5 lifetime mentions. The upgrade authority `8xYs2t…` is likewise an
SPL-Governance-owned account (236 B). Verdict: **P** (governance), effectively dormant/S with current
uncertainty.

---

## 5. SweepFees / DisableMarket / Prune / InitializeMarket (checklists #4, #5, #7)

**SweepFees** (`3357-3390`): signer must be `fee_sweeper::ID` = the DAO treasury PDA above
(`1566-1570`). It moves **only `market.pc_fees_accrued`** to a pc-mint account of the sweeper’s choice and
zeroes the counter; **`market.referrer_rebates_accrued` is never swept** (it leaves the market only when an
OO with rebates settles, or is folded into `pc_fees_accrued` when an OO settles without a referrer,
`2858-2874`). Any unclaimed market-level rebates are stranded (S). No rounding issue: the transferred amount
is the exact u64 counter; a failure reverts the whole tx.

**DisableMarket** (`3357-3364`): requires `disable_authority` = same DAO PDA; only sets the `Disabled` flag.
Zero disabled markets exist on-chain.

**Prune** (`2724-2767`, parser `2510-2567`): requires `market.prune_authority() == Some(signer)`; for every
V1 market `prune_authority()` returns `None` (`137-142`), so **Prune always fails for all 727,164 live
markets**. Zero V2 markets exist anyway. Prune cannot move funds even where enabled: it only removes the
OO’s own book orders and credits that same OO’s free balance (`cancel_leaf_node`, `952-993`, checks
`leaf.owner == open_orders_address`).

**InitializeMarket** (`3392-3519`, parser `1653-1740`): all 5 market-owned containers must be program-owned,
zeroed and padded; vaults must be SPL token accounts whose owner is `create_program_address([market, nonce])`
and have no delegate/close authority (`1700-1724`). This pins each vault to the market via the PDA hash:
pointing a new market at another market’s vault requires a PDA collision (infeasible). Mints are
sanity-checked and must match the vaults. The 5 containers may alias each other, but the result is an
unusable market whose fields point at shared accounts; not exploitable. Verdict: **closed**.

---

## 6. NewOrderV3 / matching / arithmetic (checklist #6)

- Fund locking (`state.rs:3169-3212`): bid locks `max_native_pc_qty_including_fees`, asks lock
  `max_coin_qty * coin_lot_size` (checked mul); deposits are verified to have landed
  (`balance_change == deposit_amount`, `3319-3321`); SPL transfer authority is the signer, so a caller
  cannot pull another user’s tokens as `payer`.
- Fees (`fees.rs:81-119`): `taker_fee = ceil(rate*pc)`, `maker_rebate = floor(rate*pc)`,
  `taker_rate = 2*maker_rate`, `referrer = taker_fee/2`; thus `taker_fee >= Σ maker_rebates + referrer`
  (per-fill floors can only reduce Σ rebates). `net_fees >= 0` always; `pc_deposits_total` never gates
  withdrawals and is write-only (`312/319` plus updates at `2811-2812`, `3185-3209`, `matching:532/850`), so
  even a wrap there is harmless.
- Taker debits/credits are bounded by the amounts locked at order time (`remove_taker_fee`, `new_bid`
  `863-876`; asks `543-590`); maker events debit at most the leaf quantity × price that was locked
  (`matching:450-492`, `766-810`). `credit_locked_*` uses `checked_add` (abort), `unlock_*` asserts
  `free <= total` (`634-667, 2760-3277`). No path can inflate `native_coin_total`/`native_pc_total`.
- Self-trade: `AbortTransaction` reverts; `DecrementTake`/`CancelProvide` release only locked amounts;
  maker rebate + referrer ≈ taker fee, so self-trading is round-trip neutral (no minting).
- **Overflow checks are OFF in the deployed ELF**: the binary contains “index out of bounds” and “called
  `Option::unwrap()`…” panic strings but **zero** “attempt to add/subtract/multiply with overflow” strings;
  the repo’s `[profile.release]` does not enable them (`dex/Cargo.toml`). All unchecked arithmetic sites
  were enumerated; each is either bounded by construction (locked amounts, fee identities) or on the
  write-only deposits counters. The only wrap I could not bound a priori — maker debits vs. locked — is
  invariant-bounded: Σ maker fill pays ≤ original leaf qty × price × pc_lot = locked, including when fills
  and cancels are consumed out of order (§3.4).
- ReplaceOrderByClientId(s) (`1962-1996`, `3327-3355`): account-index map `[0,4,5,1,7,3]` correctly
  selects market,bids,asks,OO,owner,event_q from the NewOrderV3 layout; cancel errors propagate except
  `OrderNotFound` (fixed in `737c4ba`, present in v0.5.10) so no partial state is left behind.

Verdict: **closed** — no value creation, no fund lock/unlock errors reachable by an unprivileged caller.

---

## 7. The v0.5.9 → v0.5.10 fee mismatch (historical, with on-chain scar)

`fees::referrer_rebate` changed from `amount/5` (v0.5.9) to `amount/2` (v0.5.10, `fees.rs:117-119`). The
market accrues the rebate at **match time** (`matching.rs:527-530, 845-848`) but the OpenOrders credits it
by **recomputing from the event’s fee at consume time** (`state.rs:3040-3046`). Any taker-fill event created
before the upgrade and consumed after it credits `fee/2` while the market set aside only `fee/5`; on later
`SettleFunds`, `market.referrer_rebates_accrued -= oo.rebates` (`2873`, unchecked) **wraps**.

On-chain evidence: exactly **one** of 727,161 markets (`DMLqLtQWshKAfDndddk82A8Dwr6K3yvY7S8F8wMS6WH8`) has
`referrer_rebates_accrued = 18446744073709551614 = 2^64 − 2` (the exact signature of a −2 wrap); no other
counter anywhere is near 2^64. The upgrade window closed in Dec 2022; since then producer and consumer use
the same constants, so it is **not reproducible today**. It remains an architectural landmine: any future
rebate-schedule change desynchronizes matching and consume the same way. (No upgrade has occurred —
upgrade authority is governance-held, §4.)

---

## 8. Known-historical-bug sweep / the “Jan-2023 OpenBook vulnerability” rumor (checklist #9)

What I checked:

- **GitHub advisories:** `GET /repos/openbook-dex/program/security-advisories` and
  `…/project-serum/serum-dex/security-advisories` → `[]` (none ever published). OSV/RustSec query for
  `serum_dex` → no advisories.
- **Audits:** OtterSec’s public list contains *Serum v4* (`dex-v4`, different codebase) and *OpenBook v2* —
  **no v1/v3 audit**. Serum v4 findings (rent-exemption, event-queue DoS, unclosed user accounts) target
  v4 code that is not this program; the v1 code already checks rent exemption at init
  (`state.rs:1680-1685`) and rejects closed accounts at load (`611-619`).
- **Upstream history:** fixes present in the deployed build include market-init close-authority check
  (`be1e924`, v0.5.1) and CancelOrdersByClientIds error propagation (`737c4ba`, v0.5.6). No post-freeze fix
  exists in master or in the Raydium fork (`raydium-io/openbook-dex`: only SDK/anchor bumps and
  `traverse_orders`; PR #35/#36 “Zero fees”/“Multi permissioned dex” closed unmerged).
- **The closest documented “January 2023 OpenBook” event is an integration freeze, not a program bug:**
  Raydium’s security docs record that a program update changed account semantics and their AMM crank needed
  a patch. That update is the **v0.5.10 deploy of 2022-12-20** (fee schedule: SRM/MSRM discounts removed,
  4 bps base / 1 bp stable, referrer 1/2 of taker fee — `CHANGELOG.md` 0.5.10; the commit
  `89d2593 “remove flagship market and keep everything at 4bps”`). It broke integrations’ fee
  expectations; it is not a value-extraction vulnerability.
- **Serum v3.1 note (checklist #10):** its deployed ProgramData (`DTxcpNApaMLNfYgwQ99PmpCm8rjS7o1q2YdfzYsrYohB`,
  last deploy slot 146,728,883 ≈ 2022-08-19, matching `737c4ba`’s date) embeds fee sweeper
  `DeqYsmBd9BnrbgUwQjVH4sQWK71dEgE6eoZFw3Rp4ftE` and disable authority `5ZVJgwWxMsqXxRMYHXqMwH2hd4myX5Ef4Au2iUsuNQ7V`
  (both on-curve EOAs; the fee-sweeper account does not exist on-chain → unusable unless funded by a holder
  of that old key; disable authority holds 194.4 SOL, never observed signing). No `Min amount requested not
  met!` literal in the ELF ⇒ the deployed Serum build **predates the Oct-2022 `send_take` implementation**
  (master only); the same V1/V2 permissioned machinery is present but its gating (`prune_authority`,
  `consume_events_authority`) is the same as analysed here. Serum’s SAS/crank gates are equivalent; no
  distinct unprivileged path found.

**Conclusion on the rumor:** not substantiated in any public record for the deployed v0.5.10 build; no
advisory, no fix, no writeup. If it referred to a specific report, it was likely the v0.5.10 fee/account
semantics change (integration-level) or a V2/permissioned-market issue — and **zero V2 markets exist** on
either program’s mainnet deployment, so such issues have no live surface today.

---

## 9. What an attacker can/cannot do (exact)

**Can:**
- Trade, crank `ConsumeEvents` for any V1 market (intended), cancel own orders, settle/close own OpenOrders.
- Initialize their own markets/OO accounts (self-funded; no victim value).
- Capture rent of any **zeroed, funded, program-owned OpenOrders account** (init+close) — primitive is real
  (`state.rs:174-189`, `2769-2791`), but a full-chain scan finds **0** such accounts (and 0 closed ones).
- DoS a market by filling its event queue (liveness only; no fund gain); crank any pending events.

**Cannot:**
- Settle/close/cancel another user’s OpenOrders (owner signature), or redirect their funds.
- Withdraw from any vault except as the OO owner (free balance) or the governance treasury
  (`SweepFees`).
- Prune V1 markets, bypass crank-authority gating, disable markets, sweep fees.
- Craft events: every event’s `owner`/`order_id`/amounts are produced by matching against validated state,
  and consumed only against the account whose address equals `event.owner` on the same market.
- Create value via fee/rounding/overflow paths (bounds above; overflow checks off but no reachable
  invariant-breaking wrap).

**Costs:** all E-U-adjacent operations are rent + tx fees; the only “profit” primitive (zeroed-OO capture)
has no live inventory, so net $0 at measurement slot.

---

## 10. Simulation specs (for the parent, if it wants proof artifacts)

No material E-U path exists to prove on mainnet. Below are the two cheap, precise specs.

### S1 — zeroed-OO rent capture (E-U primitive, $0 live) — local validator / fork, NOT mainnet simulate
Precondition: account `A` owner=`srmq…`, data len 3228, all-zero data, lamports ≥ rent-exempt, funded by a
third party; market `M` any V1 market; attacker keypair `K`.

Tx 1 (init):
- `InitOpenOrders`, data `0x00 0f 00 00 00` (`[version=0][discrim=15 u32 LE]`), accounts:
  0. A `[w]` · 1. K `[signer]` · 2. M `[]` · 3. `SysvarRent111111111111111111111111111111111` `[]`
Tx 2 (close):
- `CloseOpenOrders`, data `0x00 0e 00 00 00`, accounts:
  0. A `[w]` · 1. K `[signer]` · 2. D `[w]` (K) · 3. M `[]`
Expected: A’s lamports move to D; A.data[5..13] = `01 00 00 00 00 00 01 00`? (flags = 0x100 Closed), account
later GC’d. On current mainnet this cannot be simulated because no zeroed OO account exists.

### S2 — authority checks fail without the DAO signer (mainnet `simulateTransaction`, read-only)
- `SweepFees`, data `0x00 08 00 00 00`, accounts: market (e.g. `B2na8Awyd7cpC59iEU43FagJAPLigr3AP3s38KM982bu`),
  its pc vault, `GTgd6NaobHDLSFAh2kG5DTNsL4SBJH42Qq11jpjWCfXA` (READONLY, not signer), fee receiver, vault
  signer PDA, SPL Token program → expect failure at `state.rs:1566-1570` (WrongSigner).
- `Prune`, data `0x00 10 00 00 00` + `ff ff`, accounts market/bids/asks/prune-auth(signer)/OO/OO-owner/event_q
  → any V1 market fails at `state.rs:2540` (`None != Some`).

### S3 — historical mismatch replay (optional, archival fork at slot 168,006,653)
Find a v0.5.9-created taker Fill event still queued at the upgrade slot, consume it post-upgrade, settle the
taker OO, and observe `market.referrer_rebates_accrued` wrap by `fee/2 − fee/5` (the `DMLq…` market with
`2^64−2` is the surviving scar). Requires `--slot` archival RPC; not needed for live risk.

---

## 11. Open items / uncertainty

1. **Realm liveness:** whether the “Serum Community Fork” realm has a live council governance (and thus a
   real P path to sweep fees / disable markets / upgrade) was not fully established — 5 lifetime treasury
   mentions, no observed sweep. Governance-gated either way; not E-U.
2. **Serum program flag census:** public RPC refused `getProgramAccounts` for the Serum program
   (`KEY_EXCLUDED_FROM_SECONDARY_INDEX`); OpenBook’s counts are confirmed. Parent’s Bitquery/Dune data can
   close this.
3. Historical claim “500k–1M SOL in dead market rent” is not supported for *market accounts alone*
   (my spot sum over ~725k market accounts = **3,001 SOL**); the parent’s ~672,800 SOL figure must include
   the four larger market-adjacent containers (request/event queues, bids/asks) and OpenOrders.

## 12. Files / evidence
- `analysis/onchain_spot_checks.json` — program/authority/flag counts + OpenOrders census at slot 453,191,278.
- `analysis/treasury_sigs.json` — 5 lifetime mentions of the DAO treasury PDA (incl. the CreateRealm tx sig).
- `analysis/source_audit_evidence.json` — compact machine-readable evidence for every claim above.
- ProgramData ELFs were fetched and analysed during the audit (embedded security.txt → `546e5fe`/`v0.5.10`;
  embedded authority key bytes; overflow-string analysis) but not persisted here. Refetch commands:
  `python3 analysis/onchain_spot_checks.py` (needs `analysis/rpc.py`) and
  `getAccountInfo 9K32VSPTg4PHY7Hb2QZq26e5CujwMgt8Bqq4kJrp5zp8` / `DTxcpNApaMLNfYgwQ99PmpCm8rjS7o1q2YdfzYsrYohB`.
- Source refs: `/tmp/opencode/ob-program` @ `v0.5.10` (`546e5fe`), `/tmp/opencode/serum-dex` @ `92992b3`.
