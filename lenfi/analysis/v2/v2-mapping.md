# Lenfi V2 (Aiken) — live validator → source mapping & external attack surface

Investigation: Lenfi (ex-Aada) V2 "zombie funds". Date: 2026-10-12. Chain: Cardano mainnet (keyless Koios).
Repo: https://github.com/lenfiLabs/lenfi-smart-contracts @ clone HEAD `882be2f` (2025-01-02, "vulnerability_fix" merge).
Evidence files (this folder): `koios_script_info_v2.json`, `koios_creation_tx_info.json`,
`koios_deployed_validators_tx_info.json` (empty = testnet) + `koios_deployed_validators_name_map.json` (empty),
`koios_pool_nft_asset_info.json`, `koios_pool_nft_holders.json`, `koios_pool_addresses_info.json`,
`koios_leftovers_addresses_info.json`, `koios_collateral_addresses_info.json`,
`koios_credential_utxos_{pool,collateral,leftovers}.json`, `decoded_*.uplc` (UPLC dumps), `decode_ref.py`, `koios_queries.py`.

## 0. Corrections to the prior brief (verified)

- The 336-byte script (`9b99fef5…`) is **leftovers.ak**, NOT the collateral validator. It is also used as the
  **"liquidations" address** (`src/util.ts:352-361`: `liquidationsPkh = validatorToScriptHash(new LeftoversLeftovers())`;
  the param `liquidations_pkh` baked into the live collateral script is exactly `9b99fef5…`).
- The 14,492-byte script (`8021830a…`) is **collateral.ak** (traces `collateral_amount_check ? False`, …).
- Live pool UTxOs are NOT at the enterprise address from the brief. Pools sit at **stake-enabled addresses**
  (`addr1xyew3s9wx…<per-pool stake script>`): 98 pool UTxOs (1 pool NFT + pool datum each). Same for collateral
  (8 addresses) and leftovers (18 addresses). See §7.

## 1. Mapping table (live scripts)

| live script (Plutus V2, mainnet) | bytes | source module | function | best-matching commit |
|---|---|---|---|---|
| `32e8c0ae314ef4be452c16a999867f66d1a1791fc972cb2f7c74e38d` | 8021 | `validators/pool.ak` | `spend` + `mint` | `c14ca68` (2024-02-17), logic identical to `eb7dc68` (2024-02-21) except comments |
| `9b99fef5ee9a6b170a418999e89edad93bbf55bf1feef57b6053d634` | 336 | `validators/leftovers.ak` | `leftovers` | `c14ca68` (only comments added in `2f3b27b`) |
| `8021830afedd85fda1253da2be75c0e65c482148eb8ca690903cb` | 14492 | `validators/collateral.ak` | `spend` + `mint` | `2f3b27b`/`eb7dc68` (2024-02-21) — includes the `2f3b27b` Pooled-oracle arg swap |

Overall best match for the launch deployment: **`eb7dc68` (2024-02-21)** (merge of PR #3). The Dec-2024 fix
`f0148f9`/`882be2f` is **NOT** in the live pool script (see §2). Repo-committed compiled artifacts
(`src/validators_deployed.json`, `src/validators.json`) are stale: they contain the *old aada* codebase
(pool 10134 B → hash `4f0ea56a…`; traces like "Will check pool change" do not exist in the live script) and never
match the live bytecode. Aiken is not installed here; no byte-level reproduction attempted.

Live parameter constants (from UPLC tails):
- pool: `(delegator_nft_policy=c04e78ea267631f27975446a15d96ef1f3bbcdbf99577d3e552c663b, pool_config_script_hash=ecf0762dfc1c15f918937b151197b3f955e390cff20f6e78ef0be6c9)`
- leftovers: none
- collateral: `(pool_script_hash=32e8c0ae…, liquidations_pkh=9b99fef5…, param_merge_script_hash=b6e02be7d97343048c53a06786bfd6185f5fdef306a870cfc8edf033)`

## 2. pool.ak — spend/withdraw conditions (citations to `validators/pool.ak` @ eb7dc68 / pre-fix)

Types: `Datum { params: Constants(8 fields), balance: Int, lent_out: Int, total_lp_tokens: Int }`;
`Redeemer { action: Destroy | Continuing(ContinuingAction), config_ref: OutputReference, order: Option<OutputReference> }`;
`ContinuingAction = LpAdjust{value_delta, continuing_output} | Borrow{loan_amount, collateral_amount, borrower_tn,
interest_rate, continuing_output} | CloseLoan{loan_amount, repay_amount, continuing_output} | PayFee{fee, continuing_output}`.

Common checks (all spend paths): pool input found by `output_ref`; `pool_nft_policy = this_script_hash`;
reference input at `config_ref` must hold NFT `(ecf0762d…, params.pool_config_assetname)` (`config_has_nft`);
its inline datum parsed as `pool.Config`. No signature is ever required.

- **Destroy** (L134-161): `lp_token_delta + total_lp_tokens == 0` (burn *all* remaining LP); mint redeemer for the pool
  policy must be `BurnPoolNFT(burn_tn)` with `burn_tn == params.pool_nft_name`; `quantity_of(mint, delegator_nft_policy,
  params.pool_config_assetname) == -1` (burn delegator NFT). **No output checks at all** → whole pool value can go anywhere.
- **LpAdjust** (L164-226): LP mint delta must be burned/minted with the LP token policy; transition checks
  (`validate_transition`, L69-132): output at `continuing_output` at the same address, `params` unchanged,
  `balance_delta == pool_fee + value_delta`, `lent_delta == 0`, `tokens_delta == lp_token_delta`,
  value change for loan asset exactly `output_balance - balance`, ≤2 non-ADA assets (dust check).
  - deposit: `value_delta > 0`, `lp_token_delta > 0`, `value_delta >= min_transition`,
    `truncate(owned_proportion) <= value_delta` (owned_proportion = lp_delta*(balance+lent_out)/total_lp_tokens).
  - **withdraw (PRE-FIX, live)**: `value_delta < 0`, `lp_token_delta < 0`, `value_delta * -1 >= min_transition`,
    `lp_token_delta < total_lp_tokens` (always true for negatives), and `truncate(owned_proportion) >= value_delta`
    ⇔ withdrawn ≥ pro-rata share — **no upper bound**. Verified in live UPLC: `lessThanInteger lp_token_delta
    total_lp_tokens` directly (no `× -1`). The fix (`f0148f9`, 2024-12-20) changed it to `lp_token_delta * -1 <
    total_lp_tokens` and `value_delta * -1 <= truncate(owned_proportion) * -1`. **No recipient/output-value check** →
    withdrawn value can be sent anywhere in the tx.
- **Borrow** (L227-270): `loan_amount > 0`, `>= min_loan`, `interest_rate > 0`,
  `interest_rate >= finance.get_interest_rates(...)`; collateral mint redeemer (same tx, collateral policy) must
  contain `MintNFTElem(pool_utxo == output_ref, _)`; transition `balance_delta == pool_fee - loan_amount`,
  `lent_delta == loan_amount`, `tokens_delta == 0`. Loan-funds destination is enforced by the collateral mint handler
  (`collateral.ak fn mint`) / order contract, not here.
- **CloseLoan** (L271-289): `loan_amount > 0`, `repay_amount > loan_amount`; transition `balance_delta == pool_fee +
  repay_amount`, `lent_delta == -loan_amount`, `tokens_delta == 0`.
- **PayFee** (L290-306): `fee > min_fee`; transition `balance_delta == fee`, `lent_delta == 0`, `tokens_delta == 0`.
- **mint** (L311-379): `MintPoolNFT(details)` — output at index must be at own credential with inline
  `ScriptCredential(stake_hash)`; `Publish(CredentialDelegation(stake_cred, initial_delegation))` redeemer must be
  `pool_stake.CreatePool(oref)`; mint exactly `[(stake_hash, 1)]`; ≤3 assets. `BurnPoolNFT(name)` — mint exactly
  `[(name, -1)]`.

## 3. leftovers.ak — spend conditions (`validators/leftovers.ak:9-13`)

Datum: `LeftoversDatum = AssetClass { policy_id, asset_name }`; redeemer `Void`.
- Spend iff `utils.validate_mint_nft(tx.mint, datum.policy_id, datum.asset_name, -1)` (`utils.ak:52-63`): the mint
  field must contain **exactly** `{policy_id: {asset_name: -1}}` (singleton list). Nothing else: no signature, no
  output address/value check, no datum re-check. It is a pure "burn-to-unlock" script.
- Two live datum families: **registry** `{32e8c0ae…, <pool stake hash>}` (deployed validators storage) and
  **liquidation leftover** `{8021830a…, <borrower_tn>}` (borrower compensation; created by `collateral.ak` L346-351).

## 4. collateral.ak — spend conditions (`validators/collateral.ak:81-489`)

Params `CollateralParams { pool_script_hash, liquidations_pkh, param_merge_script_hash }`. Datum `CollateralDatum`
(14 fields, `types/collateral.ak:6-21`). Redeemer `{action: CollateralRepay | CollateralLiquidate(Int), interest: Int,
merge_type: ImmediateWithPool(ORef) | DelayedIntoPool{output_index, amount_repaying}}`.
Common: finite validity bounds, `upper-lower <= 3_600_000` (1 h); platform fee paid via an output to
`platform_fee_collector_address` with loan tokens ≥ tier fee and inline datum == raw bytes of `borrower_tn`;
`interest_check` (provided ≥ computed from `deposit_time` to `upper_bound`, `finance.calculate_interest_amount`).
- **CollateralRepay** (L186-204): burn borrower NFT `(collateral_script_hash, borrower_tn)`
  (`validate_mint_nft_few_per_policy`) — requires owning the NFT. Then:
  - `ImmediateWithPool`: pool input has pool NFT; pool redeemer is `Wrapped(Continuing(CloseLoan{loan_amount >=
    datum.loan_amount, repay_amount >= computed}))`.
  - `DelayedIntoPool` (L432-485): output at index at merge-script address (`b6e02be7…`) with datum `MergeDatum
    {borrower_tn, pool_nft_name, repay_amount, loan_amount, collateral_oref=this_oref}`; value ≥ repay + fee; ≤2 assets.
- **CollateralLiquidate** (L205-388): **no NFT, no signature** — permissionless liquidation. Requires
  `interest > 0`, `interest_rate > 0`, `interest >= computed`, `finance.check_is_undercollaterized(value_to_repay,
  collateral_value, liquidation_threshold)`; for non-ADA assets oracle data from reference inputs
  (`utils.retrieve_oracle_data`, validity `valid_to >= upper_bound`, oracle withdraw redeemer required).
  Liquidation output (L335-373): if `borrower_compensation > 0 && undercollateralized`, output at
  `liquidation_output_ref` must be at `liquidations_pkh` (leftovers script) with the **same stake credential**,
  collateral token quantity ≥ compensation, datum `{collateral_script_hash, borrower_tn}`, ≤2 assets.
  Then same merge options as repay.
- **mint** (L491-766): borrower-NFT mint is tied to a pool `Borrow` redeemer and a fully recomputed collateral output
  (datum, overcollateralization vs `initial_collateral_ratio`, stake match, `tag == Some(pool_oref)`,
  `borrower_tn == blake2b_256(serialise(pool_oref))`); burns just require `-1` of own policy.

## 5. Attached reference scripts on the 336-byte address (decoded)

- **2852 B (99 distinct)** = `validators/liquidity_token.ak` `fn liquidity_token`; params `(pool_hash, token_name)`
  e.g. `f8dddd3e…` = `(32e8c0ae…, 4c29cb6c…)`. Traces: `correct_pooltoken_name/out`, `correct_recorded_lptokens`,
  `depositing_at_script/gt_0`, `minted_lp_match_deposit`, `nft_name_datum_check`, `nfts_check`, `tokens_mint_check`
  (exact match to HEAD source). Redeemers: `TransitionPool | CreatePool | DestroyPool`.
- **5064 B / 5065 B (96 + 3 distinct)** = `validators/pool_stake.ak` `fn pool_stake`; params `(pool_nft_policy,
  delegation_nft, utxo_to_consume)` e.g. `4c29cb6c…` = `(32e8c0ae…, {c04e78ea…, 55a8ea4f…}, ORef{6f1660ba…,3})`;
  `2923d85c…` differs only in params (index 42). Traces: `amount_check`, `asset_is_ada`, `nft_check`,
  `oracle is expired`. Redeemers: `Publish | Withdraw{ExactWithdrawal|SwapWithdrawal} | CreatePool`.
  (`cbor.diagnostic` debug traces added in `2f3b27b` produce no static strings; not byte-verified.)
- Pattern (`src/pool/create.ts`, `src/deploy_validators.ts`): per pool, `pool_stake` is parameterized by
  `(poolScriptHash, delegatorNft, utxoToConsume)`, `liquidity_token` by `(poolScriptHash, stakeKeyHash)`; both are
  deployed as CIP-31 reference scripts on UTxOs at the leftovers address, datum = `{pool script hash, stake hash}`
  (= pool NFT AssetClass). Decoded dumps saved: `decoded_336B_*`, `decoded_f8dddd3e*` (2852), `decoded_4c29cb6c*`,
  `decoded_76265109*`, `decoded_207c537c*` (5064), `decoded_2923d85c*` (5065).

## 6. `src/deployedValidators.json` (19 entries) — testnet, not mainnet

All 19 `txHash` values are **not found** on mainnet (Koios `/tx_info`, batch of 19): `koios_deployed_validators_tx_info.json`
= `[]`. No validatorName → output mapping is possible on mainnet; the file records a testnet deployment only.

## 7. On-chain creation txs of the live scripts (Koios `/script_info` + `/tx_info`)

| script | creation tx | block | UTC time |
|---|---|---|---|
| leftovers `9b99fef5…` (336 B) | `5d88f8525f6840373c5d857eec4dcc8e5657378b5b2133a55a2a4e396d5f29e0` | 9943789 | 2024-02-17 09:13:58 |
| delegator NFT policy `c04e78ea…` (672 B) | `7f2902e49f12c214fb0050a83b42be464cc838f6666e5ce10800613f8a1ae586` | 9943809 | 2024-02-17 09:22:09 |
| pool_config `ecf0762d…` (3387 B) | `0102105ebc4e8844383f897a9cdb5cdc2be218f81a0bd0a26476da02e81bc204` | 9944391 | 2024-02-17 12:41:28 |
| delayed_merge `b6e02be7…` (2171 B) | `7e97a534fade0f6ce3c6796d8c8741e0f41da1f472c7cedad52e56403d439601` | 9944396 | 2024-02-17 12:43:17 |
| pool `32e8c0ae…` (8021 B) | `b205fa3070545828fff750dde8a8ab3270baff9ca4b3bc78bb5e0f523934f00c` | 9944398 | 2024-02-17 12:43:35 |
| collateral `8021830a…` (14492 B) | `f071d334cdac93773624d578d81666f2e8aaf53662281a4ba90d67861d18db5c` | 9962754 | 2024-02-21 19:46:07 |
| liquidity_token `f8dddd3e…` + pool_stake `4c29cb6c…` (per pool) | `e6a62419df4d9855dc6c7bbee84a6de9fb9b60f7daa3cbae1a5fec3d623fe0b8` | 9968432 | 2024-02-23 03:14:50 |

The 3 brief-listed enterprise addresses hold only deploy "carriers" (datum `d87980` = `Constr 0 []`, CIP-31 ref script):
pool carrier `b205fa30…:0` 35.52 ADA; collateral carrier `f071d334…:0` 63.41 ADA; leftovers carrier `5d88f852…:0` 2.40 ADA.
Carriers have a datum that cannot type-check as `Datum`/`CollateralDatum` → spend handlers fail → **likely locked forever**.

## 8. External (unprivileged) attack surface

Legend: (a) must own an NFT; (b) signature; (c) pool/owner privilege; (d) public state only.

**pool.ak (`32e8c0ae…`, 98 live pools):**
1. `LpAdjust` **withdraw** — (d) + any LP tokens of the pool (mintable/buyable). Pre-fix check gives **no upper bound**
   on the withdrawn value (only `≥ pro-rata share`); outputs unconstrained → a single LP holder can move up to the whole
   liquid balance (`balance`) of a pool into any output. Needs: pool UTxO with valid datum, `config_ref` UTxO with the
   config NFT (must still exist on-chain; not verified), LP mint = burn. No signature, no NFT ownership, no privilege.
2. `Destroy` — (a) requires holding/burning 100% of remaining LP supply + the pool NFT (locked in the pool) + delegator
   NFT; **no output checks** → whole pool value sweepable in one tx. Reachable only when no other LP tokens remain.
3. `Borrow` / `CloseLoan` / `PayFee` — (d) permissionless but tightly constrained transitions; no value-destination
   check inside pool.ak (borrow destination enforced by `collateral.ak fn mint`/order contracts).
4. `mint` — (d) permissionless pool creation; `BurnPoolNFT` is just `-1` mint (only reachable through Destroy spend).

**leftovers.ak (`9b99fef5…`, 216 registries + 31 liquidation leftovers):**
5. Spend = burn exactly one NFT, **nothing else checked** — no output address/value check.
   - Registry UTxOs `{32e8c0ae…, nft_name}`: reachable only in a tx that also spends the matching pool UTxO and burns
     its pool NFT → effectively gated by pool `Destroy` (c/a). If a pool NFT was already burned, the registry UTxO is
     **bricked** (can't burn twice). 1 of 99 NFTs is already burned (supply 0).
   - Liquidation leftovers `{8021830a…, borrower_tn}`: requires the borrower NFT burn (a). Because outputs are
     unchecked, a borrower who burns their NFT in a bundled tx (e.g. via a malicious batcher/dApp) can have the
     compensation redirected anywhere — confused-deputy risk. No third party can burn the NFT without the holder's
     key (NFT sits in the borrower's wallet).
   - Anyone may create arbitrary leftovers UTxOs with arbitrary datums (permissionless); no theft vector by itself.

**collateral.ak (`8021830a…`, 1 live loan + carriers):**
6. `CollateralLiquidate` — (d) permissionless. Preconditions: an existing `CollateralDatum` UTxO, oracle data for
   non-ADA assets (oracle withdraw redeemer, `valid_to >= upper_bound`), undercollateralization vs
   `liquidation_threshold`. The liquidator controls the tx's validity upper bound (≤1 h window) → interest accrual and
   price selection within that window are tx-crafted; borrower compensation is forced to the leftovers address with an
   exact datum/quantity (but only when `borrower_compensation > 0`; otherwise the check is vacuous).
7. `CollateralRepay` — (a) borrower NFT; the same tx can also spend leftover liquidation UTxOs (outputs unchecked, §5).
8. `mint` — (d) permissionless borrower-NFT mint as part of a pool `Borrow`; fully recomputed collateral datum checks.
   Burning `-1` requires the NFT to be present as input.

**Reference scripts:** only attached to UTxOs (CIP-31), no independent authority; they are executable code for the
corresponding script hashes (e.g. anyone may reference the 2852 B `liquidity_token` to mint/burn LP tokens subject to
its checks).

## 9. Live inventory snapshot (raw; no valuation)

- 98 pool UTxOs (pool NFT + `pool.Datum`) at `addr1xyew3s9wx…<per-pool stake>`; 739.17 ADA total across those
  addresses (380.41 ADA of it in non-NFT, no-datum UTxOs that are also unspendable as-is) + loan tokens in pool UTxOs.
- leftovers credential `9b99fef5…`: 249 UTxOs / 13,888.73 ADA across 18 addresses = 216 registries + 31 liquidation
  leftovers + 1 carrier + 1 no-datum.
- collateral credential `8021830a…`: 10 UTxOs / 275.16 ADA across 8 addresses = 1 live loan datum (200 ADA,
  2024-05-15) + 1 carrier + 8 no-datum.
- The enterprise-form addresses from the brief are carriers only (35.52 / 63.41 / 2.40 ADA).

## 10. Blockers / caveats

- **No byte-level commit proof**: aiken is not installed and the repo's committed compiled artifacts are stale (old
  codebase). Commit attribution is by source-diff + deployment timestamps + trace-string/UPLC spot checks
  (pre-fix `LpAdjust` verified directly in the live UPLC). Byte-level confirmation needs compilation with the
  historical toolchain (stdlib 1.5.0, early-2024 Aiken) or CEK evaluation.
- Koios keyless limitations: `/credential_utxos` returns no inline-datum payload (used `/address_info`); testnet
  deployment txs from `deployedValidators.json` are invisible on mainnet, so no name→hash map.
- `pool_config`/`delegator NFT` UTxO existence (needed as reference inputs for any pool spend) not verified in this pass.
- The 5064 B vs 5065 B pool_stake variant difference is parameter-only (output-reference encoding); not byte-diffed
  beyond param extraction.
