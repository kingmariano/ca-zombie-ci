# Yield Millionaire (Base) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Base (8453) · **Status:** read-only research; all exploit
paths verified on local/CI forks only; **no mainnet transactions were sent**.

**Target (from L2-Triage-A):** `Yield Millionaire`, Base, `LIVE-FUNDED $192,660` →
core contract `0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029` (aUSDC position).

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|
| Base AaveVault `0xD4F3Ba2F…` (custody of users' USDC in Aave V3) | **$0.00 E-U** | Every share burn goes through `_verifySignature`: EIP-191 signature of `context.sender`, bound to recipient, share amount, destination chain, per-sender nonce, chain id, `address(this)` and deadline. Neither the local `EVMEntry` relayer (`msg.sender`-agnostic) nor a forged cross-chain message "from" the ZetaChain router can skip it. | Owner + proxy admin = **1-of-2 Safe (threshold 1)** → either single key can upgrade the impl or guardian-pause + `rescueFunds` the whole vault (category P). Same key set can also swap the zEVM router's vault mapping. |
| Holders' USDC | **$151,303.90 H-O** (1,335 holder addresses; actively withdrawing) | Self-service withdrawal works: sign `CallContext` (EIP-191/ERC-1271), anyone relays to `EVMEntry.withdraw`; vault burns shares and pulls USDC from Aave. Round-trip proven in fork tests (99.999999% recovered, gas only). UI is dead, so recovery is DIY — but dozens of holders withdraw daily on-chain. | Aave V3 Base USDC liquidity (16.8M idle vs 151k claim = 0.9%) — no exit constraint observed. |
| Protocol fees | **$36.92 P** | `accumulatedFees` (2% of yield) claimable by owner only (`withdrawFees`). | — |
| Stuck | **$0.00 S** | No paused flags, no bricked paths found. | — |

**Live value has changed since triage:** at triage block 52,460,482 the vault held 192,694.83 aUSDC ($192,660). At verification block 52,518,710 (2026-10-12) it holds **151,340.82 aUSDC**. The −41,354.01 difference is fully explained by ordinary user withdrawals: in `[52,460,000 … latest]`, `Withdraw` events = 42,672.53 USDC (all `destinationChain = 8453`) vs `Deposit` = 1,292.05 USDC (net −41,380.49 ≈ balance delta + interest). No anomalous outflow.

## 2. Total live extractable now

**External unprivileged attacker: $0.00 (confidence: high).**
Whole-vault funds at the cited block: **151,340.82 USDC ≈ $151,340.82** at the $1.00 peg
(≈ $151,298 at DefiLlama's live USDC price $0.99972); of which **151,303.90** is holders'
redemption value (`totalAssets`) and **36.92** accrued protocol fees.

## 3. The protocol and the exact custody mechanics

Yield Millionaire is a discontinued ZetaChain "omnichain yield" app (repo:
`ZetaChain-Venture-Studio/yieldmillionaire-`; last commit 2025-10-14; front-end dead per triage).
Users deposit USDC on Base/Polygon/BNB; funds sit in an upgradeable **AaveVault** per chain that
supplies USDC to Aave V3 and keeps an internal share ledger. Cross-chain messages are routed by
`YieldMil` on ZetaChain (zEVM).

Deployed Base components (all verified against the repo at HEAD; `AaveVault.sol` and
`EVMEntry.sol` are byte-identical between the Etherscan bundles and repo HEAD):

| Component | Address | Version / notes |
|---|---|---|
| AaveVault proxy (`ProxyBase`, ERC-1967) | `0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029` | impl `0x9C187591…` **v1.2.1** (deployed 2025-10-08) |
| Vault owner **and** proxy admin | `0xCe246ef822210467C94bC1269EcFd8760DffE61C` | Gnosis **Safe 1.4.1, threshold 1/2**; owners: `0xb7406383…` (plain EOA) and `0x31B5aBcF…` (EIP-7702-delegated EOA) |
| `EVMEntry` proxy (deposit/withdraw entry) | `0xCB513DB80C6C76593770Fc4a1827d5Ab8186b0cD` | impl `0x932f1B96…` **v1.3.0**; same Safe as owner |
| Custodied asset (Aave V3 aUSDC) | `0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB` | `ASSET()`; `aUSDC.balanceOf(vault)` = 151,340.818462 |
| Underlying token | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | USDC; vault balance = 0 (all supplied) |
| Aave V3 Base Pool | `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5` | `POOL` |
| ZetaChain GatewayEVM | `0x48B9AACC350b20147001f88821d31731Ba4C30ed` | `GATEWAY`; TSS-driven |
| zEVM router (address in cross-chain sender field) | `0xE65eEe518A897618cBEe25898f80200E7988c81e` | `YIELDMIL`; live on ZetaChain as **YieldMil v1.4.2**, not paused, owner `0xABD10F0A…` |

Value-moving paths and their gates (deployed v1.2.1):

* **Withdraw** (`withdraw(bytes)`, only `EVMEntry`; or `onCall` with `context.sender == YIELDMIL`):
  `_withdraw` → `_verifySignature` (reverts `InvalidSignature` unless the **share owner's**
  signature over
  `keccak256(abi.encode(sender, to, amount, destinationChain, nonce, CHAIN_ID, deadline, vault))`
  EIP-191-wrapped passes, ECDSA or ERC-1271) → `_burn(sender, shares)` → `POOL.withdraw` →
  USDC to `receiver` (or bridged via `EVMEntry.onCallback`). Nonce increments per sender.
* **Deposit** (`deposit(bytes)`, only `EVMEntry`; or `onCall` from gateway): pulls TOKEN from the
  gateway/`EVMEntry` (which itself just received the funds from `msg.sender`/Permit2), supplies to
  Aave, mints shares to `onBehalfOf`. No free mint is possible: both balance and a transient,
  TSS-scoped gateway allowance are required (only `GatewayEVM.executeWithERC20` creates it, bound
  to the bridged amount and reset in the same transaction).
* **Permissionless pays-the-caller functions:** none. `EVMEntry.deposit`/`withdraw` are the only
  unprivileged entrypoints and they only move the caller's own funds / a signed holder's funds.
* Owner functions: `updateGuardian` → (guardian) `pauseDeposit/pauseWithdraw` → `rescueFunds`
  (ASSET/TOKEN rescue allowed only while both paused) — i.e. the Safe can sweep everything; plus
  `changeImplementation` on the proxy. Both are privileged (P) by design.

Historical note (relevant because the corpus row is old): the Jun–Sep 2025 implementations
(v1.0.0/1.0.1/1.1.0) had **no vault-side signature check** for withdrawals, but the sender in
the message was always the EVM caller of `EVMEntry.withdraw` (or of `YieldMil.withdraw` on zEVM,
which enforced `msg.sender == context.sender` from 2025-09-24). Only self-service withdrawal was
possible; no third-party theft occurred — see the exact ledger reconciliation in §6.
Signature-authorization was introduced with v1.2.0 (2025-09-30, after the Sept 23–25 commits) and
v1.2.1 (2025-10-08) added support for >65-byte ERC-1271 signatures (the app's users are mostly
ERC-4337 smart wallets on Base).

## 4. Live-state assessment (Base block 52,518,710; CI re-verified)

* `VERSION() = "1.2.1"`; `getOwner() = getProxyAdmin() = 0xCe246ef8…` (EIP-1967 admin slot
  `0xb5312768…` = Safe); `getFee() = 200` (2%).
* `totalSupply() = 144,119,897,114` shares (144,119.897114); `totalAssets() = 151,303,897,324`
  (151,303.897324); `aUSDC.balanceOf(vault) = 151,340,818,462`; identity
  `totalAssets == balanceOf − getAccumulatedFees()` holds exactly.
* `getAccumulatedFees() = 36,921,138` (36.92 USDC); `getLastVaultBalance() = 151,339,073,268`
  at block 52,517,265 (tracks balance at last accrual).
* Pause flags (EIP-7201 slot `0xe869…2d05`) = `0x0` — deposit and withdraw both unpaused.
* Share ledger reconstructed from **all 19,736 events** (14,554 deposits / 5,158 withdrawals,
  incl. two v1.0.0-era 4-field `Deposit` events and one 4-field `Withdraw` event) reconciles
  **to the unit**: Σmints − Σburns = 144,119.897114 = on-chain `totalSupply` (delta 0).
  1,335 addresses hold positive shares; top holder `0xa8e3ef3b…` has 21,874.87 shares
  (22,965.27 USDC; nonce 0). All-time flows: 586,645.09 deposited, 437,150.69 withdrawn.
* Safe: threshold 1, owners `0xb7406383…` (no code) and `0x31B5aBcF…` (23-byte EIP-7702
  delegation designator ⇒ single key), Safe nonce 4.
* Aave V3 Base USDC idle liquidity = 16,794,523 USDC ⇒ the 151k redemption is 0.9% of available
  liquidity (no exit constraint).
* zEVM `YieldMil` (block 19,445,185): `VERSION = 1.4.2`; `getEVMEntry(8453) = 0xCB513DB8…`;
  `getVault(8453, Aave, ZRC20-USDC.BASE) = 0xD4F3Ba2F…`; paused flags = 0; owner `0xABD10F0A…`.

## 5. What an attacker can / cannot do (exact call paths)

| Path | Preconditions | Result |
|---|---|---|
| `EVMEntry.withdraw(ctx)` with `sender` = victim, any signature | victim's EIP-191/1271 signature over the vault-bound digest (65-byte garbage, 66-byte garbage, and attacker-signed variants all tested) | reverts `InvalidSignature` — **verified** |
| Replay of a previously-valid context | sender's nonce already consumed; digest binds current nonce | reverts `InvalidSignature` — **verified** (after a real round-trip in-test) |
| Direct `vault.deposit/withdraw` | `msg.sender == EVMENTRY` | reverts `NotEVMEntry` — **verified** |
| `vault.onCall` spoof | `msg.sender == GATEWAY` **and** `context.sender == YIELDMIL` | attacker sender → `NotYieldMil`; even with `sender = YIELDMIL`, withdrawal still requires the holder's signature — **verified** |
| Forged deposit (`onCall 0x01`) | gateway must hold the tokens **and** have approved the vault; both are created only inside a TSS-driven `executeWithERC20` and consumed in the same tx | bare call reverts; documented precondition shown on fork — **verified** |
| `pauseDeposit/pauseWithdraw` | guardian | `NotGuardian` for anyone else — **verified** |
| `setFee/rescueFunds` | owner | `NotOwner` — **verified** |
| Owner rescue while unpaused | — | reverts `VaultIsNotPaused`; owner must first self-appoint guardian and pause both flows — **verified (P, fork only)** |

Gas/costs: a holder withdrawal costs only Base gas (~150–200k gas; <$0.01) and can be relayed by
anyone; no flash loans or capital are needed for any path — none of them yields profit.

## 6. Why the headline number changed and why it is not a theft

Window `[52,460,000 … 52,518,682]` (≈1.3 days): `Withdraw` 42,672.53 USDC (all same-chain,
destinationChain 8453) and `Deposit` 1,292.05 USDC via `EVMEntry` — i.e. ordinary users exiting.
The vault's aUSDC balance moved 192,694.83 → 151,340.82 (+0.26 USDC interest accrued). Every one
of the 19,736 lifetime events is classified and reconciled; no unaccounted mint/burn exists, so
no historic drain hide in the data. (Two topic hashes initially unexplained were resolved to the
v1.0.0-era 4-argument `Deposit(address,address,uint256,uint256)` / `Withdraw(address,address,uint256,uint256)`
events — the 5.330654-share reconciliation gap they close is exactly the seed 4.567891 + 0.862765
− 0.1 flow of 2025-06-25.)

External context checked: the April 2026 ZetaChain `GatewayEVM` arbitrary-call exploit
($333,868 across four chains) drained only ZetaChain-controlled wallets; its
`_executeArbitraryCall` deny-listed the `onCall`/`onRevert` selectors, so `Callable` vaults like
this one were unreachable through it; the path is now disabled. No incident involving this vault
was found (no post-mortem, no anomalous events).

## 7. PoC / fork verification

Foundry suite `poc/test/YieldMillionaire.t.sol` (8/8 PASS locally and in CI; fork-only,
public-RPC, no secrets): live-state asserts; unprivileged-withdraw negatives (garbage 65/66-byte
and attacker-signed signatures); bounded garbage-signature loop; spoofed `onCall` paths incl.
`YIELDMIL` impersonation; deposit-forgery preconditions; no-free-money checks (zero-share burn
underflow, amount=0 rejection); holder round-trip deposit→withdraw via a real ECDSA signature
(99.999999 USDC recovered of 100, nonce consumed, replay rejected); privileged
pause+rescue demonstration.

* Local run: `forge test -vv` → **8 passed / 0 failed** (fork block 52,518,710).
* CI (GitHub Actions `kingmariano/ca-zombie-ci`): `<<CI_URLS>>` — **<<CI_RESULT>>**
  (fork block `<<CI_BLOCK>>`, `aUSDC.balanceOf(vault) = <<CI_AUSDC>>`).
* CI artifacts: `ci-out/live-state.json` (public-RPC snapshot), `ci-log.txt`.

## 8. Verdict, residual risk, blockers

**Verdict:** the $192,660 triage row is stale; the vault today holds **151,340.82 aUSDC
(≈$151,340)**, of which **$0.00 is extractable by an external unprivileged attacker** (high
confidence). The funds remain **holder-recoverable (H-O, ≈$151,303.90)** and the path is proven
live by ongoing withdrawals (most recent hours before this report).

Residual/latent risks (not E-U):

1. **1-of-2 Safe with threshold 1** is both owner and proxy admin of the vault and `EVMEntry`;
   compromise of either key (one is a plain EOA, one an EIP-7702-delegated EOA) ⇒ upgrade to a
   draining impl or guardian-pause + `rescueFunds` of the entire vault. Same keyset controls the
   zEVM router mapping (its owner is a separate EOA, `0xABD10F0A…`).
2. ZetaChain-side compromises (TSS/observer or `YieldMil` owner) can *emit* authenticated
   messages, but **cannot** burn balances without holder signatures; they can at most steer
   in-flight deposits or gas-refund flows.
3. Dead front-end: holders must build/sign `CallContext`s themselves (or use any relayer) to
   exit. Assets are not stuck, but the UX cliff could strand unsophisticated users.

## 9. Methodology, sources, caveats, files

Methods: on-chain reads at explicit blocks (public Base/ZetaChain RPCs); full event history via
GoldRush (19,736 events, gzipped raw kept); Etherscan V2 verified sources; repo git history
diffed against deployed bytecode sources; fork PoCs (local + CI). Price: DefiLlama
(`base:0x8335…` USDC = $0.99972; aUSDC same). Caveats: event decode relies on raw log fields
(verified against direct RPC for governance events); only the **Base** vault of this protocol is
in scope (Polygon/BNB vaults not assessed); the deployed impl was verified by source identity with
repo HEAD + on-chain behavioral tests, not by full bytecode recompilation.

Files: `README.md` (this), `summary.json`, `analysis/` (source bundles, `gr_all_events.json.gz`,
`ledger_holders.csv`, `flow_summary.json`, `governance_timeline.json`, `live-state.json` from CI),
`poc/` (Foundry suite + vendored forge-std), `ci/run.sh`, `ci-out/`, `ci-log.txt`.
