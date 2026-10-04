# CrediX Finance (Sonic, chainId 146) — Live-state drain analysis

**Role in H-46 zombie-hunt:** child deep-dive. **Scope:** how much an *external, unprivileged* attacker
can drain/profit from CrediX's live contracts **right now**.

**Method:** read-only on-chain state at explicit pinned blocks, via public Sonic RPC endpoints
(`rpc.soniclabs.com` returned `eth_blockNumber = 0x0` during this session and was abandoned;
final reads used `sonic-rpc.publicnode.com`, cross-checked against `sonic.drpc.org` and
`sonic.api.onfinality.io/public`). Etherscan V2 (`chainid=146`) for tx/token/event history.
No transaction was signed or sent. No keys or credentials are stored in this folder.

**Pinned verification block: `80,330,684` (`0x4c9bfbc`).**
Secondary snapshots: `80,324,451`, `80,327,628`, `80,329,208`, `80,329,508`, `80,330,200`, `80,330,371`.

---

## 1. VERDICT (headline)

| Category | Amount | Confidence |
|---|---|---|
| **E-U — external unprivileged extractable** | **$0.00** | **high** |
| H-O — holder-only recoverable | **$49.95** (market C: 21.0572 USDC + 28.8645 scUSD; markets A/B dust $0.026) | high |
| P — privileged/governance-only (current value) | **$0.00** (keys control all 3 markets; latent over future inflows + market C's $49.95) | high |
| S — stuck/bricked (real USD) | **$0.00** (nominal-only: ~2.8M ac-token surplus, 2.5M USDC + 3.25M scUSD unbacked, ~$11.7M nominal open debt) | high |

Total real underlying value held by all CrediX-controlled contracts: **$49.95** (essentially all in the
small third market; the two exploited markets hold **$0.02631 of dust**). There is no permissionless
call that lets an outsider take any of it.

**Critical residual risk (not E-U):** the original exploiter EOA
`0xF321683831Be16eeD74dfA58b02a37483cEC662e` **still holds five live roles on the core-market ACLManager**
(`POOL_ADMIN`, `EMERGENCY_ADMIN`, `RISK_ADMIN`, `BRIDGE`, `ASSET_LISTING_ADMIN`) — verified
`hasRole = true` at block 80,330,684 and never revoked since the exploit. Anyone with those keys can
mint unbacked aTokens (`mintUnbacked` exists) and call `rescueTokens` on the core pool (confirmed by
`eth_call` simulation). Today those powers extract **$0** because the pools are empty, but they are a
standing drain-on-next-deposit primitive.

---

## 2. Contract inventory (three markets + treasury)

All three are Aave V3 forks (pool impls 21,673 B, selectors match Aave V3.0.x, plus a fork-specific
`rescueTokens(address,address,uint256)` = `0xcea9d26f`). Names/units differ per market:
`c*` = core (B), `si*` = stability (A), `ci*` = isolated (C).

### Market A — "Sonic Stability Credix market" (deployed by EOA `0x3d0c177e…`)
| Item | Address |
|---|---|
| PoolAddressesProvider (owner = ACL admin = EOA `0x3d0c177E035C30bb8681e5859EB98d114b48b935`) | `0x4b139f6E816934D580D9305Ca0f115145f698973` |
| Pool (proxy; impl `0x8cc50713d3c7525fc4fc87514aa3beffeab92e96`) | `0x0850A9759165B25832E2cAa3dB3f2d04dc583D4E` |
| PoolConfigurator (proxy; impl `0xe11bc682642b8e2e6b54d0f81146659a9bc39818`) | `0x1C5D4B5DFC1A47e5Db839Cb8A0Fb36bAb1E986B7` |
| PriceOracle | `0xce767E508A17321C25117b44d246e4611bbEcFE4` |
| ACLManager (all roles only to EOA `0x3d0c177e…`) | `0x1637b78Dd5541F0dB2f3d04EeD39De37Df71BD08` |
| PoolDataProvider | `0x5d10c393F9DF12BbbA49B8E8d5D7Fc4674d2e115` |
| Reserves | acUSDC, acscUSD, acwS, USDC, scUSD, wS |

### Market B — "Sonic Credix core Market" (deployed by `0xc7461891c88f6a609d9149d2826704bd178a80de`; post-mortem victim)
| Item | Address |
|---|---|
| PoolAddressesProvider (owner/ACL admin = Gnosis Safe `0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F`) | `0x282eDE6BbD2d224D454C995e66f08569A5508e9a` |
| Pool (proxy; impl `0xe3a900e0f0aaae2cd79c5849fa465470feb5f4f8`) | `0x56eb1bcB2aA011517fD7bf32641E79Bd8471770e` |
| PoolConfigurator (proxy; impl `0x12d1f5bc35397dfef5d41a77a6865151efd6233a`) | `0xc9122E191d9bDaBf9b59A31C01D4e6c4cd719E89` |
| PriceOracle | `0xc131bA07e9a6533e46Ca539280d02a42AC9C131a` |
| ACLManager | `0x8f0431F6Adb3e81D282d0508c16e2817DC95095b` |
| PoolDataProvider | `0xA298a88760c64dFA3D6774a9dbec04eF4297a850` |
| Reserves | wS, USDC, scUSD, WETH, stS |

### Market C — "Sonic Credix YT-scUSD isolated market" (deployed by same `0xc7461891…`)
| Item | Address |
|---|---|
| PoolAddressesProvider (owner/ACL admin = Safe `0xD3E02C92…`) | `0x3BC884500E670e184eF1421a6980455fd3FA3739` |
| Pool (proxy; impl `0xb14a1153f2c83143f3e0db20ea18de005992b76e`) | `0x12144c9b3fdCc1E40083280C3FE28BB568814A91` |
| PoolConfigurator (proxy; impl `0x5d8f9ff63011a0997f12a7b4496723d89a04d2d0`) | `0x091d37deb0df29675a1a188ffd6647a4cf75bc0f` |
| PriceOracle | `0xfae2038b7b4a25aca1c3fc0ff8c7c19d09a78806` |
| ACLManager (all roles only to Safe) | `0x3f8547e4b349e65853d058bc81b7ffbe3b8f12d4` |
| PoolDataProvider | `0x8c6a79f47ce3febe4e571747af39fb305a6070e8` |
| Reserves | YT-scUSD (collateral only), USDC (borrow only), scUSD (borrow only) |

### Treasury / governance
- Treasury proxy `0x5dc4dd7969944300083994c60e2ce67b4b81457c` → impl `0x26c40aa39c3522df342bf8cc1c2c8bf8f86c31a6`
  (AaveEcosystemReserve: `transfer`/`approve`/`createStream`/`withdrawFromStream`, admin-gated).
  EIP-1967 admin = Safe `0xD3E02C92…`; `getFundsAdmin()` = `0xd7c4B70cf16364160488e37f1D290CCa67DD7A73`.
- Gnosis Safe `0xD3E02C92…` v1.3.0, threshold **2/3**, owners `0x6d0F4Cec05a7066D3f509A732D59Ede630989053`,
  `0x75eF5d635388d7C97425596CE50c11844234128B`, `0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf`.
- Original admin EOA from the post-mortem: `0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf` (Safe owner).

---

## 3. Live balances (pinned block 80,330,684)

Aave V3 holds the underlying **inside the aToken contracts** (not at the Pool — the Pool holding 0 is
by design, not evidence of drainage). Balances below are `underlying.balanceOf(aTokenContract)`.

### Market B (core) — real underlying = $0.02631
| Reserve | aToken | Underlying held | USD |
|---|---|---|---|
| USDC | `0xEc26D07B5c0a99D3690375A2CC229E5b943e7726` | 0.001564 | $0.00156 |
| scUSD | `0xa175EE511de429275d26Ac5420fAbeb60C67C372` | 0.021567 | $0.02157 |
| stS | `0x83e2613b74b2697c85416a9a1fbb043f8056990b` | 0.062596 | $0.00284 |
| WETH | `0x7151f90076b54961771dfdaaf600e5b8b87cee20` | 0.000000128 | $0.00035 |
| wS | `0x95cAF53667D912F3491173fd4712450dFcf4c89f` | 0.000000066 | ~$0 |

Supply-side (aToken totalSupply, at block 80,324,451): wS 26,444,996.98; USDC 5,782,533.96;
scUSD 5,274,301.75; WETH 188.82; stS 4,019,889.52.
Debt-side (vToken totalSupply): wS 87,348,720.40; USDC 3,546,779.97; scUSD 2,287,442.81;
WETH 560.11; stS 14,986,667.79.
`unbacked` field: **USDC 2,500,000.25**, **scUSD 3,250,000.00** (residue of the exploit's unbacked mints),
wS/stS ~0. Uncollected `accruedToTreasury`: wS 134,264.73, USDC 50,488.93, scUSD 15,842.71,
WETH 1.66, stS 17,260.70 (nominal claims only).

### Market A (stability) — real underlying = $0
Its own USDC/scUSD/wS aToken contracts hold **0**. What it does hold is Market B's aTokens as collateral:
| Held at aToken | Amount | Real value |
|---|---|---|
| asiacUSDC `0x0eee208934e66a6e44517e627a2475fc891b3a38` | 1,766,553.246410 acUSDC | $0 (B's USDC aToken holds $0.0016) |
| asiacscUSD `0x1acd539e2a76cf876889dd8119c1d873821551a1` | 628,927.452181 acscUSD | $0 (B's scUSD aToken holds $0.0216) |
| asiacwS `0xed01f103c284253d0824c0125f673f11c14d2ea4` | 2,577,959.221003 acwS | $0 (B's wS aToken holds ~0) |

Supply-side: acUSDC 1,276,955.55; acscUSD 516,940.01; acwS 345,310.17; USDC 956,834.09; scUSD 866,907.02;
wS 2,071,461.15. Debt-side: USDC 1,169,406.14; scUSD 1,065,685.94; wS 2,512,952.72.

### Market C (isolated) — real underlying = $49.92 (+ external YT collateral)
| Reserve | aToken | Underlying held | USD |
|---|---|---|---|
| USDC | `0xacd8c3e8fd67142a677b35aabe3f21e3779b58c7` (aciUSDC) | 21.057200 | $21.0573 |
| scUSD | `0xb1eebda7f7ec7bd53d1f2d12b414129f89f24aaf` (aciscUSD) | 28.864500 | $28.8630 |
| YT-scUSD | `0xe192d8700fbdc8aae23b5881c3ef55b90de69373` (aciYT-scUSD) | 38.3079 YT-scUSD | external token, oracle $1.0788 → $41.33 nominal |

Supply-side: aciUSDC 36.391245 (21.06 still liquid = 57.9 %); aciscUSD 28.864500 (100 % liquid);
aciYT 38.3079. Debt: 15.355283 USDC held entirely by borrower `0xeae43e21a658b41d741139854cafde9ef7a580ab`
(collateral 19.1642 YT-scUSD; `getUserAccountData` HF = **1.1445**, healthy → not liquidatable).
Config: YT-scUSD collateral-enabled (ltv 75 %, liqThreshold 85 %, bonus 10.5 %); USDC/scUSD
`collateralEnabled=false`, `borrowingEnabled=true`, both active, not frozen, not paused.

### Treasury — real value $0
Holds only aTokens: acUSDC 136.838, acscUSD 45.116, acwS 587.513, acwETH 0.08694, acstS 6,577.07
(nominal; all claims on the empty core pools).

### Prices used (DefiLlama, 2026-10-04)
wS $0.041968 · USDC $1.000003 · scUSD $0.999949 · WETH $2,700.61 · stS $0.045404 · S $0.041588.

---

## 4. Roles & authority TODAY (hasRole at block 80,330,684)

| Role | Market A ACL `0x1637…` | Market B ACL `0x8f04…` | Market C ACL `0x3f85…` |
|---|---|---|---|
| DEFAULT_ADMIN | EOA `0x3d0c177e…` | Safe `0xD3E02C92…` | Safe |
| POOL_ADMIN | EOA `0x3d0c177e…` | **attacker `0xF321…`** + Safe | Safe |
| EMERGENCY_ADMIN | EOA `0x3d0c177e…` | **attacker** + Safe | Safe |
| RISK_ADMIN | — | **attacker** + Safe | Safe |
| BRIDGE | — | **attacker** + Safe | Safe |
| ASSET_LISTING_ADMIN | — | **attacker** + Safe | Safe |
| FLASH_BORROWER | — | — | Safe |

- Provider `owner()`: A = EOA `0x3d0c177e…`; B = Safe; C = Safe. Pool proxies use an *immutable* admin
  (the PoolAddressesProvider), so pool-implementation upgrades run through `provider.setPoolImpl(...)`
  by the provider owner (Safe for B/C).
- **Role history** (Etherscan logs): Market B granted to attacker in a **Safe `multiSend` transaction
  `0x0cc3520951a2b41281dcc9a0d37ef3f7f139b75675d83ae72e3b8e903334f35e`, block `40,687,491`
  (2025-07-29)** — submitted by admin EOA `0x0dd010…` through MultiSend `0x40a2accbd92bca938b02010e17a5b8929b49130d`,
  executed by Safe `0xD3E02C92…`; 5 × `RoleGranted` emitted. **No `RoleRevoked` for `0xF321…` has ever
  been emitted** (the only revokes are the 2025 setup cleanup of `0xc7461891…` / `0x84cae48c…`; Market A
  revoked `RISK_ADMIN` from `0x619603ae…` at block 38,069,111). All other early admins are clean.
- `mintUnbacked(address,uint256,address,uint16)` exists on both pool impls (selector `0x69a933a5`);
  `BRIDGE_ROLE` is live for the attacker on Market B. `rescueTokens(address,address,uint256)`
  (fork-specific, selector `0xcea9d26f`) exists on both pools; `eth_call` simulation shows it **succeeds
  from the attacker and from the Safe on pool B, reverts (`"1"`) from an arbitrary address** →
  POOL_ADMIN-gated. Pool A rejects the attacker (no role there).

---

## 5. The Aug 2025 exploit, as re-verified on-chain

1. **2025-07-29, block 40,687,491:** Safe grants attacker `0xF321…` five roles on core-market ACL.
2. 2025-07-29/30: attacker raises supply/borrow caps on configurator B.
3. **2025-08-04, blocks 41,548,518–41,580,100:** attacker calls `setUnbackedMintCap` and `mintUnbacked`
   on pool B (USDC/scUSD/wS, etc.), `approve`+`supply` of the resulting **acUSDC/acscUSD/acwS into pool A**
   (which accepts core aTokens as collateral), then `borrow`s real USDC/scUSD/wS from pool A and core
   assets from pool B; proceeds are swapped out through routers (`0xef4fb24a…` CoW-style,
   `0x92643dc4…`, `0xac041df4…`, `0xc325856e…`, `0x5e023c31…`).
4. Attacker's last transaction: 2025-08-04 11:16 (block 41,592,455). No activity since.
5. Attacker positions were **never closed**: at block 80,330,684 the EOA still holds the unbacked
   aTokens (acUSDC 1,794,050.83; acscUSD 3,648,015.53; asiacUSDC 1,200,000.25; asiacscUSD 250,000.00)
   and the matching debts (cUSDC 3,137,089.52; cscUSD 1,717,138.94; cwS 81,434,732.78;
   cwETH 413.209; cstS 13,030,969.63; siUSDC 1,101,477.76; siscUSD 514,862.83; siwS 1,787,473.00).
   Attacker wallet also still holds 23.5814 S, 0.750757 USDC, 500.0 scUSD.

---

## 6. Permissionless-path analysis (all routes checked)

| Path | Result |
|---|---|
| `withdraw` own aTokens | Only pro-rata; markets A/B have $0.0263 total, market C belongs to its depositors. \$0 for outsiders. |
| `borrow` | Needs collateral + liquidity. A/B: no liquidity. C: only YT-scUSD collateral (external token, 38.3 total supply, held by two parties) and only $21 USDC of liquidity. |
| `flashLoan` / `flashLoanSimple` | A/B have no liquidity. C: repayment + premium required; no free money. |
| `liquidationCall` | Market C borrower HF 1.1445 (healthy). Attacker positions cannot even be evaluated: `getUserAccountData` **reverts** on A/B and C for their accounts because `getAssetPrice(scUSD)` reverts (broken feed). Even if computable, seizable collateral is drained-token claims → $0. |
| `mintToTreasury` (permissionless) | Mints aTokens to the treasury (claims on empty pools); no value; does not extract. |
| `rescueTokens` | POOL_ADMIN-gated (confirmed). Pool token balances: **$0** (pools never hold user tokens in Aave V3; Etherscan shows zero tokentx ever for both pool addresses). Attacker could call it → rescues nothing. |
| ACL `grantRole` | Needs DEFAULT_ADMIN; attacker does **not** have it (Safe does). |
| Proxy `initialize/upgradeTo` | All proxies initialized; immutable-admin pool proxies upgrade only via provider owner (Safe/EOA). Treasury/config proxies admins set. No uninitialized value-bearing proxy found. |
| Oracle `setAssetSources` | Owner-gated (owner/admin path = Safe or protocol ACL admin); no unprivileged write observed. |
| DEX/AMM | The only external pool for the unbacked tokens `sAMM-acUSDC/ghUSDC` (`0x8b6b4480…`) has reserves of **1 wei acUSDC / ~1e-6 ghUSDC** — no market. No external redemption for acUSDC claims. |
| Direct transfers to pools/contracts | Matrices over all 64 deployer contracts × 15 tokens and tokentx-union scans show no stray real assets (only the balances listed in §3). |

---

## 7. Classification

### E-U (external unprivileged extractable) = **$0.00, high confidence**
There is no public function, on any of the three markets, that lets an actor with no roles and no
allowances remove value. Both exploited markets are empty except **$0.02631** of dust that only their
existing aToken holders can claim pro-rata; the live third market's **$49.92** sits behind aToken
ownership and its entire admin surface belongs to the 2/3 Safe. The only "free" entry point,
`rescueTokens`, was probed by `eth_call` and is POOL_ADMIN-gated, and the pools hold no tokens.

### H-O (holder-only recoverable) = **$49.95**
- Market C: aciUSDC holders can withdraw up to 21.0572 USDC; aciscUSD holders up to 28.8645 scUSD
  (reserve is 100 % liquid; note 42 % of aciUSDC supply is currently borrowed, so if the borrower
  defaults, recovery is lower).
- Markets A/B: aToken holders have pro-rata claims on $0.02631 dust (market B) and $0 (market A).
- Market C additionally custodies 38.3079 YT-scUSD (external SJ yield token), oracle-priced $1.0788
  (~$41.33 nominal); its true redemption value is external and unverified.

### P (privileged / governance-only) = **$0.00 current**, but fully controlled
- Market B: attacker EOA (5 roles) + Safe (all roles, provider owner, can upgrade pool impl).
- Market A: EOA `0x3d0c177e…` (all roles + provider owner).
- Market C: Safe (all roles + provider owner) — could in principle redirect the $49.92 via a malicious
  pool implementation, but requires 2/3 signatures.
- Treasury: `getFundsAdmin` = `0xd7c4B70cf16364160488e37f1D290CCa67DD7A73`; proxy admin Safe.
- **Latent/standing risk:** the never-revoked attacker roles + unbacked-mint capability mean any future
  deposit into markets A/B can be drained again. This is P (requires the attacker's keys), not E-U.

### S (stuck / bricked) = **$0.00 real** (large nominal amounts)
- Market A aToken contracts hold ac-token **surplus** with no sweep path: acUSDC +489,597.70,
  acscUSD +111,987.44, acwS +2,232,649.05 above aToken totalSupply. No function can move the surplus;
  nominal value only (claims on empty market B).
- Market B `unbacked`: 2,500,000.25 USDC + 3,250,000.00 scUSD, and uncollected `accruedToTreasury`
  (wS 134,264.73 etc.) — claims with no backing.
- **Broken scUSD oracle feeds on all three markets** (`getAssetPrice(scUSD)` reverts): any account with
  scUSD exposure cannot compute account data or be liquidated; the attacker's A/B positions are
  permanently unliquidatable, and market C's scUSD reserve is unpriceable (borrowing it reverts).
- Open debts in A/B (~$11.7M nominal at current prices) are uncollectible: every collateral pool is
  empty, so liquidators would seize worthless aTokens.

---

## 8. Negative results (dead ends with evidence)

1. **Pool underlying balances are 0 for every reserve** — expected Aave V3 design (underlying lives at
   aToken contracts). Verified `USDC.balanceOf(poolA)=0`, `USDC.balanceOf(poolB)=0` via `cast`.
2. **aToken-held underlyings in markets A/B are dust** ($0.02631 total) at block 80,330,684;
   token amounts: USDC 1564 raw, scUSD 21567 raw, stS 62,596,374,932,801,559 raw, WETH
   128,281,837,804 raw, wS 66,463,101,749 raw.
3. **Pool A and Pool B have zero token-transfer history** (Etherscan `tokentx` → "No transactions found"
   for both pool addresses) → nothing to `rescueTokens`.
4. **`rescueTokens` probe (`eth_call`, block 80,330,684):** pool B: attacker `0xF321…` → `0x` success,
   Safe → `0x` success, arbitrary `0x…01` → revert `"1"`. Pool A: all non-role callers revert.
5. **Attacker account data reverts** (`getUserAccountData` → `execution reverted`) on markets A and B —
   consequence of the broken scUSD oracle, which also disables liquidations of those accounts.
6. **Market C borrower is healthy:** `0xeae43e21…` collateral $20.68, debt $15.36, HF 1.1445 → no
   liquidation profit.
7. **Market C USDC/scUSD cannot be used as collateral** (`collateralEnabled=false`) → no borrow path
   without the scarce external YT-scUSD (total supply 38.3079; $0 balance held by attacker).
8. **`sAMM-acUSDC/ghUSDC` pool `0x8b6b4480…` is empty** (reserves: 1 wei acUSDC, 999,999,900,001 wei
   ghUSDC) → no external market for the attacker's acUSDC claims.
9. **All reserves active / not frozen / not paused** on A, B and C (bits decoded from raw configuration
   + `getReserveConfigurationData`) — so the reason nothing is extractable is *lack of assets*, not a
   pause switch.
10. **No unverified value-bearing proxy found:** all proxies (pools, configurators, treasury) have
    implementations set and admin paths accounted for; implementation contracts hold no funds.
11. **Scam token flagged:** a fake `UЅDС.e` (`0x02cc2c1454f70ab574051905fb6e78d635439892`, Cyrillic
    characters) appears in candidate histories; no protocol contract holds it.

---

## 9. Uncertainties / caveats

- `rpc.soniclabs.com` (post-mortem-suggested fallback) was stuck at block 0 during this session;
  final values are from publicnode/drpc/onfinality. All headline values are backed by at least one
  independent `cast` call in addition to batched RPC reads.
- USD conversions use DefiLlama spot prices on 2026-10-04; dust values move with spot.
- `scUSD`'s official oracle is broken (reverts); DefiLlama market price (~$0.99995) was used.
- `YT-scUSD` is an external token ("SJ Yield Token scUSD"); its oracle price ($1.0788) is not a market
  price and its redemption mechanics were not audited. It is excluded from the real-value totals.
- Market C is tiny ($49.95) and was likely a test/isolated market; a fourth dormant market with zero
  activity cannot be 100 % excluded, but the complete token-event universe of all protocol/admin
  addresses shows only three aToken families (`ac*`, `si*`, `ci*`).
- The attacker's roles on Market B, if exercised, can only drain *future* deposits; no such deposits
  exist now.

---

## 10. Evidence index (`raw/`)

| File | Content |
|---|---|
| `final_snapshot.json` | **Pinned block 80,330,684** balances, roles, rescue probes for all 3 markets |
| `enumeration.json` | Full market A/B reserve enumeration (providers, configurators, oracles, ACLs, aTokens, reserve data) |
| `marketC.json`, `marketC_positions.json` | Market C enumeration, borrower HF, flags, oracle prices |
| `balances.json` | Supply/debt/unbacked/accrued for A/B at block 80,324,451 |
| `liquidity_at_atokens.json` | Underlying held by every aToken/debt-token contract, A/B |
| `matrix_balances.json` | All 64 deployer-created contracts + key addresses × 15 tokens + native at block 80,327,628 |
| `completeness.json` | tokentx-union completeness scan across all protocol addresses at block 80,329,508 |
| `roles.json`, `role_granted_*.json`, `role_revoked_*.json` | Role snapshots + full grant/revoke event history |
| `grant_tx.json`, `grant_receipt.json` | The Safe multiSend tx that granted the attacker 5 roles |
| `borrow_logs_*.json` | Every Borrow event (A, B, C) |
| `etherscan/account_txlist_*.json`, `etherscan/tokentx_*.json`, `etherscan/txlistinternal_*.json` | Raw histories (attacker, admin, Safe, deployer, 0x3d0c, Safe owners, pools, providers) |
| `getsourcecode_*.json` | Etherscan V2 contract metadata/sources (ACLManagers, providers, configurators, proxies) |
| `flags_prices.json`, `extra_checks.json`, `selectors.json`, `deployer_contracts_meta.json` | Flags/oracle prices, proxy slots, selector extraction, deployed-contract metadata |
| `prices_defillama.json` | Price evidence |
| `marketC.json` | Market C full state |

*Report generated read-only; no state-changing call was ever broadcast.*
