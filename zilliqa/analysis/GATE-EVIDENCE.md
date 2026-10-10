# C2-58 — Gate evidence (raw read-only outputs)

All calls are `eth_call` simulations against the live chain via `https://api.zilliqa.com`
(no transactions). Reproducible with `analysis/scripts/collect_evidence.py`
(19/19 assertions PASS, CI run 38024023094).

## A. Z2 deposit contract (0x00000000005a494c4445504f53495450524f5859)

```
version()                -> 0x…09        (9)
getTotalStake()          -> 0xb8825eda2da1f878251508d   = 3,568,928,130.68 ZIL
getFutureTotalStake()    -> same
minimumStake()           -> 0x84595161401484a000000      = 10,000,000 ZIL
maximumStakers()         -> 0x100                        = 256
withdrawalPeriod()       -> 0x70b70                      = 461,680 blocks
blocksPerEpoch()         -> 0xe10                        = 3,600
currentEpoch()           -> 0x28fb                       = 10,491
getStakers()             -> 24 staker keys (first: 848886d0f3381a18fef63f30d201c4a556726b77962f1e68eaf129e78e9c0432df8b05f60bc5f5db48a881073bfaa368)
eth_getBalance(proxy)    -> 0xb8d59676e33b66432f51e0a    = 3,575,215,847.17 ZIL   (block 37,770,483; 3,575,198,943.17 at CI block 37,772,814)
EIP-1967 impl slot       -> 0x…05dff05a33aca5d190f8f78a47aebaa002f55d31
EIP-1967 admin slot      -> 0x00 (zero)
```

Gate tests (from = 0x1111…1111 random):

```
reinitialize()                       -> REVERT data 0xf92ee8a9  (OZ InvalidInitialization)
withdraw(<real 48-byte bls key>)     -> REVERT data 0xd7a2ae6a  (Unauthorised)
depositTopup(<real bls key>, 1 wei)  -> REVERT data 0xd7a2ae6a  (Unauthorised)
unstake(<real bls key>, 1)           -> REVERT data 0xd7a2ae6a  (Unauthorised)
setRewardAddress(<real bls key>, x)  -> REVERT data 0xd7a2ae6a  (Unauthorised)
```

`deposit_v9.sol` gating (source, `zilliqa/src/contracts/deposit_v9.sol`):

```solidity
modifier onlyControlAddress(bytes calldata blsPubKey) {
    ...
    if ($._stakersMap[blsPubKey].controlAddress != msg.sender) revert Unauthorised();
    _;
}
function _authorizeUpgrade(address) internal override {
    require(msg.sender == address(0), "system contract must be upgraded by the system");
}
function withdraw(bytes calldata blsPubKey) public { _withdraw(blsPubKey, 0); }   // -> onlyControlAddress
function _withdraw(...) internal onlyControlAddress(blsPubKey) { ... (bool sent,) = msg.sender.call{value: releasedAmount}(""); }
```

Proxy code is a pure delegatecall shell (no admin/upgrade entrypoint); see
`analysis/dep_proxy_code.txt` (355 bytes).

## B. Legacy SSNList staking (proxy 0x62a9d5d6…, impl 0xa7c67d49…)

```
eth_getBalance(proxy)                 -> 0x0
eth_getBalance(impl)                  -> 0x47c867bfac7194f9e81dc00 = 1,388,481,925.046 ZIL (block 37,770,483)
GetBalance(impl) [legacy]             -> {"balance":"1388481925046259750896","nonce":1859}  (= 1,388,481,925.046 ZIL in qa)
GetSmartContractState(impl)           -> disabled for this address ("GetSmartContractState is disabled for contract address …")
GetSmartContractSubState(paused)      -> {"constructor":"False"}   (contract NOT paused)
GetSmartContractSubState(verifier)    -> Some(0x412b55a0ebc1001f930aba8dc107022a3a2ba484), receiving addr 0x37415f95…, verifier_reward=0
state-read precompile(impl, contractadmin) -> 0x38c986f6252a32b1c0fa732784c1a94e9f42a394
state-read precompile(proxy, admin)   -> 0x38c986f6252a32b1c0fa732784c1a94e9f42a394
state-read precompile(proxy, implementation) -> 0xa7c67d49c82c7dc1b73d231640b2e4d0661d37c1
state-read precompile(impl, minstake) -> 0x8ac7230489e80000 = 10,000,000 ZIL
GetSmartContractInit(multisig)        -> owners_list = 5 addresses, required_signatures = 2 (creation block 6,744,947)
```

Scilla source gating (`ssnlist.scilla`, `proxy.scilla` in this folder):

```
procedure validate_proxy()   : is_proxy = builtin eq _sender proxy_address  (throw otherwise)
procedure validate_admin(i)  : is_admin = builtin eq i contractadmin
procedure validate_verifier(i): is_verifier = builtin eq i verifier
transition drain_contract_balance(initiator) : validate_proxy; validate_admin initiator; TransferFunds bal initiator
```

Every transition in the deployed SSNList v1.1 calls `validate_proxy` (14 occurrences);
value-moving delegator transitions (`withdraw_stake_rewards`, `withdraw_stake_amount`,
`stake_deposit`, `AddFunds`) are caller-scoped via `initiator`; admin transitions
(`pause`, `unpause`, `update_admin`, `update_verifier`, `drain_contract_balance`,
`update_staking_parameter`, `add_ssn`, `remove_ssn`) require `validate_admin initiator`;
`assign_stake_reward` requires `validate_verifier initiator`.

## C. scilla_call precompile allowlist (0x…5a494c53)

Raw `abi.encode(target, transition, mode[, args])` input, `mode = 1` (keep origin).

| From | Target / transition | Result |
|---|---|---|
| `0x1111…1111` (random) | SSNList proxy / `AddFunds` | **REVERT** (whole-tx failure; allowlist) |
| `0x03A79429acc808e4261a68b0117aCD43Cb0FdBfa` (allow-listed) | SSNList proxy / `AddFunds` | **SUCCESS `0x`** |
| allow-listed | SSNList impl / `drain_contract_balance(initiator = 0x38c986f6…)` | **REVERT** (`validate_proxy`: sender ≠ proxy) |
| allow-listed | SSNList proxy / `withdraw_stake_rewards` | REVERT (no SSN entry for that caller) |

Source (`zq2/zilliqa/src/precompiles/scilla.rs`, mainnet fork `tighten_precompile_rules` +
allowlist active since block 29,108,584, 2026-06-16):

```rust
// Optional caller allowlist. When the list is non-empty, only the listed addresses may
// invoke the `scilla_call` precompile; any other caller fails the whole transaction.
if !allowlist.is_empty() && !allowlist.contains(&inputs.caller) {
    ctx.chain.enforce_transaction_failure = true; ... PrecompileError
}
```

Sender resolution (`call_mode_1_sets_caller_to_parent_caller` = true at genesis):
`mode 1` → original tx signer (or parent caller at depth ≥ 2); `mode 0` → immediate caller.
Neither can be a Scilla contract address that the attacker does not control, so a direct
call to the SSNList **implementation** can never pass `validate_proxy`.

## D. Escrow claim vault (0x00000000005a494c31455343524f5750524f5859)

```
eth_getBalance                        -> 0x21ff07eb9aa067a961d40 = 2,568,681.35 ZIL
EIP-1967 impl slot                    -> 0x…3a1af9034449a8c0375af7027f1bea5ecfb604af
claim(garbage proof, dst=…, chainid=32769) -> REVERT "No balance lodged"
```

`escrow_v1.sol`: `lodge()` public payable (credit to `msg.sender`); `claim()` requires a
Groth16 proof over (old_address, new_address, chain_id); `_authorizeUpgrade` requires
`msg.sender == address(0)`.

## E. Legacy transaction handling (why Scilla txs are dead)

`zq2/zilliqa/src/exec.rs`:

```rust
if let Transaction::Zilliqa(txn) = txn {
    if fork.zil_transfers_only_to_escrow {           // active since block 36,383,379 (2026-09-22)
        let to_escrow = txn.to_addr == contract_addr::ESCROW_PROXY;
        let payload = if to_escrow { LODGE } else { Vec::new() };
        ... apply_transaction_evm(from, Some(ESCROW_PROXY), ..., amount, payload, ...)  // target is ALWAYS escrow
        return ...
    }
    if fork.disable_zilliqa_txn_execution {          // active since block 31,759,109 (2026-07-20)
        return Err("Zilliqa transaction execution is disabled at block {}");
    }
    ...
}
```

Net effect: a legacy transaction can only move ZIL into the escrow; it can never invoke a
Scilla contract transition.
