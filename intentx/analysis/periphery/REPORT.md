# IntentX Periphery — Unprivileged Extraction Audit

**Campaign:** read-only financial-security research on the live IntentX (SYMMIO-based perp DEX) deployment.
**Scope:** IntentX-owned periphery contracts (MultiAccount, solver deposit vaults, solver/partyB contracts, CarbonFeeRebate, SymmExecutor, TargetRebalancer, INTX token ecosystem). The SYMMIO diamond core is explicitly out of scope (separate agent).
**Question:** can an EXTERNAL UNPRIVILEGED attacker extract value TODAY without a privileged key?
**Method:** read-only `eth_call`/`eth_getCode`/`eth_getStorageAt` via public RPCs, Etherscan V2 (contract + logs modules), Blockscout v2 APIs, GoldRush holders API, GitHub sources. No transaction was signed or sent. No private keys used.
**Date/time of live reads:** 2026-10-03 (block numbers recorded in §7).

---

## 0. Headline result

**No unprivileged extraction path was found in any IntentX periphery contract. Every value-moving path is gated by an owner/admin role, a whitelist, or a backend signature — or the contract holds no value.**

Nearest misses / notable facts (details in §2):

| # | Fact | Why it is not an E-U path |
|---|------|---------------------------|
| 1 | IntentX GitHub `main` `MultiAccount.depositAndAllocateForAccount` has `onlyOwner` **commented out** (`github/MultiAccount_gh.sol:247-248`). The **deployed** Base/Arb/Mantle implementation has `onlyOwner` restored (`MultiAccount_base.sol:247`). | Not deployed. Live call from a random address reverts `MultiAccount: Sender isn't owner of account`. |
| 2 | Deployed `MultiAccount._call` allows a non-owner to execute arbitrary account calldata **only** for selectors pre-delegated by the account owner; the inner call can only reach `SymmioPartyA._call`, which forwards **only** to its fixed `symmioAddress` and is `onlyRole(MULTIACCOUNT_ROLE)`. | Live call from random address reverts `MultiAccount: Unauthorized access`; call to partyA reverts `AccessControl: ... missing role 0xebee9ae4…`. |
| 3 | `OnChainSymmioVaultV2` has a **signer + BALANCER EOA** trust surface, and the signed withdrawal digest does **not** bind `msg.sender` (only `receiver`). | Funds always go to the signed `receiver`; replaying another user's signature is griefing only, not theft. Requires 2 compromised keys to extract. |
| 4 | Newer `SolverVault` (found during enumeration) holds **409,161.89 USDC** in-contract. | Deposit is permissionless but withdrawals require `SIGNER_ROLE` (EOA) signature bound to `msg.sender`, and payout requires `EXECUTOR_ROLE` (3-of-4 Safe). |
| 5 | `CarbonFeeRebate` holds **581.95 USDC** of unclaimed rebates; its implementation contract is **openly initializable** (no constructor `_disableInitializers`). | The implementation holds no tokens and is never called through the proxy delegatecall. The live proxy is initializable-once-already. Claim requires a backend `carbonTrustedAddress` signature and `msg.sender == _user`. |

Residual privileged-key risks (documented, not unprivileged) are in §5.

---

## 1. Deployed-instance inventory (live values)

All balances are raw token units. USDC = 6 decimals on Base/Arbitrum. "n/a" = contract not present on that chain or not found by name search. Role holders are the enumerable (`getRoleMember`) or spot-checked (`hasRole`) results.

### 1.1 MultiAccount (user account factory, TransparentUpgradeableProxy)

| Chain | Proxy | Impl | Impl source version | Paused | saltCounter | Roles (live) | ProxyAdmin → owner |
|---|---|---|---|---|---|---|---|
| Base | `0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86` | `0x54a870306b2ED367D135c43F2C2daFa9061bB887` | 355-line (Base=Arb=Mantle byte-identical) | false | 10,394 | ADMIN=`0x319F10D1…` (TimelockController); PAUSER=`0x9BC9CA7e…`; SETTER not held by any tested admin (timelock, `0x9BC9`, `0x942d`, `0x67736569`, impl) | `0x942dd39a…` → TimelockController `0x319F10D1…` (minDelay 259,200 s = 3 d; PROPOSER+EXECUTOR = EOA `0x67736569…`) |
| Arbitrum | `0x141269E29a770644C34e05B127AB621511f20109` | `0x1cb4b1dcee1ebde41c272c7c14bf55d565e2830c` | same 355-line | false | 2,864 | ADMIN+SETTER=`0x67736569…` (EOA) | ProxyAdmin `0x433BE520…` (Arb instance) → TimelockController `0xE802853F…` (minDelay 3 d; proposer `0x67736569…`) |
| Mantle | `0xECbd0788bB5a72f9dFDAc1FFeAAF9B7c2B26E456` | `0x829af7dda2538b78acf64babe683a7eb34ad8373` | same 355-line | false | 13,100 | ADMIN=`0x7Aded3C2…` (TimelockController, minDelay 3 d); SETTER false for it/`0x9BC9`/`0x67736569` | ProxyAdmin `0x3adc81cc…` → TimelockController `0x7Aded3C2…` |
| Blast | `0x083267D20Dbe6C2b0A83Bd0E601dC2299eD99015` | `0xf39352ec34a007b2726e2c4610a13f7aea86684e` | 208-line older variant | false | 1,158 | ADMIN+SETTER=`0x629bCef8…` (Gnosis Safe 1.3.0, 3-of-6) | ProxyAdmin `0x8f06459f…` → Safe `0x629bCef8…` |
| Blast | `0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e` | `0xf39352ec…` (same) | same 208-line | false | 1,081 | same as above | same ProxyAdmin → Safe `0x629bCef8…` |

Initialization state (all chains): proxies storage slot 0 = `…01` (initialized, unpaused); implementation slot 0 = `…ff` (constructor `_disableInitializers()` executed → impl cannot be initialized/taken over). Symmio addresses live: Base `0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43`, Arb `0x8F06459f184553e5d04F07F868720BDaCAB39395`, Mantle `0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5`, Blast `0x3d17f073cCb9c3764F105550B0BCF9550477D266`.

### 1.2 Solver deposit vaults

| Chain | Contract | Kind | Impl | Live balances | Roles (live) | ProxyAdmin → owner |
|---|---|---|---|---|---|---|
| Arbitrum | `0x40423eF1FdCc21738A9031d0295b7Ce6739cD1Ae` | **OnChainSymmioVaultV2** TransparentUpgradeableProxy (the only V2 deployment found) | `0x68EF307822138027A26F7fFFC05178be9c446Ac9` (deployed source == GitHub V2 except import paths) | vault USDC = **1.000000** (= `lockedBalance`); 401,426.170314 USDC deposited, forwarded to solver | ADMIN/SETTER/PAUSER/UNPAUSER = Safe `0x25537fe2…` (2-of-3); BALANCER = EOA `0x441ee70b…` | ProxyAdmin `0xcFbcCAD6…` → Safe `0x25537fe2…` |
| Arbitrum | `0x68EF3078…` | V2 implementation (not a proxy) | – | 0; `symmio/solver/signer = 0`, `_initialized = ff` | – | – |
| Arbitrum | `0xAdBb55b3d7f93A6c213754e8B7a89996Cd009179` | **SolverVault** proxy (newer product, not in original brief; discovered via deployer scan) | `0x98058ab24b31e9987F3C5d74EcF351a8cE3F59f1` | vault USDC = **409,161.893001**; totalDeposited 1,292,996.81744; totalWithdrawn 58,410.924439; pendingToWithdraw 0 | ADMIN/SETTER = Safe `0x25537fe2…`; EXECUTOR/REBALANCER = Safe `0x14622475…` (3-of-4); SIGNER = EOA `0x751CFA90…` | (EIP-1967 proxy; admin not required for finding — all writers role-gated) |
| Arbitrum | `0x2190315d…`, `0xb86B965E…`, `0x8E42263A…`, `0xbB62C389…` | SolverVault proxies (empty) | same impl | 0 USDC; all counters 0 | same role set per proxy | – |
| Base | `0x7785fE35F6510D111063579AA14F7D28aD84512A` | OnChainSymmioVault **v1** proxy (dead) | `0x0b2e5F8e…` (310-line V1) | USDC = 0; currentDeposit = 0; lockedBalance = 0; LP totalSupply = 0 | ADMIN/SETTER=`0xf1d63df1…` (EOA); BALANCER=`0x6b3535Be…` (EOA); PAUSER none | ProxyAdmin `0x00f3e793…` |
| Base | `0x6e79556F…`, `0xBc40D95e…`, `0xeD865FF8…`, `0xC4369Fbe…` | V1 implementations/proxy impls | 258/300-line variants | 0; all uninitialized (`symmio()=0`) | – | – |

### 1.3 Solver / PartyB / executor contracts

| Chain | Contract | Kind | Live state | Roles (live) |
|---|---|---|---|---|
| Arbitrum | `0xE72284fc2D56bE2C1649742FD131BceA41A94a6a` | ERC1967Proxy → SymmioPartyB `0x556f255e…` (solver of the V2 vault) | USDC 0.980571; its SYMMIO sub-account received the ~401 k deposits; `symmio=0x8F06459f…`, paused=false | DEFAULT_ADMIN+MANAGER = Safe `0x25537fe2…`; TRUSTED/EXECUTOR not held by tested EOAs; ERC-1271 `signer` unset |
| Base | `0x1bD0C555…`, `0xB3Ccac825…` | ERC1967Proxy → SymmioPartyB `0x4a23e09b…` (new; symmio = `0xa805FE5b…`) | 0 USDC, paused=false | admin/manager not exhaustively enumerated; all writers role-gated in source |
| Base | `0x9F20BaD77CCa97f2F96De88b146603Ca3F65baD5` | ERC1967Proxy → NoxPartyB `0xdd409C78…` | USDC 0.074257; symmio `0x91Cf2…`; paused=false | MANAGER/TRUSTED/EXECUTOR not held by `0x67736569`/`0x9BC9` |
| Base | NoxPartyB impls `0x975DABAb…`, `0xABf0C8b3…`, `0xdd409C78…`, `0x1d26bCf3…`, `0xd7ED5F8A…` | implementations | 4 of 5 uninitialized (`symmio()=0`, 0 balances) | – |
| Base | `0x433BE520b115d771D6DA17a573FdCb01d69d579d` | SymmExecutorUpgradeable proxy (main) | owner=`0x67736569…`; multiAccount=`0x8Ab178…` (main); paused=false; keepers `0xaf8d3aad…`✔, `0x916bf416…`✔ (EOAs) | `addKeeper` onlyOwner |
| Base | `0x25D7572F32D9CFB96799EFDF50804a982a983F0A` | SymmExecutor proxy | owner=`0x67736569…`; multiAccount=`0x39EcC772…`; same two keepers ✔ | – |
| Base | `0x3c3de3739d1c8092AD378E44220829eEBe062855` | SymmExecutor proxy | owner=`0x59A175fE…`; multiAccount=`0x921Dd892…` (Carbon/Privex community); keeper `0xa66a0541…`✔ | – |
| Base / Arb | `0x1c529cF1392CDe198B5CdaC11C7e50780a0686A4` / `0x19E3EFCE03FeCc63AF0Fc8769Ee7799551622dbE` | SymmExecutor implementations | uninitialized (owner=0, multiAccount=0) | – |
| Base | `0xcB420c74…` + live proxy `0x6c81c0Ef…` | CarbonFeeRebate (proxy impl + standalone uninitialized impl) | live proxy: USDC 581.951898; totalReward 1,003.0; owner=`0x67736569…`; trusted=EOA `0x8D169168…`; rebateToken=USDC | `setCarbonTrustedAddress` onlyOwner; `claim` needs backend signature |
| Base | `0x74dC2aeF96EFEbfE34054Ee615fd6ec5637Bfc9A` | TargetRebalancer (non-proxy) | owner=`0x67736569…`; USDC 0; `allowedPartyBs` owner-managed | `executeInstantRebalance` onlyOwner |
| Base | `0x23651fe94ec68e60e2f18ae26284ab60d0dee663` (sample; 10,394 accounts exist) | SymmioPartyA account (create2 by MultiAccount) | `symmioAddress=0x91Cf2…`; USDC of account = tracked in diamond | `_call` = `onlyRole(MULTIACCOUNT_ROLE)` where MULTIACCOUNT_ROLE = MultiAccount proxy; `setSymmioAddress` = DEFAULT_ADMIN (`0x9BC9…`) |

### 1.4 INTX token

| Token | Chain | Live state |
|---|---|---|
| `0x7D27187eb33a7B1d99258FF222633670F84fa342` | Base | `IntxOFT` ("IntentX Token", 18 dec), totalSupply 8,190,206.364488; owner = GnosisSafeProxy `0x06f246ea…`; LayerZero OFT |
| Top-100 holders scan | Base | 19 contract holders: GnosisSafeProxy (owner), OdosRouterV2, CoW GPv2Settlement, Uniswap v4 PoolManager, Uniswap V2 router, TokenChwomper (unrelated), and EIP-7702 delegated EOAs (`0xef0100…`). **No IntentX staking/xINTX/rewards/merkle contract holding INTX was found.** |
| `0x8A6455fA50ac683685fb9D822ca33EBD722923E2` | Base | Unverified legacy token "IntentX"/"INTX", supply 100.31 B, owner `0xF0309CAD…`; holders are 7702 EOAs/routers; no claim path identified (out of scope beyond noting) |
| SYMMIO-side `AirdropHelper 0x3C9f21bB…`, `SymmVesting 0xd66C37e5…`, `SymmioFeeDistributor 0x5cB72ed5…` | Base | hold **0 INTX** — not relevant to INTX pools |

### 1.5 Deployment provenance (for completeness)

- IntentX deployer EOA: `0x67736569B61BdB7F1A756EF069aB5B9590668E4c` (no code). Created, among others (Base): MultiAccount impl `0x54a870…`, SymmExecutor impl + 3 proxies, CarbonFeeRebate impl + proxy, IntxOFT, TimelockController `0x319F10D1…`, TargetRebalancer, NoxPartyB impls, SymmioPartyB/ZenithPartyB, vault V1 infra.
- Arbitrum creations include: OnChainSymmioVaultV2 impl + proxy, SolverVault impl + 5 proxies, SymmioPartyB `0x556f255e`, NoxPartyB `0x3c3de373`, IntxOFT proxy `0x7D27187e…`, TimelockController `0xE802853F…`, several ERC1967 proxies.
- `0x9BC9CA7e6A8F013f40617c4585508A988DB7C1c7` created the Base MultiAccount proxy (accountsAdmin on all chains).

---

## 2. Per-contract findings

### 2.1 MultiAccount — answers to the explicit questions

Deployed sources: `MultiAccount_base.sol` (= Arb, Mantle; 355 lines), `MultiAccount_blast.sol` (208 lines, older). GitHub `main` copy: `github/MultiAccount_gh.sol` (375 lines) — **differs from all deployed copies**.

**(a) `depositAndAllocateForAccount` — is it onlyOwner?**
- Deployed Base/Arb/Mantle: `function depositAndAllocateForAccount(address account, uint256 amount) external onlyOwner(account, msg.sender) whenNotPaused` (`MultiAccount_base.sol:247`; modifier at lines 39–42).
- Deployed Blast: `… external onlyOwner(account, msg.sender) whenNotPaused` (`MultiAccount_blast.sol:154`).
- GitHub `main`: `onlyOwner` is commented out (`github/MultiAccount_gh.sol:247-248`). **Not deployed.**
- Live evidence (Base, block 52,127,298): `eth_call depositAndAllocateForAccount(0x23651…, 1e6)` from `0x1111…` → revert `MultiAccount: Sender isn't owner of account`. Not an E-U path.

**(b) `trasnferAccount` — present? what does it check?**
- **Not present** in any deployed IntentX MultiAccount source (grep across Base 355-line, Blast 208-line, and the GitHub `main` copy — zero hits). The GitHub-repo ABI used by the subgraph (`github/symmioMultiAccount_abi.json`) does list `trasnferAccount` (typo) and `setAccountImplementaion`, but that is SYMMIO's generic/DeusV3 fork, not IntentX's deployed contract.
- For reference, the DeusV3 variant's function is owner-gated: `require(msg.sender == owner[accountAddress], "…Sender isn't account owner")` (`github/DeusV3MultiAccount.sol:1782-1789`, pulled from a Fantom deployment). No IntentX-deployed contract exposes it.
- Related deployed function that does exist: `editAccountName(accountAddress, name)` (`MultiAccount_base.sol:223`). It lacks an explicit ownership check on `accountAddress`, **but** it writes only to `accounts[msg.sender][indexOfAccount[accountAddress]]` — i.e., the caller's own account array — and reverts if the index is out of range. It cannot rename or otherwise modify a victim's account entry. No value movement.

**(c) `_call` / delegatedAccesses / apiExecutor**
- Deployed `_call` (`MultiAccount_base.sol:285-299`): `bool isOwner = owners[account] == msg.sender;` — if owner, any calldata (own account only). If not owner: `require(_callData.length >= 4)` and `require(delegatedAccesses[account][msg.sender][functionSelector])` → `MultiAccount: Unauthorized access`.
- The inner call goes to `ISymmioPartyA(account)._call(_callData)` (`innerCall`, lines 270–278). Deployed SymmioPartyA (`github/SymmioPartyA_gh.sol:47`) is `external onlyRole(MULTIACCOUNT_ROLE)` and does `symmioAddress.call(_callData)` — the target is **fixed to the partyA's own `symmioAddress`**; calldata cannot be aimed at an arbitrary contract.
- `apiExecutor` exists **only in GitHub main** (`github/MultiAccount_gh.sol:300-301,366-373`), where `_call` would skip the delegation check for `apiExecutor`. The deployed Base impl has no `apiExecutor` symbol at all (grep + verified source). Not an E-U path today.
- Live evidence (Base, block 52,127,298): `_call(0x23651…, [0x12345678])` from `0x1111…` → `MultiAccount: Unauthorized access`; direct `0x23651fe9._call(0x12345678)` → `AccessControl: account 0x1111… is missing role 0xebee9ae4283d502e7ed608f7bff6281dc40560c705aa66f8f31324862ed03f5a`.
- `delegateAccess`/`delegateAccesses`/`proposeToRevokeAccesses`/`revokeAccesses` are all `onlyOwner(account, msg.sender)` (lines 75–133). `revokeCooldown = 0` live on Base (revocation can be immediate after proposal), irrelevant to third parties.
- `addAccountDelegateAccessAndCall` (line 328) is callable by anyone but deploys a **new** account owned by the caller and delegates/executes only on it. No effect on existing accounts.

**(d) `withdrawFromAccount` / `withdrawFromAccountTo` gating**
- Deployed versions expose only `withdrawFromAccount` (`MultiAccount_base.sol:264`), `onlyOwner(account, msg.sender)`, and it encodes `withdrawTo(owners[account], amount)` — the recipient is forced to the account owner. Live random-call revert: `MultiAccount: Sender isn't owner of account`.
- `withdrawFromAccountTo(account, amount, destination)` exists **only in GitHub main** (`github/MultiAccount_gh.sol:269-280`); it is `onlyOwner` there. Not deployed on any of the four chains (verified against the four deployed verified sources).

**(e) Proxy upgrade authority and initialization state**
- Base: ProxyAdmin `0x942dd39a05efee912b08c1b1486490a02e26d89f`, owner = `0x319F10D14B5B7195a1693f4f5C015370C4324Fa6`, which is a **TimelockController** (≈8.8 KB code; hasRole proofs) with `minDelay = 259,200 s` and `PROPOSER_ROLE`/`EXECUTOR_ROLE` on EOA `0x67736569…`.
- Arbitrum: ProxyAdmin `0x433BE520b115d771D6DA17a573FdCb01d69d579d`, owner = TimelockController `0xE802853F67c618dBbB071D59E0B9537A4a7Fe8B7`, minDelay 3 d, proposer EOA `0x67736569…`.
- Mantle: ProxyAdmin `0x3adc81cc43d9e1636de9cbac764afcb1f3ae6cde`, owner = TimelockController `0x7Aded3C2D7224495F96d82BF52B6998f230c04f0`, minDelay 3 d, proposer EOA `0x67736569…`.
- Blast: ProxyAdmin `0x8f06459f184553e5d04F07F868720BDaCAB39395` (per chain), owner = Gnosis Safe 1.3.0 `0x629bCef8659a11f576eC0Aad0A8fB35a8356ffcf`, threshold 3-of-6.
- Initialization: all four proxies have slot 0 = `0x…01` (initialized, unpaused) and the implementations slot 0 = `0x…ff` (disabled in constructor). There is no uninitialized proxy/impl to seize. No public `initialize` reachable.

**(f) `setSymmioAddress` / `setAccountImplementation` roles**
- Both `onlyRole(SETTER_ROLE)` (`MultiAccount_base.sol:139,157`; Blast version lines 79,84).
- Live SETTER holders: Arb = EOA `0x67736569…` (also DEFAULT_ADMIN); Blast = Safe `0x629bCef8…`; Base/Mantle = none of the tested admins hold it (DEFAULT_ADMIN could grant it; Base ADMIN is the 3-day timelock).
- Impact if abused (privileged only): changing `symmioAddress` affects `getCollateral()` used by **user-initiated** deposits and where `depositFor` is called; existing partyA accounts keep their own `symmioAddress` until their admin changes it. This is a privileged-key risk, not an unprivileged extraction path.

**(g) Any function that can move ownership/balances without the owner?**
- No. `owners[account]` is written only in `addAccount`/`addAccountDelegateAccessAndCall` (for newly created accounts, to `msg.sender`) and would only be changed by a transfer function that does not exist. `editAccountName` cannot touch other users' entries. `setAccountsAdmin` is DEFAULT_ADMIN-only. Balances of accounts live in the SYMMIO diamond and can only be moved via partyA `_call`, which the MultiAccount proxy can only reach for the owner or delegated selectors.

**Conclusion (MultiAccount): explicit negative result; no E-U path on any chain.**

### 2.2 OnChainSymmioVaultV2 (Arbitrum `0x40423eF1…`, impl `0x68EF3078…`)

Deployed implementation source matches the GitHub `solver-deposit-vault` V2 exactly (only relative-import paths differ; 287 lines). Verified live at Arb block 511,339,455:

```
signer          = 0xD6ADf61fA28a8A07053d0352d6cD9aAc6Fd10233   (EOA, no code)
solver          = 0xE72284fc2D56bE2C1649742FD131BceA41A94a6a   (SymmioPartyB proxy)
symmio          = 0x8F06459f184553e5d04F07F868720BDaCAB39395
collateral      = 0xaf88d065… (USDC), decimals 6
depositLimit    = 10,000,000.000000 USDC
currentDeposit  =   401,425.170314 USDC
lockedBalance   =         1.000000 USDC
paused          = false, withdrawalPeriod = 0
vault USDC bal  =         1.000000 USDC   (== lockedBalance → 0 free funds)
```

Role members (`AccessControlEnumerable`, block 511,339,455): DEFAULT_ADMIN/SETTER/PAUSER/UNPAUSER `0x25537fe2…` (Safe 2-of-3), BALANCER `0x441ee70b…` (EOA). ProxyAdmin `0xcFbcCAD6…` owner = same Safe.

**Fund flow decoded from logs** (Etherscan V2 `getLogs`, blocks 455,155,068 → 511,342,997; saved `raw/arb_v2vault_getlogs.json`):
- 20 × `Deposit` + 20 × `DepositToSymmio` → total 401,426.170314 USDC forwarded to `solver` via `symmio.depositFor`.
- 2 × `WithdrawRequestEvent`: id 0 = 1.000000 USDC (sender=receiver `0x8Fab4e5Ba…`, nonce 2); id 1 = 10,613.870314 USDC (sender=receiver `0x6626735E…`, nonce 2).
- 1 × `WithdrawRequestAcceptedEvent` (providedAmount 1.000000 USDC) → id 0 Ready; `currentDeposit` = 401,426.170314 − 1.000000. No claim event (no `WithdrawClaimedEvent`).
- Live request state: id 0 = `Ready` (status 1), acceptedAmount 1.000000, `claimableAt 1779208259` (past; now ≈1791043943); id 1 = `Pending` (status 0), amount 10,613.870314, minAmountOut same.

**Audit of the extraction surface:**
- `requestWithdraw` (lines 100–130): EIP-712 `WithdrawRequest(uint256 amount,uint256 minAmountOut,address receiver,uint256 nonce,uint256 deadline)` signed by `signer`; replay guard `usedNonces[receiver][nonce]`; `deadline` checked. OZ `ECDSA.recover` (low-s, v-enforced). Bogus 65-byte zero signature → revert `ECDSA: invalid signature` (simulated block 511,349,904).
- **Missing sender binding**: the digest does not include `msg.sender`. A third party who observes a valid signature can submit it first, making themselves `request.sender` while the payout still goes to the signed `receiver`. Impact: griefing/DoS of the victim's request slot — **not value extraction** (the receiver cannot be changed and payouts are receiver-bound).
- `claimForWithdrawRequest` (lines 205–218) is permissionless but pays `request.receiver`; it is `Ready`-gated and sets `Done` before transfer (no re-reentrancy, amount from `acceptedAmount`). Simulated from a random address → **succeeds**, would pay 1.000000 USDC to `0x8Fab4e5Ba…` (the bound receiver), not the caller.
- `acceptWithdrawRequest` (156–190), `rejectWithdrawRequest` (143–154), `withdrawNotLockedCollateralTokens` (192–203) are `onlyRole(BALANCER_ROLE)`; free balance is 0. `setSigner/setSolver/setDepositLimit/setSymmioAddress/setWithdrawalPeriod` are SETTER-only. `deposit` is `nonReentrant`.
- The ~401 k USDC is in the solver's SYMMIO sub-account, reachable only through SymmioPartyB roles (Safe `0x25537fe2…`) — the vault itself has no function to pull it.
- The V2 implementation `0x68EF3078` is uninitializable (`_disableInitializers`; slot0 `0xff`) and holds nothing. No second V2 was found: Blockscout name search returns no other `OnChainSymmioVaultV2`; deployer-creation scans on Base (318 txs) and Arb (49 txs) show a single V2 pair; the subgraph configs mention no vault; `docs`/web search returned no additional addresses.

**Conclusion: no E-U path. Live actionables (not E-U): anyone may trigger the 1.000000 USDC claim that pays `0x8Fab4e5Ba…`; a 10,613.870314 USDC request awaits BALANCER acceptance.**

### 2.3 SolverVault (Arbitrum `0xAdBb55b3…` + 4 empty siblings) — discovered during enumeration

Deployed source (`sources/solvervault_arb_0x98058ab2/…`, OZ 5.4, not published in GitHub):
- `deposit` open to anyone (custody vault, holds **409,161.893001 USDC**).
- `requestWithdraw` (80–105): signature over `WithdrawRequest(address user,uint256 amount,address receiver,uint256 nonce,uint256 deadline)` where **`user` = `msg.sender`**; verified against `SIGNER_ROLE` members; per-user nonce. This binding fixes the V2 sender-binding gap.
- `acceptWithdrawRequest`/`rejectWithdrawRequest` = `EXECUTOR_ROLE`; `cancelWithdrawRequest` = request user; `rebalance` = `REBALANCER_ROLE` and only to `isWhitelisted` addresses; `setWhitelist` = SETTER. All 22 requests live are terminal (`Accepted`=1 or `Canceled`=3; none Pending).
- Live role members (block 511,342,997): ADMIN/SETTER Safe `0x25537fe2…` (2-of-3); EXECUTOR/REBALANCER Safe `0x14622475…` (1.4.1, 4 owners, threshold 3); SIGNER EOA `0x751CFA90…`. Simulated: bogus sig → `0xf645eedf` (`ECDSAInvalidSignature`); random `rebalance` → `AccessControlUnauthorizedAccount(0x1111…, 0xccc64574…)` (REBALANCER hash).

**Conclusion: no E-U path; requires SIGNER EOA or Safe keys.**

### 2.4 SymmioPartyB / NoxPartyB (solver PartyB contracts)

- New `SymmioPartyB` (`sources/SymmioPartyB_arb_0x556f255e…`, 205 lines): `_call`/`_multicastCall`/`adlClose` authorize `MANAGER_ROLE`/`TRUSTED_ROLE` **or** `ISymmio(symmioAddress).isCallFromInstantLayer()`.
  - Live probe (Arb block 511,349,904): `isCallFromInstantLayer()` returns **false** for a random caller on both the Arb diamond `0x8F06459f…` and the Base diamond `0x91Cf2D8E…` — the instant-layer bypass is not externally triggerable.
  - `withdrawERC20` is `MANAGER_ROLE`; `_authorizeUpgrade` is `DEFAULT_ADMIN_ROLE`; `setSymmioAddress`/`setRestrictedSelector` admin-only; ERC-1271 `signer` is unset and `setSigner` needs `SETTER_ROLE` (never granted at init).
  - Solver proxy `0xE72284fc`: DEFAULT_ADMIN+MANAGER = Safe `0x25537fe2…`.
- Legacy `NoxPartyB` (`github/NoxSolver_isc.sol`, deployed variant `sources/8453_NoxPartyB_0x975DABAb…`): `_call` requires MANAGER/TRUSTED/EXECUTOR (restricted selectors even stricter); `withdrawERC20` MANAGER and destination restricted to `withdrawalAddress`/`ledgerMultiSigWithdrawalAddress`; `changeWithdrawalAddress` is MANAGER. Only the ERC1967 proxy `0x9F20BaD77…` is initialized; balance 0.074257 USDC. No E-U path.

**Conclusion: no E-U path; solver funds require a manager/admin key.**

### 2.5 SymmExecutorUpgradeable

- Deployed source matches `github/SymmExecutor_isc.sol` (99 lines). `_call(account, callDatas)`/`_call2` are `onlyKeeper whenNotPaused` and forward to `MultiAccount._call` (lines 68–80). A keeper can only execute selectors that an account owner explicitly delegated to the executor (`delegatedAccesses[account][executor][selector]`), and the calldata lands on that account's `SymmioPartyA` → Symmio diamond. This is a legitimate "keeper can request close" capability, **not** a theft primitive (proceeds stay in the user's account). Keepers are EOAs (`0xaf8d3aad…`, `0x916bf416…`, `0xa66a0541…`, code length 3) and can be changed only by the owners (`0x67736569…` / `0x59A175fE…`).
- Live `isKeeper` checks at Base block 52,126,160: all three active keepers confirmed `true`; the uninitialized impl `0x1c529cF…` (owner=0) is not usable.

**Conclusion: no E-U path.**

### 2.6 CarbonFeeRebate

- Live proxy `0x6c81c0Ef…` (impl `0xcB420c74…`, USDC rebate token): `claim(_user,_amountRebate,_timestamp,signature)` requires `msg.sender == _user` and `ecrecover` of an `eth_sign` message over `keccak256(abi.encodePacked(_user,_amountRebate,_timestamp))` equal to `carbonTrustedAddress` = EOA `0x8D169168…`; `claimed[_user]` is monotonic (prevents double claim). Simulated bogus signature → revert `Signer =! Trusted.` (Base block 52,127,298).
- 581.951898 USDC remains unclaimed (totalReward 1,003.0). No permissionless claim exists.
- Implementation `0xcB420c74…` has **no constructor** and is uninitialized (owner/trusted/token = 0). Anyone can initialize that implementation contract (it is not behind the proxy and holds no tokens) — a hygiene issue with **no value impact found**; the proxy storage is separate.
- Arb `0xB891F77…` deployment is uninitialized and token-less.

**Conclusion: no E-U path.**

### 2.7 TargetRebalancer

- `rebalance(...)` is gated on `allowedPartyBs[msg.sender]` (owner-registered); `executeInstantRebalance` is `onlyOwner` and requires a matching request. Owner EOA `0x67736569…`; balance 0. **No E-U path.**

### 2.8 SymmioPartyA accounts (the create2 accounts)

- All accounts are created from the `accountImplementation` template stored in the MultiAccount proxy (verified sample `0x23651fe94ec68e60e2f18ae26284ab60d0dee663`, Base). The template source is `github/SymmioPartyA_gh.sol`.
- Each account's `_call` is `onlyRole(MULTIACCOUNT_ROLE)`; MULTIACCOUNT_ROLE is granted to the MultiAccount proxy in the constructor. `setSymmioAddress` on an account is DEFAULT_ADMIN-only (`0x9BC9…` for accounts created with the current `accountsAdmin`). No deposit/withdraw functions of their own; the only token-adjacent external call is `_call` → `symmioAddress.call`. **No E-U path.**

### 2.9 Base OnChainSymmioVault v1 family (dead)

- The one initialized V1 proxy `0x7785fE35…` has `currentDeposit=0`, `lockedBalance=0`, USDC=0, LP `totalSupply=0`; roles: BALANCER `0x6b3535Be…`, SETTER+ADMIN `0xf1d63df1…` (both EOAs), no PAUSER. The four other OnChainSymmioVault contracts are uninitialized implementations. The V1 `claimForWithdrawRequest` is permissionless but receiver-bound and `Ready`-gated; there are no funds and no requests. **No value at risk.**

### 2.10 INTX token / staking / airdrop (task 4)

- The canonical INTX is the LayerZero OFT `0x7D27187e…` (owner = Gnosis Safe `0x06f246ea…`). Top-100 holder scan: 19 contracts, none is an IntentX staking/rewards/merkle/airdrop contract; they are routers/settlement/7702 delegated EOAs. Blockscout name searches (`Staking`, `xINTX`, `Merkle`, `Airdrop`, `Distributor`, `Claim`) produced no IntentX staking contract; the SYMMIO `AirdropHelper`/`SymmVesting`/`SymmioFeeDistributor` on Base hold 0 INTX.
- Result: **no contract holding INTX with a permissionless claim/drain path was identified**, and no unclaimed merkle/airdrop pool associated with the OFT was identified. (The legacy unverified 100.3 B-supply `0x8A6455fA…` token is a separate contract; no claim path identified either.)

---

## 3. Explicit negative results (gate evidence)

| Contract | Function attempted | Caller | Result (live `eth_call`) |
|---|---|---|---|
| Base MultiAccount | `depositAndAllocateForAccount` | `0x1111…` | revert `MultiAccount: Sender isn't owner of account` |
| Base MultiAccount | `_call` (existing account) | `0x1111…` | revert `MultiAccount: Unauthorized access` |
| Base MultiAccount | `withdrawFromAccount` | `0x1111…` | revert `MultiAccount: Sender isn't owner of account` |
| Base SymmioPartyA | `_call` | `0x1111…` | revert `AccessControl: … missing role 0xebee9ae4…` (MULTIACCOUNT_ROLE) |
| Arb V2 vault | `requestWithdraw` (bogus sig) | `0x1111…` | revert `ECDSA: invalid signature` |
| Arb V2 vault | `claimForWithdrawRequest(0)` | `0x1111…` | succeeds → pays bound receiver `0x8Fab4e5Ba…`, not caller |
| Arb SolverVault | `requestWithdraw` (bogus sig) | `0x1111…` | revert `0xf645eedf` (`ECDSAInvalidSignature`) |
| Arb SolverVault | `rebalance` | `0x1111…` | revert `AccessControlUnauthorizedAccount(0x1111…, 0xccc64574…)` |
| Base CarbonFeeRebate | `claim` (bogus sig) | `0x1111…` | revert `Signer =! Trusted.` |
| Arb/Base SYMMIO | `isCallFromInstantLayer()` | `0x1111…` | returns `false` (no instant-layer bypass) |

No candidate E-U extraction path exists to report.

---

## 4. Method and limitations

- Read-only only: `eth_call`, `eth_getCode`, `eth_getStorageAt`, `eth_getLogs`, Etherscan V2 (`contract` + `logs` modules), Blockscout v2, GoldRush holders. **No transaction was signed or broadcast; no keys were touched.**
- Etherscan V2 free tier blocks `account` module on Base/Arb → transaction/creation enumeration used Blockscout `addresses/{a}/transactions` pagination (`bs_txscan.py`, creations saved in `raw/bs_creations_*.json`) and deploy-script logs.
- Mantle (`explorer.mantle.xyz/api/v2` = 502) and Blast (`blast.blockscout.com/api/v2` = 404) explorers were unavailable; those chains were covered by direct RPC reads of the known proxies/impls and by the IntentX subgraph per-chain configs (`github/sg_mantle_083.json`, `sg_blast_083.json`), which list only the MultiAccount contracts.
- The V2 vault's 401 k USDC lives in the solver's SYMMIO sub-account, which is core-diamond territory (separate agent); this report only verifies that the vault has no function able to move it, and that the solver contract's write paths are role-gated.

## 5. Privileged control surface (documented for completeness — NOT unprivileged)

- **EOA `0x67736569B61BdB7F1A756EF069aB5B9590668E4c`**: deployer; PROPOSER+EXECUTOR of Base/Arb/Mantle timelocks (3-day delay); Arb MultiAccount ADMIN+SETTER; CarbonFeeRebate owner + its ProxyAdmin owner; SymmExecutor/TargetRebalancer owner. Compromise = admin-level control after the timelock delay on 3 chains, immediately on Arb MA roles.
- **Safe `0x25537fe2…` (2-of-3)**: V2 vault ADMIN and ProxyAdmin owner; solver PartyB admin/manager; SolverVault ADMIN/SETTER. Compromise = drains via upgrades/management (V2 vault itself only holds 1 USDC; the solver sub-account holds ~401 k).
- **Safe `0x14622475…` (3-of-4, includes balancer EOA `0x441ee70b…`)**: SolverVault EXECUTOR/REBALANCER (409 k USDC in-contract).
- **EOA signer `0xD6ADf61f…` (V2) / `0x751CFA90…` (SolverVault)**: can authorize withdrawal requests, but payout still needs BALANCER/EXECUTOR acceptance.
- **Safe `0x629bCef8…` (3-of-6)**: Blast MultiAccount ADMIN+SETTER + ProxyAdmin owner.
- **EOA `0x9BC9CA7e…`**: accountsAdmin of all partyA accounts (can `setSymmioAddress` on each account → redirect those accounts' calls) and Base MultiAccount PAUSER.
- The ~581.95 USDC CarbonFeeRebate surplus and ~1 USDC V2 locked claim are the only unclaimed user-side amounts identified.

## 6. Files / evidence index (all inside `intentx/analysis/periphery/`)

**Scripts**
- `es.sh` — Etherscan V2 helper (chainid/module/action).
- `bs_txscan.py` — Blockscout transaction pager; prints contract creations of an address.

**Deployed source extracts (flat, for diffing)**
- `MultiAccount_base.sol`, `MultiAccount_arb.sol`, `MultiAccount_mantle.sol` (355-line, byte-identical), `MultiAccount_blast.sol` (208-line).
- `vault_0x0b2e5F8e….sol`, `vault_0x6e79556F….sol`, `vault_0xBc40D95e….sol`, `vault_0xeD865FF8….sol`, `vault_0xC4369Fbe….sol` (Base OnChainSymmioVault variants).

**GitHub sources of record (`github/`)**
- `MultiAccount_gh.sol`, `SymmioPartyA_gh.sol`, `SymmExecutorUpgradeable_gh.sol`, `CarbonFeeRebate_gh.sol`, `NoxSolver_gh.sol` (intentx-SmartContracts main); `*_isc.sol` duplicates; `TargetRebalancer_isc.sol`, `SymmioPartyB_isc.sol`, `DeusV3MultiAccount.sol` (typo `trasnferAccount` reference); `symmioMultiAccount_abi.json`; per-chain subgraph configs `sg_*.json`, `subgraph_base.json`, `base_analytics.yaml`.
- `github/vault/` — `OnChainSymmioVaultV2.sol`, `deployProxy.ts`, `configure.ts`, `log.txt` (deployment log).
- `github/aarc_*.ts|md` — frontend constants (diamond/MultiAccount only).

**Deployed verified source trees (`sources/`)**
- `sources/8453_MultiAccount_0x54a870…/`, `sources/42161_MultiAccount_0x1cb4…/`, `sources/5000_MultiAccount_0x829a…/`, `sources/81457_MultiAccount_0xf393…/`
- `sources/8453_CarbonFeeRebate_0xcB42…/`, `sources/8453_SymmExecutorUpgradeable_0x1c52…/`, `sources/8453_NoxPartyB_0x975D…/`, `sources/8453_IntxOFT_0x7d27…/`
- `sources/SymmioPartyB_arb_0x556f…/`, `sources/SymmioPartyB_base_new_0x4a23…/`
- `sources/v2vault_arb_0x68EF…/` (deployed V2 impl), `sources/solvervault_arb_0x98058…/` (deployed SolverVault)
- `sources/vaults/` (five Base V1 source trees)

**Raw JSON/text evidence (`raw/`, 119 files)** — key ones:
- Etherscan sources: `chain8453_impl_0x54a870….json`, `chain42161_impl_0x1cb4….json`, `chain5000_impl_0x829a….json`, `chain81457_impl_0xf393….json`, `chain8453_src_0x8Ab178….json`, `chain42161_src_0x141269….json`, `chain5000_src_0xECbd07….json`, `chain81457_src_0x083267D….json`, `chain81457_src_0xd6ee1f….json`, `chain8453_src2_*.json` (SymmExecutor/Carbon/OFT), `chain8453_vault_*.json`, `chain42161_v2vault_*.json`, `chain42161_solvervault_*.json`, `partyB_*.json`, `partyA_sample_*.json`.
- Logs/receipts: `arb_v2vault_getlogs.json` (58 decoded vault events used for the fund-flow math), `arb_v2vault_logs_p1.json`, `bs_logs_0x8Ab178….json`, `bs_logs_0x433BE520….json`, `bs_logs_0x25D7572F….json`, `bs_logs_0x3c3de373….json`.
- Creation scans: `bs_creations_67736569.json` (Base 318 txs / 48 creations), `bs_creations_arb_67736569.json` (Arb), `bs_creations_9BC9.json` (Base).
- Searches/info: `bs_search_*`, `bs_search2_*`, `bs_search3_*`, `bs_base2_*`, `bs_arb_*`, `bs_info*_*.json`.
- Holders: `goldrush_intx_holders.json`, `goldrush_legacy_intx_holders.json`, `goldrush_deployer_txs.json`.

## 7. Block-number log (all reads are `eth_call`/`getLogs`; no writes)

| Chain | Block(s) | What was read |
|---|---|---|
| Base | 52,124,753 | MultiAccount proxy/impl/admin slots, paused, symmio, accountsAdmin, saltCounter, revokeCooldown |
| Base | 52,126,160 | MultiAccount role checks, timelock checks, SymmExecutor owners/keepers, V1 vault reserve |
| Base | 52,127,298 | CarbonFeeRebate live state, INTX token, NoxPartyB balances, `eth_call` gate simulations |
| Base | 52,127,298 | Final: timelock/Safe identities, init slots, keeper code checks |
| Arbitrum | 511,339,081 | V2 impl state (uninitialized), V2 deployment found |
| Arbitrum | 511,339,455 | V2 proxy full state + role enumeration |
| Arbitrum | 511,342,997 | SolverVault states/roles, MultiAccount Arb, solver PartyB probes, `isCallFromInstantLayer` probes, gate simulations |
| Arbitrum | 511,349,904 | V2 request structs, claim simulation, Safe owners, bogus-signature simulations |
| Mantle | 101,455,947 | MultiAccount proxy/impl/admin, roles, ProxyAdmin owner (timelock) |
| Blast | 41,116,198 / 41,116,205 | Both MultiAccount proxies, roles, ProxyAdmin → Safe |

*Report generated read-only from the live chains on 2026-10-03. All statements above are backed by the saved raw evidence; no speculation beyond explicitly labelled privileged-key observations.*
