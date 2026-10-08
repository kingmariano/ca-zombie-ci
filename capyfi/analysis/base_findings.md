# CapyFi on Base (chain 8453) — verified deployment & extractable value

**Date:** 2026-10-08 · **Blocks used:** enumeration @ 52,347,849 (hash 0xb3b229ead539bed345…), liquidity checks ~52,349,000–52,349,600, Borrow-log scan 45,692,792–52,348,700 · **Method:** read-only public RPC + GoldRush (Covalent) event logs; no tx signed/sent.

## Verdict

**No unprivileged extraction path found today. Extractable ≈ $0.** The protocol holds **≈$83.1k idle market cash** (oracle prices) / **$81.2k** (DefiLlama), against **$4,591 total borrower debt**. All 32 borrowers are solvent (`shortfall = 0`). Oracles are healthy and not attacker-manipulable; admin is a 4/7 Gnosis Safe with no pending changes.

## 1. Verified deployment (all suspicious addresses resolved)

| Role | Address | Evidence |
|---|---|---|
| Unitroller proxy | `0x00dc4965916e03A734190fA382633657c71f867E` | has code, `getAllMarkets()` → 7 markets; verified source "Unitroller", proxy=1 |
| Comptroller impl | `0xD31F102994eD0b01E5d5D25CBA0a4bFBCA9c5076` | `comptrollerImplementation()`; verified source **byte-identical (normalized) to the Ethereum Comptroller impl** |
| Oracle | `0x03c1cF154d621E0Fd7e2b88be3aE60CCf07Aca31` | verified "ChainlinkPriceOracle"; `getUnderlyingPrice` identical to Ethereum version |
| Admin (Unitroller + oracle + all cTokens) | `0x6C15e4Bc44CC5674b1d7956D0e9596d2E509eD24` | **Gnosis Safe v1.4.1, 7 owners, threshold 4**, nonce 15 |
| Unitroller creation | tx `0xd4ea7dae…60693`, deployer `0x6a138bd6d69feb3c2f5426549e60e644778ad04c`, block 45,691,089 (2026-05-07) | block scan |

**Address-collision explanation (not a hijack):** the docs-listed Base Unitroller `0x00dc…f867E` is the *same address as the Ethereum Comptroller impl* because deployer `0x6a138bd6…` used CREATE with the same nonce sequence in **different order** on the two chains. On Ethereum nonce1 = Comptroller impl; on Base nonce1 = Unitroller proxy. Same story for the oracle (`0x03c1cF…`: ETH nonce9 = caETH IRM, Base nonce9 = ChainlinkPriceOracle). The Ethereum Unitroller `0x0b9af1…` has **no code on Base** — the docs are wrong about that address, but the listed Base Unitroller is genuine.

Config: `closeFactor = 0.5`, `liquidationIncentive = 1.08` (8% bonus), `pauseGuardian = 0`, `pendingAdmin = 0`, `pendingComptrollerImplementation = 0`; global mint/borrow/transfer/seize pauses all `false`; **whitelist = 0x0 on all 7 markets** (open mint). All 6 CErc20 markets share one delegate impl `0x40161dC1b52A4dA762Df7C3b1e77288CB0A97DE6` (byte-identical on all; source identical to Ethereum); caETH is a direct CEther. `sweepToken` is admin-only.

## 2. Markets (7 — two are undocumented: caWMXN, caWCOP)

| cToken | Market | Underlying | Cash | Oracle USD | DefiLlama USD | Borrows | Reserves | CF |
|---|---|---|---|---|---|---|---|---|
| caETH | `0x654A9003…548e` | native ETH | 2.413895 | $5,904.96 | $5,902.81 | 0 | 0.0000177 | 0.80 |
| caCBBTC | `0x0D8105B7…B642` | cbBTC | 0.07455379 | $6,072.83 | $6,072.16 | 0.0000005 | 0 | 0.80 |
| caUSDC | `0x5aDb71ad…26C7` | USDC | 14,985.227137 | $14,982.42 | $14,979.62 | 240.007438 | 0.001097 | 0.85 |
| caWARS | `0x304Cc258…4d23` | wARS | 41,861,466.50 | $27,585.87 | $26,086.03 | 4,907,746.43 | 30,044.41 | **0** |
| caWBRL | `0x60122282…1FC8` | wBRL | 143,001.2229 | $28,545.44 | $28,114.27 | 5,595.24 | 59.37 | **0** |
| caWMXN | `0x089b8704…6fC8` | wMXN | 200 | $10.99 | $11.10 | 0 | 0 | **0** |
| caWCOP | `0xc8010267…94ab` | wCOP | 50,000 | $15.55 | $15.50 | 0 | 0 | **0** |
| **Total** | | | | **$83,118.07** | **$81,181.49** | **$4,591.01** | $31.69 | |

Mint/borrow guardian pauses: all `false`. Borrow caps: 26 ETH / 4 cbBTC / 5,000 USDC / 20M wARS / 35k wBRL / 5k wMXN / 1.5M wCOP. **Backing invariant holds exactly for every market** (`cash + borrows − reserves == totalSupply × exchangeRateStored`; surplus = 0), i.e. no unbacked cTokens, no donation imbalance.

## 3. Borrowers / liquidatability (complete)

- Borrow events: 101 unique logs → **32 unique borrowers** (GoldRush + cross-checked; sum of current per-borrower debts equals `totalBorrows` to within interest-accrual rounding — borrower set is complete).
- `getAccountLiquidity` on all 32: **shortfall = 0 everywhere → nothing is liquidatable.**
- Nearest-to-edge meaningful account: `0xafe8d60a…9a45` (debt $199.97, remaining liquidity $67.22; healthy). Dust accounts `0xe19fe0e2…ea53` and `0x3d72fb63…ab29` have ~$1e-6 remaining liquidity but sub-$0.002 debt — max liquidation profit < $0.001.
- Dominant account `0x7e3022…8d5c` holds ~80–99% of cETH/cCBBTC/cUSDC/cWARS/cWBRL cTokens (≈$76.6k collateral) and owes $4,277; liquidity $17,679. The protocol is effectively one whale depositor (likely the team treasury).

## 4. Extractable-value candidate paths

1. **Liquidations (8% bonus, 50% close factor)** — no shortfall accounts → $0. Confidence: definitive.
2. **Oracle manipulation** — ETH/cbBTC/USDC/BRL/MXN feeds are canonical Chainlink `EACAggregatorProxy`s (live, updated minutes ago). wARS/wCOP feeds are custom `CapyfiAggregatorV3` **push** oracles: owner/authorized-only `updateAnswer`, bounds enabled (wARS 0.0005–0.00077, wCOP 0.00013–0.0004), updated every ~2h through Safe `0x35ede363…` (relayer `0xacdc3eba…`). Prices are within 0.3–5.8% of DefiLlama; wARS/wBRL oracle reads *high* (bad for a borrower), so no borrow-side arbitrage. No unprivileged manipulation path. Confidence: high.
3. **Admin/mint takeover** — Safe 4/7, no pending admin/impl; cToken impls identical to Ethereum; `sweepToken`/`_reduceReserves`/`_set*` all admin-gated. Note (trust, not unprivileged): all four LatamStable tokens (wARS/wBRL/wMXN/wCOP, OZ5 UUPS ERC20s) have DEFAULT_ADMIN/MINTER/PAUSER/UPGRADER roles held by **EOA `0x5CA3F8EE…F20F`**, which is also a Capyfi Safe owner. A key compromise there could mint and dump into the markets (ceiling ≈ all cash), but that is a privileged-key path.
4. **Donation / first-mint inflation** — all markets have supply and exact backing (surplus 0); no path. Confidence: high.
5. **Paused/deprecated markets** — none paused; wARS/wBRL/wMXN/wCOP are collateral-disabled (CF=0) but borrowable. No extraction.
6. **Oracle staleness** — `ChainlinkPriceOracle` has **no staleness check** (uses `latestRoundData`, returns 0 only if answer ≤ 0); feeds are fresh today. A frozen feed would persist a stale price but currently favors the protocol; requires feed failure, not attacker action. Confidence: high.
7. **cToken/Comptroller source** — no backdoors: Comptroller main file and CErc20Delegate are identical (normalized) to the Ethereum deployment; CEther standard.

## 5. Negative results / blockers

- Etherscan V2 free plan does **not** serve `getLogs` for chainid 8453 (only `getsourcecode` works); Dune API credits were exhausted; Blockscout MCP credits were exhausted. Logs were sourced from GoldRush (Covalent) event API with 1M-block windows + raw RPC cross-check.
- The documented "Ethereum Unitroller `0x0b9af1…`" does not exist on Base; the documented Base Unitroller/oracle addresses are real (nonce-collision artifact).
- No liquidatable accounts, no unprivileged admin path, no oracle path, no token/accounting quirk found. **Unprivileged attacker extractable value today: ≈ $0** (dust-level <$0.001 theoretical).
