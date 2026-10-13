# Child adversarial review — refuting the "$0 extractable" claim (AutoShark, BSC)

**Reviewer role:** independent adversarial verifier. **Scope:** read-only `eth_call` probes from fresh EOA
`0x00000000000000000000000000000000d34dbeef` against keyless RPC (`https://bsc-rpc.publicnode.com`).
**Blocks:** ~127,436,369. No transactions, no keys, no writes outside this dir.
**Verdict: claim NOT refuted — no material (> $100) path found for a fresh unprivileged attacker.**
One *latent* candidate is documented below with its exact preconditions; it is not currently reachable permissionlessly.

---

## 1. Probes performed (call → result, from fresh EOA)

### FeeDistributor proxies (feeTo `0x593CC303…`, impl `0xe1f153c3`; squid fee vault `0xe0B4Add509…`, impl `0x45948ce5`)
| Call | Result |
|---|---|
| `initialize(0xd34dbeef,0xd34dbeef)` (both) | revert `Initializable: contract is already initialized` |
| feeTo `distribute(address[])` / `burn(address[])` | revert `caller is not the keeper or owner` |
| feeVault `distributeSingle(address[])` | revert `caller is not the keeper or owner` |
| `withdrawBEP20(address)` (both) | revert `Ownable: caller is not the owner` |
| `transferOwnership` (both) | revert `Ownable: caller is not the owner` |

Selector-dispatch scan of implementation bytecode: 11 selectors (feeTo) / 9 (feeVault); **all** are the
gated functions above or auto-getters (`owner`, `keeper`, `router`). No missed entry point.

### jawsPool `0x5D2112Ba…` (impl `0x73f76d34`)
| Call | Result |
|---|---|
| `initialize()` | revert `already initialized` |
| `getReward()` | **succeeds, pays 0** (contract holds 0 JAWS, 0 rewardsToken LP `0x1BbA5C6C…`, 0 BNB) |
| `withdraw(1)` | revert `locked` |
| `withdrawAll()` | succeeds, pays 0 (empty) |
| `recoverBEP20`, `setRewardsToken` | revert `Ownable` |
| `notifyRewardAmount` | revert `Whitelist: caller is not on the whitelist` |

56-selector dispatch scan matched the decompile; no un-gated value-moving function.

### Launchpad `0xa9f48fee…` (impl `0x2a5d80b7`)
| Call | Result |
|---|---|
| `harvest()` | revert `have you participated?` |
| `finalWithdraw(0,0)`, `flipAllowClaim()`, `setRaisingAmount(0)` | revert `admin: wut?` |
| `initialize(...)` | revert `already initialized` |
| refund path | none exists (only `getRefundingAmount` view) |

23-selector scan: LP (3,354 ≈ $479) can only move via admin `finalWithdraw`.

### MasterOcean `0x8857af82…`
- `FINS.balanceOf(farm) = 0`; FINS `totalSupply 499,999,997.1 / max 500,000,000` → emissions dead.
- `updatePool(25)`, `massUpdatePools()`, `emergencyWithdraw(25)` succeed from fresh EOA but pay 0.
- No `migrator()` getter.

### MasterSquid `0x86a47ddd…` (the interesting one)
- Live: `squidPerBlock = 20e18`; `totalAllocPoint = 1e25 + 16,000`; **pid 15 `allocPoint = 1e25`** → pid 15 carries
  ~99.99999999999999984 % of all emissions; all other 15 pools split ~3.2e-20 SQUID/block.
- SQUID `totalSupply 30.39M` vs `maxSupply 400M` → **mint is live** (not capped out like FINS).
- `updatePool(15)` from fresh EOA **succeeds**. pid 15 `lastRewardBlock = 12,695,616` (stale since 2021):
  first update computes a 2,294,815,060 SQUID windfall mint, which exceeds the cap
  (30.39M + 2,294.8M > 400M) and **silently no-ops** (SushiToken-style `mint` returns false, ignored).
- `massUpdatePools()` **reverts**: pid 0 `SafeMath: subtraction overflow` (farm SQUID balance 80,902 wei
  < `squidStaked 1.7996e24`). Individual `updatePool(15)` still works.
- Farm SQUID float = **80,902 wei ≈ $6e-15** (the parent report's "80,902 SQUID ≈ $6" is a units error: it is wei, not tokens).
- `withdraw(15,0)` / `emergencyWithdraw(15)` from fresh EOA succeed, pay 0.
- pid 15 staker = **team owner EOA `0xbf00B8b5…`** (`userInfo(15,team) = 20e18`); that EOA also holds
  `9.9998e24 / 1e25` of the staking token.

### Peers/pairs/tokens
- Balance == reserve **exactly** on all 4 value pairs (WETH/BTCB, DAI/USDT, USDT/BUSD, FINS/WBNB), and on
  SQUID/WBNB → `skim`/`sync` pay $0; `sync()` succeeds as no-op.
- LP allowances of MasterOcean/MasterSquid/feeVault on DAI/USDT & USDT/BUSD pairs to PancakeRouter = **0**;
  team EOA `0x91d6136a…` allowance on WETH/BTCB pair to PancakeRouter and to feeTo's router = **0**.
- `FINS.burn(1)` / `SQUID.burn(1)` from fresh EOA revert; all mints role-gated.
- SQUID/WBNB pair live: 12,280,558.7 SQUID / 1.19528 WBNB (≈ $890 at report pricing).

## 2. Latent candidate (NOT currently attacker-reachable)

**Farm pid 15 emissions → dump into SQUID/WBNB.**
Sequence if the precondition held: acquire SQUIDY → `deposit(15, amt, 0)` → call `updatePool(15)` to reset the
stale clock → every later `updatePool(15)` mints ~20 SQUID/block to the farm → `withdraw(15, pending)` → sell
SQUID into pair `0x2e0484D3…` (1.195 WBNB side). Total extractable is bounded by that pool depth: ≈$890 minus
costs, over ~5–20 days depending on the attacker's share of pid 15.
**Why it is not live:** the staking token `SQUIDY 0x15c51300…` cannot be obtained permissionlessly.
Checks: owner holds 9.9998e24/1e25; `mint(address,uint256)` → `caller is not the minter`; `mint(uint256)` →
`Ownable`; **no pair** on FinsFactory, PancakeSwap v2 factory, PancakeSwap v3 (all fee tiers), ApeSwap,
BakerySwap, MDEX, BiSwap, BabySwap, or Thena. No FinsPair in the 194-pool set references SQUIDY.
The only account that can farm the live emissions is the team EOA (privileged holder = P, not E-U).

## 3. Residual uncertainty
- Approval history not scanned exhaustively (spot checks only; all zero). Bounded-time limitation.
- Non-factory/exotic SQUIDY venues not exhaustively disproven, but supply concentration (99.998 % team EOA)
  plus absence on 9 factories makes permissionless acquisition implausible.
- These do not change the verdict; confidence **high (~90 %)** that no fresh-attacker path > $100 exists today.
