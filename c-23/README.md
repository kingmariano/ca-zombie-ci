# C-23 — 1inch Fusion v1 Settlement (`0xa888…`) Yul calldata corruption: live extractability

**Campaign:** zombie-hunt · **Chain:** Ethereum · **Date of work:** 2026-10-03
**Status:** read-only research; PoC fork-verified only (local + GitHub Actions). No mainnet transactions sent.
**Target:** `0xA88800CD213dA5Ae406ce248380802BD53b47647` — verified `Settlement` (1inch Fusion v1), immutable.
**Pin block for live state:** `26,109,263` (2026-10-03 ~04:00 UTC) · **Last activity observed:** block `26,106,881` (2026-10-02 19:59 UTC).

## TL;DR

The Yul overflow in `Settlement._settleOrder` is **still present and still executable** in the deployed
bytecode. It does not let an attacker take anything from Settlement itself (it holds only spam dust and is
not upgradeable) — it lets an attacker make Settlement call `resolveOrders(...)` on **any** address with
**fully attacker-chosen arguments**. Every third-party Fusion-v1 resolver contract that trusts this callback
(`msg.sender == Settlement` + a publicly-derivable first argument + "transfer my tokens to msg.sender") is
therefore drainable, one token per transaction. Seven such resolver contracts were **drained end-to-end on a
mainnet fork** at the pin block. A third-party drainer bot is already sweeping this class live (observed from
2025-03 through 2026-10-02).

| # | Target | Live extractable (unprivileged) | Why open / closed | Latent risk |
|---|---|---|---|---|
| 1 | **Settlement `0xA888…` itself** | **$0** (own balances are spam dust; no sweep/owner) | Bug is live, but Settlement holds nothing worth taking and has no privileged path | The corruption primitive stays live forever (immutable contract) |
| 2 | **7 confirmed resolver contracts** (table §4) | **≈ $400.75 gross** (market prices @ block 26,109,263) | Fork-proven full extraction: 0x5623B873, 0x7a359544, 0xe789c556, 0x84D99Aa5, 0xBd4DBE0C, 0xcb13e91f, 0xB02F | More tokens per victim (one tx each); more resolvers likely exist |
| 3 | `0x5B93D80D…` (partial ~$1.4k) | **not proven** | Direct `resolveOrders` probe with self/creator args did not move tokens; operator arg unknown | Would add ~$1.4k if the right operator arg / state is found |
| 4 | `0xA9048585…` (~$28) | **not proven** | Direct probe with empty `data` moves tokens, but the full corrupted path (non-empty `data`) reverts | Needs a `data`-empty variant of the calldata |
| 5 | **User approvals to Settlement** (11 events total) | **$0** | 2 live approvals with balance: one holder has 0 balance; the other's USDT approval is to Settlement while the LOP pull needs a maker signature + LOP allowance (DEXT has no LOP allowance) | None found |
| 6 | Successor deployments `0x2Ad500…` (ETH `Settlement`, BNB `SimpleSettlement`, 17 chains) | **$0** | Rewritten v2 code (solc 0.8.23): no vulnerable Yul pattern, no `resolveOrders` callback | — |

**Total live extractable now: ≈ $400.75 gross / ≈ $395 net** (gas at 0.0764 gwei on 2026-10-03 makes the
per-token sweep — ~650k gas ≈ $0.13 per token, ~34 tokens ≥ $1 — cost only a few dollars; at 5 gwei it would
be ≈$22). Confidence: high that the path is live and proven; medium in the USD total (market prices,
thin-liquidity slippage not quantified). It is contested: an active drainer bot has been harvesting the same
contracts (§5), so value observed at the pin block may be gone by the time anyone acts.

---

## 1. The bug, exactly

The deployed `Settlement` (`0xA888…`, verified source, solc 0.8.17, direct deployment, no proxy) contains the
vulnerable Yul block in `_settleOrder` (source file `contracts/Settlement.sol`, saved at
`analysis/settlement_sources/contracts__Settlement.sol`):

```yul
let interactionLengthOffset := calldataload(add(data.offset, 0x40))
let interactionOffset := add(interactionLengthOffset, 0x20)
let interactionLength := calldataload(add(data.offset, interactionLengthOffset))
...
// Copy calldata and patch interaction.length
let ptr := mload(0x40)
mstore(ptr, _FILL_ORDER_TO_SELECTOR)
calldatacopy(add(ptr, 4), data.offset, data.length)
mstore(add(add(ptr, interactionLengthOffset), 4), add(interactionLength, suffixLength))
{  // Append suffix fields
    let offset := add(add(ptr, interactionOffset), interactionLength)   // <-- unchecked overflow
    mstore(add(offset, 0x04), totalFee)
    mstore(add(offset, 0x24), resolver)
    ...
}
```

`interactionLength` is a full attacker-controlled calldata word and both the pointer arithmetic and the
length patch are unchecked. Setting `interactionLength ≈ -512` makes the "appended" settlement suffix land
over attacker-controlled padding. `fillOrderInteraction` then decodes the suffix with
`DynamicSuffix.decodeSuffix` (read backwards from the end of `interactiveData`) and gets a **fully fake
suffix**: attacker-chosen `resolver`, `token`, `rateBump`, `takingFee`, `tokensAndAmounts`. At the
`_FINALIZE_INTERACTION` branch it executes:

```solidity
IResolver(target).resolveOrders(suffix.resolver.get(), allTokensAndAmounts, data);
```

`target` comes from the first 20 bytes of the interaction payload (attacker-chosen). The victim resolver
then transfers its own tokens to `msg.sender` (Settlement), and the crafted self-signed limit order that
Settlement is simultaneously filling routes those tokens to the attacker's receiver.

* Post-mortem: Decurity, "Yul Calldata Corruption — 1inch Postmortem" (2025-03-07), linked from
  `zombie_hunt/incidents_zombie_contracts.md`. Public reproduction: DeFiHackLabs
  `src/test/2025-03/OneInchFusionV1SettlementHack.sol_exp.sol`.
* Incident: 2025-03-05, ~$4.5–5M drained from the **TrustedVolumes** resolver `0xB02F…`; most returned
  after negotiation. Settlement itself was the vulnerable caller, not the victim.
* The patch: 1inch "proactively redeployed the relevant contract" (blog, 2025-03-07). The old `0xA888…`
  is immutable and was never patched — it remains live and callable. Successor `Settlement`/`SimpleSettlement`
  at `0x2Ad5004c60e16E54d5007C80CE329Adde5B51Ef5` (and `0x65497E56…` on Cronos/HyperEVM/Monad) are a
  different, rewritten codebase (solc 0.8.23) with no vulnerable pattern and no `resolveOrders` callback.

## 2. Live state of the target (block 26,109,263)

| Check | Result |
|---|---|
| Code | 4,419 bytes, verified `Settlement`, solc 0.8.17, **immutable** |
| Proxy / admin | no EIP-1967 implementation slot (`0x360894…` = 0); `owner()` reverts; no roles |
| ETH balance | **0** |
| ERC-20 balances | USDC 0, USDT 0, WETH 1 wei, 1INCH 4 wei, DAI 1 wei; ~1,000 other token entries are spam dust (largest priced items < $1 total) |
| `settleOrders(bytes)` | public, unguarded — still callable |
| `resolveOrders` selector `0x1944799f` in code | present (Settlement itself implements the resolver interface) |
| `feeBank()` | `0xa0844e046a5B7Db55Bb8DcdFfbF0bBF9c6dc6546` — FeeBank holds **0 1INCH**; only depositor `withdraw` / owner (`0x7951c7…`) `gatherFees`; not unprivileged-extractable |
| Last direct `settleOrders` tx | 2024-06-21 (EOA resolvers `0x959065f2…`, `0xf14f1798…`) |
| Last use of the **corrupted path** | block `26,106,881` (2026-10-02 19:59 UTC) — tx `0x41259d1baaa094654a0d4b6a899468b557b783627b6bd768bacbfa665317725e` |

## 3. Candidate enumeration

* Top-level `settleOrders` callers (Blockscout, full history, 1,500 pages in CI): **14 unique senders** —
  almost all EOAs (market-maker operators), plus the bot/probe contracts below.
* ERC-20 senders to Settlement (all history, CI): **749 unique addresses**; **763** addresses code-scanned;
  **14** bytecodes contain the `resolveOrders(address,bytes,bytes)` selector `0x1944799f` (the identical set
  was found by the local scan and by the CI scan; the false-positive rate for a 4-byte selector over ~750
  contracts is ~10⁻³, so these are genuine dispatcher entries).
* All 14 are unverified; creators are resolver-operator EOAs (`0xEe230d…`, `0xad714915…`, `0xC97567…`,
  `0x11799622…` (the Settlement deployer), `0x55DCad91…`, `0x959065F2…`, …).
* CI Blockscout-priced holdings across all 14 `resolveOrders` contracts: **$1,813.20** (includes the two
  unproven candidates `0x5B93D80D…` $1,411.91 and `0xA9048585…` $28.40, and possibly inflated CoinGecko
  rates); the conservative, cross-priced number for the **7 fork-proven** victims is **$400.75** (§4).

## 4. Full extraction table (fork-proven, block 26,109,263)

All seven below were drained end-to-end in `test_03_live_full_extraction` with the live bytecode
(`poc/test/C23.t.sol`): the victim's token moved to an attacker-chosen receiver in one ~600–670k-gas tx.
USD = DefiLlama/Blockscout market price at the pin block (whole-holdings valuation; one token per victim
was actually moved on the fork).

*The `test_02` direct screen (empty `data`) is only indicative: resolvers that unconditionally
`abi.decode` their `data` argument revert on empty data yet succeed with the 87 zero bytes the corrupted
path supplies (e.g. `0x7a359544`, `0xe789c556`); conversely `0xA9048585` passes the empty-data screen but
reverts on the real non-empty `data`. The full-path test is authoritative.*

| Resolver | `resolverArg` needed | Token (proven) | Amount proven | Gas | Total holdings (USD) |
|---|---|---|---|---|---|
| `0x5623B873…` | `0xEe230d…` (owner) | GYEN | 1,313.756325 | 665,960 | **$30.77** |
| `0x7a359544…` | `0xC97567…` (creator) | EURA | 11.491223665276228210 | 618,904 | **$160.39** |
| `0xe789c556…` | `0x9108813F…` (operator) | XAUT | 0.001194 | 629,710 | **$94.63** |
| `0x84D99Aa5…` | self | FNT | 176.053403 | 590,995 | **$18.12** |
| `0xBd4DBE0C…` | self | DEGEN | 749,607.0 | 608,753 | **$89.42** (RIO $84.19 + dust) |
| `0xcb13e91f…` | self | DUCKER | 4,258.61963885256 | 653,865 | **$6.66** |
| `0xB02F…` (TrustedVolumes) | self | WETH | 0.00001 | 600,153 | **$0.78** |
| | | | | **Σ** | **$400.75** |

Unproven / excluded:

| Resolver | Direct probe (`resolveOrders` from Settlement, empty data) | Full corrupted path | Notes |
|---|---|---|---|
| `0x5B93D80D…` | no movement (tried self, creator and 9 further historical operator EOAs via `eth_call`) | not reached | ~$1.4k of holdings (partial list) if a valid operator arg is found |
| `0xA9048585…` | moves tokens (self) | reverts with the real non-empty `data` | ~$28; needs a `data`-empty calldata variant |
| `0x0B3e6d29…`, `0x6482E8fB…`, `0x7B3b0810…`, `0xE8269790…`, `0xEEfCc15d…` | no movement / zero balance | n/a | dust only |
| `0x5623B873…` **dsETH** | — | already drained by the live bot 2026-10-02 | evidence of active competition |

Additional costs to realise the table: each victim/token is a separate tx (~600–670k gas). At the pin-block
gas price of 0.0764 gwei and ETH $2,678 that is ≈ **$0.13 per token** (~34 tokens ≥ $1 → ≈$5 total; all 607
non-zero token positions → ≈$80). Slippage on thin tokens is the larger unknown; a 10–30% haircut on the
illiquid half implies a realistic net of roughly **$300–390**.

## 5. The class is being actively exploited right now

A third-party drainer (`0xC0ffeEBA…`, via its contract `0xE08D97e1…`) has been repeatedly using the corrupted
path against these resolver contracts in 2026:

* `0x41259d1baaa094654a0d4b6a899468b557b783627b6bd768bacbfa665317725e` (block 26,106,881, 2026-10-02):
  `0xE08D97e1` → `Settlement.settleOrders` → `Settlement.resolveOrders(0x5623B873, owner, [dsETH,0|dsETH,124720433445741], data=87 zero bytes)`
  → 124,720,433,445,741 dsETH moved to the bot, then sold for WETH.
* Same sender, same pattern: `0x7a359544…` (2025-11-02, 1,715,120,146,143,939,974 UNI,
  `resolverArg = 0xC975671642534F407EbdcaEF2428D355eDe16a2C`) and `0xe789c556…` (2026-04-07,
  97,315,481,250,000,000,000 YIELDX, `resolverArg = 0x9108813F22637385228a1C621c1904BbbC50dc25`) — both
  traces saved in `analysis/`.
* Other Settlement transfers from this resolver class came from distinct addresses
  (`0xe9bc82…` on `0x7B3b0810…` in 2025-03, `0xfbc5565e…` on `0x84D99Aa5…` in 2026-08), so more than one
  drainer is involved.

This proves the primitive is live **and contested**; balances measured at the pin block are a snapshot.

## 6. What an attacker can / cannot do

**Can (unprivileged, no keys, no whitelist):**
1. Call `Settlement.settleOrders(crafted)` from any contract (msg.sender becomes the resolver for the outer
   order; the order's own resolver list is bypassed by the public-time-limit path since `interaction`
   tail bytes are zero).
2. Force Settlement to call `resolveOrders(resolverArg, tokensAndAmounts, data)` on any target, with
   `resolverArg` and the token/amount list fully chosen.
3. For a target that meets the vulnerable pattern, receive its ERC-20 balances at an address of choice
   (via the simultaneously-filled self-signed order).
4. Repeat per token. Cost ≈ 600–670k gas per token.

**Cannot:**
1. Take anything from `Settlement` itself (dust only; no sweep; immutable).
2. Use outstanding user approvals: Settlement's only `transferFrom` is `FeeBank.deposit` (1INCH, from
   msg.sender). The LOP fill that pulls a maker's asset requires the maker's signature over the order hash,
   and for the one approval holder with a balance the token path is additionally gated by LOP allowance
   (DEXT: none) — `test_04` proves the unsigned fill reverts.
3. Extract ETH from resolver contracts (their `resolveOrders` moves ERC-20s only; the arbitrary-call branch
   would need `data` that the corrupted path cannot supply without reverting).
4. Attack the successor v2 Settlement / SimpleSettlement (different code, no `resolveOrders`).
5. Use the corrupted path against resolvers whose `resolveOrders` strictly ABI-decodes `data` unless the
   padding between the resolver address and the suffix is ≥64 zero bytes — the PoC uses 87 zero bytes
   (matching the live bot), which is why 7 of the 14 candidates work and `0xA9048585…` does not.

## 7. PoC / fork verification

`poc/` (Foundry, `via_ir = true`, vendored `lib/forge-std`), `poc/test/C23.t.sol`:

| Test | What it proves | Result |
|---|---|---|
| `test_01_historical_repro` | Fork at block 21,982,110 (pre-attack): the exact 2025-03-05 exploit extracts **1,000,000 USDC** from `0xB02F…` — harness validated against the real incident | PASS |
| `test_02_live_screen_all` | Direct `Settlement → resolveOrders` probe of all 14 candidates at the pin block; records which move tokens | PASS (6 move with empty `data`) |
| `test_03_live_full_extraction` | Full corrupted-path extraction at block 26,109,263: **7 victims drained** (table §4), gas 590,995–665,960 per tx | PASS |
| `test_04_approvals_not_extractable` | Approval holders' allowances/balances; unsigned LOP fill reverts; no owner / no EIP-1967 slot | PASS |

**CI runs (GitHub Actions, public `kingmariano/ca-zombie-ci`):**
* Run 1 (PoC + heavy enumeration): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37099199777
* `forge test` result: **4 passed, 0 failed** (`test_01` gas 1,152,827; `test_03` gas 7,485,971).
* `ci/run.sh` result: 14 top-level senders / 749 token senders / 763 code scans → the same 14
  `resolveOrders` contracts; Blockscout-priced total across them $1,813.20. Artifacts:
  `ci-artifacts/result-c-23/ci-out/{settlement_enumeration.json,resolver_balances.json,enumeration.log}`.

Heavy enumeration job `ci/run.sh` re-derives the sender set, the `resolveOrders` code scan and per-contract
token balances on the CI runner; results in `ci-out/`.

## 8. Verdict and residual / latent risk

* **Verdict:** the bug is live and exploitable by anyone. The immediately extractable value at the pin block
  is **≈$400.75 gross** from seven fork-proven resolver contracts (realistic net ≈$220–240 after per-token
  gas), and it is being actively harvested by at least one third-party drainer. `0x5B93D80D…` (~$1.4k) and
  `0xA9048585…` (~$28) are excluded only for lack of a working argument/`data` variant.
* **Latent:** the primitive cannot be patched away (immutable). Any future resolver integration that trusts
  `Settlement`'s `resolveOrders` callback — or any contract with a loose `resolveOrders(address,bytes,bytes)`
  — becomes drainable the moment it holds tokens. New third-party resolvers copying the old ResolverExample
  pattern (which the live bot's targets show is still happening) re-open the class.
* **Blockers to a full sweep:** per-token transactions and gas; thin liquidity on some tokens; blacklist/
  paused tokens would revert; the competing live drainer.

## 9. Methodology & sources

* Verified source + ABI: Etherscan V2 (`getsourcecode`) → `analysis/etherscan_Settlement_src.json`,
  `analysis/settlement_sources/` (24 files). Vulnerable Yul confirmed in the deployed source.
* Live state: `eth_getCode`/`eth_call` at explicit blocks (26,109,263 / 21,982,110) via archive RPCs
  (BlockPi/NodeReal/dRPC); Blockscout for enumeration, balances and exchange rates; DefiLlama
  (`coins.llama.fi`) for cross-priced valuations (`analysis/confirmed_valuation.json`).
* Incident/mechanics: Decurity post-mortem; Halborn "Explained: The 1inch Hack (March 2025)"; 1inch blog
  "Vulnerability in obsolete 1inch contract affecting resolver contracts"; DeFiHackLabs PoC.
* Decompiled/behaviour of victims: fork probes + historical call traces (`analysis/trace_26106881.json`,
  `analysis/trace_bot_7a359544.json`, `analysis/trace_bot_e789c556.json`).
* Campaign context: `zombie_hunt/FINDINGS.md` C-23, `incidents_zombie_contracts.md` row 17,
  `x_social_leads.md` rows 272/353.

**Caveats / limitations**
* USD totals are market-price snapshots at block 26,109,263; illiquid tokens (RIO, $RAINI, TXL, DUCKER, …)
  may realise less; one token per victim was actually moved on the fork, the rest are assumed standard.
* The live drainer may have emptied some balances after the pin block; re-measure before acting.
* `0x5B93D80D…` may be a legitimate, well-guarded resolver rather than a victim (2997 historical
  same-token payments to Settlement); its operator argument was not recovered.
* All work is read-only; no mainnet transaction was ever sent.

**Files index**
```
c-23/
├── README.md                 # this file
├── summary.json              # machine-readable summary
├── analysis/                 # sources, traces, enumeration JSONs, valuation scripts
├── poc/                      # Foundry: src/OneInchAttack.sol, test/C23.t.sol, lib/forge-std
├── ci/run.sh                 # heavy enumeration job (CI)
├── ci-out/                   # CI enumeration results (artifacts)
├── ci-log.txt / ci-artifacts # downloaded CI logs/artifacts
└── ci-links.md               # CI run URLs
```
