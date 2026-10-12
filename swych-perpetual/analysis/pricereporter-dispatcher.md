# PriceReporter dispatcher analysis (0x1CB9992c13Ac8de4d14661e7d05b3DB178b70dC5)

Raw runtime bytecode disassembled (cast code + custom parser; code 4,647 bytes).
The dispatcher (offset 0x12..0xa8) contains exactly these selector→entry points:

| selector | entry | function (resolved) | gating (verified in bytecode/eth_call) |
|---|---|---|---|
| 0x044ad7be | 0xae | isReporter(address) | view |
| 0x07b99f37 | 0xe6→0x1af | executeSwapOrders(uint256[]) | CALLER→slot1 mapping → require(isReporter[msg.sender]) |
| 0x5bf9ac5b | 0xfb→0x2a2 | postPriceAndExecuteOrders(address[],uint256[],uint256[]) | require(isReporter[msg.sender]) — revert "PriceReporter:unauthorized" observed live |
| 0x5de5c212 | 0x10e→0x403 | removeReporter(address) | onlyOwner |
| 0x5e02cb7d | 0x121→0x59d | reporters(uint256) | view |
| 0x5efa519d | 0x14c | getReporterCount() | view (slot 2) |
| 0x715018a6 | 0x15d | renounceOwnership() | onlyOwner |
| 0x8da5cb5b | 0x165 | owner() | view |
| 0x93a91e33 | 0x176→0x5db | unknown batch function | require(isReporter[msg.sender]) (same CALLER→slot1 check at 0x5dc..0x5ef) |
| 0xdd8755f2 | 0x189→0xa11 | addReporter(address) | onlyOwner |
| 0xf2fde38b | 0x19c→0xb47 | transferOwnership(address) | onlyOwner |

## Critical finding

`executeOrder(uint256,address)` (0x7e498c81), `executeSwapOrder(uint256,address)` (0x04358662) and
`postPrices(address[],uint256[])` (0x5cdb595c) are **NOT dispatcher entries** in the deployed contract.
They appear in the bytecode only as PUSH4 constants used for *outgoing* calls
(0x7e498c81 = OrderManager.executeOrder, 0x04358662 = OrderManager.executeSwapOrder,
0x5cdb595c = PriceOracle.postPrices). eth_call with those selectors falls through to the fallback and
reverts with empty data — for every caller, including whitelisted reporters.

Therefore the deployed PriceReporter (and its identical twin 0x161BddB95C079AE14F6EE85A246E106D1a00143d)
has **no unprivileged entry point**. Order execution is possible only through the three whitelisted
reporter EOAs [0x2E7B39eF…, 0x75cE0c34…, 0x6f369f5d…], which stopped transacting in 2024-03/2025-01.
The OrderManager itself accepts executeOrder only from this PriceReporter (`onlyExecutor`).

⇒ The entire order/position/liquidation surface is unreachable for an external unprivileged attacker.
