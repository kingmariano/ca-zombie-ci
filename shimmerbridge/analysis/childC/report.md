# ShimmerBridge origin-side independent audit — childC report

**Target:** `OriginalTokenBridge` at `0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898`
(Ethereum/BSC/Polygon/Arbitrum/Base/Optimism/Avalanche/Fantom) and its full LayerZero v1 receive path
(Endpoint `0x66A7…`, ReceiveUln301 `0x245B…` on Ethereum; per-chain equivalents elsewhere).
**Question:** can an external, unprivileged attacker (no owner/admin keys, no protocol privileges; own capital
and flash loans allowed) extract locked tokens **today**?
**Method:** source audit of verified standard-JSON; bytecode-level recompilation of all four contracts;
live-state verification via public RPC (`eth_call`, `eth_getCode`, logs); per-chain cross-checks.
**Category key:** `E-U` exploitable by unprivileged caller · `H-O` requires owner/admin capability ·
`P` requires protocol/infrastructure precondition · `S` safe/observation (no exploitation path).

---

## 1. Verification that the audited code is the deployed code

### 1.1 Source integrity
All four verified sources saved under `analysis/` are **byte-identical** to the standard-JSON embedded in the
Etherscan verification records (script: `/tmp/opencode/cmp_sources.py`):
- `contracts/OriginalTokenBridge.sol` (+ 17 inherited/dependency files) — 18/18 identical.
- `contracts/Endpoint.sol` (v1 endpoint) — 7/7 identical.
- `contracts/uln/uln301/ReceiveUln301.sol` (+ deps) — 22/22 identical.
- `contracts/uln/uln301/SendUln301.sol` (+ deps) — 41/41 identical.

### 1.2 Bytecode integrity (recompiled from the verified standard-JSON)
The bridge carries Etherscan's `SimilarMatch` flag, so it was recompiled with the exact solc
`0.8.17+commit.8df45f5f` (sha256-verified official binary) and compared against `eth_getCode`:

| Contract | Chain | compiled / on-chain size | differing bytes | Interpretation |
|---|---|---|---|---|
| OriginalTokenBridge | Ethereum | 15241 / 15241 | 320 B in 16 ranges | **all 16 ranges are exactly 20-byte immutable patches** — 7× WETH `weth` and 9× Endpoint `lzEndpoint`; everything else incl. metadata is byte-identical |
| Endpoint | Ethereum | 15282 / 15282 | 2 B in 2 ranges | immutable `chainId` (=1, confirmed by `getChainId()`), patched in-place |
| ReceiveUln301 | Ethereum | 12985 / 12985 | 73 B in 4 ranges | immutable `localEid`(101) + endpoint(`0x66A7…`)×2 + 32-byte metadata IPFS tail; **no logic bytes differ** |
| SendUln301 | Ethereum | 22620 / 22620 | 12 ranges | only immutable patches (endpoint, nonce contract, treasury) + metadata tail |

**Conclusion:** the audited sources are the exact deployed logic on every checked field. No hidden logic exists
in the deployed bytecode.

### 1.3 Live gate configuration (Ethereum; read 2026-10-13)

| Parameter | Value | Implication |
|---|---|---|
| Bridge `owner` | `0x562De36D…5b31` (EOA) | privileged; assumed unavailable |
| Bridge `remoteChainId` / `trustedRemoteLookup(230)` | `230` / `0x9c6d…7898`+`0x9c6d…7898` (40 B) | unlock only accepted from the same-address WrappedTokenBridge on eid 230 |
| Bridge `useCustomAdapterParams` | `true`; `minDstGasLookup(230,0)`=100000 | send-side requires ≥100k dst gas in adapterParams |
| Endpoint `uaConfigLookup(bridge)` | all zeros → DEFAULT send/receive versions | bridge does **not** pin any library or config |
| Endpoint default libs | send v4=`0xD231…F705`, receive v5=`0x245B…eEfC` | `getReceiveLibraryAddress(bridge)=0x245B…eEfC` |
| ReceiveUln301 `localEid` | `101` (Ethereum v1 chain id) | `_assertHeader` requires packet dstEid=101 |
| ReceiveUln301 `getUlnConfig(bridge,230)` | confirmations **21**, requiredDVNCount **4**, optionalDVNCount **0**, DVNs `0x3802…F20D`, `0x589d…236b`, `0xa4fE…5c2cd`, `0xa59B…0BA5` | 4-of-4 DVN attestations required; no optional DVNs |
| ReceiveUln301 `getAppUlnConfig(bridge,230)` | all zeros | config is the eid-230 *default* (not custom) |
| ReceiveUln301 `executors(bridge,230)` | `0x0` → `defaultExecutors(230)` = `0x1732…3059` | execution gate is the default LayerZero executor only |
| ReceiveUln301 `addressSizes(230)` | `20` | v1 path = 20-byte sender + 20-byte receiver = matches 40-byte trustedRemote; size per eid is one-shot (`setAddressSize` reverts once set) |
| Endpoint `inboundNonce(230, path)` | **529** | last consumed nonce |
| `failedMessages(230, path, n)` for n=1..529 | **all zero** (full scan) | no stuck/retryable messages on the Ethereum path |
| Recent `PayloadVerified` on `0x245B…` | srcEid ∈ {184,110,198,102}, dstEid=101 only; **no eid-230 events** | DVN activity for Shimmer has indeed stopped |

Other chains (BSC, Polygon, Arbitrum, Base, Optimism, Avalanche): same bridge code (15241 B), same
trustedRemote(230)=`0x9c6d…7898`+self, custom executor = none, `addressSizes(230)`=20, confirmations=21,
**4 required DVNs** each (Fantom: 3 required DVNs, same style). Each chain's unlock is independently gated by
its own DVN set and default executor.

---

## 2. The unlock chain, gate by gate

An attacker who wants the bridge to release tokens must make the following true (all four gates in series):

1. **Endpoint receive auth** — `Endpoint.receivePayload` requires `msg.sender == defaultReceiveLibraryAddress`
   (`0x245B…`, because the bridge's receive version is DEFAULT). Only code inside the ReceiveUln301 can call it
   (`Endpoint.sol:100-112`). Attacker cannot call `receivePayload` directly.
2. **CRITICAL — Receive library verification** — `ReceiveUln301.commitVerification` is externally callable, but
   (a) `_execute` requires `msg.sender == getExecutor(receiver, srcEid)`, which for the bridge is the default
   executor `0x1732…3059`, and (b) `_verifyAndReclaimStorage` requires the effective ULN config to be satisfied:
   4/4 listed DVN addresses must have recorded `hashLookup[keccak(header)][payloadHash][dvn]` with
   `confirmations >= 21`. Attacker attestations are keyed by the attacker's own address and are ignored
   (`ReceiveUln301.sol:49-62`; `ReceiveUlnBase.sol:43-77,90-124`; `ReceiveLibBaseE1.sol:77-102`).
   The config that applies is a function of `(receiver, srcEid)` parsed from the packet itself; for
   `srcEid=230` it is the 4-DVN default; for any other `srcEid` the bridge's own trusted-remote check still
   blocks execution (see gate 3), and in all cases the attacker still needs that eid's DVN quorum.
3. **Trusted remote + source chain** — `LzApp.lzReceive` requires `srcAddress == trustedRemoteLookup[230]`
   (the 40-byte path = remote bridge `0x9c6d…7898` + local bridge), and `_nonblockingLzReceive` requires
   `srcChainId == 230` and `packetType == PT_UNLOCK` and `supportedTokens[token]`
   (`LzApp.sol:31-40`; `OriginalTokenBridge.sol:125-130`).
4. **Message fields are hash-bound** — DVN attestations are keyed by `keccak256(header)` and
   `keccak256(payload)`, where the 81-byte header covers version, nonce, srcEid, sender, dstEid, receiver.
   No field (including the 32-byte sender, whose low 20 bytes form the v1 path) can be altered without
   invalidating every attestation (`PacketV1Codec.sol`; `AddressCast.toBytes` truncates, but the full
   32-byte value is what DVNs attest).

There is no path around gates 2 and 4 without DVN attestations: `setConfig` on the receive library is
`onlyEndpoint`, and the endpoint forwards `msg.sender` as the oapp, so only the bridge itself (via its
owner-gated `LzApp.setConfig`) could ever attach a weaker custom config; the bridge has none
(`getAppUlnConfig(bridge,230) = 0`). `setDefaultUlnConfigs`/`setDefaultExecutors`/`setAddressSize` are
lib-owner (LayerZero) only. `Endpoint.setSendVersion/setReceiveVersion/setConfig` only ever write
`uaConfigLookup[msg.sender]` — an attacker calling them writes to the attacker's own entry, never the bridge's.

Replay is closed by both layers: `_verifyAndReclaimStorage` deletes the consumed DVN attestation entries and
the endpoint enforces strictly sequential `nonce == ++inboundNonce[srcEid][path]` (`Endpoint.sol:100-112`).
A second execution of any packet reverts.

**`retryMessage`** (permissionless) can re-run a stored failed message, but `failedMessages` entries are only
created by `_storeFailedMessage` from `lzReceive`, i.e. only for endpoint-delivered packets that already passed
the trusted-remote check, and the retry requires the exact payload hash and consumes the entry. It re-executes
a genuine remote-bridge-authorized transfer (`to` fixed by the remote message) — not a forgery primitive.

---

## 3. Findings

### F1 — Permissionless `retryMessage` replays only genuinely-authenticated messages — no forgery (S, Informational)
`NonblockingLzApp.retryMessage` (NonblockingLzApp.sol:46-56) has no caller gate and calls
`_nonblockingLzReceive` directly, **skipping** the `_srcAddress` trusted-remote comparison that `lzReceive`
performs. However, the storage key `failedMessages[srcChainId][srcAddress][nonce]` (NonblockingLzApp.sol:18,33)
binds the exact `(230, trustedPath, nonce)` tuple; entries only get written from `_blockingLzReceive`
(NonblockingLzApp.sol:24-30) which is reached only from the endpoint-gated `lzReceive`, and the payload hash is
checked (NonblockingLzApp.sol:48-50). An attacker cannot fabricate an entry, cannot choose `to`, and the entry
is deleted before execution. Full nonce scan 1..529 on Ethereum shows no pending entries at all.
**Verdict: not exploitable.**

### F2 — Retry path is not `nonReentrant`; WETH-unwrap hook can re-enter permissionless functions (S, Low — hardening)
`_nonblockingLzReceive` decrements `totalValueLockedSD` *before* external calls and `retryMessage` deletes the
failed-message entry *before* the call, so classic CEI is respected (OriginalTokenBridge.sol:132-143;
NonblockingLzApp.sol:50-54). But the retry path executes `payable(to).call{value}(...)`
(OriginalTokenBridge.sol:135-139) while neither the bridge's `ReentrancyGuard` (only `bridge`/`bridgeNative`
are guarded, OriginalTokenBridge.sol:75,94) nor the endpoint's `receiveNonReentrant` (only held in the
`lzReceive` path, Endpoint.sol:76-81,100) is active. A malicious `to` can re-enter `bridge()/bridgeNative()`
(the guard is free on this path) and `retryMessage` for other stored messages. All re-entrant entry points
move only the caller's own funds or replay other already-authenticated messages; no accounting edge exists
(TVL is decremented exactly once per message, per-message state is independent). No extraction path found.
**Verdict: informational hardening (add `nonReentrant` to `retryMessage`).**

### F3 — `accruedFeeLD`/`withdrawFee` revert if TVL exceeds balance (S, Low — owner-impact only)
`accruedFeeLD` = `balanceOf(this) - TVL_SD*rate` (OriginalTokenBridge.sol:63-65) underflows (Solidity 0.8) if
balance < TVL; then `withdrawFee` (owner-only) reverts too. Unprivileged actors cannot push balance below
`TVL*rate`: user bridging only *increases* both balance and TVL consistently (dust is returned and never
counted, OriginalTokenBridge.sol:79-89), and unlocks only occur via authenticated messages. Live state is
consistent (USDC/WBTC/WETH accrued=0; USDT has a +1000-unit surplus). If a future authenticated unlock used
`totalAmountSD < withdrawalAmountSD` the fee view could brick — a remote-side trust matter, not attacker
reachable. **Verdict: not exploitable unprivileged; owner-only annoyance.**

### F4 — `verify()` is permissionless and header-unvalidated; attestations persist per caller (S/P, Info)
`ReceiveUln301.verify` → `_verify` writes `hashLookup[headerHash][payloadHash][msg.sender]` for any
81-byte-ish `_packetHeader` without `_assertHeader` and without validating the packet (ReceiveUln301.sol:64-66;
ReceiveUlnBase.sol:43-46). Only addresses present in the effective config count in `_checkVerifiable`, so
attacker-written entries are inert. The latent hazard: if a privileged config change later added such an
address as a DVN, its pre-written entries would become valid retroactively. Requires `setDefaultUlnConfigs`
(LayerZero) or bridge-owner `setConfig`. **Verdict: not exploitable today (P); defense-in-depth note for the
DVN-config owner.**

### F5 — The entire security boundary is the 4-of-4 DVN quorum + default executor (P, Critical-if-compromised)
For Ethereum: DVNs `0x3802…F20D`, `0x589d…236b`, `0xa4fE…5c2cd`, `0xa59B…0BA5`, confirmations=21
(all LayerZero-operated; per-chain sets differ; Fantom requires 3). A quorum of DVN signing keys could attest a
forged header (`srcEid=230, dstEid=101, sender=0x…9c6d…7898, receiver=bridge`) + payload
`abi.encode(PT_UNLOCK, token, attacker, amountSD, totalAmountSD, false)` and have the default executor
(`0x1732…3059`, an EIP-1967 upgradeable LayerZero proxy, impl `0x1Ed8…`, unverified public source) commit it,
draining up to the full token balances. This requires off-chain key compromise / infrastructure takeover — not
an unprivileged smart-contract exploit. **Verdict: conditional (P), precondition = DVN quorum or LayerZero
infra compromise.** Note the executor's own `msg.sender` gate (`ReceiveLibBaseE1.sol:88`) is a *second*
independent requirement; a compromised DVN set alone still needs executor submission.

### F6 — Privileged paths that can move principal (H-O, by design; keys assumed unavailable)
- Bridge owner: `setTrustedRemote(230, …)` (LzApp.sol:89-92), `setConfig` (attach custom ULN with an
  attacker DVN + custom executor, LzApp.sol:71-73 → ReceiveUln301.sol:29-43), `setReceiveVersion`
  (point to a malicious library, LzApp.sol:79-81), `setRemoteChainId`, `registerToken`, `withdrawFee`
  (bounded by accrued fees only).
- Endpoint owner (LayerZero): `newVersion` + `setDefaultReceiveVersion` swaps the default receiver for every
  DEFAULT-version OApp, including this bridge (Endpoint.sol:149-171).
- Receive-lib owner (LayerZero): `setDefaultUlnConfigs(230, …)` can redefine the DVN set/confirmations
  (UlnBase.sol:55-70); `setDefaultExecutors`.
- `renounceOwnership` is a no-op (TokenBridgeBase.sol:38), so ownership cannot be accidentally destroyed;
  `transferOwnership` is owner-only (Ownable.sol:69-72).
**Verdict: privileged-only; no unprivileged path through any of these functions.**

### F7 — Unlock accounting trusts the remote payload (P/S, trust assumption)
`_nonblockingLzReceive` decrements `totalValueLockedSD[token]` by `totalAmountSD` but transfers
`withdrawalAmountSD * rate` (OriginalTokenBridge.sol:132-143). A malicious/buggy remote bridge could pass
`totalAmountSD < withdrawalAmountSD` and drain up to the bridge's current balance while leaving TVL inflated
(bricking `withdrawFee`, see F3), or `totalAmountSD > withdrawalAmountSD` to deflate TVL. Bounded by the
bridge's actual token balance; requires messages from the authenticated remote app. ShimmerEVM is shut down
and DVN support for eid 230 has ceased, so this is unreachable, and it is not an unprivileged attacker
capability in any case. **Verdict: trust-assumption note; not exploitable today.**

### F8 — Griefing/DoS cannot reach the unlock path (S)
- Nonce consumption: `receivePayload` is receive-library-gated (Endpoint.sol:108-112); no external actor can
  consume the bridge's per-path nonces.
- Blocking via `storedPayload`: the bridge's `lzReceive` never reverts for the legit path (trusted-remote check
  passes; all payload errors are absorbed by the nonblocking self-call, NonblockingLzApp.sol:24-30), so no
  attacker-reachable `storedPayload` entry can be created for `(230, path)`. `forceResumeReceive` is owner-only.
- Front-running the executor: `commitVerification`'s state changes (attestation deletion + delivery) happen
  atomically; an attacker cannot be the executor and cannot make the message fail without executor gas
  choices. A message can at worst be delayed, not redirected.
- `retryMessage` replay of a genuine failed message only pays the fixed remote-specified recipient.
**Verdict: no profitable DoS found.**

### F9 — Stray ETH is trapped; `retryMessage` retains `msg.value` (S, Info)
`receive()` accepts ETH (OriginalTokenBridge.sol:166) and no function can withdraw raw ETH (only WETH unwrap
forwards to a message recipient). `retryMessage` is `payable` but ignores `msg.value`, permanently retaining it
(NonblockingLzApp.sol:46). Both harm only the sender; neither yields a profit path against principal.

### F10 — No external function can decrement TVL or transfer principal outside the unlock path (S)
Grep-level enumeration of all state mutation: `totalValueLockedSD` is written only in `_bridge` (`+=`, line 109)
and `_nonblockingLzReceive` (`-=`, line 132). Token transfers out of the bridge exist only in `withdrawFee`
(owner, bounded by accrued fees), `_nonblockingLzReceive` (authenticated unlock), and dust refunds to the
depositor (`bridge`). No other token-moving functions exist. **Verdict: confirmed closed.**

---

## 4. Replay / packet forgery checklist (all negative)

| Vector | Result |
|---|---|
| Custom receive library for bridge | Not set (`uaConfigLookup = 0`, `getReceiveLibraryAddress = default 0x245B…`) |
| Custom ULN config for bridge (weaker DVN set) | Not set (`getAppUlnConfig = 0`); `setConfig` only callable via the bridge's owner-gated wrapper |
| Attacker self-attestation via permissionless `verify()` | Entries keyed by attacker address; never in the DVN list |
| Forced overwrite of DVN attestations (`commitVerification` by non-executor) | Whole tx reverts at `_execute` (executor check), attestations not consumed |
| Replay of executed packet | Endpoint sequential nonce + attestations deleted in `_verifyAndReclaimStorage` |
| Cross-chain replay (same address on 8 chains) | dstEid/localEid + per-chain DVN attestations chain-bound |
| Field malleability in header/path (sender truncation, srcEid cast) | Attestations bind full header hash; `toUint16` reverts on overflow; path size frozen at 20 |
| Nonce skipping / stored payload poisoning on legit path | Requires executor call; nonblocking wrapper absorbs failures |
| Pending attested-but-unexecuted message | None found for eid 230 (recent logs); if one existed, only the default executor could submit it and its recipient is fixed |

---

## 5. Bottom line

**No unprivileged, live extraction path exists today on any of the eight origin-side deployments.** The unlock
path is defended in series by four independent, correctly-implemented gates that the deployed bytecode matches
exactly: (i) `Endpoint.receivePayload` is callable only by the default receive library `0x245B…`; (ii)
`ReceiveUln301.commitVerification` can only be submitted by the per-chain default executor and only succeeds
with 4/4 (Fantom 3/3) on-chain DVN attestations under a config that no unprivileged caller can influence
(custom executor = 0, custom app config = 0, every setter `onlyOwner`/`onlyEndpoint`); (iii) the 40-byte
trusted-remote path plus `srcChainId==230` check in the bridge; and (iv) full header/payload hashing so no
field can be altered without invalidating attestations — with replay closed by nonce monotonicity and
attestation deletion. `retryMessage` is permissionless but can only replay messages that already passed all of
the above, `withdrawFee` cannot touch principal, and no other function can move value or decrement TVL. The
strongest conditional path is a quorum compromise of the four LayerZero-operated DVN keys for eid 230 (or
LayerZero infrastructure/owner-key takeover: swapping the default receive library, redefining the eid-230
default ULN config, or upgrading the executor proxy), after which a forged `PT_UNLOCK` message for an
attacker-chosen recipient could be executed and drain the affected chain's full token balances (order of
$10^5 across all deployments combined); a
lesser variant requires the bridge owner key (to set a custom 1-of-1 DVN config or a malicious receive
library). All of these require key compromise or privileged action, not an unprivileged on-chain exploit.

*Verified independently in this session: source-to-deployed bytecode equality for all four contracts,
live gate configuration on Ethereum plus spot-checks on six more chains, full scan of 529 nonces'
`failedMessages`, and recent receive-library event decoding. No owner/admin keys were used; all calls were
read-only.*
