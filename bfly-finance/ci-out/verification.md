# BFly Finance — live verification (read-only)

- generated: 2026-10-03T17:00:44.086996Z
- Starcoin mainnet chain_id=1 head=32904633 (0x60188a35d8deb1d4...)
- global switch (protocol freeze): **False**
- STC pool: 14,060,938.315 STC locked, 34,928.867 FAI debt, 189 vaults
- oracle STC/USD: 10000/1000000 -> **$0.01/STC** (protocol-internal, 90x the last market print)
- liquidatable vaults live: **31**, collateral 4,051,161 STC, debt+fee 37,718.44 FAI

## The live arbitrage (deployed bytecode + live pool state)

- deployed liquidation seizure: **111.11 STC per 1 FAI repaid** (clip formula: cover*1e8/(price_value*(100-penalty)))
- TokenSwap STC/FAI pool: 410,813.79 STC / 21,413.90 FAI -> **19.18 STC per FAI**
- DEX swap fee: [3, 1000] (0.3%); DEX freeze: [False]

### Full-cycle attack: XUSDT -> STC -> FAI -> liquidate whale -> STC -> XUSDT

- spend **786.34 XUSDT** -> buy 574,795 STC -> buy 12,472.68 FAI
- liquidate underwater whale vault 0x0c357315f9351540114596324f41006e (HF 0.7158364720919949) -> seize **1,385,854 STC**
- sell STC -> receive **1,561.44 XUSDT**
- **NET PROFIT = 775.10 XUSDT (1.9857x)**
- STC-holder variant: net **+811,059 STC** (sellable for 778.14 XUSDT)

## Why the other paths are closed

- `MarketScript::liquidation -> Liquidation::clip -> STCVaultPoolA::crack` is the only permissionless value-moving path; `crack`/`Vault::rearrange` are `public(friend)` and enforce the clip ratio.
- `Config::update_config` is **deprecated (aborts)**; `update_config_sign`/`set_global_switch` are admin-gated.
- `Treasury::get_with_capability` needs a `WithdrawCapability` only the admin holds; `Treasury::withdraw` uses the signer's own vault.
- `lock_*` paths require a `VaultPoolConfigExtension` that does not exist; `STCTreasury`/`STCVaultPoolB` are not initialized.
- Minting FAI to liquidate is a structural loss (300 STC locked per FAI vs 111.11 STC seized); the profit exists **only** because the STC/FAI DEX pool misprices FAI at ~19-40 STC.

## Verdict

- **External unprivileged extractable value: ~775 XUSDT (bridged USDT) — executable today, net of 0.3% swap fees and slippage.**
- In STC terms: **+811,059 STC**; at the last market print ($0.00011112/STC) that is ~$90.12; at the protocol oracle it is $8,110.59.
- Capital required: ~786 XUSDT (or ~575k STC already held); both obtainable on-chain. The opportunity persists until the pool re-prices.