# Enjin legacy CryptoItems — incident + platform analysis (C2-23)

All data read-only from Ethereum mainnet. Addresses verified with `eth_getCode`/`eth_call`.
No transactions were signed or sent. Keyed RPC URLs are redacted; all scripts read endpoints from env.

## 1. Incident at a glance

| Item | Value |
|---|---|
| Exploit tx | `0xd4a382da03c99ce3084661b913b50b525a4b283f66f510bcf1040152830b2a7e` |
| Block | 25,834,071 (2026-08-25) |
| Attacker EOA | `0x5ec1BA7892D11059c39557b762a97DD695778Ca5` |
| Attack contract | `0x7083DdecE38216C7741fa76c75326Bea744ED321` (owner = attacker EOA) |
| Compromised proxies | NFT template `0x13fA4b9a6C2F2604C919f96F456e3B50E968b157`, FT template `0x268c039a3127D3107c014F0DC6c390a53E6dB27f` |
| Proceeds in tx | 5,238,353 ENJ from the Adapter reserve (5,231,353 to attacker + 7,000 fee) |
| Total attacker extraction | **6,453,855.47 ENJ** from the reserve across ~370 blocks (vault→attack-contract ENJ transfers, Etherscan logs) |
| Post-incident reserve | Adapter `0x4E643a25a64952895f553f20252861258727174e` still holds **3,272,608.45 ENJ** (2026-10-09) |

## 2. Architecture (verified)

```
        PA 0xfaaFDc07…043C (facade, selector-routed via its own `delegates` table)
        ├─ 0x684811e5 (balanceOf)
        ├─ 0x68ee930e (CryptoItemsAdapters):
        │     0x33d332ab deployAdapter(uint256,string,uint8)   <- shell factory (was permissionless)
        │     0x41c1df0e transferNonFungiblesFromAdapter(operator,from,to,id)   <- NFT gateway
        │     0xf95d7da3 transferFungiblesFromAdapter(operator,from,to,id,amount) <- FT gateway
        │     0xddeadbb6 getAdapter(uint256)
        ├─ 0x1b73f458 (CryptoItemsUsers: 0xf6089e12 melt(uint256[],uint256[]))
        └─ 0x553f1e22 / 0x9a67aef2 / 0xc6bc3e5f / 0xd257ea24 (melt sub-modules)

        Adapter 0x4E643a25…174e (eternal storage)
        ├─ holds item ledger (owner-of-record mapping) + ENJ reserve (3.27M ENJ today)
        └─ only approved caller may write (PA); direct writes revert for anyone else

        NFT template 0x13fA…b157 / FT template 0x268c…d27f ("Managed" delegatecall proxies)
        ├─ slot0 manager, slot1 pendingManager, slot2 delegates mapping, fallback -> delegates[msg.sig]
        ├─ native: getManager() 0xd5009584, transferManager(address) 0xba0e930a,
        │          acceptManager() 0x48ff15b3, delegates(bytes4) 0xa0a2daf0
        └─ per-base-type "shell" contracts lazily deployed by PA; shells consult the template's
           delegates table for every selector (a shared routing table for all shells)
```

## 3. Exploit mechanism (exact)

1. `delegates[0xfe4b84df]` (= `initialize(uint256)`) on both templates routed to the item
   adapter implementations (`0x24591e79` NFT / `0x75512f84` FT). Those implementations keep their own
   storage layout (`slot1 = _ownerOf`, `slot2 = _totalSupply`) and have an **unauthenticated**
   `initialize(uint256)` (`require(_totalSupply == 0)` passes because the proxy's slot2 mapping base is 0).
2. Any caller invokes `NFT_TEMPLATE.initialize(1)` → `DELEGATECALL` to `0x24591e79` →
   `slot1 = msg.sender` = **proxy's `pendingManager`** (storage-slot collision).
3. Caller calls native `acceptManager()` → `manager = msg.sender`.
4. As manager: `updateContract(address,string,string)` (`0x61455567` → `0x04866013`) rewrites the
   shared routing table. Attacker registered a private selector `stealNFT(address,address,uint256)`
   (`0x6453dcf6`) on the NFT template and `transferFrom(address,address,uint256)` (`0x23b872dd`) on the FT
   template → their contract `0x99294e5e`; also replaced `initialize`/`acceptManager` routes with
   lock stubs (`0x73497e1c` / `0x6561d8a6`) to prevent re-takeover.
5. `PA.0x33d332ab` lazily deployed a shell per target baseType; calling
   `shell.stealNFT(victim, attacker, id)` made the shell execute the attacker's implementation via
   DELEGATECALL and call the PA gateway `0x41c1df0e(attacker, victim, attacker, id)` as the shell —
   passing `require(getAdapter(baseType) == msg.sender)` — reassigning the ledger's owner without any
   approval from the victim.
6. `PA.melt(ids, amounts)` burned each stolen instance and released its ENJ backing from the reserve.

The guard string on the attacker's adapter is `only pwn`
(`require(msg.sender == 0x7083Ddec…, "only pwn")`) — both steal selectors are gated to the original
attack contract, whose own write functions are `owner`-gated (owner = attacker EOA).

## 4. What changed after the incident (mitigation)

* **Enjin global lock**: tx `0xe7f2d0a3b90250adcbba7f0a82900d20510ba5584a47aa8aafe9869a25e81c27`
  at block **25,835,670** — EOA `0x0c49daa59Ac390c7B87027F5FA6Bd2eC83bEA349` → Adapter manager contract
  `0xE5cb0C8E…` (selector 0x12371416) → `Adapter.globalLock()` (0x8e1f81bb). The Adapter emitted
  `0xd8d7d71f…(true)` and `isGlobalLocked()` has been true since. This froze **all transfers and melts**,
  including for legitimate owners.
* **Enjin mitigation tx**: `0x2d92aed4d9a7147ba6588e329b25a9ffcb66278bf939eeaf534d7697cf60a57e`
  at block **25,853,511** (≈2.7 days after the exploit), from `0x1421d753DcEc9Ac1589c29D1D046Aa6e4C18A028`
  (PA manager EOA) to PA, method `updateContract(address,string,string)` with
  `_delegate = address(0)` and signatures:
  `deployAdapter(uint256,string,uint8); transferFungiblesFromAdapter(address,address,address,uint256,uint256); transferNonFungiblesFromAdapter(address,address,address,uint256); setApprovalForAllAdapter(address,uint256,bool,address);`
  → the PA routing entries for `0x33d332ab`, `0xf95d7da3`, `0x41c1df0e`, `0xfed9dc6a` were set to 0,
  and PA's fallback now reverts `Function does not exist.` for them (for every caller).
* The templates stayed compromised (manager = attacker contract, permanently: `initialize` locked,
  `acceptManager` needs non-zero pendingManager which can no longer be written). But the attacker's
  manager rights no longer lead anywhere because the item-moving gateways and the shell factory are
  disabled on PA, and PA's own `updateContract` is manager-only for Enjin (`Sender is not manager.` for others).
* Platform activity: **0 logs from PA in the last 100,000 blocks** (checked at block 26,152,504).
  The last protocol flows are the attacker's Aug-25/26 sweep.

## 5. Current status (latest block 26,152,504, 2026-10-09)

| Check | Value |
|---|---|
| NFT/FT template manager | `0x7083Ddec…` (attacker contract; owner = attacker EOA) |
| pendingManager (slot 1) | 0 on both |
| `initialize(1)` via templates | revert `locked` |
| `acceptManager()` | revert `Managed: Sender must be the new manager` |
| `transferManager` / `updateContract` on templates | revert `Managed: only manager` / `Sender is not manager.` |
| Malicious adapter registered? | yes: NFT `0x6453dcf6`→`0x99294e5e`, FT `0x23b872dd`→`0x99294e5e` |
| Calling those via shells | revert `only pwn` (caller must be `0x7083Ddec…`) |
| PA gateways `0x41c1df0e` / `0xf95d7da3` | revert `Function does not exist.` (disabled) |
| PA shell factory `0x33d332ab` | revert `Function does not exist.` (disabled) |
| PA `updateContract` | revert `Sender is not manager.` |
| Adapter direct writes (`0x95760fb9`, `0x7843e5dd`) | revert (not approved) |
| Adapter reserve | 3,272,608.45 ENJ |
| PA activity last 100k blocks | 0 logs |

`melt()` is routed but **frozen**: the Adapter is globally locked since block 25,835,670 (Enjin
emergency tx `0xe7f2d0a3b90250adcbba7f0a82900d20510ba5584a47aa8aafe9869a25e81c27`). The same
holder+item melt sim succeeds at block 25,834,070 and reverts at latest — proven in the PoC (test 07).
The Adapter manager `0xE5cb0C8E…` can `globalUnlock()` and `releaseERC20()` (P).

## 6. Files

* `incident_tx.json`, `incident_receipt_summary.json`, `incident_trace_calls.json` — raw decoded incident data
* `mitigation_tx.json` — decoded Enjin mitigation tx
* `vault_out_attacker.json` — reserve→attacker ENJ transfers (total 6,453,855.47 ENJ)
* `disasm/0x99294e5e.asm` — disassembly of the attacker's adapter (shows the `only pwn` gate)
