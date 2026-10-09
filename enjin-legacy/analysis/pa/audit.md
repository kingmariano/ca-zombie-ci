# Enjin legacy CryptoItems — PA / Adapter audit (C2-23 zombie-hunt II)

**Scope:** PA facade `0xfaafdc07907ff5120a76b34b731b278c38d6043c` and storage Adapter
`0x4e643a25a64952895f553f20252861258727174e` (+ all module contracts currently reachable through PA).
**Method:** read-only. `eth_call` / `eth_getCode` / `eth_getStorageAt` / explorer APIs only.
No transactions were signed or sent.
**Latest block used: 26152687** (state verified at this block; the tx-history and simulation
evidence was collected between blocks 26152497–26152687 on 2026-10-09).
**RPC:** NodeReal/BlockPi (keyed URL from env only, never written to disk).

Artifacts: `selectors.json` (machine-readable full table), `raw/` (evidence: storage dumps,
traces, simulations, tx samples), `decompiled/` (heimdall outputs for PA, Adapter, modules
A/B/C/D/E/G/H/I/J/K, `0x04866013`, `0x130ed4c3`), `code/` (raw bytecode of every contract).

---

## 0. Executive summary

| Question | Answer |
|---|---|
| (a) Can an external unprivileged attacker, at the latest block, **move any item ownership**? | **No.** Module I revert: `CryptoItemsTransfers: Sender is not approved`; Adapter writes are platform-gated and the Adapter is additionally **globally locked**. |
| (b) Can an unprivileged attacker **release any ENJ** from the Adapter reserve (3,272,608.45 ENJ)? | **No.** Melt only pays for balances the caller actually burns; ENJ-out functions on the Adapter revert for random callers (also pre-lock); the manager contract's `releaseERC20` reverts `Sender is not a manager.` |
| (c) Can an unprivileged attacker **register/overwrite adapters or repoint PA modules**? | **No.** `deployAdapter` was removed from PA routing on 2026-08-28 (delegates set to 0, verified across blocks 25853510→25853511); direct calls on module B revert; the only table mutator is `updateContract` (manager-only, PA manager EOA). |

The PA is **not** a proxy/upgradeable contract (EIP-1967 impl/admin slots = 0; no `owner()`).
It is a stateless-looking facade with an internal selector→module registry (`delegates(bytes4)`,
storage slot 2) plus 6 hardcoded admin selectors. A new mechanism was discovered: the registry
**can** be updated by the PA manager through routed selector `0x61455567` (module `0x04866013`),
and chain evidence shows it was used on 2026-08-28 to disable 4 adapter entry points.

---

## 1. PA dispatch model

PA bytecode is ~997 bytes. Dispatch (disassembly `decompiled/PA-disassembled.asm`, decompile `decompiled/PA-decompiled.sol`):

1. 6 selectors are handled **in PA itself** (hardcoded compare table):
   - `0x48ff15b3 acceptManager()` — caller must equal slot1 (pendingManager); promotes pending → manager (slot0), emits `ManagerUpdate`; then clears pending.
   - `0x7457bbf7` (unresolved in all 4byte DBs; **getter returning slot1** = pendingManager) — view.
   - `0x8d0a3a08 removeManager()` — caller must equal slot0 (manager); zeroes manager+pending.
   - `0xa0a2daf0 delegates(bytes4)` — view; returns `delegates[selector]` (mapping at slot 2).
   - `0xba0e930a transferManager(address)` — caller must equal slot0; sets slot1 = new pending.
   - `0xd5009584 getManager()` — view; returns slot0.
2. Any other calldata selector: `key = keccak256(bytes4‖0…0 ‖ uint256(2))`; `impl = SLOAD(key)`.
   - If `impl == 0` → revert `"Function does not exist."`
   - Else `delegatecall(impl, calldata)`; returndata bubbled exactly (revert data preserved).
3. **Storage layout observed on PA** (block 26152687): slot0 = manager `0x1421d753…` (EOA, empty code);
   slot1 = 0 (no pending manager); slot2 = `delegates` mapping base; slot3 = 0x76 counter;
   slot5 = PA itself; slot6 = storage contract = Adapter `0x4e64…`.

**Module registration/mutation:** there is no `setDelegate` in the hardcoded set, but routed
selector **`0x61455567 updateContract(address,string,string)`** (module `0x04866013`) writes the
registry: it is guarded by `require(msg.sender == getManager(), "Sender is not manager.")` and
validates delegate code + "FuncId clash." before committing. Chain proof of mutation:

| block | `delegates[0x33d332ab]` |
|---|---|
| 25853510 | `0x68ee930e…` (module B) |
| 25853511 | `0x0000…0000` |
| latest | `0x0000…0000` |

The tx at 25853511 is `0x2d92aed4…57e` sent **by the PA manager EOA `0x1421d753…`** with
`updateContract(address(0), "deployAdapter(uint256,string,uint8);transferFungiblesFromAdapter(…);transferNonFungiblesFromAdapter(…);setApprovalForAllAdapter(…);", "Disable unused ERC adapter entry points")`.

---

## 2. Full selector table (74 routed at latest block; 6 hardcoded)

Machine-readable: `selectors.json`. Summary by module (all confirmed against live storage keys
`keccak(selector‖02)` — script `tools/extract_selectors.py`, results `raw/selector_routing.txt`):

| module | routed selectors | role |
|---|---|---|
| `0x684811e5…` (A) | 6: `00ad800c name`, `00fdd58e balanceOf`, `0e89341c uri`, `4e1273f4 balanceOfBatch`, `a22cb465 setApprovalForAll`, `e985e9c5 isApprovedForAll` | ERC-1155 read/approval surface |
| `0x68ee930e…` (B) | 5: `6352211e ownerOf`, `9bb7f44e`, `b97f0eb7` (manager-only helper), `ddeadbb6 getAdapter(uint256)`, `f0342125 getStorageContract()` | adapter/ownership queries (its 4 gateway/deploy selectors were **disabled 2026-08-28**, see §3.2) |
| `0x1b73f458…` (C) | 21 (`f6089e12 melt`, item metadata/scope queries & setters) | CryptoItemsUsers |
| `0x7d846227…` (I) | 4: `f242432a safeTransferFrom`, `2eb2c2d6 safeBatchTransferFrom`, `ff469a8e safeMulticastTransferFrom`, `12ab550f` | movement logic |
| `0x29bb095b…` (J) | 7: `28dbff7b`, `2df3f42a`, `3941412b`, `4049ddd2 chainId`, `7e2c20ad`, `a3c4f748 isReplicated`, `fb2b9992` | bridge/replicate helpers, "Bridge is not the creator of _id" guards |
| `0x6df3f217…` (K) | 26: `cd23dde0 create`, `3d7d20a4 mintFungibles`, `00549c2b mintNonFungibles`, `e07d3b5a assign`, `6907be85 acceptAssignment`, `862440e2 setURI`, `34e07ff3 setTransferable`, `a6566f8d setMeltFee`, `934930a1 setTransferFee`, `e6e21c75 setWhitelisted`, `c2eed0de releaseReserve`, `819b25ba reserve`, … | item admin |
| `0xd6afd25d…` (H) | 2: `b37cd03d getStorageContractAddress()`, `c4d66de8 initialize(address)` | storage pointer init (manager-only) |
| `0x04866013…` | 1: `61455567 updateContract` | **delegate-table mutator (manager-only)** |
| `0x130ed4c3…` | 2: `0aa6231e`, `c8b1d5e1` | events, "Sender is not manager or approved" guards |

Note: selector names were resolved with OpenChain/4byte; a few remain unresolved
(e.g. `9bb7f44e`, `0565276f`, `71f77a64`) — marked in `selectors.json`.

---

## 3. Module findings (guards)

### 3.1 Movement module I — `0x7d846227…` (`safeTransferFrom`, `safeBatchTransferFrom`, multicast)
- Requires `msg.sender == _from` for the direct case and staticcalls the Adapter to test scope
  approvals ("CryptoItemsTransfers: Sender is not approved" / "…Receiving contract did not
  return ERC1155_ACCEPTED"). Uses delegatecall libraries `0xc6bc3e5f` (F) and module B helpers.
- Simulation from a random EOA (`0x…1111`) transferring a real item:
  `CryptoItemsTransfers: Sender is not approved` (evidence `raw/simulation_battery.txt`).
- The Adapter move itself (`ffaf6633`, `95760fb9`, `bf73f5b2`) is **platform-gated + lock-gated**
  (see §4). Successful tx trace (block 25495637): `user → PA → delegatecall I → staticcalls
  Adapter 73007500/0a432df0 → call Adapter ffaf6633` (succeeded pre-lock).

### 3.2 Module B gateways + deploy shell — `0x68ee930e…`
- `ddeadbb6 getAdapter(uint256)` / `f0342125 getStorageContract()` are public views that read the
  Adapter (owner ledger). `b97f0eb7` requires `msg.sender == getManager`
  ("CryptoItemsAdapters: Sender is not the manager").
- `41c1df0e transferNonFungiblesFromAdapter` / `f95d7da3 transferFungiblesFromAdapter` require
  `getAdapter(id) == msg.sender` ("CryptoItemsAdapters: Sender is not the adapter for _id") — only
  the registered shell/adapter token can pass.
- `33d332ab deployAdapter(uint256,string,uint8)`: deploys a new shell via a vtable pointer stored
  in the Adapter and registers it; validates base type vs single id ("Cannot deploy an adaptor on
  a single non fungible id", "vtable is 0").
- **Status at latest block:** all four (`33d332ab`, `41c1df0e`, `f95d7da3`, `fed9dc6a`) are
  **not routed** — `delegates[] = 0`, disabled at block 25853511 (§1). Direct calls to module B for
  these revert (`raw/simulation_battery.txt`), because module B's own storage has
  `getStorageContractAddress == 0` (its storage slots are empty except a legacy manager), so the
  `extcodesize` guard fails before any adapter check — i.e. address(0)-caller bypasses are
  impossible.
- Modules B/C/D/E/F/G/H/I/J/K all have their **own** storage with only slot0 set to a legacy EOA
  `0x1952e45d…`; `getStorageContractAddress` is **zero** in their own context, so standalone use of
  their adapter-facing functions reverts. They only operate as delegatecall targets of PA.

### 3.3 Melt (`f6089e12`) — module C `0x1b73f458…` → libraries D `0x553f1e22…`, E `0x9a67aef2…`, G `0xd257ea24…`, F `0xc6bc3e5f…`
- `melt` has no caller whitelist, but it delegatecalls library D which:
  - requires the item to be created on this chain (`getUint(0xe4b9bbf5…)`), computes burn amounts from
    the caller's holdings via libraries E/G, delegatecalls them, then calls the Adapter's
    token-out function `0x7843e5dd(recipient=msg.sender, amount)` **from the PA context**.
  - The Adapter pays only to the melter and only for balances burned in the same call; the ENJ
    (token at Adapter slot15 = `0xf629cbd9…`) comes from the reserve the Adapter holds.
- Simulation from a random EOA at latest block reverts (empty revert data — lock/balance path);
  an attacker has nothing to burn, so even without the lock this is not a theft path.
- Last **successful** melt on-chain: block **24554698** (2026-02-28). 423 melts succeeded before it
  in the sampled window; none after.

### 3.4 Item-admin module K `0x6df3f217…`
- `setURI`, `setTransferable`, `setMeltFee`, `setTransferFee`, `setWhitelisted`, `mintFungibles`,
  `mintNonFungibles`, `assign`, `releaseReserve`, `updateName`, etc. all resolve the item creator
  through the Adapter and revert `CryptoItemsCreators: Sender is not the creator of _id` for
  non-creators (verified by simulation). `releaseReserve` (creator-only) is the only path that
  intentionally lets reserve funds leave to a user.
- Manager-only entries in these modules (`transferManager`/`removeManager` style) revert for
  random callers.

### 3.5 Module H `0xd6afd25d…` and module `0x04866013…`
- `c4d66de8 initialize(address)` (H, routed): `"Managed: only manager"` — sets the storage-contract
  pointer (slot6) and calls the new storage contract. Manager-only; no one-shot flag, but caller
  must be PA slot0.
- `61455567 updateContract(address,string,string)` (`0x04866013`, routed): **manager-only**
  (`"Sender is not manager."`), writes the PA `delegates` table (register or disable selector
  entries; "FuncId clash." checks). This is the module-table mutator.

---

## 4. Adapter `0x4e643a25…` — ledger, gates and ENJ reserve

- Holds the item ledger (ownerOf/balance slots, mappings) and **3,272,608.451601512688826076 ENJ**
  (verified latest block; Adapter slot15 = ENJ token address).
- Every mutating function follows the same guard pattern (decompiler renders it as a mapping read):
  platform check + (for several classes) `isGlobalLocked` checks. Empirical probe matrix:

| call | from random EOA | from PA (control) |
|---|---|---|
| `setUint(bytes32,uint256)` @ latest | revert | revert (locked) |
| `setUint(bytes32,uint256)` @ 25800000 (pre-lock, archive) | revert | **success** |
| `7b129b06(uint256,address)` (adapter registry setter) @ pre-lock | revert | **success** |
| `addApprovedAddress` / `removeApprovedAddress` | revert | (manager-gated, not PA) |
| `mintFungible` | revert | revert |
| `releaseETH` | revert | — |
| `globalLock` / `globalUnlock` | revert | manager contract passes `globalUnlock` |
| `7843e5dd` (token payout) pre-lock | revert | revert (extra conditions) |
| `69326b68` (token payout) pre-lock | revert | revert |

  => random callers can never write; PA can write only when unlocked and only through registered
  module code paths.
- **Global lock:** `isGlobalLocked() == true` at latest block. It was set at block **25835670**
  (2026-08-25) by EOA `0x0c49daa5…` calling `lockStorage()` on the Adapter's manager contract
  **`0xE5cb0C8E160C5aC4669D1dfD689Df01bA9eea3eB`** (the only Adapter event in 24M→latest is the
  lock event; data `…01`). `lockStorage()` from a random EOA reverts `Sender is not a manager.`
  The manager contract can call `globalUnlock()` (spoof-simulation succeeded), so unfreezing is a
  manager action, not available to outsiders.
- **`isApprovedAddress(x)` getter (0xb4c8c5c4) returns false for PA and all modules** while the
  platform write-gate nevertheless accepts PA (proven: successful `setUint`/`7b129b06` from PA at
  pre-lock blocks; successful adapter write inside tx at block 25495637). The getter reads a
  different list than the write gate — documented discrepancy, no security impact found.
- Adapter manager = `0xE5cb0C8E…` (contract). Its functions (`releaseERC20`, `releaseERC1155`,
  `releaseERC721`, `releaseETH`, `lockStorage`, `transferManager`, `acceptManager`, `resetApproval`,
  approval counts) are all manager-gated; `releaseERC20(ENJ, attacker, 1e18)` from random reverts
  `Sender is not a manager.`.

---

## 5. Proxy / upgradeability checks

- EIP-1967 implementation slot `0x360894…382bbc` and admin slot `0xb53127…5d6103` are **zero** on
  PA, Adapter and manager contract. EIP-1822/ZeppelinOS slots also zero. No `owner()` function
  (delegates[0x8da5cb5b] = 0 → "Function does not exist.").
- PA manager: EOA `0x1421d753DcEc9Ac1589c29D1D046Aa6e4C18A028` (empty code); no pending manager.
  Two-step transfer (`transferManager` → `acceptManager`).
- **Who can repoint PA modules?** Only the PA manager, via manager-only `updateContract` (module
  `0x04866013`). The manager is NOT the compromised `0x7083ddece38216c7741fa76c75326bea744ed321`
  from the sibling subagent's context; `0x7083ddece…` does not appear as manager/pending/owner of
  PA, Adapter, module H or the manager contract E5cb (checked storage slots 0–40/0–120 of each).
- The Adapter's manager (`0xE5cb0C8E…`) can lock/unlock and release tokens; E5cb itself is
  controlled by a small set of manager EOAs (`0x0c49daa5…`, `0x073Cc6d7…` observed calling it).

---

## 6. Freeze timeline (2026)

| block | event |
|---|---|
| 24554698 (Feb 28) | last **successful melt** (ENJ release) |
| 25495637 (Jul) | last successful item **transfer** in sample |
| 25819814 (Aug 23) | last successful `setApprovalForAll` |
| **25835670 (Aug 25)** | manager EOA `0x0c49daa5…` calls `lockStorage()` → **Adapter globally locked** |
| **25853511 (Aug 28)** | PA manager EOA `0x1421d753…` calls `updateContract(0, "…adapter signatures…")` → 4 adapter entry points **removed from PA routing** |
| 26067701+ (Sep 27) / 26125127+ (Oct 5) | user attempts (`setApprovalForAll`, `safeTransferFrom`) all revert on-chain |

---

## 7. Explicit conclusions at latest block 26152687

**(a) Move items — NO.**
Unprivileged path tested and rejected: `PA.safeTransferFrom(victim, attacker, id, 1, "")` from
`0x…1111` → `CryptoItemsTransfers: Sender is not approved`. The Adapter write functions that
actually move balances (`ffaf6633`, `95760fb9`, `bf73f5b2`) are reachable only from the PA context
and are frozen by `isGlobalLocked`. Even the legitimate owner currently gets an empty-revert
(lock path), matching the on-chain failures of Sep 27 and Oct 5.

**(b) Release ENJ — NO.**
Payouts execute only via Adapter token-out functions called from PA-delegated melt code, after the
caller burns their own balances (payout recipient = caller, amount computed from own holdings);
random-caller melt reverts. Manager contract `releaseERC20` reverts `Sender is not a manager.` for
outsiders. The reserve has not moved since Feb 2026; it is frozen by the global lock.

**(c) Register/overwrite adapters, repoint modules — NO.**
`deployAdapter` (previously routed) was **removed from PA routing** on 2026-08-28 (delegates
zeroed — verified block-exact). Direct calls to module B's `33d332ab`/`41c1df0e`/`f95d7da3` from a
random EOA revert. The Adapter adapter-registry setter `7b129b06` rejects random callers (accepted
only from PA context pre-lock). The delegates table can only be changed by the manager through
`updateContract`.

**Residual risk (not external-attacker reachable):** the PA manager EOA can re-enable/repoint
module selectors via `updateContract`; the Adapter manager contract (`0xE5cb0C8E…`, controlled by
its manager EOAs) can `globalUnlock()` and `releaseERC20()`. These are trusted-role powers and the
natural next step for any "who could still drain the 3.27M ENJ" question.

---

## 8. Evidence index (`analysis/pa/`)

- `selectors.json` — full selector/module/guard table + disabled selectors + manager map
- `raw/PA_storage_slots_0_40.txt` — PA slot dump
- `raw/module_discovery.json`, `raw/selector_routing.txt` — iterative module discovery closure (241 selectors inspected)
- `raw/simulation_battery.txt` — all eth_call probes from random EOA (revert reasons)
- `raw/tx_f242432a_rawtrace.json`, `raw/trace_*.json` — success vs failure call trees
- `raw/tx_updateContract.json`, `raw/etherscan_pa_txlist_desc.json` — routing-change evidence
- `raw/etherscan_logs_0x4e643a25.json` — global-lock event at block 25835670
- `tools/extract_selectors.py`, `tools/discover_modules.py`, `tools/simulate_battery.sh` — reproducers
- `decompiled/*.sol|asm|abi.json` — heimdall outputs for PA, Adapter, modules A/B/C/D/E/F/G/H/I/J/K, `0x04866013`, `0x130ed4c3`
- `code/*.hex` — raw bytecode for every address analysed
