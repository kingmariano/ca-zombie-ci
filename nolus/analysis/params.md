# C2-31 Nolus — on-chain parameters & governance facts (pirin-1)

All reads: public LCD/RPC (keyless), 2026-10-09 ~06:30–16:00 UTC. Primary reference block:
**pirin-1 height 27,319,088** (2026-10-09T06:38Z); gov params via ABCI at height 27,319,295.
App: `nolusd 0.8.6`, Cosmos SDK `v0.53.3-nolus-4` (wasmd v0.61.15-nolus fork).

## Gov module params (ABCI `/cosmos.gov.v1.Query/Params`, height 27,319,295)

| Param | Value |
|---|---|
| min_deposit | **200 NLS** (200,000,000 unls) |
| max_deposit_period | 10 days (864,000s) |
| voting_period | **3 days** (259,200s) |
| quorum | **33.4%** |
| threshold | **50%** |
| veto_threshold | **33.4%** |
| min_initial_deposit_ratio | 25% |
| proposal_cancel_ratio | 50% |
| expedited_min_deposit | 300 NLS |
| expedited voting period | 1 day; expedited threshold 66.7% |

Raw evidence: `raw/gov_params_abci.json` (protobuf, base64).

## Staking (LCD `/cosmos/staking/v1beta1/pool`)

- bonded: **212,518,285.80 NLS** (`212518285802600` unls)
- not bonded (unbonding pool): 57,403,690.09 NLS
- 19 bonded validators; top-1 28.60M NLS (13.5%), top-3 78.59M (37.0%), top-5 119.4M (56.2%)
- unbonding time: 1,814,400s (**21 days**); max validators 25

## NLS token / market (2026-10-09)

- total supply: 922,943,861.74 NLS (unls supply 922,943,861,741,208)
- price: **$0.00364916** (CoinGecko); MEXC mid ~$0.003674
- circulating ~889.9M NLS; market cap ~$3.25M
- 24h volume **$62.4k all venues** (MEXC $57.1k, Raydium CLMM $5.25k, Osmosis $23)
- MEXC NLS/USDT book: asks total **2.158M NLS** (of which only ~1.85M NLS within 2× mid; tail at absurd prices up to $200M/NLS); bid side total **$1,926**
- Osmosis NLS pools (1041/1300/2301): total ~7,020 NLS (~$25.6)

## Community pool (LCD `/cosmos/distribution/v1beta1/community_pool`)

| Denom | Amount (base units) | USD |
|---|---|---|
| unls | 240,000,000,954,907.67 | **~$875.8k** |
| ibc/18161D… (USDC noble) | 6,529.91 (µUSDC) | ~$0.007 |
| ibc/F5FABF… (USDC) | 22,947.40 (µUSDC) | ~$0.023 |
| ibc/6CDD46… (ATOM) | 9,320.10 (µATOM) | ~$0.018 |
| ibc/ED07A3… (OSMO) | 15,793.91 (µOSMO) | ~$0.001 |
| ibc/3D6BC6… (NTRN) | 8,057.09 (µNTRN) | ~$0.000 |

The CP is **effectively 240.0M NLS**; the non-NLS balances are micro-unit dust (~$0.05 total).
Cross-check: distribution module account holds 246.15M NLS (CP + ~6.15M NLS fee pool/outstanding rewards).

## Governance history (100 most recent proposals, ids ~275–374)

- **99 PASSED / 1 REJECTED** (prop 295, "Get Airdrop" scam).
- Turnout: min 93.4M, median 150.1M, max 183.1M NLS (~70–86% of bonded).
- All protocol migrations/pins: **100% Yes**, 0 No, 0 NWV.
- The only hostile proposal (295) was rejected with **NoWithVeto = 162,331,398 NLS** (+1.18M No, 4.57M Yes).
  ⇒ empirical opposition bloc on a hostile proposal ≈ 162M NLS = 76% of bonded.
- Msg types used: MsgSudoContract (106), MsgPinCodes (24), MsgUpdateParams (13), MsgUnpinCodes (11),
  MsgSoftwareUpgrade (6), MsgMigrateContract (2, on the Admin contract itself in v0.8.6 era).
- No MsgCommunityPoolSpend has ever been executed (tx search: 0 results).

## Governance-controlled primitives (all verified)

1. `MsgCommunityPoolSpend` — pays CP to any address. CP = 240.0M NLS.
2. `MsgUpdateParams(wasm)` — **wasm keeper authority = gov module account**
   (`app/keepers/keepers.go`: `authtypes.NewModuleAddress(govtypes.ModuleName).String()` passed to `wasmkeeper.NewKeeper`).
   Gov can therefore change `code_upload_access` (currently `AnyOfAddresses`:
   Admin contract `nolus1gurg…` + team EOA `nolus1klq25…`) and `instantiate_default_permission`.
3. `MsgPinCodes` / `MsgUnpinCodes` — pin/unpin arbitrary code IDs.
4. `MsgSudoContract(Admin contract, migrate_contracts{to_release, migration_spec})` —
   per-contract **explicit `code_id`** is honored (proven in props 277/299/306/313/329/345 for the
   platform contracts `admin`/`timealarms`/**`treasury`**, and props 371/373 for protocol contracts).
   The Admin contract's versioning checks compare release/storage strings **self-reported by the
   target code** (`platform_package_release` query) — a malicious replacement contract can satisfy them.
5. `MsgSudoContract(<protocol contract>, …)` — gov can also sudo individual protocol contracts
   (e.g. oracle swap-tree updates).
6. `MsgUpdateParams(x/tax)` — gov can change `fee_rate` (currently 100% of base-denom tx fees go to the
   treasury contract) and `treasury_address` (currently the treasury contract), plus per-DEX profit
   addresses for foreign-denom fees.
7. `MsgUpdateParams(contractmanager)`, `(solanacarrier)` — gov authority params (fee_payer for the
   Solana carrier; failure/resubmit config). Minor.

## Protocol contract surface (78 contracts created by Admin contract `nolus1gurg…`)

Admin of every protocol contract = the Admin contract itself; Admin contract admin = itself.
Live markets (registered): SOLANA-METIS-{USDC,SOL,CB_BTC,WETH}. Osmosis/Neutron markets are sunset
(DefiLlama hallmarks; contracts remain, ~$0 balances). Platform contracts: `admin` (code 913),
`treasury` (911), `timealarms` (912), `rewards_dispatcher`, legacy `lpp`/`leaser`/`oracle`.

### Contract bank balances (Nolus chain, height ~27,319,1xx)

| Contract | Balance | USD |
|---|---|---|
| treasury (911) | 152,008,181.07 NLS | **~$554.7k** |
| SOLANA-METIS-USDC-lpp | 97,093.07 USDC (solray carrier) | $97.1k |
| SOLANA-METIS-SOL-lpp | 93.744 SOL (solray carrier) | $14.1k |
| SOLANA-METIS-CB_BTC-lpp | 0.10651540 cbBTC | $6.4k |
| SOLANA-METIS-WETH-lpp | 0.32499733 WETH | $0.8k |
| Reserve (legacy) | 5 NLS | $0.02 |
| leaser (legacy) | 1 NLS | $0.004 |
| oracle (legacy) | 0.097 NLS | $0.0004 |
| all other 70 contracts | dust/0 | <$0.01 |

Cross-check: DefiLlama 2026-10-04 snapshot Nolus-chain idle TVL $116,876 ≈ measured LPP carried $118.3k
(decimals validated). Total protocol TVL snapshot ~$345k (incl. ~$228k Solana-side positions).

## Module accounts (11) — nothing else gov-movable

bonded/not-bonded staking pools (bookkeeping), distribution (CP + fee pool), fee_collector (empty),
gov (empty), mint (empty), transfer (empty), feegunder (2 unls), interchainaccounts (empty),
**vestings (empty)**, wasm (empty). No lpp/lease native module accounts (protocol is CosmWasm-based).
