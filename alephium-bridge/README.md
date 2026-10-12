# Alephium Bridge (AlphBridge) — Phase-2 deep dive: live value & unprivileged-extraction assessment

**Campaign:** zombie-hunt II · L2 watchlist Phase-2 · **Chains:** Alephium + Ethereum + BNB Chain · **Date:** 2026-10-12
**Status:** read-only research; PoC fork-verified on CI only; **no mainnet transaction sent**. No secrets in this folder (CI repo is public).
**Triage row (Phase 1):** `LIVE-FUNDED`, $253,490, ETH+BSC only. This deep dive found the triage **missed the Alephium-side custody (14,187,624.84 ALPH)** and re-classifies the finding: this is not a dead zombie — it is a **live, post-exploit relaunched bridge** whose entire value is guardian-gated.

---

## 1. TL;DR

| # | Target | Live unprivileged extractable | Why closed | Latent risk |
|---|---|---|---|---|
| 1 | ETH TokenBridge `0x579a3bDE…dD43` ($221,149 custody) | **$0** | Every value-moving path (`completeTransfer*`) requires a **guardian-signed VAA**; attacker-forged VAA with the real emitter/payload reverts `VM signature invalid`. Standard Wormhole-Portal TokenBridge logic; replay-protection live; no pause switch | Off-chain watcher forgery — the actual 2026-05-30 vector — if the watcher fix regresses. `messageFee() == 0` on the core makes message *publishing* free (validated off-chain) |
| 2 | BSC TokenBridge `0x2971F580…4dD8` ($25,595 custody) | **$0** | Implementation **byte-identical** to the ETH one (same codehash), same 4-guardian set (3-of-4), same gating | Same |
| 3 | Alephium custody `226T1Xsp…MEWBZ` ($989,576) | **$0** | Contract operations are guardian-authorized; it **survived the May-30 compromise untouched** while the EVM side was drained (attacker had forged *EVM-bound* messages only) | Guardian tx-signing path; Ralph source not public |
| 4 | wALPH token `0x590F82…89A6` ($6,315) | **$0** | 81,026.59 wALPH + 663.95 USDT sent **to the token contract itself**; no function exists to move them (owner powers = mint/burn of wALPH only) → **S (stuck)** | none |

**Total live extractable by an external unprivileged attacker: `$0` — confidence: high (contract level).**
**Live bridge custody at stake (operational, user-backed): ≈ $1,236,320** — see §5.

---

## 2. What the Alephium Bridge is (verified on-chain)

A **Wormhole-Portal-derived TokenBridge** deployment (Apache-2.0 code, `(AlphBridge)` naming) with its **own 4-guardian set** — not the canonical Wormhole deployment (`0x3ee18b22…`). Verified live configuration (block 26,175,504 ETH / 127,187,224 BSC, 2026-10-12):

| Piece | Ethereum | BNB Chain |
|---|---|---|
| TokenBridge proxy | `0x579a3bDE631c3d8068CbFE3dc45B0F14EC18dD43` (ERC1967, verified) | `0x2971F580C34d3D584e0342741c6a622f69424dD8` (ERC1967, verified) |
| Implementation | `0x0F843945075DF4EA9C8a21f0e0CcFD5eB073eEAb` ("BridgeImplementation", verified) | `0xfba7c899FFa8f8503b7a9690C45A63c5BCb4fB78` (unverified label; **runtime code byte-identical** to ETH impl — codehash `0x015189b8…5757`) |
| `chainId()` | 2 | 4 |
| Core (`wormhole()`) | `0x01e82b67367dE9f805E55de730D5007a752912A8` | `0xE674e61111ecE5988113DA56f0b2Cc3CB22D5304` |
| Governance | chainId `0`, contract `0x…0004` | same |
| Guardian set | `getGuardianSet(0)` = **4 keys**, current index **0**, expiry 0 | same 4 keys |
| Registered emitters | chain 255 = `0x7f42f8e2…4800` (Alephium bridge), chain 4 = BSC bridge | chain 255 = `0x7f42f8e2…4800`, chain 2 = ETH bridge |
| `messageFee()` | 0 | 0 |

Guardian keys (identical on both chains, **never rotated — index 0 since deployment**):
`0x214f15D574A4D7895EEd709F80F7B49E5fE5Ad29`, `0x78C7B8dD49CEdd6311f03357bBD7299B4d747852`, `0x4B2CbEa0E19473D90e41581d4F39FA44b5fb88fB`, `0x9eFb0cd728D59bA13EAbe2f17ceBF9f3AB6989A1`. Quorum observed in all VAAs: **3 of 4**.

**Trust surface is exactly three chains:** ETH bridge accepts VAAs only from chain 4 (BSC) and chain 255 (Alephium); BSC bridge only from chain 2 (ETH) and 255 (checked ids 0,1,2,3,4,5,6,10,23,30,255; nothing else registered).

Alephium side (chain 255 in-bridge): custody contract `226T1XspViny5o6Ce1jQR6UCGrDXuq5NBVoCFNufMEWBZ`
— `asset.attoAlphAmount = 14,187,624.84289993 ALPH`, one mutable field (locked ledger 14,187,623.84), immFields `[0x7f42f8e2…4800 (= its own VAA emitter id), 255, 0x0, 18]`, **active daily** (9,660 txs; latest 2026-10-12 05:43 UTC).

**The bridge is live on all three chains**: ETH `completeTransfer` calls on 2026-10-12 (e.g. tx `0x94874cf8…`, a legit 5.1792 USDC bridge-out from Alephium), BSC transfers on 2026-10-11/12, Alephium custody ops daily. The bridge's own explorer (`explorer.bridge.alephium.org`) shows continuous message flow in both directions (e.g. Alephium→ETH sequence #8219, Alephium→BSC #1932, BSC→Alephium #1836, all within the last 13 hours).

**Why the Alephium custody survived the incident (evidence-based):** on 2026-05-30 the attacker demonstrably controlled/directed the guardian *signing* of Alephium-origin messages and used it to mint 13.76M unbacked wALPH and release ~$305k of EVM collateral. If the 14.19M ALPH custody on Alephium could have been released by the same forged-message technique, that is what would have been taken (≈$1M, more than the realized total). No ALPH left the custody contract in the incident (official transaction lists contain no such release; the custody balance is intact and it continues paying out only through its normal operations). The Alephium-side release path is therefore a *different* gate from the watcher-fed VAA path, and was not broken.

---

## 3. Total live extractable now: `$0` (E-U) — confidence high

The only way value leaves the custody is a message signed by ≥3 of the 4 guardians. No on-chain function reads external events; the bridge validates *signatures*, not facts. The 2026-05-30 exploit did not break that — it made the guardians *sign* fabricated messages off-chain (see §4). An external unprivileged attacker with only public contracts/mempools cannot produce such a signature, cannot redirect a valid VAA (recipient is fixed in the payload), cannot replay consumed VAAs, and cannot mint/burn wALPH (bridge-only). Proven by 9/9 fork tests (§7).

**Classification**

| Category | USD | Notes |
|---|---|---|
| **E-U** (external unprivileged) | **$0.00** | high confidence at the contract level; see residual risk §8 |
| **H-O** (holder-only self-service) | **$0.00** | bridge is live; no stranded user claims found |
| **P** (guardian/governance-only) | **$1,236,320.26** | live custody: ETH $221,149.17 + BSC $25,595.48 + Alephium $989,575.61. Recovery power demonstrated 2026-06-02 (upgrade→burn→downgrade in one tx) |
| **S** (stuck/bricked) | **$6,315.01** | 81,026.59 wALPH + 663.95 USDT trapped at the wALPH token contract `0x590F82…89A6` (no reachable transfer path) |

Prices used (DefiLlama, 2026-10-12 ~09:30 UTC): ALPH $0.069749, USDT $0.999263, USDC $0.999708, WBTC $83,305.80, WETH $2,550.59, WBNB $749.08. Live values drift (bridge operating).

---

## 4. The exploit mechanism (May 30 2026) — why the contracts are sound but the perimeter was not

Primary sources: Alephium postmortem (2026-09-04), on-chain report (2026-06-02), burn explainer (2026-06-08), Inference AG audit "Alephium's Watcher v1.2".

1. **Root cause (off-chain):** the bridge's Watcher/re-observation fallback path did not apply the same validation as the primary path. Under an **eclipse-style disruption** of the bridge's own Alephium full nodes, the fallback re-fetched events for not-yet-synced transactions that had "interacted with the bridge". The attacker deployed a fake contract on Alephium (`24ZjqcvV8vVCn29zd1TThqAtaS8pMvJ4Co1MK5zncPcAB`) that emitted a **LOG7 forged VAA event**; legit guardian software signed it.
2. **No key compromise.** This deep dive decoded the actual attack VAA on-chain (tx `0x928e369e…`, block 25,207,237): `emitterChainId=255`, `emitterAddress=0x7f42f8e2…4800` (the real bridge), `targetChainId=2`, payload = Transfer 200,967.309973 USDT → attacker `0x6681ebC8…921d`, **signed by guardians 0, 1, 3** — the same set still active today (index 0).
3. **Drain (64 s):** 200,967.31 USDT / 0.3353 WBTC / 17,594.63 USDC / 5.1819 WETH released on Ethereum, 36,750.11 USDT / 24.3862 WBNB on BSC, plus **13,757,076.37 unbacked wALPH minted**.
4. **Remediation:** 13,257,077.37 wALPH (96.4%) burned 2026-06-02 via a **guardian governance upgrade** (tx `0xade2846a…`, block 25,230,400 → impl `0x9cc524cA…511a`, burn, downgrade to standard impl in the same tx — verified from receipt logs). Per Alephium's burn explainer, the recovery required approval from the **full guardian set** (independent verification by each) and the burn capability was introduced *only* in the temporary implementation. Watcher fixed; audited by Inference AG (2 low issues fixed); users reimbursed; bridge relaunched at the same addresses.
5. **On-chain code today is the same standard implementation as before the hack** (only one `ContractUpgraded` event ever; temporary recovery impl removed). There is **no pause switch**; safety now lives entirely in guardian operations + watcher validation — precisely, the perimeter that failed once.

**Fix verification limits:** the fix is off-chain (Watcher code, not public/verifiable by read-only research). We can only verify (a) the on-chain gating still requires guardian signatures, (b) the guardian-backed recovery/replay machinery is intact, and (c) primary sources claim the fallback path now enforces the same validation.

---

## 5. Live-state assessment (all citations on-chain, 2026-10-12)

### Ethereum — block 26,175,504
| Check | Value |
|---|---|
| ETH TokenBridge USDT `balanceOf` | **171,129.124138** (`outstandingBridged` 171,129.073685 — liabilities ≈ reserves) |
| USDC | **15,290.699043** |
| WBTC | **0.26804329** |
| WETH | **4.872060710** (`outstandingBridged` 4.87206071) |
| native ETH | 0.042681230296196839 (unwrap buffer) |
| ≈ USD | **$221,149.17** |
| wALPH `totalSupply` (0x590F82…89A6) | 13,411,372.809450093504847991 |
| wALPH held by the token contract itself | 81,026.592890601536475071 (**stuck, S**) |
| USDT held by the token contract | 663.953878 (**stuck, S**) |
| Impl slot | `0x0F84…eEAb`, codehash `0x015189b8…5757`, `isInitialized` = true |
| Guardian set | 4 keys, index 0, expiry 0 |
| Upgrade history | exactly 1 event: 2026-06-02 `0x0F84…eEAb → 0x9cc524cA…511a` (recovery), then back — receipt logs 526–530 of tx `0xade2846a…` |
| Governance replay state | `governanceActionIsConsumed(0xc4b261d8…6dd7)` = **true** (recovery VAA cannot be replayed) |

### BNB Chain — block 127,187,224
| Check | Value |
|---|---|
| WBNB | **24.492289910** |
| USDT | **6,969.186073060** |
| USDC | **284.784332170** |
| ≈ USD | **$25,595.48** |
| wALPH(BSC) supply / owner | 746,499.34976577 / bridge (correct) |
| Impl slot | `0xfba7c899…fB78`, codehash **identical** to ETH impl |
| Guardian set | same 4 keys, index 0 |

### Alephium (node/explorer backend)
| Check | Value |
|---|---|
| Custody `226T1Xsp…MEWBZ` | **14,187,624.84289993 ALPH ≈ $989,575.61** |
| Assets held | ALPH only (no tokens) |
| Liveness | 9,660 txs; deposits/withdrawals daily, latest 2026-10-12 05:43 UTC |
| Backing check | custody 14.188M ALPH vs wALPH on ETH 13.411M + BSC 0.7465M = 14.158M → ~99.8% backed (post-relaunch the team added native ALPH for the 500k escaped unbacked wALPH) |

### Historical attack VAAs (decoded via `core.parseVM`, all valid=True, guardianSetIndex=0)
| VAA | Content | Signers | Status |
|---|---|---|---|
| Attack USDT (tx `0x928e369e…`, blk 25,207,237) | 200,967.309973 USDT → attacker, emitter = real bridge | guardians 0,1,3 | `isTransferCompleted` = true (replay blocked) |
| Recovery (tx `0xade2846a…`, blk 25,230,400) | module "TokenBridge", action 2 (Upgrade) → `0x9cc524cA…` | guardians 0,1,3 | governance consumed |
| Live bridge-out (tx `0x94874cf8…`, blk 26,175,002) | 5.1792 USDC → user, emitter = real bridge | guardians 0,1,2 | completed (replay blocked) |

---

## 6. What an attacker can / cannot do

**Cannot (all verified live):**
- `completeTransfer(craftedVAA)` / `completeTransferAndUnwrapETH(craftedVAA)` → core returns `VM signature invalid` for attacker-signed VAAs; a VAA with 0 signatures is rejected; junk bytes revert. Funds are released only to `payload.to` (fixed at signing time) — no redirect.
- Replay any historical/attack VAA → `transfer already completed` (hash map live).
- Mint/burn wALPH (or BSC wALPH) → `caller is not the owner` (owner = the TokenBridge).
- `upgrade()` / `registerChain()` → require a governance VAA from chain 0 / `0x…0004` signed by 3-of-4 guardians; also single-use.
- Pull tokens into the bridge from any account other than `msg.sender` (`transferTokens` is `safeTransferFrom(msg.sender…)`).
- Drain the Alephium custody: no unprivileged method observed; it kept its balance through the whole May-30 incident.

**Could (residual, not contract-level):**
- Re-run the **watcher forgery** if the off-chain fix regressed: guardians would again sign fabricated messages; identical outcome (collateral release + unbacked mints). Requires eclipse-level network manipulation against bridge nodes — not reproducible/verifiable read-only; prohibited in this campaign (no attacks on live infra). Historical value: ≈$305k collateral + realized wALPH (≈$450–815k headline).
- Complete *unclaimed* legit VAAs with `arbiterFee > 0` before their intended recipient: by design the completer receives the fee (relayer incentive). Not quantified (fee is usually 0); recipient funds are unaffected.
- `messageFee() == 0`: anyone can publish messages on the cores for free — harmless on-chain (emitter = sender), but it means the "cost" of feeding the watcher is zero if any validation gap exists.

---

## 7. PoC / fork verification (read-only forks; no mainnet txs)

`poc/test/AlephiumBridgePoC.t.sol` — **9/9 PASS** (local run 2026-10-12; CI run __CI_URL__).

| Test | Proves |
|---|---|
| `test_eth_live_state` | custody balances/config/guardians/impl codehash at fork tip |
| `test_bsc_live_state` | BSC custody + identical guardian set + **byte-identical implementation** |
| `test_forged_vaa_rejected_and_no_funds_move` | attacker-signed 150,000-USDT VAA with real emitter → `VM signature invalid`; custody unchanged |
| `test_unsigned_vaa_rejected` | 0-signature VAA rejected |
| `test_attack_vaa_guardian_signed_and_replay_blocked` | the real May-30 attack VAA verifies (guardians 0,1,3 — **no key compromise**), amount 200,967.309973 USDT decoded, replay reverts |
| `test_recovery_governance_vaa_guardian_signed` | June-2 recovery VAA: governance chain 0/`0x…0004`, action Upgrade→`0x9cc524cA…`; current impl back to standard |
| `test_today_live_transfer_vaa_replay_blocked` | a bridge-out VAA from 2026-10-12 (5.1792 USDC): bridge live, replay blocked |
| `test_walph_mint_burn_bridge_only` | mint/burn revert `caller is not the owner` for an attacker |
| `test_governance_entrypoints_reject_junk` | `upgrade`/`registerChain`/`completeTransfer` revert on junk |

Key CI/local evidence: `forge test -vv` → 9 passed; log line `core rejection reason: VM signature invalid`. `ci/run.sh` re-dumps live state to `ci-out/live_state.json` each run (artifact).

Run locally: `cd poc && forge test -vv` (uses `FORK_RPC_URL`/`RPC_URL` and `BSC_RPC_URL` env or public fallbacks).

---

## 8. Verdict, residual risk, blockers

- **Verdict:** E-U **$0** (high). The contracts enforce a strict 3-of-4 guardian-signature gate on every exit path; the only successful extraction in the bridge's history came from fooling the *off-chain* Watcher into signing forged messages — not from a contract flaw. The triage's "$253k live" was correct as far as it went, but (a) $6,315 of it is unrecoverable (stuck at the wALPH token contract), (b) the bridge is **live**, and (c) the triage **missed the $989,576 Alephium-side custody** — true live custody is ≈$1,236,320.
- **Latent risk:** a watcher-fallback regression re-opens the same drain; `messageFee=0` keeps the cost of fabrication at zero; the bridge remains a 4-key, single-set trust domain (no rotation since launch).
- **Blockers for an attacker:** guardian private keys were never compromised and the set is unchanged; forged VAAs fail signature verification; consumed VAAs cannot be replayed; the Alephium custody never lost funds.
- **Wreckage (not extractable by third parties):** per Alephium's postmortem (verification 2026-08-21), ~4.4 ETH remains in known attacker wallets (main `0x6681ebC8…921d`: 3.6233 ETH; parking `0x0baD8f95…509c`: 0.3964 ETH; tornado-feeder `0xEC60E38F…7E69`: 0.3383 ETH); ~150.7 ETH of proceeds were mixed through Tornado Cash. These are the attacker's own funds — no third-party claim path.
- **Out of scope / unverifiable:** whether the (non-public) Watcher fix is complete — the independent audit (Inference AG v1.2) covers the fix; no on-chain or fork test can validate off-chain code.

## 9. Methodology, sources, caveats, files

**Method:** contract discovery from the DefiLlama adapter + Alephium incident report → verified sources via Etherscan V2 (ETH) and BSC bytecode diff → live reads via public RPCs (`ethereum-rpc.publicnode.com`, `bsc-rpc.publicnode.com`, `node.mainnet.alephium.org`, `backend.mainnet.alephium.org`) → VAA extraction from real tx calldata and decoding via the bridge's own core (`parseVM`) → fork tests (Foundry 1.7.x, solc 0.8.24) → CI (`kingmariano/ca-zombie-ci`).

**Sources:** Alephium postmortem & on-chain report & burn explainer (alephium.org/news); Inference AG "Alephium's Watcher" audit v1.2; Etherscan/BscScan; DefiLlama prices; explorer.alephium.org; campaign corpus (`FINDINGS.md`, `l2-triage-a/summary.json`).

**Caveats:** (1) live values move — figures are point-in-time (block 26,175,504 ETH / 127,187,224 BSC / 2026-10-12 Alephium); (2) the Alephium Ralph contract source is not public; its gating is assessed from behavior + architecture, not source; (3) guardian quorum (3-of-4) is observed in VAAs and matches the Portal ⅔+1 formula; the core implementation is unverified on both chains; (4) `ci/run.sh` output contains only public addresses/balances (no keys — the CI repo is public).

**Files:** `README.md` (this), `summary.json`, `analysis/raw/` (verified sources, live dumps, VAA hexes, upgrade receipts, codehashes), `ci-out/live_state.json` (CI artifact), `poc/` (Foundry project), `ci/run.sh`, `ci-log.txt`, `ci-artifacts/`.
