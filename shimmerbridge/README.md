# ShimmerBridge — L2 Phase-2 deep dive: live extractability determination

**Campaign:** zombie-hunt II (L2 watchlist, Phase 2) · **Protocol:** ShimmerBridge (ShimmerEVM ↔ 8 EVM chains, LayerZero EndpointV1)
**Chains:** Ethereum, BSC, Polygon, Arbitrum, Base, Optimism, Avalanche, Fantom (custody) — remote chain ShimmerEVM (chain 148 / LZ chain id 230)
**Date of work:** 2026-10-13 · **Triage row:** `l2-triage-a` (LIVE-FUNDED, $126,237; full total incl. AVAX/Fantom ≈ $184,842)
**Status:** read-only research; all PoC tests executed on local mainnet forks only. **No mainnet transactions sent.** No keys used.

---

## TL;DR

**An external, unprivileged attacker can extract $0 live from ShimmerBridge.** The locked tokens are not
attacker-reachable, and they are not recoverable by anyone either: the only unlock path is a LayerZero
message from ShimmerEVM (EID 230), a chain that **stopped block production on 2026-09-30** after the
**LayerZero bridge was shut down on 2026-08-29** (official sunset). The origin-side code is correct:
unlocking requires a 4-of-4 LayerZero DVN attestation set (3-of-3 on Fantom) **plus** the LayerZero default
executor, and every unprivileged shortcut reverts (fork-proven, 15/15 tests).

| Target | Live extractable (unprivileged) | Why closed | Latent risk |
|---|---|---|---|
| OriginalTokenBridge `0x9C6D…7898` — Ethereum | **$0** | Unlock needs authenticated LZ message from dead EID 230; 4/4 DVNs + executor gate | DVN-quorum / LayerZero-infra compromise (P) |
| — Avalanche | **$0** | same, 4/4 DVNs + executor | same |
| — BSC / Polygon / Arbitrum / Optimism / Base | **$0** | same, 4/4 DVNs each | same |
| — Fantom | **$0** | same, 3/3 DVNs | same |

**Total live extractable now (E-U): $0.00** — confidence **high**.
**Stuck / unrecoverable (S): $184,841.94** (all 8 chains, priced 2026-10-13).
**Owner-extractable accrued fees (P): $0.0013** (dust; principal cannot be withdrawn even by the owner).
**Holder/user recoverable (H-O): $0.00** — no self-service withdrawal exists, no failed/stored payloads anywhere.

---

## 1. The bridge and the exact unlock mechanism

ShimmerBridge is a LayerZero **EndpointV1** lock/mint bridge:

- **Origin side (this finding):** `OriginalTokenBridge` at `0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898`,
  deployed 2023-11-30 (Ethereum block 18,680,563; creator `0x5c7b9952…`), verified source,
  solc 0.8.17, **not a proxy**. Same address on BSC, Polygon, Arbitrum, Base, Optimism, Avalanche, Fantom.
  It locks original tokens (USDC/USDT/WBTC/WETH/WBNB/WMATIC/WAVAX/WFTM depending on chain).
- **Remote side:** a `WrappedTokenBridge` at the **same address** on ShimmerEVM (EVM chain 148).
  `trustedRemoteLookup(230)` = `0x9c6d…7898` ++ `0x9c6d…7898` (remote ++ local) on every origin chain.
- **Unlock path (the only way tokens leave custody):**
  1. `Endpoint.receivePayload` — callable only by the endpoint's default receive library
     (`0x245B6e8F…` on Ethereum; per-chain equivalent elsewhere). Bridge `uaConfigLookup` = zeros →
     it uses **DEFAULT** library versions.
  2. `ReceiveUln301.commitVerification` — permissionless to call, but `_execute` requires
     `msg.sender == getExecutor(bridge, 230)` (default executor `0x1732…3059` on Ethereum) and
     `_verifyAndReclaimStorage` requires the effective ULN config to be satisfied: **4/4 required DVNs**
     (`0x3802…F20D`, `0x589d…236b`, `0xa4fE…5c2cd`, `0xa59B…0BA5` on Ethereum), confirmations ≥ 21.
  3. `LzApp.lzReceive` — requires `msg.sender == endpoint` **and** `srcAddress == trustedRemoteLookup[230]`;
     `_nonblockingLzReceive` requires `srcChainId == 230`, `packetType == PT_UNLOCK`, `supportedTokens[token]`,
     and decrements `totalValueLockedSD` before paying out.
  4. Packet fields (version/nonce/srcEid/sender/dstEid/receiver) and payload are hash-bound to DVN
     attestations; replay is closed by the endpoint's strictly sequential `inboundNonce` and by
     `_verifyAndReclaimStorage` deleting consumed attestations.

An attacker who could forge a `PT_UNLOCK` packet for `srcEid=230, sender=wrapped bridge, receiver=bridge`
would drain the chain's token balances. Every field is bound to the 4 DVN attestations, so the security
boundary is the DVN quorum + executor — LayerZero-operated infrastructure.

**Why nothing can unlock today (two independent reasons):**

1. **Source chain dead.** Official Shimmer sunset: the LayerZero bridge for ShimmerEVM was shut down
   **2026-08-29**; ShimmerEVM stopped block production **2026-09-30** (blog.shimmer.network "Shimmer is
   Sunsetting", Jul 23 2026; TangleTreasury announcement 2026-08-28; LayerZero notice 2026-08-22 ceasing
   DVN/Executor support for 15 chains incl. Shimmer). The **last bridge message of any kind was 2026-08-30
   22:57:18 UTC (ShimmerEVM block 8,026,990, LayerZero Scan)**; the Shimmer L1's final milestone
   **24,359,373 was produced ~07:44 UTC on 2026-09-30** (frozen Tangle explorer / @theiotafeed). No new
   legitimate message can originate from EID 230. All official ShimmerEVM RPCs are dead (404/502; thirdweb
   returns `chainId` but errors on block queries); the last retrievable on-chain anchor is the Aug 30
   message above. Child A's full attempt log is in `analysis/childA/report.md`.
2. **No in-flight messages.** `inboundNonce[230][path]` (last consumed) is 529 on Ethereum / 2089 on
   Avalanche / etc.; `hasStoredPayload(230, path) = false` and `failedMessages(230, path)` is empty on
   **all 8 chains** — there is no pending unlock to deliver or replay. Recent `PayloadVerified` events on
   the receive library contain no eid-230 entries (DVN activity for Shimmer has ceased).

---

## 2. Live-state assessment (2026-10-13, pinned blocks)

| Chain | Block | Owner (Safe 1.3.0, 3-of-5) | Endpoint | Custody USD |
|---|---|---|---|---|
| Ethereum | 26,185,157 | `0x562De36D…5b31` | `0x66A71Dce…d675` | $75,455.20 |
| BSC | 127,441,435 | `0xA891988D…B057` | `0x3c226981…cf62` | $25,086.00 |
| Polygon | 95,471,075 | `0xe6D0732b…3798` | `0x3c226981…cf62` | $8,428.81 |
| Arbitrum | 514,495,775 | `0xFE6e2663…58d1` | `0x3c226981…cf62` | $7,129.16 |
| Base | 52,561,295 | `0xfE4E3Fe3…4EB9` | `0xb6319cC6…0dd7` | $205.79 |
| Optimism | 158,156,583 | `0x261869Aa…dafE` | `0x3c226981…cf62` | $10,036.77 |
| Avalanche | 97,462,318 | `0x1188cA84…16fe` | `0x3c226981…cf62` | $57,552.53 |
| Fantom | 123,677,136 | `0xf80b03F2…bD05` | `0xb6319cC6…0dd7` | $947.67 |
| **Total** | | | | **$184,841.94** |

Every owner is a **Safe v1.3.0 multisig, 3-of-5, with the identical 5 signers on all chains**
(`0xa1efcde1…`, `0xED38E7dC…`, `0x8fdb179D…`, `0xd639e0Fb…`, `0x411f9D60…`; `analysis/owners.json`).
(Note: the independent childC report describes the owner as an EOA — corrected here after reading
`getThreshold()/getOwners()/VERSION()` live.)

Per-chain gates (all verified live): `remoteChainId()=230`; `trustedRemoteLookup(230)` = same-address
40-byte path; bridge uses DEFAULT library/config on the endpoint (`uaConfigLookup` = zeros); effective ULN
config for eid 230 = **4 required DVNs** (Fantom: 3), confirmations 21, no optional DVNs, custom executor 0;
`addressSizes(230)=20`. Exact balances/TVL/fee reads per token are in `analysis/fee-accounting.json` and
`analysis/valuation.json`; the full per-chain token table is in `analysis/childB/`.

Owner privileges (P): `registerToken`, `setRemoteChainId`, `setTrustedRemote`, `setConfig`,
`setReceiveVersion`, `withdrawFee` — exercised by a **3-of-5 Safe** per chain (same signers).
**`withdrawFee` is bounded by accrued fees** = `balance − TVL×rate`;
live accrued fees total **$0.0013** (ETH 0.001 USDT + BSC 0.000264 USDT; zero elsewhere). There is **no
function that lets the owner withdraw principal**, and `renounceOwnership` is disabled. Not upgradeable.

---

## 3. What an attacker can and cannot do

| Attempt | Result | Evidence |
|---|---|---|
| Call `bridge.lzReceive(...)` with a forged unlock | Reverts `LzApp: invalid endpoint caller` | `test_02` (ETH + AVAX) |
| Call `endpoint.receivePayload(...)` directly | Reverts `LayerZero: invalid default library` | `test_03` |
| Call permissionless `ReceiveUln301.verify()` to self-attest | Records only the attacker address; `verifiable()=false`; `commitVerification` reverts `LZ_ULN_Verifying` | `test_04` |
| `commitVerification` without DVN quorum | Reverts `LZ_ULN_Verifying` | `test_05` (both chains) |
| `commitVerification` with quorum but as non-executor | Reverts `LZ_MessageLib_OnlyExecutor` | `test_05` |
| Forge `sender` = attacker (with quorum + executor) | Payload stored, **no funds move** | `test_06` |
| Use `srcEid=101` instead of 230 (with quorum + executor) | Payload stored, **no funds move** (empty trusted remote) | `test_07` |
| Replay a delivered packet | Reverts (`LZ_ULN_Verifying` — attestations consumed; nonce used) | `test_05` step 4 |
| `retryMessage` to inject a payload | Reverts `NonblockingLzApp: no stored message`; no failed/stored entries exist on any chain | `test_09` + live scan |
| Owner takes principal via `withdrawFee` | Reverts `not enough fees collected`; only $0.0013 fees exist | `test_08` (both chains) |
| Unprivileged admin calls (`registerToken`, `setRemoteChainId`, `withdrawFee`) | Revert `Ownable: caller is not the owner` | `test_08` |
| Full unlock with 4/4 DVNs + executor (fork-impersonated) | **Succeeds** — proves the gate is exactly the DVN quorum + executor | `test_05` |

The fork "success" case is intentional: it shows the deployed code has no hidden unprivileged bypass — the
only thing standing between the attacker and the funds is LayerZero's DVN keys (4 on most chains, 3 on
Fantom) plus the executor, which are not obtainable by an unprivileged on-chain actor.

---

## 4. PoC / fork verification

`poc/` — Foundry project, 2 suites, **15 tests, 15/15 PASS** (local fork runs; CI run URL below):

- `poc/test/ShimmerBridgeGate.t.sol` (Ethereum, 9 tests): live state + all gate proofs above.
- `poc/test/AvalancheGate.t.sol` (Avalanche, 6 tests): live state (largest leg, $57.5k) + gate proofs.
  The suite self-discovers the ReceiveUln301 `localEid` (106 on Avalanche) by distinguishing
  `LZ_ULN_Verifying` from `LZ_ULN_InvalidEid`, and reads DVNs/executor live from the library.

CI (GitHub Actions, public `kingmariano/ca-zombie-ci`): run URL recorded in `ci-log.txt`/`summary.json`
(`ci_run_urls`). Fork blocks and gas are in the run logs (`poc/test` logs include the live numbers).

Independent verification (`analysis/childC/`): the verified sources were **recompiled and byte-diffed
against `eth_getCode`** — identical except immutable patches — so the audited code is the deployed code.
A full scan of all 529 nonce entries' `failedMessages` on Ethereum found none, and no eid-230
`PayloadVerified` events were found recently.

---

## 5. Verdict, residual and latent risk

- **E-U: $0.00 (high confidence).** No unprivileged path exists; all candidate paths revert; the code is
  byte-equal to the audited source; the only unlock route requires the LayerZero DVN quorum + executor and
  a live source chain.
- **S: $184,841.94 stuck.** Even the bridge owner and LayerZero cannot move principal through the bridge's
  own functions. The tokens are permanently stranded: the source chain that could authorize releases no
  longer exists. Anyone still holding wrapped tokens on ShimmerEVM holds worthless claims.
- **P: $0.0013** of accrued fees (the only owner-extractable value).
- **H-O: $0.00** — no self-service recovery; no stored/failed payloads; wrapped-token holders cannot redeem.
- **Latent/conditional paths (all privileged, not E-U):**
  - Compromise of the 4-of-4 DVN keys (Ethereum et al.) / 3-of-3 (Fantom) **plus** the LayerZero executor
    → forged `PT_UNLOCK` could drain up to the full per-chain balances (order $10^5). Requires off-chain
    key compromise.
  - LayerZero endpoint/lib owner (`0xBe010A7e…`) repointing the default receive library or redefining the
    eid-230 default ULN config → same effect; trusted-party power, not an unprivileged exploit.
  - Bridge-owner key could attach a custom 1-of-1 DVN config or malicious receive library (owner-gated).
  - `accruedFeeLD` underflows (bricks owner fee withdrawal) if a future authenticated message used
    `totalAmountSD < withdrawalAmountSD`; unreachable while EID 230 is dead (childC F3/F7).

---

## 6. Methodology & sources

- Verified sources pulled from Etherscan V2 for all chains; unpacked to `analysis/src-eth/`,
  `analysis/src-lz-endpoint/`, `analysis/src-receive-uln/`, `analysis/src-send-uln/`.
- Live state read with `cast` against public RPCs at pinned blocks (table in §2); balances cross-checked
  with GoldRush (`analysis/goldrush-balances.json`); prices from DefiLlama (`analysis/prices-llama.json`,
  priced 2026-10-13); fee accounting via direct `accruedFeeLD`/`totalValueLockedSD`/`balanceOf` reads
  (`analysis/fee-accounting.json`).
- Sunset evidence: blog.shimmer.network "Shimmer is Sunsetting" (2026-07-23); LayerZero notice
  2026-08-22 (DVN/Executor support ends for 15 chains incl. Shimmer); TangleTreasury 2026-08-28;
  ShimmerEVM RPCs dead (404/502 / backend errors); last bridge message 2026-08-30 22:57 UTC (LZ Scan);
  L1 final milestone 24,359,373 (~07:44 UTC 2026-09-30). The WrappedTokenBridge source (remote side) is
  `LayerZero-Labs/wrapped-asset-bridge` @ `d89dc70dbfb9576601e4f9d69a4b2c210c256afd` — byte-identical to
  the verified on-chain `OriginalTokenBridge` source (both sides use the same codebase).
- PoC: Foundry 1.8.5, `forge test` against mainnet forks (Ethereum + Avalanche), run in CI.
- Independent adversarial audit by a child subagent (`analysis/childC/report.md`, `functions.md`);
  remote-side forensics in `analysis/childA/`; cross-chain data collection in `analysis/childB/`.

**Caveats / limitations:**
- The verdict "no extraction" depends on LayerZero DVN/executor honesty (off-chain trust) — unverifiable
  on-chain; stated as the conditional path.
- The Fantom leg's USDC (`0x28a92dDe…`) is a LayerZero-bridged USDC.e trading at ~$0.90; value shown is
  DefiLlama's mark. The Fantom leg was not fork-tested (mechanism identical; gate config verified live:
  3 required DVNs).
- USD totals are marks at 2026-10-13 prices, not realizable proceeds (nothing is realizable).
- No mainnet transaction was sent; fork impersonation of DVNs/executor was used only to prove the gate.

**Files index:** `README.md` (this file) · `summary.json` · `analysis/` (state dumps, sources, pricing,
children A/B/C) · `poc/` (Foundry: `test/ShimmerBridgeGate.t.sol`, `test/AvalancheGate.t.sol`) ·
`ci-out/`, `ci-log.txt` (CI evidence).
