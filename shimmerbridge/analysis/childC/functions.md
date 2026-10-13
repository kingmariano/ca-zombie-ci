# ShimmerBridge — Origin-side external function surface (childC)

Scope: `OriginalTokenBridge` (0x9C6D5a71FdD306329287a835e9B8EDb7F0F17898, same address on 8 chains) and its full
inheritance chain (`TokenBridgeBase → NonblockingLzApp → LzApp → Ownable`, `ReentrancyGuard`).
Sources audited are byte-identical to on-chain verified sources (see report.md §1.1).
"Principal" = the locked bridge tokens (USDC/USDT/WBTC/WETH/…). "Can move principal?" means *other people's* locked value.

Legend for gate: **any** = no caller restriction; **endpoint** = `msg.sender == lzEndpoint`;
**self** = `msg.sender == address(this)`; **owner** = `onlyOwner`; **stored-msg** = requires a pre-existing
`failedMessages` entry that only the endpoint path can create.

| Contract | Function | Caller gate | Can move principal? | Notes |
|---|---|---|---|---|
| OriginalTokenBridge | `bridge(token,amountLD,to,callParams,adapterParams)` payable | any | No (adds to TVL) | Locks caller's tokens; fee-on-transfer safe via balance delta; dust returned; `nonReentrant`; `totalValueLockedSD += amountSD`. L75-90 |
| OriginalTokenBridge | `bridgeNative(amountLD,to,callParams,adapterParams)` payable | any | No (adds to TVL) | Wraps caller's ETH→WETH (`IWETH.deposit`); `msg.value>=amountLD`; leftover becomes nativeFee. L94-100 |
| OriginalTokenBridge | `registerToken(token,sharedDecimals)` | owner | Config (enables new token) | Sets `supportedTokens` + `LDtoSDConversionRate`. L46-56 |
| OriginalTokenBridge | `setRemoteChainId(uint16)` | owner | Config (changes unlock src gate) | L58-61 |
| OriginalTokenBridge | `accruedFeeLD(token)` view | any | No | `balanceOf(this) - TVL_SD*rate`; **reverts on underflow** if TVL > balance. L63-65 |
| OriginalTokenBridge | `estimateBridgeFee(...)` view | any | No | Fee estimate only. L67-71 |
| OriginalTokenBridge | `withdrawFee(token,to,amountLD)` | owner | Only accrued surplus | `require(amountLD <= accruedFeeLD)` — cannot touch principal. L115-121 |
| OriginalTokenBridge | `supportedTokens` / `LDtoSDConversionRate` / `totalValueLockedSD` / `remoteChainId` / `weth` / `owner` / `failedMessages` / `trustedRemoteLookup` / `minDstGasLookup` / `precrime` / `useCustomAdapterParams` / `lzEndpoint` / `isTrustedRemote` / `getTrustedRemoteAddress` / `getConfig` views | any | No | Auto-generated getters + view helpers. |
| OriginalTokenBridge | `receive()` payable | any | No | Accepts ETH; no function can ever withdraw stray raw ETH (only WETH unwrap forwards to message `to`). L166 |
| OriginalTokenBridge | `_nonblockingLzReceive(...)` internal | via `nonblockingLzReceive`/`retryMessage` only | **YES (unlock path)** | Requires `srcChainId==remoteChainId(230)`, `supportedTokens[token]`, `packetType==PT_UNLOCK`; `TVL -= totalAmountSD`; transfers `withdrawalAmountSD*rate`. L125-144 |
| TokenBridgeBase | `setUseCustomAdapterParams(bool)` | owner | Config only | L23-26 |
| TokenBridgeBase | `renounceOwnership()` override | owner (no-op) | No | Overridden empty body — ownership can never be renounced. L38 |
| TokenBridgeBase | `_checkAdapterParams` / `PT_MINT` / `PT_UNLOCK` | internal/constants | No | Send-side validation; with flag=true requires adapterParams len≥34 and gas ≥ `minDstGasLookup[230][0]`=100000. L10-13, L29-35 |
| LzApp | `lzReceive(srcChainId,srcAddress,nonce,payload)` | **endpoint** (0x66A7…/0x3c22…/0xb631…) | Delivery path (then gated by trusted remote + nonblocking wrapper) | Checks `_msgSender()==lzEndpoint` **and** `keccak256(srcAddress)==keccak256(trustedRemoteLookup[srcChainId])` with non-zero length. L31-40 |
| NonblockingLzApp | `nonblockingLzReceive(...)` | **self** | No directly | Only reachable through `_blockingLzReceive`'s self-call. L37-41 |
| NonblockingLzApp | `retryMessage(srcChainId,srcAddress,nonce,payload)` payable | **any** (stored-msg gate) | Re-executes a stored unlock | `failedMessages[src][srcAddress][nonce] != 0` + exact payload hash; deletes entry then calls `_nonblockingLzReceive`. Entry can only be created by an endpoint-delivered, trusted-remote-validated message. `msg.value` is silently retained (no refund). L46-56 |
| LzApp | `setConfig(version,chainId,configType,config)` | owner | Can change ULN config/executor for this OApp | Calls `endpoint.setConfig` with `msg.sender = bridge` — the only way a custom (possibly weaker) config could ever be attached to the bridge. L71-73 |
| LzApp | `setSendVersion(version)` / `setReceiveVersion(version)` | owner | Can point endpoint to another send/receive lib | Privileged only. L75-81 |
| LzApp | `forceResumeReceive(srcChainId,srcAddress)` | owner | Clears endpoint `storedPayload` for the bridge only | Cannot create stored payloads unprivileged. L83-85 |
| LzApp | `setTrustedRemote(srcChainId,path)` / `setTrustedRemoteAddress(...)` | owner | Can change unlock source gate | L89-97 |
| LzApp | `setMinDstGas(dstChainId,packetType,minGas)` | owner | Config only | L110-114 |
| LzApp | `setPrecrime(address)` | owner | No | `precrime` is never used anywhere in logic. L105-108 |
| LzApp | `_lzSend(...)` internal | internal | No | Requires `trustedRemoteLookup[remoteChainId]` non-empty. |
| Ownable (OZ 4.9) | `transferOwnership(address)` | owner | Ownership change | L69-72 |
| Ownable (OZ 4.9) | `renounceOwnership()` | owner (no-op override) | — | See TokenBridgeBase. L61-63 |
| ReentrancyGuard | `nonReentrant` on `bridge`/`bridgeNative` only | — | — | Unlock/retry path is **not** behind this guard (endpoint has its own `receiveNonReentrant` for the lzReceive path; retryMessage path has neither — see report F4). |

## Peripheral contracts in the unlock chain

| Contract | Function | Caller gate | Can move principal? | Notes |
|---|---|---|---|---|
| Endpoint v1 (0x66A7… etc.) | `receivePayload(srcChainId,srcAddress,dstAddress,nonce,gasLimit,payload)` | msg.sender must be the UA's receive lib (bridge: default = ReceiveUln301 0x245B…) | Delivers message | Sequential `nonce == ++inboundNonce[src][path]`; reverts if `storedPayload`; on `lzReceive` revert it caches StoredPayload (blocking mode). L100-125 |
| Endpoint v1 | `retryPayload(...)` | any | Re-delivers an endpoint-cached payload only | Requires `storedPayload` entry (ceated from an endpoint-validated message); same nonce. L127-142 |
| Endpoint v1 | `forceResumeReceive(srcChainId,srcAddress)` | the UA that owns the stored payload (bridge → its owner) | Clears cache | L209-222 |
| Endpoint v1 | `setConfig` / `setSendVersion` / `setReceiveVersion` | any caller **for itself only** | Cannot touch bridge | Writes `uaConfigLookup[msg.sender]`; the bridge can only be changed via its own owner-gated wrappers. L176-207 |
| Endpoint v1 | `newVersion` / `setDefaultSendVersion` / `setDefaultReceiveVersion` | endpoint owner (LayerZero) | Can swap default libs for all default-version OApps | Privileged. L149-171 |
| ReceiveUln301 (0x245B… etc.) | `commitVerification(packet,gasLimit)` | **executor only** — `msg.sender == getExecutor(receiver,srcEid)` in `_execute` | Delivers unlock | Also requires effective config satisfied: 4/4 DVNs (3/3 on Fantom), confirmations ≥21; deletes attestations; calls `endpoint.receivePayload`. ReceiveUln301.sol L49-62; ReceiveLibBaseE1.sol L77-102 |
| ReceiveUln301 | `verify(header,payloadHash,confirmations)` | **any** | No (only records `hashLookup[…][msg.sender]`) | Permissionless, no header validation; only addresses listed in the ULN config ever count in `_checkVerifiable`. ReceiveUlnBase.sol L43-46 |
| ReceiveUln301 | `setConfig(eid,oapp,type,config)` | onlyEndpoint, with `oapp = endpoint caller` | Could weaken bridge config **only if bridge (owner) calls it** | Endpoint forwards `msg.sender` as oapp. ReceiveUln301.sol L29-43 |
| ReceiveUln301 | `setDefaultUlnConfigs` / `setDefaultExecutors` / `setAddressSize` | lib owner (LayerZero) | Can set DVNs/executor per eid | `setAddressSize` reverts if already set (`addressSizes[230]=20` is frozen). UlnBase.sol L55-70; ReceiveLibBaseE1.sol L57-64 |
| Default executor (0x1732… on Ethereum) | proxy fallback → implementation | implementation-dependent | Cannot forge attestations | EIP-1967 upgradeable proxy, admin 0xa367…, impl 0x1Ed8… (public source unverified). Even a permissionless execute entrypoint cannot bypass the DVN check inside `commitVerification`. |

**Bottom line for the table:** the only functions that can ever decrease `totalValueLockedSD` or move locked
principal are `_nonblockingLzReceive` (internal) and `retryMessage` (which can only replay messages that already
passed the endpoint + trusted-remote gate). No external function writes TVL or transfers principal without an
owner key or a DVN-attested LayerZero message.
