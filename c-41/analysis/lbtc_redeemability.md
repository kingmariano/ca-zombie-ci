# C-41 · Mode LBTC redeemability & realizable value

**Date:** 2026-10-03 · **Method:** read-only eth_call/eth_getLogs + verified source (Mode Blockscout) · no transactions.
**Blocks:** Mode tip ~45,427,000; Ethereum tip ~26,107,000+.

## 1. What the Mode LBTC token actually is

- Mode LBTC `0x964dd444e3192F636322229080A576077B06FbA3` is a **TransparentUpgradeableProxy**
  (EIP-1967 impl `0x5F6e76202AcfC8D0B833d9a6e74991BEb08b7FfC`, verified name **`LBTC`**).
- It is **not a LayerZero OFT** and has no OFT peer/endpoint functions. It is Lombard's native
  LBTC contract with an **independent supply** per chain ("LBTC on source and destination chains
  are linked with independent supplies" — source comment). Verified source file:
  `analysis/src_lbtc/main.sol` (contracts/LBTC/LBTC.sol).
- Total supply on Mode: **254.00015 LBTC** (8 dec); the ionLBTC market holds **249.00006075**.

## 2. Peg-out (BTC redemption) is DISABLED on Mode

`redeem(bytes scriptPubkey, uint256 amount)` burns LBTC and emits `UnstakeRequest` for the
consortium to pay BTC to the scriptPubkey. Live state (block ~45,427,000):

| check | call | result |
|---|---|---|
| withdrawals flag | `LBTCStorage` slot `0xa9a2395e…c700`+3, low byte | **0 → disabled** |
| ever enabled? | `WithdrawalsEnabled(bool)` logs since genesis | **none** |
| treasury | `getTreasury()` | **`0x0` (unset)** |
| paused | `paused()` | false |
| pauser | `pauser()` | `0x0` |
| burn commission | `getBurnCommission()` | 10,000 sat (0.0001 BTC) |
| owner | `owner()` | `0xB463A294Ff2cBd3D75A2FbcBD35cF6072661b8e3` (contract) |
| consortium | `consortium()` | `0x0Ae91EC854dBAFBC59Fc96B90c46255beE9D67aE` |

- `redeem(<P2WSH script>, 1e5)` from the depositor reverts **`WithdrawalsDisabled()` (0x46ee9e35)**
  — proven on a Mode fork (`poc/test/IonicC41.t.sol::test_mode_lbtc_redeem_reverts_withdrawals_disabled`).
- Even if withdrawals were enabled, `_transfer(from, getTreasury(), fee)` would transfer the fee to
  `address(0)` (treasury unset) → the standard OZ ERC20 check reverts. So **two independent gates**
  close the BTC peg-out: flag = false and treasury = 0.

## 3. Bridge-out is also closed

- `depositToBridge(bytes32 toChain, bytes32 toAddress, uint64 amount)` requires
  `destinations[toChain] != 0`.
- `getDestination(bytes32(1))` (Ethereum) = `0x0`; **no `BridgeDestinationAdded` logs ever** →
  no destination is registered for any chain → `depositToBridge` reverts `UnknownDestination()`.
- There is therefore **no Mode → Ethereum (or any chain) LBTC path**.

## 4. The only on-chain venue is also closed

- Mode LBTC holders: ionLBTC market (249.00006075), Balancer V2 Vault (3.9999321),
  depositor EOA (1.00000000), plus dust.
- The Balancer pool `0xcc53c20aD428359FbaEF29684Dd2c9B55F378ce6` (BPT `LBTC/wBTC`, poolId
  `0xcc53c20a…000000000000000000000015`) holds (latest) **3.9999321 LBTC + 0.20025164 WBTC
  ≈ $16.9k** — but `Vault.swap(...)` for LBTC→WBTC **reverts `BAL#402` (SWAP_DISABLED)** for
  every size tested (1 LBTC, 0.01, 0.001, 0.0001). The pool is paused for swaps.
- No other LBTC pool exists on Mode (holders: market, Balancer Vault, depositor, 4 dust EOAs;
  no other contract holds LBTC).
- Therefore there is **no market at all** for Mode LBTC today: even a holder who obtains LBTC
  cannot sell it on-chain. Realizable value ≈ $0 for everyone until the pool is un-paused or a
  new venue appears (both privileged/third-party actions).

## 5. Contrast: Ethereum LBTC is live and redeemable

- Ethereum LBTC `0x8236a87084f8B84306f72007F36F2618A5634494`: `paused()=false`,
  `getTreasury()=0x251a604E8E8f6906d60f8dedC5aAeb8CD38F4892`, withdrawals flag (same LBTCStorage
  slot) = **0x01 → enabled**, total supply 7,507.86 LBTC, owner `0x055E84e7…`.
- So Lombard's peg-out works on Ethereum but the **Mode deployment is in a closed state**
  (withdrawals off, treasury unset, no bridge destinations) — consistent with an abandoned/
  limited deployment.

## 6. Who can recover the 249 LBTC, and how much

| actor | path | realizable |
|---|---|---|
| External unprivileged attacker | none (see `README.md` path table) | **$0** |
| ionLBTC depositor `0x9E34d89C…` (EOA) | redeem blocked by missing oracle; Mode LBTC peg-out/bridge closed; the only pool has swaps disabled | **$0 today** (and $0 even after an oracle fix, until a venue or peg-out is restored) |
| cToken holder `0x1155b614…` (NOT a member, 55,375 cTokens) | `redeem` skips the oracle for non-members → **works** | **~$9.4** (0.00011075 LBTC) |
| Privileged (comptroller/oracle admin Safe 2-of-4 + LBTC owner) | add LBTC oracle + enable withdrawals/set treasury | up to **~$21.13M** nominal (249.00006075 × $84,869.01) after privileged action |

**Nominal value:** 249.00006075 LBTC × $84,869.01 = **$21,132,250** (LBTC price from DefiLlama
`ethereum:0x8236a870…`, 2026-10-03; BTC spot $84,571.50).
**Realizable today by anyone unprivileged: $0.** Holder self-service: $0 (blocked). The value is
effectively **S (stuck)**, with a **P (privileged)** restoration path.

## 7. Caveats

- The Mode RPC does not serve a native Mode LBTC price; Ethereum-LBTC parity is used for the
  nominal figure only. Parity is not realizable given the closed peg-out.
- The consortium/owner could re-enable withdrawals and set a treasury at any time (privileged),
  which would restore the depositor's recovery path after the oracle is also fixed.
- If the Balancer pool is un-paused or a new LBTC venue appears, the realizable value would change;
  the buy-side liquidity is only ~0.2 WBTC (~$16.9k) either way.
