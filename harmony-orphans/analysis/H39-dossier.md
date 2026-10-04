# H-39 dossier — "ONE for BSC" / "ONE for Ethereum" NativeOFT escrows (Harmony)

**Status:** read-only research. All calls are `eth_call` / `cast call` / `cast storage` / Blockscout reads.
Fork verification in CI (`poc/test/HarmonyOrphans.t.sol`, 11/11 PASS, run 37188265963).
**Block of record:** Harmony 93,624,315 (2026-10-04). Price: ONE = $0.00245693 (DefiLlama, 2026-10-04).

## 1. Identification (resolved from abbreviated H-39 lead)

| Contract | Name (on-chain) | Balance | Share of supply held by itself |
|---|---|---|---|
| `0x5B18a4E73F9A4fe337A072516b317863Ad3046aA` | "ONE for BSC" (symbol ONE, 18 dec) | 62,531,259.468551870330371539 ONE | 100% |
| `0x905582f21fB9855c809d5b8933272a292dfbB138` | "ONE for Ethereum" (symbol ONE, 18 dec) | 13,101,396.431214960428021286 ONE | 100% |

Both are the **LayerZero v1 `NativeOFT` extension** (`solidity-examples`, OFT + ReentrancyGuard + payable `sendFrom`),
decompiled and matched byte-for-byte against the open-source source:
- code keccak (both, identical) = `0x4310a9b25a66146421b849c2109a6e66a87c12342b84c18d4ba049c00a3a38f2`, 24,336 bytes, unverified on explorer.
- LZ endpoint hard-coded: `0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4`.
- Both deployed by and owned by EOA `0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C` (code size 0, nonce 460,
  balance 72.42 ONE); "ONE for BSC" creation tx timestamp 2022-10-17.
- The explorer address name is the contract's own `name()`; the addresses are *not* bridge relayers or safes.

## 2. Mechanism (exact, from matched source)

```
deposit()            payable: _mint(msg.sender, msg.value)                     // wrap native -> internal balance
withdraw(amount)     nonReentrant: require(balanceOf(msg.sender) >= amount);   // unwrap own balance only
                     _burn(msg.sender, amount); msg.sender.call{value: amount}
sendFrom(_from,...)  payable: _debitFromNative(_from, ...)
   _from == msg.sender: mint shortfall from msg.value, _transfer(msg.sender, address(this), amount)
   _from != msg.sender: mint shortfall to msg.sender, _spendAllowance(_from, msg.sender, rest),
                        _transfer(_from, address(this), amount)
   then _lzSend(...) via endpoint (outbound message)
lzReceive(...)       require(msg.sender == lzEndpoint); require(_srcAddress == trustedRemoteLookup[srcChainId]);
   _creditTo: _burn(address(this), amount); recipient.call{value: amount}       // inbound payout
receive()            payable: deposit()
```

Escrow semantics: internal balances are locked at the contract when bridging out (`sendFrom` transfers them to
`address(this)`); inbound messages burn that locked balance and pay native out. There is **no owner rescue/withdraw**
function; the owner can only reconfigure the bridge (`setTrustedRemote*`, `setSendVersion`, `setReceiveVersion`,
`setConfig`, `setPrecrime`, `setUseCustomAdapterParams`, `transferOwnership`).

## 3. Live state at block 93,624,315 (all verified on-chain + CI fork)

| Check | "ONE for BSC" | "ONE for Ethereum" |
|---|---|---|
| native balance | 62,531,259.468551870330371539 ONE | 13,101,396.431214960428021286 ONE |
| totalSupply == native balance | yes (exact wei) | yes (exact wei) |
| balanceOf(contract itself) == totalSupply | yes | yes |
| balanceOf(all other sampled addresses) | 0 | 0 |
| owner() | 0xAC0248…7E3C (EOA) | 0xAC0248…7E3C (EOA) |
| trustedRemoteLookup(101) / (102) | `0x` / `0x` (cleared) | `0x` / `0x` (cleared) |
| endpoint getSendVersion / getReceiveVersion | 65535 / 65535 (BLOCK_VERSION) | 65535 / 65535 |
| endpoint hasStoredPayload(101/102, …) | false / false | false |
| useCustomAdapterParams | true | true |

Historical activity: 924 `ReceiveFromChain(102)` events in the indexed window (blocks 72,424,639 → 92,723,721;
~$25.97M ONE paid out inbound), matched 1:1 with `Transfer(OFT → 0x0)` burns; ~$38.07M ONE of deposits/`sendFrom`
locks in the same window. Last inbound event = block 92,723,721, **2026-08-11 19:54 UTC**.

**Freeze event (2026-08-30, blocks 93,144,294 / 93,144,382):** the owner called `setTrustedRemote(102, 0x)` /
`setTrustedRemote(101, 0x)` and `setSendVersion(0xffff)` / `setReceiveVersion(0xffff)` on both contracts
(txs `0x4f91a924…`, `0xf4e5a636…`, `0xc2c666d2…`, `0x147e891b…`, `0x40369fa9…`, `0xc5fd4ef1…`).
Both directions of the bridge are now disabled at the application level.

## 4. Attack-surface enumeration (fork-tested, all reverts)

| Path | Live result | Evidence |
|---|---|---|
| `withdraw(1)` by arbitrary EOA | revert `NativeOFT: Insufficient balance.` | every address sampled has 0 internal balance |
| `lzReceive(...)` by arbitrary EOA | revert `LzApp: invalid endpoint caller` | endpoint-gated |
| `lzReceive(...)` even pranked as the real endpoint | revert `LzApp: invalid source sending contract` | trusted remote empty (also versions BLOCK_VERSION) |
| `sendFrom(_from = OFT)` by arbitrary EOA + value | revert `ERC20: insufficient allowance` | OFT never approved anyone; cannot move its own escrow |
| `setTrustedRemote` / owner setters by arbitrary EOA | revert `Ownable: caller is not the owner` | owner is a single EOA |
| `deposit()` + `withdraw()` roundtrip | works | proves the escrow *can* pay a holder; no current holder exists |
| `hasStoredPayload` retry | nothing stored | no pending message anyone could replay |

## 5. Verdict

- **E-U: $0 (high confidence).** No permissionless path moves value. The 100%-of-supply internal balance sits at the
  contract address itself; `withdraw` is self-only; `lzReceive` is endpoint+trusted-remote gated; `sendFrom` cannot
  debit the contract's own balance (allowance check) and outbound is blocked by BLOCK_VERSION; no owner rescue exists.
- **H-O: $0 today.** Holder self-service (`withdraw`) is real and fork-proven, but no external address holds any
  internal balance. The economic claimants are holders of the wrapped ONE on BSC/Ethereum; their redemption path
  (inbound message) is currently frozen.
- **S (stuck): 75,632,655.899767 ONE ≈ $185,824** — the two escrows. Only the owner can unfreeze.
- **P (latent, owner-gated):** the owner EOA can re-enable versions + trusted remote and then a message from the
  re-configured remote contract would credit an arbitrary internal balance, which `withdraw` converts to native.
  This is the full-drain latent path if the single owner key (0xAC0248…) is compromised — privileged, not E-U.
  The LZ endpoint (`0x9740FF91…`, owner contract `0xE590a673…`) and ULN (`0x50002CdF…`) still have code, and the
  bridge was operational until 2026-08, so this path is live *conditional on the owner key* (medium confidence).

## 6. Family & remote counterparts (verified on BSC/Ethereum, 2026-10-04)

The same owner EOA deployed 92 contracts; the relevant bridge family:
- **Gen-1 OFTs (Harmony):** `0xa2ba7aa169e5c77eb37a5330f2695fee8d1216ac` ("ONE for Ethereum", balance 0) and
  `0x8da02bedf802976a69627dd8ae081493d8fdf0f0` ("ONE for BSC", balance **10 ONE**) — both effectively empty,
  no E-U relevance.
- **Historical trusted remotes of the gen-2 contracts** (set 2022-10-17, cleared 2026-08-30):
  "ONE for BSC" → BSC `0x55b9b75f2d456d010e6b8c6f62544c6efc1c101d` (block 32,725,868), later
  `0x2332137ae0386783ffbcf40d9f17e50890917e15` (block 32,760,784); "ONE for Ethereum" → Ethereum
  `0x768fa1abbc38054f9fb2218e97778cc7b110c779` (block 32,725,818), later `0x234784ec001db36c9c22785cad902221fd831352`
  (block 32,760,763).
- **BSC gen-2 counterpart** `0x2332137ae0386783ffbcf40d9f17e50890917e15` (verified ProxyOFT): `trustedRemote(116)`
  still points at the Harmony OFT, `token()` = Binance-Peg Harmony ONE `0x03fF0ff224f904be3118461335064bB48Df47938`
  (totalSupply 2,461,187,188.29 ONE), ProxyOFT token balance **211,111 ONE**, owner = Safe `0xE3364CC2C65995c924Db6D1F467d9Be275E65E35`.
- **Ethereum 1ONE** `0xD5cd84D6f044AbE314Ee7E414d37cae8773ef9D3` ("Harmony ONE", 1ONE): totalSupply 26,018,624.868 ONE.
- Endpoint `hasStoredPayload` = false for every historical (chainId, src) combination checked — nothing to replay.

Consequence: the Harmony escrows (75.63M ONE) are the **native-side backing** of the wrapped ONE on BSC/Ethereum.
Re-enabling the Harmony side (owner-only) would let remote wrapped-ONE holders redeem against that escrow; today
their inbound path is frozen.

## 7. Files

- Raw: `analysis/oft_logs.json` (3,000 newest logs), `analysis/settr_hist_*.json`, `analysis/heimdall-oneforbsc/`
  (decompiled source + ABI), `analysis/code_0x5B18…txt`, `analysis/code_0x905…txt`, `analysis/txs_0x5B18…json`.
- PoC: `poc/test/HarmonyOrphans.t.sol` (`test_H39_*`, 8 tests), CI run 37188265963 (11/11 PASS, fork block 93,624,315).
