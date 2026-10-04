# H-24 ExinPool — live-state analysis (read-only)

**Date:** 2026-10-04 · **Chain:** Mixin Network (+ Ethereum/Polkadot/Solana/Axie node accounts)
**Status:** read-only; no transactions signed or sent; no secrets used.
**Parent deliverable:** `../README.md` · **Evidence:** `../ci-out/`, `../ci-artifacts/`, `../ci-log.txt`

---

## 1. What ExinPool is (verified)

| Field | Value | Source |
|---|---|---|
| Name | ExinPool ("a staking platform powered by Exin") | `https://api.mixin.one/codes/791f20db-51ce-4af2-918b-7496864ab833` |
| Mixin app id (client id) | `c48136b1-c5ab-437a-a079-9df1dc748f1b` | same |
| App number | `7000101761` | same |
| Invite/access code | `791f20db-51ce-4af2-918b-7496864ab833` | same |
| Created | 2019-02-10T11:56:58Z | same |
| `has_safe` | `true` (Mixin Safe feature enabled for the account) | same |
| `spend_public_key` | `""` (not exposed publicly) | same |
| home_uri / redirect_uri | `https://mixin.exinpool.com` / `https://mixin.exinpool.com/auth` | same |
| creator_id | `f26ab3ca-1642-4dcb-9466-0c1ef03c5069` | same |
| Docs repo | `github.com/ExinOne/exinpoolsupport` + `ExinOne/exinpool-support`; live docs at `exinpool.support` (support.exinpool.com origin is down, Cloudflare 526) | GitHub / exinpool.support |
| Node services | XIN (Mixin), ETH 2.0, DOT, SOL, AXS | `docs/introduction.md`, `docs/rewards.md` |

**There is no smart contract.** ExinPool is a custodial Mixin **bot**: users transfer assets to the app
account (`c48136b1-…`); the operator holds the spend keys; positions are tracked in the operator's
off-chain database; exits are queue-based and executed by the bot as ordinary Mixin transfers.
DefiLlama's "Liquid Staking" category is a mislabel — no liquid staking/share token was found.
"EPC" is an ExinOne fee-point card with **no claim** on ExinPool assets (see `project-research.md` §3).

## 2. The $10.19M figure is operator self-reported, not on-chain derived

DefiLlama's adapter (`DefiLlama-Adapters/projects/exinpool/index.js`) does exactly one thing:

```js
const API = 'https://mixin.exinpool.com/api/v1/node/status'
const { data } = await get(API)
api.addUSDValue(Math.round(data.totalValueUsd))
```

Live samples taken 2026-10-04 (UTC):

| Sample | totalUsers | totalValueUsd |
|---|---|---|
| 1 | 15,081 | 10,206,895.75 |
| 2 | 15,081 | 10,218,403.60 |
| 3 | 15,081 | 10,218,421.20 |

Implications:

1. The headline TVL **cannot be verified on-chain**. Mixin Kernel does not expose per-address
   balances through public APIs, and the app's account/UTXO ownership is hidden behind Mixin's
   ghost-key scheme (see `mixin-kernel.md`). The only public balance this API reports is the
   operator's own number.
2. DefiLlama metadata marks the protocol `deadUrl: true` and `audits: "0"` while the API (and the
   operator's business) is clearly live — the *website* is what is dead (root/auth endpoints
   currently return 503/timeouts), not the API.
3. The service is **active**, not a zombie: 15,081 users and daily-updating numbers. The H-24
   premise ("current, 0 audits") is accurate, but "zombie" is not.

## 3. Mixin-side footprint (publicly measurable facts)

| Check | Value | Source |
|---|---|---|
| XIN asset id | `c94ac88f-4671-3976-b60a-09064f1811e8` | api.mixin.one |
| XIN price | $54.29 (DefiLlama) / $54.40 (Mixin ticker) | 2026-10-04 |
| XIN total supply | 1,000,000 (CoinGecko) | CoinGecko |
| XIN snapshots count | 106,546,694 | api.mixin.one |
| Kernel nodes (all-time records) | 517 (473 REMOVED, 44 ACCEPTED) | `kernel.mixin.dev` `listallnodes` |
| ExinPool docs' claim (undated) | 4.2678 nodes (4 self-owned + 0.2678 joint), **57,356 XIN pledged**, "private keys … managed by core team members with multi-signature backups" | `docs/Nodes/mixin.md` |
| Kernel XIN ledger balance | see `ci-out/exinpool-evidence.json` | `getasset` |

The docs' XIN pledge (57,356 XIN ≈ **$3.11M** at $54.29) is a subset of the self-reported AUM.
Node pledging is an operator-key operation; no external party can move a pledge (see
`mixin-kernel.md` for the mechanism + authorization analysis).

## 4. Ethereum component — fully verified, closed

ExinPool publishes its "ETH 2.0 node" account in `docs/Verify.md`:
`0xDFCE3CB1cbd896B96578005e14aDb81eC26DF923`.

| Check | Result (block 26,116,920) |
|---|---|
| Code | Gnosis Safe proxy (EIP-1167-style proxy runtime) |
| Singleton (`masterCopy()`) | `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552` — **canonical Gnosis Safe v1.3.0** |
| `VERSION()` | `1.3.0` |
| Owners (5) | `0xd116b066b8b647e9245d0d1f6ab6648ba03d118a`, `0x4f10987aa7647bc059886fbd0d363dc4eee33866`, `0x90ac5b380bcd166408f2e067dd95ce595b48c54d`, `0x61a368b599d55df7fb5fb76d450be65640d645f3`, `0x9ecd18b3b017ded68014815ed0ace9300253e144` |
| Threshold | **3 of 5** |
| Modules (`getModulesPaginated`) | `[]` (none) |
| Guard slot (`keccak256("guard_manager.guard.address")`) | `0x0` (none) |
| Fallback handler slot | `0xf48f2b2d2a534e402487b3ee7c18c33aec0fe5e4` (canonical CompatibilityFallbackHandler) |
| `nonce()` | 67 (active) |
| ETH balance | 10.749914106534813988 ETH ≈ **$28,965** at $2,694.35/ETH |
| ERC-20 balances | USDT 0, USDC 0, stETH 0, rETH 0; WETH dust 0.0000001 (1e11 wei) |

**Attack-path verdict:** none. A canonical Safe with 3-of-5 threshold, no modules, no guard and no
delegatecall extensions can only be executed by 3 owner keys. There is no permissionless function,
no upgrade path, no orphaned approval. `poc/test/ExinPoolSafe.t.sol` proves the configuration and
that forged/insufficient signatures revert (CI fork test).

## 5. External-chain node accounts

See `external-chains.md` (balances of the published Polkadot / Solana addresses; Ethereum covered
above). These are operator-controlled accounts on third-party chains; there is no ExinPool contract
on them, so no unprivileged path exists by construction — the only question is whether any address
is a contract with a flaw, which the child report checks.

### 5.1 Relevant history (full detail in `project-research.md`)

- **2020-02**: ExinOne (same team) lost ~$5M of customer savings in the FCoin collapse; resolved via
  bonds/haircuts. Third-party counterparty risk precedent, not an on-chain bug.
- **2020-03**: a joint XIN node (Fox.ONE + ExinPool + SS team, 3-of-3 multisig) lost **10,000 XIN**
  because one team mishandled its key; ExinPool's share was 3,600 XIN; users compensated ~90%.
  Demonstrates that "multisig backups" did not prevent a key-handling loss.
- **2023-09**: the Mixin Network $200M hack (cloud-provider DB compromise) suspended non-XIN
  ExinPool queues; ExinPool TVL fell ~17% then recovered. No public evidence ExinPool customer
  principal was stolen.
- **2024–2026**: no ExinPool-specific insolvency, freeze, or exit-scam evidence found. The service
  appears live (self-reported AUM updating; docs updated 2026-04).

## 6. Attack-surface enumeration — why external extraction is $0

| # | Candidate path | Status | Evidence / gate |
|---|---|---|---|
| a | Exploit a Mixin smart contract (MVM) | **Does not exist** | No ExinPool MVM/EVM contract found; the service is a bot. |
| b | Steal node XIN pledge / app UTXOs on Kernel | **Closed by cryptography** | Spending requires the operator's ed25519 spend keys; outputs are ghost-key locked; pledges require node signer keys. No external authorization path (see `mixin-kernel.md`). |
| c | Mixin app API / web (`mixin.exinpool.com`) | **No unauthenticated path observed; not fully testable** | Root and `/auth` are 503/timeout; only public endpoint observed is `GET /api/v1/node/status` (read-only). Withdrawals are signed server-side with the app spend key. Authenticated endpoints and POST semantics cannot be exercised without credentials (out of scope; no intrusive testing). |
| d | Deposit-credit / memo spoofing (fake deposit → withdraw) | **Unverifiable (closed-source)** — theoretical class for Mixin bots | Server code is not public; the bot verifies incoming Kernel snapshots off-chain. Exploiting it would require live interaction (sending transfers), which is prohibited; not counted as extractable. This is the single most plausible *latent* risk. |
| e | Weak key management / single-key hot wallet | **Not observable; positive indicators, historical precedent** | App record `has_safe: true`; docs claim multisig backups; team publishes a Shamir-secret-sharing tool (default 3-of-5); ETH funds in a 3/5 Safe. Counterpoint: the 2020 joint-node key loss (10,000 XIN) shows key handling is the weak link. Private-key custody cannot be audited externally. |
| f | Exit/redemption logic manipulation | **Off-chain** | Exits are bot-mediated transfers with documented fees (0.2% exit; 1% early-exit). No on-chain claim contract to attack. |
| g | Kernel consensus / network-level exploit | **Out of scope / no public exploit** | The Sept-2023 Mixin incident ($200M) was a cloud-provider DB compromise, i.e. an operator-side key compromise, not an unprivileged on-chain path. |

## 7. Gates where simulation is impossible

1. **Mixin side**: no public VM, no contracts, no forkable state; per-address balances and app
   UTXOs are not publicly queryable; the bot backend is closed-source. No fork PoC is possible.
2. **Deposit-credit path**: would require an authenticated Mixin account and sending live transfers
   to the production bot — prohibited by the campaign rules.
3. **Self-reported TVL**: cannot be reconciled with on-chain custody because Mixin does not expose
   account balances publicly.
4. **External chains**: partially verifiable (balances), but the accounts are EOAs/multisigs whose
   private keys cannot be audited.

## 8. Verdict

- **E-U (external unprivileged extractable): $0** — high confidence for the on-chain/contract
  surface (no contract exists; the one EVM contract is a canonical 3/5 Safe); medium confidence
  overall because the operator's off-chain server and key custody cannot be audited from outside.
- **H-O (user-recoverable): $10.22M self-reported** — users can exit through the bot's documented
  flow; this is an off-chain claim, not a permissionless on-chain withdrawal, and its solvency is
  unverified.
- **P (privileged):** operator keys control the custody; value overlaps H-O (no incremental assets
  beyond the same AUM).
- **S (stuck):** $0 found so far (no incident evidence of currently frozen withdrawals; historical
  incidents — 2020 FCoin/joint-node and 2023 Mixin hack — were resolved or compensated; see
  `project-research.md` §4).

## 9. Files

- `analysis/live-state.md` (this file) — core analysis
- `analysis/mixin-kernel.md` — Kernel pledge/custody mechanics (child)
- `analysis/external-chains.md` — DOT/SOL/ETH node balances (child)
- `analysis/project-research.md` — docs, incidents, token, key management (child)
- `poc/test/ExinPoolSafe.t.sol` — Ethereum Safe boundary tests (CI)
- `ci/run.sh` — live evidence collector (CI)
- `ci-out/exinpool-evidence.json`, `ci-out/exinpool-summary.md` — machine-readable evidence
