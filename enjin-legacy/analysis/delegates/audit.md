# Enjin legacy CryptoItems templates — full delegates-table reconstruction & audit

- **Scope**: NFT template `0x13fa4b9a6c2f2604c919f96f456e3b50e968b157`, FT template `0x268c039a3127d3107c014f0dc6c390a53e6db27f` (Ethereum mainnet, chainid 1).
- **Method**: full-history `DelegateChanged` logs via Etherscan V2 (`topic0 = 0x3234040ce3bd4564874e44810f198910133a1b24c4e84aac87edbf6b458f5353`), last-write-wins table, live verification of every selector with `cast call <template> "delegates(bytes4)(address)" <selector>`, bytecode pulled with `cast code`, heimdall disassembly of every relevant contract. Read-only: no transactions were signed/sent; all checks are `eth_call`/`eth_getCode`/`eth_getStorageAt`/log queries.
- **Latest block used**: `26152576` (2026-10-09 04:51:23 UTC). All on-chain values below re-read at that block.
- **Raw data**: `analysis/delegates/raw/` — `nft_page_1.json`, `ft_page_1.json` (template histories), `items_page_1.json` (PA/CryptoItems proxy history), `attacker_tx_receipt.json`, `attacker_tx_internal.json`, `cleanup_tx.json`.
- **Artifacts**: `history.json` (ordered event history), `table.json` (current table + verification + delegate catalogue), `decompiled/`, `disasm/` (per-contract heimdall output), scripts `fetch_logs.sh`, `parse_history.py`, `fetch_code.sh`, `fetch_bytecode.sh`, `decompile_all.sh`, `disasm_all.sh`, `build_table.py`, `rpc.sh`.

---

## 1. Reconstruction results

### 1.1 Event history (full history, from block 0)

| Template | Registration events | Distinct selectors ever | First registration | Attacker batch |
|---|---|---|---|---|
| NFT `0x13fa4b9a…` | 21 | **20** | 2021-11-01 (blocks 13530687–13530888) | 3 entries at block 25834071 (2026-08-25 18:41:59 UTC) |
| FT `0x268c039a…` | 15 | **13** | 2021-11-01 (blocks 13530678–13530886) | 3 entries at block 25834071 (same tx) |

All six attacker registrations arrived in a single transaction:
`0xd4a382da03c99ce3084661b913b50b525a4b283f66f510bcf1040152830b2a7e`
(EOA `0x5ec1BA7892D11059c39557b762a97DD695778Ca5` → contract `0x7083ddecE38216C7741fa76c75326Bea744ED321` → templates). The same tx drained 5,238,353 ENJ from the CryptoItems ecosystem and later locked `initialize`/`acceptManager` on both templates.

### 1.2 Current table (verified on-chain at block 26152576)

**NFT template** — manager(slot0) = `0x7083ddec…` (attacker orchestrator), pendingManager(slot1) = `0`, raw slot2 = `1`:

| selector | signature | current delegate | first → last block | changedBy |
|---|---|---|---|---|
| 0x01ffc9a7 | supportsInterface(bytes4) | 0x24591e792a404e5bd48ac0f694339d807b02cfd2 | 13530888 | 0xe76bc5… |
| 0x06fdde03 | name() | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x081812fc | getApproved(uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x095ea7b3 | approve(address,uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x18160ddd | totalSupply() | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x23b872dd | transferFrom(address,address,uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x2f745c59 | tokenOfOwnerByIndex(address,uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x42842e0e | safeTransferFrom(address,address,uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x4f6ccce7 | tokenByIndex(uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x61455567 | updateContract(address,string,string) | 0x04866013862349a6a19a04c8a1590ea2cf026134 | 13530687 | 0x612881… |
| 0x6352211e | ownerOf(uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x6453dcf6 | stealNFT(address,address,uint256) | **0x99294e5e8dd62fa0092a85ab37e8b5c44ec29758** | 25834071 | 0xd4a382… |
| 0x70a08231 | balanceOf(address) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0x95d89b41 | symbol() | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0xa22cb465 | setApprovalForAll(address,bool) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0xb88d4fde | safeTransferFrom(address,address,uint256,bytes) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0xc87b56dd | tokenURI(uint256) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0xe985e9c5 | isApprovedForAll(address,address) | 0x24591e79… | 13530888 | 0xe76bc5… |
| 0xfe4b84df | initialize(uint256) | 0x24591e79 → **0x73497e1c3070a031e1ee05fdeaaeb73c9dd8fcb5** | 13530888 → 25834071 | 0xd4a382… |
| 0x48ff15b3 | acceptManager() | 0x6561d8a6dd7e184308555b21b115ebe122136036 *(shadowed)* | 25834071 | 0xd4a382… |

**FT template** — same manager/pendingManager/slot2 state:

| selector | signature | current delegate | first → last block | changedBy |
|---|---|---|---|---|
| 0x01ffc9a7 | supportsInterface(bytes4) | 0x75512f843d8d22593d7256708ef80a22b97baf5e | 13530886 | 0x77255b… |
| 0x06fdde03 | name() | 0x75512f84… | 13530886 | 0x77255b… |
| 0x095ea7b3 | approve(address,uint256) | 0x75512f84… | 13530886 | 0x77255b… |
| 0x18160ddd | totalSupply() | 0x75512f84… | 13530886 | 0x77255b… |
| 0x23b872dd | transferFrom(address,address,uint256) | 0x75512f84 → **0x99294e5e…** | 13530886 → 25834071 | 0xd4a382… |
| 0x313ce567 | decimals() | 0x75512f84… | 13530886 | 0x77255b… |
| 0x61455567 | updateContract(address,string,string) | 0x04866013… | 13530678 | 0x60fc4b… |
| 0x70a08231 | balanceOf(address) | 0x75512f84… | 13530886 | 0x77255b… |
| 0x95d89b41 | symbol() | 0x75512f84… | 13530886 | 0x77255b… |
| 0xa9059cbb | transfer(address,uint256) | 0x75512f84… | 13530886 | 0x77255b… |
| 0xdd62ed3e | allowance(address,address) | 0x75512f84… | 13530886 | 0x77255b… |
| 0xfe4b84df | initialize(uint256) | 0x75512f84 → **0x73497e1c…** | 13530886 → 25834071 | 0xd4a382… |
| 0x48ff15b3 | acceptManager() | 0x6561d8a6… *(shadowed)* | 25834071 | 0xd4a382… |

Each delegate value above was re-read from storage via `delegates(bytes4)` at block 26152576 and matches the last-write-wins reconstruction (100% match; `allVerified=True` in `table.json`).

**Important dispatcher detail** (from bytecode at `0x13fa4b9a`/`0x268c039a`): the templates handle six selectors **internally, before consulting the delegates table**: `0x48ff15b3 acceptManager()`, `0x7457bbf7 pendingManager()`, `0x8d0a3a08 removeManager()`, `0xa0a2daf0 delegates(bytes4)`, `0xba0e930a transferManager(address)`, `0xd5009584 getManager()`. The delegates-table entry `0x48ff15b3 -> 0x6561d8a6` is therefore **never used** on the templates themselves (it exists to poison the routing tables of per-item "shell" proxies that copy the template's table — see §4). The fallback computes `keccak256(bytes4 selector ‖ uint256(2))` from slot 2 and reverts `"Function does not exist."` when the entry is zero.

---

## 2. How the attacker became manager (root cause, for context)

`initialize(uint256)` was registered to the standard adapters (`0x24591e79` NFT / `0x75512f84` FT). Decompiled logic of both (identical):

```solidity
// adapter storage layout under delegatecall:
//   slot1 = _ownerOf          == template slot1 = _acceptManager (pendingManager)
//   slot2 = _totalSupply      == template slot2 = raw slot of the `delegates` mapping (always 0)
function initialize(uint256 _poolId) public {       // ← no caller check
    require(_totalSupply == 0, "ERCAdapter: Adapter already initialized"); // slot2 == 0, always true on the template
    require(_poolId > 0, "ERCAdapter: _id is 0");
    _totalSupply = _poolId;    // writes template slot2 = 1
    _ownerOf = msg.sender;     // writes template slot1 = msg.sender  ← hijacks pendingManager
}
```

A **storage-slot collision** under `delegatecall` plus an unguarded `initialize`:
1. Anyone calls `initialize(1)` on either template → pendingManager (slot 1) = caller; slot 2 = 1.
2. Caller calls the internal `acceptManager()` → pendingManager == msg.sender → manager = caller.
On 2026-08-25 the attacker ran this via `0x7083ddecE38216C7741fa76c75326Bea744ED321` (displacing a pending handover to `0xE5cb0C8E160C5aC4669D1dfD689Df01bA9eea3eB`), then registered the three malicious entries per template and drained 5,238,353 ENJ through the CryptoItems Platform Adapter (`0xfaafdc07…`) gateway — see §5. The same tx locked `initialize` and `acceptManager` (see §3, stubs).

---

## 3. Current delegate contracts — selector inventory & access control

### 3.1 `0x24591e792a404e5bd48ac0f694339d807b02cfd2` — ERC721 wrapper adapter (routed on NFT for 17 selectors)
Public selectors: `0x01ffc9a7 supportsInterface`, `0x06fdde03 name`, `0x081812fc getApproved`, `0x095ea7b3 approve`, `0x18160ddd totalSupply`, `0x23b872dd transferFrom`, `0x2f745c59 tokenOfOwnerByIndex`, `0x42842e0e safeTransferFrom`, `0x4f6ccce7 tokenByIndex`, `0x6352211e ownerOf`, `0x70a08231 balanceOf`, `0x95d89b41 symbol`, `0xa22cb465 setApprovalForAll`, `0xb88d4fde safeTransferFrom(…,bytes)`, `0xc87b56dd tokenURI`, `0xe985e9c5 isApprovedForAll`, `0xfe4b84df initialize`.
- **`initialize(uint256)` — `NO CALLER CHECK`** (the historic takeover vector). **No longer routed** on either template (both now route `0xfe4b84df` to the reverting stub `0x73497e1c`).
- `transferFrom`/`safeTransferFrom`/`approve`/`setApprovalForAll`: standard ERC721 owner/operator/approval checks (verified in disassembly: `0x6c8 CALLER EQ`, approvals mapping at slot base 3; `_isApprovedOrOwner` at `0x7ea/0xf59`).
- After a successful transfer the code contains a branch calling **ctx-slot1** with the gateway selector `0x41c1df0e`. On the template ctx-slot1 = pendingManager = **0** today; the template also holds no item storage, so this branch is dead on the template itself. It is the mechanism by which live per-item *shells* (whose slot1 is the PA proxy) move records in the legacy EternalStorage.
- `0xfe4b84df` through the template now reverts `"locked"` (verified by `eth_call`, revert data `0x08c379a0…6c6f636b6564` = `"locked"`).

### 3.2 `0x75512f843d8d22593d7256708ef80a22b97baf5e` — ERC20 wrapper adapter (routed on FT for 9 selectors)
Public selectors: `0x01ffc9a7`, `0x06fdde03`, `0x095ea7b3 approve`, `0x18160ddd`, `0x23b872dd transferFrom`, `0x313ce567 decimals`, `0x70a08231 balanceOf`, `0x95d89b41 symbol`, `0xa9059cbb transfer`, `0xdd62ed3e allowance`, `0xfe4b84df initialize`.
- `initialize(uint256)`: **`NO CALLER CHECK`, same slot collision** (writes ctx slot1 = msg.sender, slot2 = id; disasm 0xb27–0xbe7). **No longer routed.**
- `transfer`/`transferFrom`/`approve`: standard ERC20 balance/allowance checks; transfer path may call ctx-slot1 with `0xf95d7da3` on live shells (dead on the template: slot1 = 0, no balances).
- `0xfe4b84df` through the template reverts `"locked"`.

### 3.3 `0x04866013862349a6a19a04c8a1590ea2cf026134` — router manager / `updateContract` (routed for `0x61455567` on both templates)
Public selectors: `0x48ff15b3`, `0x61455567 updateContract(address,string,string)`, `0x7457bbf7`, `0x8d0a3a08`, `0xa0a2daf0`, `0xba0e930a`, `0xd5009584`.
- `updateContract(address,string,string)`: sets `delegates[keccak(signature)] = addr`, emits `DelegateUpdate` (`0x3234040c…`) and `CommitMessage(string)` (`0xaa1c0a0a…`). **MANAGER-ONLY**: requires `slot0 (manager) == msg.sender` (disasm `0x2b9–0x2cd`; revert `"Sender is not manager."`).
- **Verified live**: `updateContract` from an unprivileged address reverts `"Sender is not manager."` on both templates (revert data `0x08c379a0…53656e646572206973206e6f74206d616e616765722e`).

### 3.4 `0x99294e5e8dd62fa0092a85ab37e8b5c44ec29758` — attacker adapter ("only pwn") (routed for NFT `0x6453dcf6`, FT `0x23b872dd`)
Public selectors: `0x23b872dd`, `0x6453dcf6`.
- Both entry points start with **`require(msg.sender == 0x7083ddecE38216C7741fa76c75326Bea744ED321, "only pwn")`** (disasm `0x75–0xdc` and `0x1d1–0x233`; revert data `"only pwn"` verified live for both selectors from a random caller).
- `0x23b872dd` path: builds calldata `0xf95d7da3` = `transferFungiblesFromAdapter(address,address,address,uint256,uint256)` and calls `0xfaaFDc07907ff5120a76b34b731b278c38d6043C` (the Platform Adapter proxy). One argument is read from the executing context's raw slot 2 (template slot2 = `1`).
- `0x6453dcf6` path: builds calldata `0x41c1df0e` = `transferNonFungiblesFromAdapter(address,address,address,uint256)` and calls the same PA proxy.
- **No storage writes** (only a single `SLOAD` of ctx slot2; zero `SSTORE`s in the whole contract).
- **Gateway currently dead**: the PA proxy's delegate table entries for `0x41c1df0e` and `0xf95d7da3` (and `0x33d332ab deployAdapter`, `0xfed9dc6a setApprovalForAllAdapter`) were set to **address(0)** at block **25853511** (2026-08-28 11:42:23 UTC, tx `0x2d92aed4d9a7147ba6588e329b25a9ffcb66278bf939eeaf534d7697cf60a57e`) by the CryptoItems manager `0x1421d753dcec9ac1589c29d1d046aa6e4c18a028`. Even the privileged caller `0x7083ddec` now gets a revert: `"Function does not exist."` when hitting the gateway through the attacker adapter (verified live on both templates).

### 3.5 `0x73497e1c3070a031e1ee05fdeaaeb73c9dd8fcb5` — reverting stub for `initialize` ("lock"), 92-byte assembly
- Delegatecalled by either template (`address(this) == 0x13fa4b9a… || 0x268c039a…`): **reverts `"locked"`** (verified live: `initialize(1)` on the NFT template → revert `"locked"`).
- Called directly (address(this) != templates): writes its **own** slots and returns — decoy branch, no effect on the templates.

### 3.6 `0x6561d8a6dd7e184308555b21b115ebe122136036` — reverting stub for `acceptManager` ("lock"), 43-byte assembly
- **Always reverts `"locked"`** (verified live, direct call).
- On the templates it is additionally irrelevant: `0x48ff15b3` is handled by the template's internal dispatcher before the table lookup.

---

## 4. Template-side safety of the management selectors (live `eth_call` evidence)

| Call | Caller | Result |
|---|---|---|
| `initialize(uint256 1)` on NFT template | any | revert `"locked"` (stub) |
| `initialize(uint256 1)` on FT template | any | revert `"locked"` (stub) |
| `acceptManager()` on NFT/FT template | non-zero EOA | revert `"Managed: Sender must be the new manager"` (internal fn; pendingManager = 0) |
| `acceptManager()` | address(0) simulation only | succeeds (pendingManager==0) — unreachable on-chain, no account can send as 0x0 |
| `updateContract(...)` on both templates | unprivileged EOA | revert `"Sender is not manager."` |
| `stealNFT(...)` / `transferFrom(...)` via templates | unprivileged EOA | revert `"only pwn"` |
| `stealNFT(...)` / `transferFrom(...)` via templates | `0x7083ddec` (manager orchestrator) | revert `"Function does not exist."` (PA gateway delegate = 0) |

The current manager of both templates is the attacker orchestrator `0x7083ddec…`, whose owner (slot 0) and payout (slot 1) are the attacker EOA `0x5ec1BA78…`; every state-changing function of that contract (`sweep`, `setup`, `lock`, `fe2cdc13`, `ab2786f5`, `f7d9430e`) begins with `require(slot0 == msg.sender)` (owner-gated; verified in disassembly at PCs `0x295, 0x3cd, 0x469, 0x64d, 0x6e2, 0x889`). No unguarded forwarding entry point exists.

---

## 5. Historical attack footprint (contextual evidence)

- Attack tx `0xd4a382da…b2a7e` at block 25834071 emitted 190 logs: 14 on the two templates (ManagerUpdate, 6 × DelegateUpdate + CommitMessage `"pwn721"`, `"pwn20"`, `"lock"`), then ~176 ERC-1155 `TransferSingle` / ERC-20 ENJ `Transfer` events through the Platform Adapter `0xfaafdc07…` and ENJ `0xf629cbd9…`.
- PA gateway implementations before cleanup: `0x68ee930ea6ad962205f1e29ae79bcc3dfa07c837` (since block 13530866; earlier `0x9ec524b7…` since block 8099679). Both `transferNonFungiblesFromAdapter` (`0x41c1df0e`) and `transferFungiblesFromAdapter` (`0xf95d7da3`) were zeroed at block 25853511.
- Related write-up (independent confirmation of mechanism): `yinhui1984.github.io` post "Enjin CryptoItems Attack Analysis" (storage-slot collision; initialize → pendingManager → acceptManager; route poisoning; per-item shells; melt to ENJ).

---

## 6. Conclusions (explicit)

**(a) Can an unprivileged caller set manager/pendingManager of either template? — NO.**
- Every selector that ever wrote slot 0/1 is blocked: `initialize(uint256)` now routes to the reverting stub `0x73497e1c` on **both** templates (live-revert `"locked"`); the adapters' unguarded `initialize` is unreachable; `acceptManager()` is internal, requires `pendingManager == msg.sender`, and pendingManager = **0** for both templates; `transferManager(address)`/`removeManager()` are internal and manager-only.
- No other current delegate writes slots 0/1: `0x04866013` only runs manager-gated `updateContract` when routed; `0x99294e5e` performs no `SSTORE` at all; both stubs revert in template context.

**(b) Can an unprivileged caller invoke a PA gateway item move or ENJ payout? — NO (currently).**
- The only routed paths that call the PA gateways are NFT `0x6453dcf6` and FT `0x23b872dd` → `0x99294e5e`, both **caller-gated `msg.sender == 0x7083ddec` ("only pwn")**; even for the privileged caller the PA proxy now returns `"Function does not exist."` because its `0x41c1df0e` / `0xf95d7da3` delegates are zeroed (block 25853511). No delegate of either template calls the ENJ token with value-moving semantics outside standard ERC-20 allowance checks.

**(c) Can an unprivileged caller register/replace delegates? — NO.**
- The only registration selector is `0x61455567 updateContract`, routed to `0x04866013`, and it is manager-gated (live revert `"Sender is not manager."`). The only account able to register is the current manager `0x7083ddec`, which is an attacker-controlled contract whose functions are all owner-gated to the attacker EOA — not reachable by unprivileged users. (The attacker can themselves re-register delegates at will; see caveats.)

### Residual notes / latent risks (not unprivileged-exploitable today)
1. **Both templates remain under attacker manager control** (`0x7083ddec`, owner `0x5ec1BA…`). The attacker can re-route any selector they wish. While the root takeover vector is now blocked, the templates should be treated as compromised; recovery requires the attacker's cooperation or a pre-arranged migration (shells route through these tables).
2. **PA cleanup reversibility**: the gateway delegates are zeroed by the CryptoItems manager `0x1421d753…`. If PA re-enables `0x41c1df0e`/`0xf95d7da3` in the future, shell-based flows would again reach the attacker adapter through the poisoned template table — still blocked for unprivileged users by the `"only pwn"` caller guard, but the attacker could resume item moves. Flagged for monitoring.
3. The standard adapters' internal gateway-call branch reads **ctx slot 1** (the template's pendingManager). On the two templates slot1 = 0 and the templates hold no item ledger/balances, so nothing can be moved through them directly; this branch is only meaningful on live per-item shells.
4. `acceptManager`'s delegates-table entry is shadowed on the templates; it only matters for mini-proxies that consult the table without an internal dispatcher — its stub is nonetheless a pure revert, so it is safe there.

**Answer summary: (a) No — (b) No — (c) No, with the caveat that the templates' manager is the attacker contract, so *privileged* (attacker-only) changes remain possible.**
