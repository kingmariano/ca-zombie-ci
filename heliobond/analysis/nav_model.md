# Heliobond investment_vault — NAV double-count model (analysis)

Read-only research artifact. All amounts below are USDC with 7 decimals unless
noted. References are to `Heliobond/contracts` (Soroban, Stellar).

## 1. The code, before and after the fix

**Vulnerable version** (last pre-fix main, commit `c79daec1`, 2026-09-26 18:07 +0100):

```rust
// investment_vault/src/lib.rs
fn read_total_assets(env: &Env) -> i128 {
    liquid_usdc(env) + investments + expected      // queue NOT subtracted
}
```

`withdraw(from, shares, min_out)` when `usdc_returned > liquid`:

1. `Base::burn(from, shares)` — shares destroyed immediately;
2. writes `QueuedClaim { from, usdc_owed: usdc_returned }` to `QueueEntry(tail)`;
3. returns 0.

`convert_to_assets(shares) = shares * total_assets() / total_supply()` — so after
the burn, the **same NAV is divided by a smaller supply**: the price of every
remaining share jumps by roughly `usdc_owed / remaining_supply`. The USDC owed to
the queue is still physically in the vault, but it is also counted as backing the
remaining shares.

**Fixed version** (fix `e99b4cc`, merged by PR #647 on 2026-09-26 17:31 UTC;
present on current main `b233e10`):

```rust
liquid_usdc(env) + investments + expected - queued_liabilities(env)
```

with `VaultKey::QueuedLiabilities` incremented on enqueue and decremented on
`claim()` payout. The queue is now a NAV liability.

## 2. Exact attacker model (buggy deployment)

Notation: `TA = L + I + E` (liquid + investments + expected returns), `S` supply,
victim holds `s_v`, attacker holds `s_a`, remaining supply `S_r = S - s_v`.

Preconditions (all must hold live):

1. **A victim queues a claim.** Requires a holder to withdraw while
   `s_v·TA/S > L` and utilisation `I/TA < 50%` (at ≥50% the graduated
   withdrawal-tier cap rejects the withdrawal before the queue branch).
   The queue is therefore only reachable when enough capital is deployed into
   projects (`I`) to make the victim's redemption illiquid.
2. **The attacker holds HBS shares** (`s_a > 0`). HBS is transferable (SEP-41),
   but no secondary market/DEX listing was found; the practical acquisition
   path is depositing before the queue forms.
3. **Liquid USDC is available** to pay the attacker immediately
   (`TA·s_a/S_r ≤ L` after capping the redemption; otherwise the attacker's own
   redemption queues behind the victim and nets nothing extra).

Buggy payout for burning `s_a` shares:
`pay = min(TA·s_a/S_r, L)`.
Fair (post-fix) value of the same shares: `fair = s_a·(TA - Q)/S_r`, where
`Q = s_v·TA/S` is the queued claim.

**Gross extraction** `= min(TA·s_a/S_r, L) - s_a·(TA-Q)/S_r`.

Special case `s_a = S_r` (attacker is the only remaining holder) and `L < TA`:

```
extraction = L - (TA - Q) = Q - I - E
```

so extraction is capped by the queued claim minus the value of what remains
invested; with a small attacker stake (`s_a → 0`), `L ≈ TA` and
**extraction approaches the full queued claim `Q`, bounded by the liquid
buffer `L`**.

Net attacker cash profit (what the PoC measures) `= pay - deposit_a`; it is
funded one-for-one by the queued claimant's shortfall
`= Q - (assets left when the attacker is done)`.

Second, smaller victim class: **new depositors**. While the queue is open the
share price is inflated, so `deposit()` mints too few shares and transfers value
to existing shareholders. `deposit` mispricing loss ≈
`D·Q/(TA_buggy)` per deposit `D` (first order).

Self-queue is not profitable: if the attacker queues their own claim and then
redeems with a second account, the overpayment to the second account is exactly
the shortfall of the first account's claim (zero-sum, minus their own fair
share). The attack needs a **third-party** queued claim.

## 3. Deterministic PoC numbers (see poc/poc_vulnerable.rs, run in CI)

Setup: victim deposits 40,000; attacker deposits 10,000; admin deploys 15,000
into a project (30% utilisation); victim then withdraws everything.

| Quantity | Value (USDC) | Notes |
|---|---|---|
| Victim shares | 39,800.00 | 0.5% insurance premium retained in vault |
| Attacker shares | 9,900.25 | |
| TA before queue | 50,000.00 | liquid 35,000 + investments 15,000 |
| Victim claim `Q` | 40,040.04 | queued; shares burned |
| TA after queue (buggy) | 50,000.00 | **unchanged — the bug** |
| TA after queue (fixed) | 9,959.96 | `TA - Q` |
| Attacker max immediately-payable burn | 6,930.175 shares | value = all liquid 35,000.00 |
| Attacker payout | 35,000.00 | drains the queue's liquid |
| Fair value of those shares | 6,971.97 | post-fix pricing |
| Gross diversion on the burned shares | **28,028.03** | paid − fair |
| Attacker net cash profit vs deposit | **25,000.00** | |
| TA after attack | 15,000.00 | investments only |
| Queued liabilities | 40,040.04 | **TA < Q → insolvent** |
| `claim()` payout after attack | 0.00 | liquid drained; FIFO strict |
| Victim shortfall | **25,040.04** | recoverable only if the project repays |

Fixed control (same scenario, current main): `TA_after_queue = TA_before - Q`;
the attacker's full redemption pays exactly the fair NAV (9,959.96); `TA_final
= 40,040.04 ≥ Q` — solvent.

## 4. Residual/latent issues noted (not live E-U)

1. **TTL/archival of `QueuedLiabilities`.** The queue storage entries
   (`QueueEntry`, `QueueTail`, `QueuedLiabilities`) are written without an
   explicit `extend_ttl` (only `TotalDeposited` and one other key are extended).
   A dormant queue could see the liabilities entry archived while queue entries
   are kept alive (anyone can `extendFootprintTtl`), silently re-inflating NAV.
   Requires weeks of dormancy plus state archival — latent, not live.
2. **ERC-4626 donation/inflation.** `deposit` uses integer share math with
   7-decimal USDC and a 100 USDC minimum. Zeroing a victim's shares requires
   donating `> V_units·S_units` base units — e.g. stealing a 1,000 USDC deposit
   needs ~$995B of donated liquidity. Not practical; documented as a negative.
3. **Repayment/settlement paths** (`repay_principal`, `settle_project`) keep NAV
   consistent (liquid in = investment out; impairment reduces NAV). Admin-gated.
