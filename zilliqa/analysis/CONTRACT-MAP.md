# C2-58 — Zilliqa contract map (legacy staking + Z2 deposit)

All reads on **Zilliqa 2 mainnet (EVM, chainId 32769)** via the keyless public RPC
`https://api.zilliqa.com` (`web3_clientVersion: zilliqa2/v0.21.10`). Read-only; no
transactions were signed or sent. Units: legacy JSON-RPC `GetBalance` returns **qa**
(1 ZIL = 1e12 qa); `eth_getBalance` returns **wei** (1 ZIL = 1e18 wei).

Reference block for the state below: **37,772,614** (2026-10-10 ~04:25 UTC), unless stated.

## 1. Legacy staking (ZIP-11, Scilla) — migrated from Z1 at the Z2 genesis

| # | Address (0x) | Bech32 | Role | Live balance | Gating |
|---|---|---|---|---|---|
| 1 | `0x62a9d5d611cdcae8d78005f31635898330e06b93` | `zil1v25at4s3eh9w34uqqhe3vdvfsvcwq6un3fupc2` | **SSNListProxy v1.1** (relays to impl) | 0 ZIL | `upgradeTo` / `changeProxyAdmin` / `drainProxyContractBalance` require `_sender == admin`; all other transitions relay with `initiator := _sender` |
| 2 | `0xa7c67d49c82c7dc1b73d231640b2e4d0661d37c1` | `zil15lr86jwg937urdeayvtypvhy6pnp6d7p8n5z09` | **SSNList v1.1 implementation — holds all stake** | **1,388,481,925.046 ZIL** | every transition: `validate_proxy` (sender must be the proxy) + caller-scoped `initiator`, `validate_admin`, or `validate_verifier`; `drain_contract_balance` = admin only |
| 3 | `0x38c986f6252a32b1c0fa732784c1a94e9f42a394` | (Z1-era) | **admin Wallet (Scilla multisig, 2-of-5)** | 5,533.69 ZIL (+ reward bookkeeping) | `Submit*`/`SignTransaction` owner-gated; `ExecuteTransaction` needs ≥2 signatures |
| 4 | `0x412b55a0ebc1001f930aba8dc107022a3a2ba484` | — | **verifier** (EOA, no code) | — | can only `assign_stake_reward` (reward allocation); reward receiving addr `0x37415f9581148e2e31f6740b2b88c8a49ae725f0` |
| 5 | `0x62a9d5d611cdcae8d78005f31635898330e06b93` impl slot | — | SSNListProxy state: `implementation` = #2, `admin` = #3 | — | — |

SSNList live state (block 37,772,614): `paused = false`; `contractadmin = 0x38c986f6…` (verified via the Scilla state-read precompile and `GetSmartContractSubState`); `minstake = 10,000,000 ZIL`; verifier set as above.

Multisig (`GetSmartContractInit`, creation block 6,744,947):

```
owners_list = [0x513d10c7e11949178d9d05d42df4d90ff5c3d089,
               0x2680e43cab05ddfdbb2cb9d5165769ffd8cfcd72,
               0x234cf0cf908125e3ebe91792e23898c3fc83d8fe,
               0x67205fc7eaa32d40b08f6003d1e4fd12995eb1f3,
               0xc8c6a0e9aca41cc19794bb1c60ee79c67e4d8d60]
required_signatures = 2
```

Contract sources (Scilla): `Zilliqa/staking-contract` — `ssnlist.scilla`, `proxy.scilla`,
`multisig_wallet.scilla` (copies in this folder). The deployed v1.1 bytecode is a Scilla
interpreter account (no EVM code); its state is read via legacy methods and the
state-read precompile.

## 2. Z2 staking deposit contract (EVM, core protocol contract)

| # | Address | Role | Live balance | Gating |
|---|---|---|---|---|
| 6 | `0x00000000005a494c4445504f53495450524f5859` (`ZILDEPOSITPROXY`) | EIP-1967 minimal proxy (delegatecall only; **no admin function in code**) | **3,575,198,943.17 ZIL** | impl slot = `0x05dff05a…`; admin slot = `0x00` |
| 7 | `0x05dff05a33aca5d190f8f78a47aebaa002f55d31` | deposit **v9** implementation | (stake held at proxy) | `deposit()` public payable (adds funds); `depositTopup` / `unstake` / `setControlAddress` / `setRewardAddress` / `setSigningAddress` / `_withdraw` = `onlyControlAddress`; `_authorizeUpgrade` requires `msg.sender == address(0)` (system only); `reinitialize` guarded by `reinitializer(VERSION)` |

Live values (block 37,772,614): `version() = 9`; `getTotalStake() = 3,568,928,130.68 ZIL`;
`minimumStake() = 10,000,000 ZIL`; `maximumStakers() = 256`; `withdrawalPeriod() = 461,680
blocks` (~5.3 days at 1 s blocks); `blocksPerEpoch() = 3600`; `currentEpoch() = 10,491`;
**24 live stakers**. Contract balance − total stake = 6,270,812 ZIL (pending withdrawals /
future-committee stake held by the contract).

Bytecode verification: on-chain impl code (22,972 bytes) is **byte-identical to
`zq2/zilliqa/src/contracts/deposit_v9.sol`** compiled output, except the three 20-byte
immutable slots (which hold the impl's own address on-chain and zeros in the artifact).
Diff evidence: `onchain_impl.hex` vs `artifact_v9_deposit.hex`.

## 3. Escrow / claim vault (Z1→Z2 recovery path, EVM)

| # | Address | Role | Live balance | Gating |
|---|---|---|---|---|
| 8 | `0x00000000005a494c31455343524f5750524f5859` (`ZIL1ESCROWPROXY`) | EIP-1967 minimal proxy | **2,568,681.35 ZIL** | impl slot = `0x3a1af903…`; admin slot = `0x00` |
| 9 | `0x3a1af9034449a8c0375af7027f1bea5ecfb604af` | `EscrowInit` v1 (claim vault) | — | `lodge()` public payable (credits `msg.sender`); `claim(pA,pB,pC,pubSignals)` requires a **Groth16 proof** over (old_address, new_address, chain_id); UUPS upgrade system-only |

## 4. Scilla interop precompiles (the only live way to invoke Scilla code)

| Address | Role | Gating |
|---|---|---|
| `0x000000000000000000000000000000005a494c53` | `scilla_call` precompile | caller **allowlist** of 100 contracts (mainnet fork at block 29,108,584, 2026-06-16); any other caller fails the whole transaction; native ZIL value transfers disabled since block 27,152,370 |
| `0x000000000000000000000000000000005a494c92` | Scilla state-read precompile | unrestricted (read-only) |
| `0x000000000000000000000000000000005a494c82` | penalty precompile | protocol use |

Scheduled future fork: `disable_permanently_scilla_precompiles = true` at block
99,999,999 (not active; current head ~37.77 M).

## 5. What an attacker can and cannot do

| Path | Verdict | Gate / evidence |
|---|---|---|
| Legacy Zilliqa (Scilla) tx → SSNList proxy/impl | **closed** | all legacy txns rejected since block 31,759,109 (2026-07-20); since block 36,383,379 they are rerouted to the escrow as plain transfers (`zil_transfers_only_to_escrow`) |
| EVM tx → `scilla_call` precompile → SSNList | **closed** | precompile caller allowlist (100 contracts). Verified: random caller reverts; allow-listed caller succeeds (`AddFunds`). Even an allow-listed caller cannot move funds (see below) |
| Direct impl call via precompile with forged `initiator = admin` | **closed** | `validate_proxy` requires `_sender == 0x62a9d5d6…` (the Scilla proxy); an EVM caller can never be that Scilla account. Verified revert |
| Proxy call via precompile (initiator := EVM caller) | **closed** | `validate_admin` fails: EVM caller ≠ 2-of-5 multisig address; delegator transitions are caller-scoped (only the caller's own entry) |
| Multisig `ExecuteTransaction` → proxy `drain_contract_balance` | **P only** | needs ≥2 of 5 owner signatures; the multisig itself is a Scilla contract and cannot be invoked at all today (legacy txns disabled; not in precompile allowlist) |
| Z2 deposit: withdraw/unstake to attacker | **closed** | `onlyControlAddress`; verified revert `Unauthorised()` (0xd7a2ae6a) with a real staker key from a random caller |
| Z2 deposit: reinitialize / upgrade | **closed** | `version()=9`; verified `reinitialize()` reverts `InvalidInitialization()` (0xf92ee8a9); `_authorizeUpgrade` requires `msg.sender == 0`; proxy has no admin function; admin slot = 0 |
| Escrow: claim someone else's lodged balance | **closed** | Groth16 proof bound to (old_address, new_address, chain_id); verified garbage proof reverts |

**E-U extractable: $0.00 (high confidence).**
