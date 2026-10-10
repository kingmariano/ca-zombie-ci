# H2-05 deep-dive — CHATEAU (chUSD, Plasma) & Vena Finance (Fluent)

Date: 2026-10-10 · Read-only analysis. No transactions signed or sent on any live chain.
All state pinned: **Plasma chain id 9745 @ block 34,691,115** (ts 1791632439) · **Fluent chain id 25363 @ block 17,863,118** (ts 1791632951).
RPCs used (public, keyless): `https://rpc.plasma.to` (9745 ✓), `https://rpc.fluent.xyz` (25363 ✓). Dead endpoints: `plasma.drpc.org` (paid only), `plasma-rpc.publicnode.com` (404), `fluent.drpc.org` (404), `explorer.fluent.xyz` (NXDOMAIN). Explorers: `plasmascan.to` + Etherscan V2 API `chainid=9745`; `fluentscan.xyz` (Blockscout, chain 25363).

---

## TL;DR

| Target | Live unprivileged extractable (E-U) | Why | Nominal exposure / notes |
|---|---|---|---|
| CHATEAU chUSD (Plasma) | **$0** (hard cap on any contract bug: $77.24) | chUSD `mint()` is minter-gated (only `ChateauMinting`); `ChateauMinting.mint/redeem/transferToCustody` all fail an AccessControl role check for unprivileged callers (proven by live `eth_call` simulations). No permissionless path found. | $1,024,179.89 chUSD claims vs **$77.24 on-chain USDT0** collateral (shortfall $1,024,102.65); exit requires issuer/operator settlement → custodial/trust risk, not attacker-extractable |
| Vena Finance (Fluent) | **$0** (medium confidence) | Standard Aave-v3 fork; all money surfaces verified: oracle = Pyth-Lazer-signed adapters (`updatePrices` role-gated), ACL roles on TimelockController/Safe, `rescueTokens` onlyPoolAdmin; no unprivileged extraction path found | $9,175,475.67 supplier custody in aTokens (= DefiLlama ~$9.18M TVL). Self-service withdrawal (H-O) exists; USDnr liquidity is utilization-bound |

**Total live extractable by an external unprivileged attacker (both targets): ~$0.**

---

# A) CHATEAU chUSD (Plasma, chain 9745)

## A1. Contracts (verified where noted)

| Contract | Address | Notes |
|---|---|---|
| chUSD token | `0x22222215d4EdC5510d23D0886133E7ece7F5fdC1` | **verified** (ecosystem name `chUSD`, solc 0.8.20, OFT/ERC20Burnable/ERC20Permit/RateLimiter). 18 dec |
| ChateauMinting | `0xEA6709C29d4D4B5162d8C55D0c28C5CED6cd7296` | **unverified**; ABI extracted via heimdall + selector resolution + live simulations |
| StakedchUSDV2 (schUSD vault) | `0x888888bAB58A7bd3068110749bC7b63B62CE874D` | verified ERC-4626; `asset()` = chUSD; `owner()` = Safe |
| chUSDSilo | `0x14E445182C2E281cF839eb0E9A12359653525658` | unverified; cooldown silo (holds chUSD) |
| chUSD owner | `0x478F78c416dDBEEA6BF36512c8ddD563F65DE668` | SafeProxy 1.4.1, threshold 2-of-3: `0xD9911E44…`, `0xdD62A743…`, `0x630462b8…` |
| USDT0 (collateral) | `0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb` | verified on-chain read: name/symbol `USDT0`, 6 dec; totalSupply 777,409,123.61 |

## A2. Live state @ Plasma block 34,691,115

- `chUSD.totalSupply()` = **1,024,692.236150956 chUSD** → **$1,024,179.89** @ $0.9995 (plasmascan quote, 0 USD at $1 does not change the verdict).
- `chUSD.minter()` = `0xEA6709C2…d7296` (ChateauMinting). `chUSD.owner()` = Safe above.
- `USDT0.balanceOf(ChateauMinting)` = **77.307860 USDT0** = **$77.24** @ $0.999096 (llama).
- `USDT0.balanceOf(chUSD token)` = 0; native balance of minting contract = 0.
- Old USDT0-ticker token `0x440f37cb…561e6` balance = 0 (legacy outflows only).
- chUSD `balanceOf`: EOA `0x9616042c…7aa2c6` = **963,014.6829 (94.0 % of supply)**; `0xdD62A743…` (Safe owner) 28,539.0355; Silo 12,301.5713; `0xD9911E44…` (Safe owner) 11,801.1488; EOA `0xa3533863…` 5,000.0; schUSD vault 2,604.8414; remainder ≈ 39.16 chUSD across 25 dust wallets (35 holders total). Aggregated from the **complete** Transfer log set (840 logs; sums exactly to totalSupply = 1,024,692.236150956).
- schUSD vault: `totalAssets()` = 2,604.8414 chUSD, `totalSupply()` = 2,325.2218 schUSD (NAV ≈ 1.1202).
- Lifetime collateral flow through ChateauMinting (674 USDT0 transfers): **IN 431,243.64692 / OUT 431,166.33906 → net +77.30786**. So the ~$431 k historically deposited was largely swept out to `0xD9911E44…` (207 outs) and other addresses (redemptions). Current on-chain collateral = $77.24.
- chUSD mint/burn since genesis: minted 1,500,097.086 / burned 475,404.850 → net **1,024,692.236 = supply**. The delta between 1.5 M minted and $431 k USDT0 ever received shows issuance was **not** 1:1 on-chain-collateralized at all times (off-chain/custodial settlement).
- Last on-chain activity: **block 31,927,212, ts 1788867779 = 2026-09-08 11:42:59 UTC** — a 33.0 USDT0 ↔ 33.0 chUSD redeem paid to user `0xf498fa9d…`; then ~32 days of inactivity to the pin block.

## A3. Gates (what actually blocks an unprivileged attacker)

Source-verified on chUSD (`etherscan_chateau_source.json`):
```solidity
function mint(address to, uint256 amount) external {
    if (msg.sender != minter) revert OnlyMinter();   // only ChateauMinting can mint
    _mint(to, amount);
}
function setMinter(address) external onlyOwner { ... }   // owner = 2-of-3 Safe
```
ERC20Burnable: `burn(amount)` only self; `burnFrom(account,amount)` requires the account's allowance. **No third-party burn, no permissionless mint.**

ChateauMinting (unverified; ABI + selector map from heimdall and openchain, all proven by live `eth_call` from unprivileged addresses `0x1111…` / `0x2222…` @ pinned block):
- `redeem(order,signature)` `0x95165e8b` → **reverts `AccessControl: … missing role 0x44ac9762…` = `REDEEMER_ROLE`** (keccak match).
- `mint(order,route,signature)` `0xd48c03e5` → **reverts missing role `0x9f2df0fe…` = `MINTER_ROLE`**.
- `transferToCustody(address,address,uint256)` → reverts missing role `0x85e8f2d6…` (this role is held by the Safe `0x478F78c4…` — RoleGranted log).
- `disableMintRedeem()` → reverts missing role `0x3c63e605…`; `removeSupportedAsset` → DEFAULT_ADMIN.
- Role holders (live `hasRole`): `MINTER_ROLE`+`REDEEMER_ROLE` = EOAs `0xa0fd0bd36bf8174ab2cc547049648703bb4e72af` and `0xfbdfcadc912e0219fb03f7ee1ecdd9d244e40ba6`; DEFAULT_ADMIN = EOA `0xD9911E44…`; Safe holds the custody role. **All operator keys are EOAs — but privileged, not attacker paths.**
- Order flow is EIP-712 (`hashOrder/verifyOrder/verifyNonce/delegatedSigner` present): user signs, an operator with the role submits and the contract pays from its own USDT0 balance. `setDelegatedSigner(address)` is the only entry that does not revert for a stranger, but it is **never called in the contract's entire history (0/654 txs)** and cannot bypass anything: the role check precedes signature logic on `mint/redeem` (proven by the reverts above). Max value behind it: $77.24.
- No `withdraw`/`sweep`/`rescue`-type selector exists in the 42-selector runtime dispatch of ChateauMinting (cast disassemble + openchain lookup). See `minting_selectors.txt`.

## A4. Verdict

- **E-U = $0** (high confidence). All value-moving entry points are role-gated (live revert evidence); chUSD itself cannot be minted or burned third-party; the only on-chain USDT0 an attacker could ever reach even under a hypothetical undiscovered bug is **$77.24** (current contract balance).
- **H-O (self-service exit in collateral) = $0**: redemption is operator-submitted (`REDEEMER_ROLE`); holders cannot redeem to USDT0 themselves. schUSD unstaking only returns chUSD (silo, 30-day cooldown), which is a claim, not collateral.
- **P = $77.24** (privileged operators can move the minting contract's balance to custody), and **nominal holder exposure $1,024,179.89** backed on-chain by $77.24 plus whatever the issuer holds off-chain (Covenant VC private-credit fund/custodian per docs). Unbacked on-chain shortfall vs nominal supply: **$1,024,102.65 (~99.99 %)** — a custodial/trust risk that an unprivileged attacker cannot turn into profit.
- **S = $0** (contracts live and functioning).
- Confidence qualifiers: ChateauMinting and chUSDSilo are unverified (ABI/dispatch reconstructed; sims executed against live bytecode); the $77.24 cap makes residual uncertainty immaterial for E-U.

## A5. Evidence commands (abridged; full set in `evidence_commands.md`)

```bash
cast chain-id --rpc-url https://rpc.plasma.to                       # 9745 ; block-number 34691115+
cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "totalSupply()(uint256)"   --rpc-url https://rpc.plasma.to --block 34691115
cast call 0x22222215d4EdC5510d23D0886133E7ece7F5fdC1 "minter()(address)"        --rpc-url https://rpc.plasma.to --block 34691115
cast call 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb "balanceOf(address)(uint256)" 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 --rpc-url https://rpc.plasma.to --block 34691115
cast call 0xea6709c29d4d4b5162d8c55d0c28c5ced6cd7296 <redeem-calldata> --from 0x1111111111111111111111111111111111111111 --rpc-url https://rpc.plasma.to
#   -> reverted AccessControl missing REDEEMER_ROLE 0x44ac9762eec3a11893fefb11d028bb3102560094137c3ed4518712475b2577cc
#   -> mint() from 0x2222… reverted missing MINTER_ROLE 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6
# cumulative flows & role grants: Etherscan V2 API, chainid=9745 (tokentx / getLogs / txlist)  [files minting_*.json]
```

Raw evidence files: `etherscan_chateau_source.json`, `chUSD_impl.sol`, `minting_usdt0_tokentx_all.json`, `minting_all_tokentx.json`, `minting_txlist.json`, `minting_all_logs.json`, `chud_all_transfer_logs.json`, `chud_mint_logs_sample.json`, `chud_burn_logs_sample.json`, `redeem_tx.json`, `redeem_input.txt`, `minting_bytecode.hex`, `minting_disasm.txt`, `minting_selectors.txt`, `minting_decompiled.sol/abi.json`, `prices_llama.json`, `llama_chateau.json`.

---

# B) Vena Finance (Fluent, chain 25363)

## B1. Contracts (all verified on fluentscan.xyz)

| Role | Address |
|---|---|
| Pool (proxy → impl `0xd5443A545cD467d0F5F64d5E88d7b4c94C7E5753`, "Pool", Aave v3 fork) | `0xD6E69976C8Aea2A4075Bc637fE8881672FF14013` |
| PoolAddressesProvider (owner = Timelock) | `0xf5569e98BB2FC78Af813B65C124aa63a5b141983` |
| PoolConfigurator | `0xbb2F64561b97d68C5c354F45840697dF0757C154` |
| ACLManager | `0x18797a361C79fD7b6d8C62d7eDe244353a7369Bf` |
| PriceOracle (AaveOracle) | `0xC3Be4DDD4354Cd83FcfB3bE67686387b42A353Db` |
| AaveProtocolDataProvider | `0xb6eEF266933382661827E36fE3f936396e80166E` |
| Underlyings: WETH / USDnr ("Nerona USD") / sUSDnr ("Staked Nerona Dollar") | `0x927C469E…3A54` / `0xD48e5655…28f9` / `0xFa9b3B45…Cbf4` |
| aTokens: aWETH / aUSDnr / asUSDnr (hold the underlying, standard Aave v3) | `0x8e2Ea47F…9a3a` / `0x3Ebf3cfc…1008` / `0x3161bF68…21Ed` |
| Debt tokens: variableDebt{WETH,USDnr,sUSDnr} | `0xDc8CE3dA…B92E` / `0x90cd2575…9672` / `0xBA30804c…8264` |
| Admin: TimelockController (DEFAULT/POOL/ASSET_LISTING admin; provider owner) | `0x2799ea13D3643BBa0e2d97E9877290d5e27B4f0c` |
| Emergency admin (SafeProxy) | `0x07f8b1e372e1df19948c63408e3d51b3714cfdd3` |
| Oracle feeds: VenaPythPrices; Pyth Lazer | `0xc93Dd12974e0Df7aF91bd28A6B4B34786EA3b905`; `0xACeA761c27A909d4D3895128EBe6370FDE2dF481` |

## B2. Live custody & debt @ Fluent block 17,863,118

| Asset | Held by | Exact amount | USD (price @ read) |
|---|---|---|---|
| USDnr | aUSDnr `0x3Ebf3cfc…` | 545,341.402995 | $545,463.77 @ $1.000224 (llama) |
| sUSDnr | asUSDnr `0x3161bF68…` | 8,457,557.196359 | $8,630,010.94 @ $1.020390 (llama) |
| WETH | aWETH `0x8e2Ea47F…` | 0.000388339932866218 | $0.97 @ $2,495.19 (on-chain oracle) |
| **Total** | | | **$9,175,475.67** |

Claims/debt (`getReserveData` @ 17,863,118): aUSDnr totalAToken 2,639,055.99 / variableDebtUSDnr 2,094,096.80; asUSDnr 8,457,557.20 / debt 0; aWETH 0.071077 / variableDebtWETH 0.072583. Pool *contract* holds 0 — in Aave v3 the aToken contracts are the vaults (confirmed by the balances above). TVL matches DefiLlama (~$9.18M). Reserve configs: WETH LTV 0 / LT 68 %; sUSDnr LTV 66 % / LT 73 % / borrowing disabled; USDnr LTV 75 % / LT 78 %; all active, none frozen.

## B3. Gates & unprivileged-path scan

- **Oracle**: AaveOracle (base USD 1e8) → sources are `PythProAggregatorAdapter` (WETH feedId 631 → $2,495.19; USDnr feedId 3176 → $0.999891) and `AggregatedPythPriceAdapter` (sUSDnr = feed 3176 × feed 3221 index $1.02016, multiply → $1.020049). All adapters read `VenaPythPrices`. `updatePrices(bytes)` = `onlyRole(PRICE_UPDATER_ROLE 0xd96ba01d…)` **and** `i_pythLazer.verifyUpdate{value:fee}(priceUpdate)` (signature-verified Pyth Lazer payload). Staleness 60 s enforced → stale prices revert. **No permissionless or attacker-forgeable price path.** Adapter owners = Timelock.
- **ACL** (current, live `hasRole` + RoleGranted logs): DEFAULT_ADMIN / POOL_ADMIN / ASSET_LISTING_ADMIN = TimelockController `0x2799ea13…`; EMERGENCY_ADMIN = SafeProxy `0x07f8b1e3…`. No role held by a random EOA at the pin block; earlier holders were revoked.
- **Pool surface** (impl source): standard Aave v3 functions only — `supply/withdraw/borrow/repay/liquidationCall/flashLoan/flashLoanSimple/setUserEMode/mintToTreasury/…`; `rescueTokens` is `onlyPoolAdmin` (Timelock). No custom value-moving extension found in the reserve list or dispatch.
- The `#1` Fluent protocol (Upshift, $399M) and `#2` (SharpByte, $10.3M) are separate; Vena = `#3`.

## B4. Verdict

- **E-U = $0** (medium confidence). No unprivileged extraction path found on live, verified contracts: oracle cannot be pushed or forged by strangers (Pyth signature + role + staleness); all admin surfaces (ACL, provider, upgrade path, rescue) are Timelock/Safe controlled; accounting observed is consistent with stock Aave v3. Confidence is "medium" (not high) only because the fork implementation was not byte-for-byte recompiled/diffed against upstream Aave within this pass.
- **H-O = $9,175,475.67**: supplier self-service withdrawals exist and are live; sUSDnr is ~fully liquid (asUSDnr holds all supplied sUSDnr), USDnr available liquidity = $545,463.77 against $2.64 M of aUSDnr claims (rest repayable by borrowers — normal utilization risk, not a bug).
- **P = $0** (privileged roles can pause/freeze/upgrade proxies, but no function lets them seize supplier funds).
- **S = $0**.
- Residual/negative-result notes: no anomaly reproduced; the earlier "$9.4M, no anomaly found" flag is consistent with our reads. Small custom surface (Pyth adapter timestamps must match across legs; single-leg update reverts reads — operational liveness quirk, not extraction).

## B5. Evidence commands (abridged)

```bash
cast chain-id --rpc-url https://rpc.fluent.xyz                     # 25363 ; reads pinned at block 17863118
cast call 0xD6E69976C8Aea2A4075Bc637fE8881672FF14013 "getReservesList()(address[])" --rpc-url https://rpc.fluent.xyz --block 17863118
cast call 0x3Ebf3cfcCDCd96edC1C506907C17eec2BdC31008 "balanceOf(address)(uint256)" <aUSDnr> ...   # 545,341.402995 USDnr
cast call 0xC3Be4DDD4354Cd83FcfB3bE67686387b42A353Db "getSourceOfAsset(address)(address)" 0xFa9b… --rpc-url https://rpc.fluent.xyz --block 17863118
#   -> 0xD281301334A0aEB1b5EAaa22A340D441E332bb63 (AggregatedPythPriceAdapter; children 0xdb653cf8… & 0x132A7bAe…)
# oracle source: fluentscan.xyz API v2 smart-contracts (files fluent_feed_*.sol, vena_oracle_source.sol, vena_pythprices.sol)
# ACL: cast call 0x18797a361C79fD7b6d8C62d7eDe244353a7369Bf "hasRole(bytes32,address)(bool)" … --block 17863118
```

Raw evidence files: `llama_vena.json`, `fluent_pool_contract.json`, `fluent_pool_balances.json`, `fluent_src_0xd5443A54.sol` (Pool), `fluent_src_0x3Ebf3cfc.json` (aUSDnr proxy), `fluent_src_0x18797a36.sol` (ACLManager), `fluent_src_0xf5569e98.sol` (Provider), `vena_oracle_source.sol`, `vena_pythprices.sol`, `fluent_feed_0xdb653cf8.sol` (PythProAggregatorAdapter), `fluent_feed_0xEd3Af217.sol`, `fluent_feed_0xD2813013.sol` (aggregated), `fluent_usdnr_token.json`, `fluent_usdnr_holders.json`, `fluent_susdnr_token.json`, `pythprices_logs.json`, `prices_llama.json`.

---

## Cross-cutting notes

- No transactions were signed or sent; all "exploit" checks were `eth_call` simulations against live bytecode (revert reasons captured verbatim) or log/API aggregation.
- No secrets or keyed RPC URLs are stored in this folder.
- Blockers/limitations: ChateauMinting + chUSDSilo unverified (reconstructed ABI); PRICE_UPDATER_ROLE holder on VenaPythPrices not identified (role gate verified regardless); Fluent Pool fork not byte-diffed against upstream Aave.
- What would change the verdict: (Chateau) a future permissionless function on ChateauMinting found by full symbolic decompilation — but the prize is capped at $77.24; (Vena) a fork-specific accounting bug in a non-core contract or a compromised Pyth publisher/role key (privileged).
