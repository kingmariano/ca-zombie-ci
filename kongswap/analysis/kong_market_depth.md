# KONG market depth / governance-capture feasibility (ICP)

Read-only probe by child subagent + parent verification, 2026-10-04. All data public.

## Why this matters

The KongSwap SNS treasury (governance canister `oypg6-faaaa-aaaaq-aadza-cai`) holds
**119,042.87 ICP (~$406.8k)** and **544,236,777.56 KONG**. If an attacker could cheaply
acquire ≥20% of SNS total voting power (63.98e15 VP), they could pass a *critical*
treasury-transfer proposal (rule: ≥20% of total VP YES and ≥67% of cast YES).

Because the attacker's own stake is added to the denominator, the attacker needs
`VP_att ≥ 0.2 × (63.98e15 + VP_att)` → **VP_att ≥ 16.0e15**, i.e. **~80.0M KONG staked
with max dissolve delay (2× bonus)**. The question is whether 80M KONG is purchasable.

## Live KONG venues (2026-10-04)

| Venue / pool | Canister | KONG reserve | Quote reserve | TVL (USD) | 24h vol |
|---|---|---|---|---|---|
| ICPSwap KONG/ICP | `ye4fx-gqaaa-aaaag-qnara-cai` | 3,672,809.23 KONG | 88.955 ICP | $840.60 | 0 |
| ICPSwap KONG/MAPTF | `tzap2-xaaaa-aaaar-qbm5q-cai` | 7,940.10 KONG | 433.72 MAPTF | $1.21 | 0 |
| ICPSwap KONG/ckETH | `xm6pw-uaaaa-aaaag-qnbwa-cai` | 11,171.94 KONG | 0.0007627 ckETH | $3.68 | 0 |
| ICPSwap KONG/BOB | `nemoc-diaaa-aaaag-qndbq-cai` | 9,163.87 KONG | 19.255 BOB | $3.10 | 0 |
| ICPSwap KONG/ICS | `y7qyo-piaaa-aaaar-qaq5a-cai` | 15,799.78 KONG | 853.62 ICS | $4.93 | 0 |
| ICPSwap KONG/nanas | `yw2so-kaaaa-aaaag-qnasa-cai` | 18,447.39 KONG | 870,996 nanas | $6.42 | 0 |
| ICPSwap KONG/EXE | `ppk5w-5qaaa-aaaar-qbr3a-cai` | 26.0 KONG | 0.0665 EXE | $0.01 | 0 |
| KongSwap KONG/ICP (pool 59) | `2ipq2-…` (canister) | **0** | **0** | $0 | 0 |

- **Total KONG in all live public pools ≈ 3.74M KONG (~$547 at $0.000146)**. Total KONG
  venue reserves reported by GeckoTerminal: **$1,741.27**, 24h volume **$0**.
- GeckoTerminal still lists a "KONG / ICP on kongswap" pool with $81,557 reserve — this is
  **stale**. The actual on-chain KongSwap pool 59 has `balance_0 = 0 / balance_1 = 0`
  (verified by direct query to `2ipq2-uqaaa-aaaar-qailq-cai`, 2026-10-04) and the DEX's
  `pools(null)` query returns an empty list (all pools removed).
- No CEX order book: the CoinGecko "KongSwap" market is the (dead) DEX itself.
- KONG price feeds: SNS/CMC $0.00014485; GeckoTerminal $0.00014618; FDV ≈ $147–149k.

## Cost / feasibility to acquire the quorum stake

- Needed: **~80,000,000 KONG** (2× bonus, max dissolve delay 47,340,288 s ≈ 1.5 y).
- Deepest single pool holds **3.67M KONG**. Sweeping *every* live pool yields **<4M KONG**
  (~5% of the requirement). Constant-product buying 4M KONG from a 3.67M-KONG pool is
  already beyond the pool's entire reserve.
- At the quoted spot price the notional cost of 80M KONG would be ~$11.6k, but **the tokens
  do not exist for sale on-chain**. Acquiring them would require OTC purchases from large
  holders (team/treasury/early investors) — not a permissionless market path, and the
  dominant holder is the party the attacker would be attacking.

## Free float estimate (rough)

- Total supply: 1,016,007,322 KONG (SNS API) / 1,000,000,000 (GT normalized).
- SNS treasury: 544,236,777.56 KONG (verified on-chain).
- Staked in SNS neurons: ≥ 96M KONG in the top cluster alone (7 neurons of `ljxsi-…`),
  plus ~100M+ in other neurons (3,708 neurons total).
- Live DEX pools: ~3.74M KONG.
- Conclusion: free float is small and fragmented; **the required 80M KONG is not
  obtainable through public liquidity**.

## Confidence

**High** that an on-chain-only, unprivileged attacker cannot acquire the ~80M KONG needed
for a treasury-capture proposal today. Caveat: an attacker with large OTC access and
willing sellers (e.g., dissolved-neuron holders) could in principle assemble the stake —
that is an off-market, capital-intensive path, not permissionless extraction, and the
41%-VP incumbent bloc (`ljxsi-…`) has historically voted on treasury proposals.
