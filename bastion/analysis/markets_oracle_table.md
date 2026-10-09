# C2-19 Bastion (Aurora) — market & oracle state (pinned block 219,166,504)

Read-only snapshot, 2026-10-09. All values via `eth_call` at block 219,166,504 on `mainnet.aurora.dev`.

## Comptroller — Unitroller `0x6De54724e128274520606f038591A00C5E94a1F6`

| item | value |
|---|---|
| implementation | `0x06416CACEEec5Df0b6D62aEe301C8Ee546b563cd` (verified, Compound fork) |
| oracle | `0xCa3F5f5a16ec993f933C9dCc40b929a26ef9Ce0d` (`BastionAuriOracle`; reads **Aurigami** oracle `0x5a7b8e3c…` for reporters) |
| admin | `0x4f44d184908AE367CAD0cb1b332A11545d76Bc87` (Gnosis Safe 1.3.0, **2-of-5**) |
| pauseGuardian | `0x58ac3103c54FF3757e3b9132c8598fc5C1e69475` (Gnosis Safe 1.3.0, 2-of-4 owners) |
| closeFactor | 0.50 |
| liquidationIncentive | 1.10 |
| protocolSeizeShare | 0.028 |
| transferGuardianPaused | **false** |
| seizeGuardianPaused | **false** ← liquidations not paused |
| pendingAdmin / pendingImpl | `0x0` / `0x0` (no hostile takeover path) |
| borrowCapGuardian | `0x0` |

## Markets (all 5 mint+borrow paused)

| market | cToken | underlying | dec | CF | cash | cash USD (real) | borrows | borrows USD (real) | reserves USD (real) | mintPaused | borrowPaused |
|---|---|---|---|---|---|---|---|---|---|---|---|
| cETH | `0x4E8fE8fd…` | ETH (native) | 18 | 0.70 | 29.50655 ETH | $71,443.81 | 0.50148 ETH | $1,214.22 | $3,313.38 | true | true |
| cNEAR | `0x8C14ea85…` | WNEAR `0xC42C30aC…` | 24 | 0.60 | 20,645.21 NEAR | $90,870.25 | 471.69 NEAR | $2,076.16 | $3,416.88 | true | true |
| cUSDC | `0xe5308dc6…` | USDC `0xB12BFcA5…` | 6 | 0.85 | 463,209.45 USDC | $463,019.53 | 1,676.15 USDC | $1,675.46 | $8,591.34 | true | true |
| cUSDT | `0x845E15A4…` | USDT `0x4988a896…` | 6 | 0.80 | 54,224.01 USDT | $54,183.51 | 15,292.98 USDT | $15,281.56 | $11,074.78 | true | true |
| cWBTC | `0xfa786baC…` | WBTC `0xF4eB217B…` | 8 | 0.70 | 0.347258 WBTC | $28,024.66 | 0.000892 WBTC | $72.01 | $176.11 | true | true |
| **TOTAL** | | | | | | **$707,541.76** | | **$20,319.41** | **$26,572.49** | | |

Borrow caps: cETH/cUSDT/cWBTC = 0 (uncapped), cNEAR = 1e30 (uncapped), cUSDC = 1e13 raw (10M USDC).
Nothing can be minted or borrowed today: the Comptroller's `mintAllowed`/`borrowAllowed` revert `"mint is paused"`/`"borrow is paused"` for all five markets.

## Oracle: frozen 2026-08-03, Comptroller reads the cached values

Bastion's `BastionAuriOracle` serves **cached** prices from its `prices[symbolHash]` mapping (Compound open-oracle design). For every market the price source is `REPORTER`; the reporter address is an Aurigami cToken and the override `getReporterPrice()` reads the **live Aurigami oracle** — but the cached value is only refreshed by the (now dead) keeper path.

| market | symbolHash | cached price (oracle read) | Aurigami oracle live | DefiLlama (2026-10-09) | real/oracle |
|---|---|---|---|---|---|
| cETH | `0xaaaebeba…` | **$1,848.474798** | $2,474.4035 | $2,421.2865 | **1.310×** |
| cNEAR | `0xa486e4b2…` | **$1.325163** | $4.472264 | $4.4015166 | **3.321×** |
| cUSDC | `0xd6aca1be…` | $1.000065 | $0.999848 | $0.999590 | 1.000× |
| cUSDT | `0x8b1a1d9c…` | $0.999815 | $0.999191 | $0.999253 | 0.999× |
| cWBTC | `0x98da2c5e…` | **$68,840.615** | $81,705.07 | $80,702.644 | **1.172×** |

Oracle history (events on `0xCa3F5f5a…`):
- last successful `PriceUpdated`: block 209,738,506 — **2026-08-03 10:52 UTC** (tx `0xcfbf6007…`, keeper `0x761a4f85…` → updater contract `0x65381762…`); it set ETH = $1,848.47 and NEAR = $1.719.
- last `PriceGuarded`: block 209,732,764 — 2026-08-03 09:54 UTC.
- no oracle events after 2026-08-03.
- `validate(cETH)` from an arbitrary address today → returns `false`, price unchanged; `pokeFailedOverPrice` → `"Failover must be active"`; `activateFailover` → `"Only callable by owner"` (owner = EOA `0x00000fc3E1d134BdC21E2A0dcD343CfE68e8610d`).
- ⇒ the stale prices cannot be refreshed by an unprivileged caller; refresh requires the keeper/reporter key or the oracle owner/admin.

## Liquidations are live, but only dust remains

- `seizeGuardianPaused = false`, `liquidateBorrowAllowed` has no pause check (only shortfall + close factor).
- 604 accounts still carry debt; **346 have shortfall** at the frozen prices (Σ shortfall $6,323.20 at oracle prices).
- Of those, **333 accounts have positive-gross liquidation value**: total gross **$96.20**, estimated net of Aurora gas (≈$0.06/call, 0.07 gwei) **$61.64**; sweeps that skip negative-net accounts total **$67.40 net**.
- The remaining shortfall is unbacked bad debt: e.g. `0xe5527bd1…` owes 6,011.90 USDT with $0.0000008 of collateral; `0x8839acbf…` owes 0.0268 ETH with dust NEAR/WBTC.
- Largest single-account liquidation profit found: **$1.82 gross** (`0xF89eb7b7…`, cUSDT debt / cNEAR collateral).

## Latent tripwire (single state flip: unpause mint+borrow; oracle still frozen)

Extractable by any attacker (fork-verified, CI run 37872429009):

| leg | borrow size | oracle value | real value (DefiLlama) | collateral needed (USDC, CF 0.85) |
|---|---|---|---|---|
| NEAR | 20,438.76 NEAR | $27,086 | **$89,975** | USDC $31,866 ×1.02 |
| ETH | 29.2115 ETH | $53,999 | **$70,728** | USDC $63,528 ×1.02 |
| **net** | | | **+$63,393** (conservative prices: +$51,644) | USDC $97,298 supplied |

Modeled maximum with 100 % of cash: **$65,957** at DefiLlama, **$69,097** at live Aurigami prices. WBTC leg ≈ $0 (ratio 1.172 < 1.176 break-even). The remaining $463k USDC + $54k USDT cash is *not* extractable by borrowing: it requires equal-value collateral (it is the suppliers' H-O claim).

## Categories

| category | value | note |
|---|---|---|
| E-U (today) | **$67.40** net / $96.20 gross | dust liquidation sweep only |
| H-O | **$701,288.68** | supplier net claim (cash+borrows−reserves), redeemable up to $707,541.76 cash; `redeem` not paused |
| P | **$26,572.49** | protocol reserves (`_reduceReserves`, admin-only) + unpause/oracle control in 2-of-5 Safe |
| S | $0 | nothing bricked; ~$6.3k bad debt uncollectible |
