# Angle Protocol — Ethereum (EURA/agEUR + USDA; other chains partial)

## Status & shutdown evidence (sources, dates)
- **Wind-down approved (AIP-112)**: Angle community voted an orderly wind-down of EURA and USDA; DefiLlama adapter hallmark `["2026-02-20","Project announces wind down"]` (x.com/pablo_veyrat status 2024789260054692114). X post by @AngleProtocol (status 2029161525580112263): "**1 year to redeem EURA and USDA at 1:1 with no haircut**".
- app.angle.money (via search 2026-10-04): "The protocol remains fully collateralized, and every USDA and EURA is redeemable 1:1. Redeem before **March 1, 2027**."
- DL News: after one year the redemption mechanism is discontinued.
- DefiLlama TVL 2026-10: Ethereum $1,581,911; Arbitrum $242,740; Polygon $6,680; Optimism $904; Avalanche $99.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
All Ethereum contracts verified via Etherscan V2 (`raw/angle_*` sources, probe at block **26,117,705**):
- EURA (agEUR) `0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8` — TransparentUpgradeableProxy, impl `0xc3ef7ed4…` (AgEURNameable), stableMaster = SM.
- USDA `0x0000206329b97DB379d5E1Bf586BbDB969C63274` — proxy, impl `0x028e1f0d…` (AgTokenNameable).
- **Transmuter EURA** `0x00253582b2a3FE112feEC532221d9708c64cEFAb` — DiamondProxy (EIP-2535), impl/dummy `0x5d34839a…`; live facets via `facetAddresses()`: `0x53B7d700…, 0xFa94Cd9d…, 0x65Ddeedf…, 0x99fe8557…, 0x770756e4…, 0x49c7B39A…, 0xdda8f002…, 0xD838bF7f…, 0xa09735Ef…` (facets: Redeemer, Swapper, Getters, SettersGovernor/Guardian, DiamondCut/Loupe, RewardHandler). `agToken()` = EURA.
- **Transmuter USDA** `0x222222fD79264BBE280b4986F6FEfBC3524d0137` — DiamondProxy, impl `0xfc21c913…`. `agToken()` = USDA.
- **StableMasterFront** `0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87` — TransparentUpgradeableProxy, impl `0x282dffb8…` (StableMaster, v2-style with `mint(amount,user,poolManager,minStableAmount)` / `burn(amount,burner,dest,poolManager,minCollatAmount)`, PausableMap). GOVERNOR_ROLE held by governor multisig `0xdC4e6DFe07EFCa50a197DF15D9200883eF4Eb1c8`, GUARDIAN_ROLE by `0x0C2553e4B9dFA9f83b1A6D3EAB96c4bAaB42d430` (both verified true at block).
- PoolManagers (all proxy impl `0xcee383c5…`, **impl source unverified on Etherscan**; behaviour read via IPoolManager ABI): DAI `0xc9daabC677F3d1301006e723bD21C60be57a5915`, FEI `0x53b981389Cfc5dCDA2DC2e903147B5DD0E985F44`, FRAX `0x6b4eE7352406707003bC6f6b96595FD35925af48`, WETH `0x3f66867b4b6eCeBA0dBb6776be15619F73BC30A2`, USDC manager `0xe9f183FC656656f1F17af1F2b0dF79b8fF9ad8eD`.
- AngleRouter V2 (Ethereum) `0x4579709627ca36bce92f51ac975746f431890930` (Etherscan label; not source-verified in this pass).
- Transmuter oracle configs are internal (`getOracleValues`); StableMaster per-collateral oracles: DAI `0xb41a7ce1…`, FEI `0x236d9032…`, FRAX `0x98aa7123…`, WETH `0xf7be58af…`, USDC `0xccac05d3…`.

## Live balances (token, amount, USD, price source, block)
All at **block 26,117,705**; prices `coins.llama.fi` 2026-10-04 (ts 1791100310): EURA $1.12385, EURC $1.12427, EURCV $1.12360, USD/USDC/USDT ≈ $1. Raw: `raw/angle_eth_probe.json`.
- **EURA totalSupply = 1,284,310.357** (~$1,443,360 at market).
  - EURA Transmuter collateral: **EURC 824,942.4803** ($927,425) + **EURCV 2,338.2870** ($2,627) = **$930,052**. Transmuter-issued stables `getTotalIssued` = 967,272.166 EURA; **collateralRatio = 0.85527**; redemption curve x=[0.75,0.85,0.95,0.97], y=[0.995,0.95,0.95,0.995] → under-collateralized penalty ≈0.95 → redeem payout ≈ **0.81 EUR of collateral per EURA**.
  - Idle EURA in Transmuter/SM = 0.
- **USDA totalSupply = 821,128.909** (~$821,113).
  - USDA Transmuter collateral: **USDC 394,575.2892** ($394,571). `getTotalIssued` = 393,314.061 USDA; **collateralRatio = 1.00319** (redemption ≈1:1).
  - Idle USDA in Transmuter = 0.
- **StableMaster pool managers (legacy) hold ZERO collateral**: DAI/FEI/FRAX/WETH/USDC `balanceOf(pm)`=0, `getTotalAsset()`=0, `balanceOf(SM)`=0. Stale `stocksUsers` remain (DAI 1,499,985; FRAX 1,708,011; WETH 283.4; USDC 9,835,501; FEI 0) with no assets behind them.
- SM oracles read fresh vs spot: DAI 0.88880 EURA/DAI (=1.125 $/€), readLower 0.88846; WETH 2402.86 EURA/WETH (readLower 2394.82); FRAX 0.88127/0.88853; USDC 0.88851. No staleness observed on the four probes.
- **Measured system collateral (Ethereum) = $930,052 (EURA side) + $394,571 (USDA side) = $1,324,623** vs combined supply of 2,105,439 stablecoins → **~63% coverage** at face value. Per-transmuter coverage: EURA 85.5%, USDA 100.3%. The remaining ~$781K of supply has no collateral at the probed StableMaster managers (could be treasury/AMO/other-chain reserves not covered this pass).

## Permissionless paths examined (path → gates → live values → verdict)
Source read from `AngleProtocol/angle-transmuter` (Redeemer.sol, Swapper.sol, Getters.sol, Storage.sol) and the verified StableMasterFront impl:
1. **Transmuter.redeem(amount, receiver, deadline, minAmountOuts)** (Redeemer.sol L61): permissionless; burns `amount` EURA/USDA from `msg.sender` (`burnSelf`), pays a pro-rata basket of the Transmuter's collaterals; reverts if `isRedemptionLive == 0`; no oracle dependency; penalty if collatRatio<1. Live: EURA/USDA collateral `isPaused(redeem)`=false (live), so redemption is OPEN. Payout = slice of EURA Transmuter's $930K; a caller can only burn their own tokens → **H-O (holder self-service)**, not E-U. At ratio 0.855 the caller receives ~0.81 €/EURA.
2. **Transmuter.swapExactInput/Output** (Swapper.sol L77/113): permissionless mint/burn against one collateral with fee curves, checks `isMintLive/isBurnLive` (false=false for EURC/EURCV and USDC at probe block = live), caps `stablecoinCap`; no arbitrary target/call; no oracle in rate. Caller exchanges fair value minus fee → no extraction.
3. **StableMaster.mint** (`readQuoteLower`, protocol-favourable lower quote) / **burn** (`readUpper`, min collateral out, `amount <= stocksUsers`): permissionless in principle, but the PMs hold 0 collateral → burn reverts on transfer; mint would send the minter's collateral into an empty PM at a fresh oracle rate (no profit). `paused(STABLE,pm)` keys could not be read due to an encoder bug in my probe (retry needed), but with zero balances this is immaterial for extraction. **No E-U.**
4. **updateNormalizer**: `Redeemer.sol` L86 — only governor or `isTrusted[msg.sender]` (`isTrusted(0x0)=false`); privileged. **P.**
5. **AngleRouter `0x4579709627…`**: not source-verified in this pass; known V2 router route functions, no permissionless `sweep/recover` reachable (Recovered event exists in upstream, governor-gated source). **Unverified — flag if parent wants it closed.**
6. **Oracle/flash-liquidity manipulation**: Transmuter redemption uses no external oracle; SM oracles read fresh and return lower/upper bounds around spot (spread ~0.03–0.1%), so a flash-loan manipulation of the Chainlink/TWAP-derived reads would need to move both bounds — no candidate path found. Curve/AMO positions not examined (time-boxed).
7. **Cross-chain**: Arbitrum deployment not probed on-chain; Angle API (2026-10-04) shows `USDCEUR-EURA-vault 0x0443…` (collateral 1,284.61 USDC.e; debt 442.77 EURA) plus other vaults — borrowing-module positions, not measured. Polygon/Optimism/Avalanche: only bridged-token supply, no Transmuter/StableMaster (adapter returns transmuter collaterals only on Ethereum); **not verified this pass**.

## Approvals / user-side residual risk
- EURA/USDA holders may approve Transmuter/StableMaster; `redeem` needs no allowance (burnSelf). No protocol-held allowance drain path identified.
- If a user holds EURA and wants out at ~par, current Transmuter route returns ~0.81 €/EURA; "1:1 no haircut" claims imply a privileged/governance-sponsored redemption path (app.angle.money) that is **not visible in the raw Transmuter** — a holder relying on the UI should verify their actual quote before March 1, 2027.
- USDA Transmuter is ~100% backed for its own 393K issuance, but total USDA supply is 821K; the residual 428K has no collateral at the probed SM USDC manager.

## Classification: H-O — measured $1.32M redeemable collateral ($930K EURA-side + $395K USDA-side) — **E-U $0 proven** — confidence medium
- Holders can redeem permissionlessly through the Transmuter (live, no pause); USD(A) redemption near par (ratio 1.003), EURA redemption at ~0.81 €/EURA (ratio 0.855) — the haircut is a solvency fact, not an attacker path.
- **What would change it**: (a) if any collateral mint/burn `isMintLive/isBurnLive` is true AND a StableMaster PM is funded with collateral while its feed is stale/manipulable, an unprivileged mint/burn arbitrage could extract at protocol expense (exact sequence: buy collateral → `SM.mint(amount, user, pm, minStable)` if `readQuoteLower` < market; or buy EURA → `SM.burn(amount, burner, dest, pm, minCollat)` if `readUpper` > market); no such funding/state found at block 26,117,705. (b) If total-supply coverage is really ~63% (not a measurement gap), late redeemers subsidise early ones — check Angle treasury/AMO/other-chain reserves before concluding.
- Other chains: **S/H-O unknown** (not measured); Arbitrum borrowing-module vaults outstanding debt 442.77 EURA on 1,284.61 USDC.e collateral (API snapshot), should be probed if value justifies.

## Raw evidence index (files in analysis/)
- `raw/angle_eth_probe.json` — full Ethereum probe at block 26,117,705 (transmuter collateral lists/balances/ratios/fees/pause flags, totalSupply, SM collateralMap, oracle reads)
- `raw/angle_addresses.js` — DefiLlama adapter addresses (EURA/USDA per chain, governor/guardian, treasuries, stablecoin/genesis)
- `raw/angle_adapter.js` — DefiLlama TVL adapter incl. wind-down hallmark (2026-02-20)
- `/tmp/opencode/` (scratch, not a deliverable): `Redeemer.sol`, `Swapper.sol`, `Getters.sol`, `trans_Storage.sol`, `trans_Constants.sol`, `iGetters.sol`, `sm.sol`, `ipm.sol`, `smimpl/` (verified StableMasterFront impl sources), `ValidationLogic.sol` (Aave v1.17.2 cross-check)
