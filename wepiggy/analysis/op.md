# WePiggy — Optimism (OP Mainnet, chainid 10) Compound-v2-fork deployment

**Status: FOUND and fully enumerated.** Snapshot block **157942842** (`0x96a043a`), 2026-10-08 18:34:21 UTC.

## How the comptroller was found

1. `WePiggy/contract_addresses` GitHub repo (README, `main` branch) has an **Optimism** section listing `COMPTROLLER = 0x896aecb9E73Bf21C50855B7874729596d0e511CB` plus all pTokens, IRMs, price provider.
2. Independently confirmed by DefiLlama-Adapters `registries/compound.js` → `'wepiggy'` entry: `optimism: { comptroller: '0x896aecb9E73Bf21C50855B7874729596d0e511CB', cether: '0x8e1e582879Cb8baC6283368e8ede458B63F499a5' }`.
3. On-chain confirmation: `getAllMarkets()` on that address returns 7 markets whose symbols (pETH, pUSDC, pUSDT, pDAI, pWBTC, pLINK, pOP) match the README exactly.
4. Etherscan V2 (chainid=10) `getsourcecode`: contract name `TransparentUpgradeableProxy`, impl `0x16b321c99ab31a84d565ea484f035693718c3e71` (`Comptroller`, compiler v0.8.2). Note: the OP deployment uses a **custom Comptroller fork** (OpenZeppelin-style transparent proxy, not the unitroller pattern).

## Comptroller state

- Comptroller (proxy): `0x896aecb9E73Bf21C50855B7874729596d0e511CB`
- Implementation: `0x16b321c99ab31a84d565ea484f035693718c3e71`
- Oracle: `0xb205d0aef84c666fbbe441c61dc04feb844444e6` (= `WP_PIGGY_PRICE_PROVIDER_V1` per README)
- Pause guardian: `0x4d083d94520a6cf295a039aca39e0df09998a053`; close factor 0.50; liquidation incentive 1.08
- Global pause flags: mint=False, borrow=False, transfer=False, seize=False, distributeWpcPaused=False
- **Fork quirk:** per-market pauses live in `pTokenMintGuardianPaused` / `pTokenBorrowGuardianPaused` mappings (not Compound's `mintGuardianPaused`); the plain `mintGuardianPaused(address)` getter reverts. Values below.

## Markets (7) — amounts

| Symbol | cToken | Underlying | Dec | Cash (tokens) | totalSupply (cToken units) | Supply (underlying) | Borrows | Reserves | exchangeRateStored | Supply USD | Cash USD |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pETH | `0x8e1e582879cb8bac6283368e8ede458b63f499a5` | `native ETH (cether; underlying() reverts)` | 18 | 10.226169 | 49129320416 | 10.140836 | 0.570977 | 0.656310 | 2.064111e+26 | $24,766 | $24,975 |
| pUSDC | `0x811cd5cb4cc43f44600cfa5ee3f37a402c82aec2` | `0x7f5c764cbc14f9669b88837ca1490cca17c31607` | 6 | 33403.561689 | 141008729309396 | 37683.497561 | 6760.187796 | 2480.251923 | 2.672423e+14 | $37,669 | $33,391 |
| pUSDT | `0x8158b34ff8a36dd9e4519d62c52913c24ad5554b` | `0x94b008aa00579c1307b0ef2c499ad98a8ce58e58` | 6 | 1924.943020 | 14571010633254 | 4730.852817 | 3873.097985 | 1067.188187 | 3.246757e+14 | $4,727 | $1,924 |
| pDAI | `0xc12b9d620bfcb48be3e0ccbf0ea80c717333b46f` | `0xda10009cbd5d07dd0cecc66161fc93d7c9000da1` | 18 | 1283.000325 | 7956293284854 | 3303.978135 | 2834.510186 | 813.532376 | 4.152660e+26 | $3,304 | $1,283 |
| pWBTC | `0x48a5322c3021d5ed5ce4293112141045d12c7efc` | `0x68f180fcce6836688e9084f035309e29bf0a2095` | 8 | 0.103732 | 444117503 | 0.095944 | 0.000395 | 0.008184 | 2.160324e+16 | $7,796 | $8,428 |
| pLINK | `0x8f00a5e13b3f2aaaddc9708ad5c77fbcc300b0ee` | `0x350a791bfc2c21f9ed5d10980dad2e2638ffa7f6` | 18 | 141.986003 | 1262950994059 | 280.984104 | 161.819683 | 22.821582 | 2.224822e+26 | $3,488 | $1,762 |
| pOP | `0xd6a78766514cdfc1a1fa188a7782b52313133705` | `0x4200000000000000000000000000000000000042` | 18 | 1239.510974 | 2259958803886 | 463.497335 | 15.642436 | 791.656075 | 2.050911e+26 | $53 | $142 |
| **TOTAL** | | | | | | | | | | **$81,804** | **$71,905** |

*Supply (underlying) = totalSupply × exchangeRateStored / 1e18; USD prices: DefiLlama coins API (ETH $2,442.25, WBTC $81,251.68, LINK $12.41, OP $0.1147; stables ≈ $1.00). DefiLlama protocol TVL for OP at same time ≈ $72.9k, consistent.*

## Markets — risk parameters

| Symbol | CF | isListed | pTokenMintPaused | pTokenBorrowPaused | mintCap | borrowCap | oraclePrice | InterestRateModel |
|---|---|---|---|---|---|---|---|---|
| pETH | 0.80 | True | False | False | 0 | 0 | $2,443.9028 | `0x5ea2321abff78e81702ce877319cd775e0dc865b` |
| pUSDC | 0.90 | True | False | False | 0 | 0 | $0.9998 | `0xd58fb16eace4693b2c641cae6850a82763c00a34` |
| pUSDT | 0.90 | True | False | False | 0 | 0 | $0.9995 | `0xd58fb16eace4693b2c641cae6850a82763c00a34` |
| pDAI | 0.90 | True | False | False | 0 | 0 | $0.9999 | `0xd58fb16eace4693b2c641cae6850a82763c00a34` |
| pWBTC | 0.80 | True | False | False | 0 | 0 | $81,329.6216 | `0x5ea2321abff78e81702ce877319cd775e0dc865b` |
| pLINK | 0.60 | True | False | False | 3,255,072 | 0 | $12.4055 | `0xffceacfd39117030314a07b2c86da36e51787948` |
| pOP | 0.60 | True | False | False | 4,294,967 | 0 | $0.1153 | `0xffceacfd39117030314a07b2c86da36e51787948` |

*mintCap values: pLINK 3,255,072; pOP 4,294,967 (≈2^32); others 0 = unset. borrowCap 0 (unset) for all. Oracle prices match current market (OP $0.1147 vs oracle $0.1153; ETH $2,442 vs oracle $2,443.9).*

## Empty / near-empty market analysis (Hundred-Finance donation-attack class)

**No market has totalSupply == 0.** All 7 markets are listed with CF > 0, so all are collateralizable. Ranked by smallest supply value (the relevant donation-manipulation surface):

1. **pOP** `0xd6a78766514cdfc1a1fa188a7782b52313133705` — smallest market by far: totalSupply = 2,259,958,803,886 units (22,599.6 cOP); supply = **463.497335 OP ($53)**; cash = **1,239.510974 OP ($142)**; cash/supply = 2.67 (cash > supply because reserves = 791.656075 OP). CF 0.60.
2. **pLINK** `0x8f00a5e13b3f2aaaddc9708ad5c77fbcc300b0ee` — supply = **280.984104 LINK ($3,488)**; cash = **141.986003 LINK ($1,762)**; reserves 22.821582; CF 0.60.
3. **pWBTC** `0x48a5322c3021d5ed5ce4293112141045d12c7efc` — supply = **0.095944 WBTC ($7,796)**; cash = **0.103732 WBTC ($8,428)**; cash/supply = 1.08; CF 0.80.

Largest markets for context: pUSDC supply 37,683.50 USDC / cash 33,403.56; pETH supply 10.140836 ETH / cash 10.226169 ETH (native cether market — `underlying()` reverts by design).

No truly empty (zero-supply, cash>0) market exists at this block, so the classic first-minter-captures-cash condition is not met. pOP is the only market where cash exceeds supply, and it is tiny ($142). All guardian pause flags are `false` (nothing paused).

## Artifacts
- Raw full state: `op-markets.json` (all fields incl. accrualBlockNumber, borrowIndex, reserveFactorMantissa, per-market pause flags)
- Prices: `op-prices.json`; block: `op-block.txt`
- Implementation source: `op-comptroller-impl.sol`; README copy: `contract_addresses_README.md`

RPC used: https://optimism-rpc.publicnode.com (public mainnet.optimism.io rejects batches >~16 calls with HTTP 413; helper `rpc.py` batch() now chunks at 24).
