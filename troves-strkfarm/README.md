# C2-51 — Troves / STRKFarm retired vaults (Starknet)

**Date:** 2026-10-10 · **Chain:** Starknet mainnet · **Status:** read-only research; no transactions signed or sent;
all proofs via keyless public RPC reads and `starknet_simulateTransactions` (SKIP_VALIDATE).

**Verdict in one line:** the ~$24.9k "forgotten live vaults" are real and live, but **no external unprivileged
attacker can extract any of it — E-U = $0.00**. The funds are the *unclaimed user balances* of the zkLend
recovery distributions (**H-O ≈ $24,966**, self-service via `withdraw_zklend`), plus owner upgrade power over
the same funds (P, no timelock) and worthless post-hack zkLend zTokens (latent only).

---

## 1. TL;DR

| Target | Live value | Unprivileged extractable | Why closed / open | Latent risk |
|---|---|---|---|---|
| **AutoCompounding STRK vault** `0x00541681…838ea` | 1,820.35 STRK | **$0.00** | `withdraw_zklend` pays the **caller's own stored position, exactly once** (`Zklend::Already claimed` on replay); all admin fns revert `Caller is not the owner` | owner `upgrade` (Braavos single-key); future zkLend recovery distributions |
| **AutoCompounding USDC vault** `0x016912b2…2694f` | 44.70 USDC + dust | **$0.00** | same class/gates | same |
| **Sensei STRK vault** `0x020d5fc4…2cea6` | 33,042.74 STRK | **$0.00** | claim is caller-based + replay-blocked; `withdraw/rebalance/harvest` paused; `swap/unwind_dapp2` owner-only | same + Nostra leg open (owner-only unwind) |
| **Sensei USDC vault** `0x04937b58…ae422` | 15,439.49 USDC | **$0.00** | same | same |
| **Sensei ETH vault** `0x9d23d9b1…df250` | 2.3147 ETH | **$0.00** | same | same |
| **Sensei ETH-XL vault** `0x9140757f…eed9` | 0.3532 ETH + 235.85 USDC | **$0.00** | same | same |
| **Total** | **≈ $24,966** (USDC 15,720.45 + ETH 2.6680 + STRK 34,878.69) | **$0.00** | — | — |

**Total live extractable by an external unprivileged attacker now: $0.00 (confidence: high).**
**Total user-recoverable (H-O): $24,966.19** (DefiLlama prices 2026-10-10: ETH $2,492.71, STRK $0.0745265, USDC $0.99973).

---

## 2. The finding and the mechanism

The lead comes from DefiLlama: `projects/strkfarm/index.js` (Troves = renamed STRKFarm; protocol id 4952,
`previousNames: ["STRKFarm"]`) hard-codes the TVL of two strategy families to zero:

```js
// vaults under this catagory are retired so tvl balances are not considered
const retiredBalance = 0
```

- `computeAutoCompoundingTVL` → `STRATEGIES.AutoCompounding` (2 vaults)
- `computeSenseiTVL` → `STRATEGIES.Sensei` (4 vaults: STRK, USDC, ETH, ETH-XL)

The Braavos `starknet-meta` registry tags the same contracts *deprecated*. The six vaults are **not**
decommissioned: they still hold **$24,966 of recovered funds** belonging to users, and their
zkLend-recovery claim functions are live. That is the whole finding — a stale-adapter/deprecation gap,
**not** a live exploit path.

On-chain retirement timeline (vault `Upgraded` events): the vaults were upgraded to the recovery class at
blocks **1,242,433 / 1,243,009** and again at **1,273,089–1,273,097** (≈ 2025-03-28, when the zkLend recovery
claims opened). Classes today:

| Vault | Class hash | Owner | Paused |
|---|---|---|---|
| AutoCompounding STRK/USDC | `0xb9901f375d6a56d374c3334440148f55839e865d1151e4d3c297cd9498c166` | `0x3495dd1e…62e8d0` | no (no pause fn) |
| Sensei STRK/USDC/ETH | `0x24b350501cd8e28a29c6b3faa986e124f3b03ac93a8cfc7c511d820949e96a3` | `0x55d39827…c0e16e` | **yes** |
| Sensei ETH-XL | `0x610d2859724fa01a6a19efdc2212c8bdd8801aa8ac0c245b42f73d67550fdbe` | `0x55d39827…c0e16e` | **yes** |

Both owners are Braavos smart accounts (class `0x36078334…527f`) — single-owner, no multisig, no timelock.

## 3. Live-state assessment (blocks 16,150,656 → 16,154,146; CI re-run 16,154,131–16,154,146)

Liquid balances held by the vault contracts (raw token balances; `balanceOf(vault)`):

| Vault | STRK | USDC (bridged) | ETH | zkLend zTokens (face) |
|---|---:|---:|---:|---|
| AutoCompounding STRK | 1,820.347 | 0.002 | 0.0000007 | 13,333.42 zSTRK |
| AutoCompounding USDC | 0.101 | 44.700 | 0.0000016 | 7,244.88 zUSDC |
| Sensei STRK | 33,042.740 | — | 0.0000151 | 318,231.51 zSTRK |
| Sensei USDC | 6.142 | 15,439.492 | 0.0001337 | 1,003,975.35 zUSDC |
| Sensei ETH | 8.703 | 0.404 | 2.314723 | 615.31 zETH |
| Sensei ETH-XL | 0.653 | 235.852 | 0.353175 | 104,515.41 zUSDC |
| **Total** | **34,878.686** | **15,720.450** | **2.668049** | 331,565.68 zSTRK / 1,115,739.03 zUSDC / 615.31 zETH |

zkLend-recovery batch registry (`get_zklend_amount(batch)`), batch 1 on all six vaults, batch 2 on the four
Sensei vaults (tokens/amounts raw in `ci-out/proofs.json`; e.g. Sensei STRK b1 = 15,323.93 STRK, b2 = 2,273.13 STRK;
Sensei USDC b1 = 3,270.26, b2 = 2,646.64; Sensei ETH b1 = 0.2161, b2 = 0.9732; Sensei ETH-XL b1 = 67.50, b2 = 168.35;
AC STRK b1 = 1,820.30; AC USDC b1 = 44.695).

## 4. What an attacker can / cannot do (exact call paths)

Every value-moving entry point on the six vaults was probed live. Results (all with **unprivileged callers**;
`starknet_call` with caller = 0 and `starknet_simulateTransactions` from real non-owner accounts):

| Function | Gate proven on-chain | Evidence |
|---|---|---|
| `withdraw_zklend(batch_id, receiver)` | **Caller's own stored position only** — a caller with no position gets nothing (no token transfer in trace); receiver's position is *not* paid when the caller has none (receiver-basis test → no transfer); pays **exactly** the stored `zklend_position` amount; one-time per batch | `single_claim_S_STRK_AC_owner` → transfer 826,786,388,187,987 STRK (== `zklend_position`) ; `single_claim_S_USDC_AC_owner` → 2,368 USDC; `double_claim` → `Zklend::Already claimed` |
| `withdraw_nostra(receiver)` | caller-position based; no transfer for non-holder; holder test transferred nothing (position already 0 / no claim) | sims `withdraw_nostra_*` |
| `claim_zklend`, `set_batch_amount`, `transfer`, `register_zklend`, `swap`, `unwind_dapp2`, `set_settings`, `upgrade`, `pause`/`unpause` | **owner-only** | revert `Caller is not the owner` (decoded from hex `0x43616c6c6572…6f776e6572`) |
| `withdraw`, `rebalance`, `harvest` (Sensei) | **paused** (`is_paused()=1` on all four) | revert `Pausable: paused` |
| `harvest` (AutoCompounding) | permissionless but **dead**: Ekubo distributor has no claim for the vaults (`/claims/<vault>` = `[]`) | revert `Removed` at the claim step, before any swap |
| `locked`, `deposit`, ERC-4626 fns | not exposed on the retired class / position-gated | class ABI (17 / 57 entry points) + probes |

So the only live money path is a user withdrawing **their own** recovery share once. An attacker with zero
position extracts $0; there is no third-party claim, no replay, no owner-check bypass, no unpause, no
swap-route abuse reachable today.

## 5. PoC / verification

- **CI (GitHub Actions, public repo):** two runs, both **success** —
  https://github.com/kingmariano/ca-zombie-ci/actions/runs/38017926416 (first) and
  https://github.com/kingmariano/ca-zombie-ci/actions/runs/38018391041 (final, clean sync)
  (workflow `poc.yml`, branch `troves-strkfarm`; artifacts `result-troves-strkfarm`:
  `ci-out/proofs.json`, `ci-out/PROOFS.md`, `ci-out/run_stdout.txt`).
- **Consolidated proof suite:** `analysis/ci_proofs.py` (also run locally). 18 simulations — 5 SUCCESS
  (all showing exact/no transfers as expected), 13 REVERTED with decoded gates; 0 SIM_ERROR in CI.
  Plus 6 vaults × static `starknet_call` probes (caller=0).
- **Key simulated numbers:** non-holder `withdraw_zklend` → SUCCESS, 0 transfers (all vault families);
  receiver-basis → SUCCESS, 0 transfers; self-claim → exact amounts (0.000826786 STRK, 0.002368 USDC);
  double-claim → `Zklend::Already claimed`.
- **Static probes:** `withdraw_zklend` succeeds from caller 0x0; `claim_zklend`/`upgrade`/`set_batch_amount`/
  `transfer`/`register_zklend` revert; `unpause` reverts `Caller is not the owner`.
- **CI block range:** 16,154,131–16,154,146 · **local block range:** 16,150,656–16,154,023.

## 6. Verdict and residual / latent risk

- **E-U: $0.00 (high confidence).** No external unprivileged extraction path exists today.
- **H-O: $24,966.19.** Each recorded claimant can withdraw their exact share once via
  `withdraw_zklend(1, own_address)` (and `withdraw_nostra` for the Nostra leg). This works even while the
  Sensei vaults are paused. Unclaimed balances simply sit in the vaults.
- **P: owner upgrade power (same $24.9k).** Both owners are single-owner Braavos accounts; `upgrade` is
  untimelocked and could change vault logic/sweep balances. No evidence of misuse; key-compromise risk only.
- **Latent:** (a) zTokens held (331.6k zSTRK / 1.12M zUSDC / 615 zETH) are the original hacked zkLend
  positions — no redemption path today; any future zkLend recovery distribution would flow through the same
  owner-register + user-withdraw pipeline. (b) AC-vault `harvest` is permissionless and takes a caller-supplied
  Avnu swap route; it is dead today (`Removed`), but if a new Ekubo claim is ever allocated to these vaults the
  swap path re-arms — the newer strkfarm code guards `beneficiary == vault` + token/amount checks, the old
  deployed class's guard could not be exercised (no valid claim). (c) The Sensei delta-neutral positions still
  carry open Nostra legs (`get_nostra_amount`: S_USDC 9,522.31, S_STRK 15,444.99, S_ETH 1.1253, S_ETH-XL
  0.3532 in receipt units); unwinding is owner-only (`unwind_dapp2`) and not counted in the $24.97k.

## 7. Methodology & sources; caveats

- Keyless public Starknet RPCs: `starknet-rpc.publicnode.com`, `api.cartridge.gg/x/starknet/mainnet`;
  DefiLlama prices + adapter source; Braavos `starknet-meta`; trovesfi GitHub (frontend/SDK ABIs); class ABIs
  via `starknet_getClass`; `starknet_getEvents` for the retirement timeline; Foundry not applicable (Cairo).
- Caveat 1: vault source is not public; gates were proven **behaviourally** by simulation/trace (strong:
  exact transfers, decoded revert strings), not by reading Cairo source. The position→payout formula itself
  (share × batch) was verified only through exact-amount transfers.
- Caveat 2: funds are point-in-time (blocks recorded); zToken face values are not valued; the Nostra legs are
  not included in the H-O total.
- No transactions were signed or sent; no keys are used by any script; all endpoints keyless.

## 8. Files index

- `README.md` — this report
- `summary.json` — machine-readable summary
- `analysis/ci_proofs.py` — consolidated read-only proof suite (state, claims, gates, simulations)
- `analysis/rpc.py` — keyless Starknet RPC helper (keccak selectors, no deps)
- `analysis/read_state.py`, `read_claims.py`, `probe_access.py`, `simulate_*.py` — incremental probes
- `analysis/adapter_*.js` — DefiLlama strkfarm adapter sources (retiredBalance=0 evidence)
- `analysis/braavos_troves_metadata.json` — "deprecated" vault registry
- `analysis/live_state_raw.json`, `live_claims.json`, `access_probe_caller0.json`, `sim_*.json` — local raw outputs
- `analysis/events_retirement.json` — upgrade-event timeline
- `ci/run.sh` — CI job; `ci-out/` — CI proof outputs; `ci-log.txt` / `ci-artifacts/` — CI run + artifacts
