# C2-09 Archway — governance-capture economics (re-verified 2026-10-05, h 17,644,367)

## 1. Live governance parameters

From `abci_query /cosmos.gov.v1.Query/Params` (raw base64 + decoded in
`analysis/gov_params_abci_decoded.json`; the REST route `/cosmos/gov/v1/params` returns
501 on this node because the gRPC-gateway route expects `/params/{params_type}`):

| param | value |
|---|---|
| min_deposit | **5,000 ARCH** (5e21 aarch) |
| max_deposit_period | 14 days |
| voting_period | **7 days** |
| quorum | **0.334** |
| threshold | **0.500** |
| veto_threshold | **0.334** |
| min_initial_deposit_ratio | 0 |
| proposal_cancel_ratio | 0.5 (no cancel_dest) |
| burn_vote_veto | true |
| expedited | voting 1 day, threshold 0.667, but expedited_min_deposit denom is `"stake"` (nonexistent) → expedited unusable |

## 2. Live stake and pools (h 17,644,367)

| item | amount | USD @ $0.00038313 |
|---|---|---|
| bonded (sum of 18 bonded validators) | 221,867,913.393 ARCH | $85,004 |
| not-bonded (unbonding) | 270,057,400.329 ARCH | $103,465 |
| total supply | 1,178,684,426.923 ARCH | $451,564 |
| community pool | 96,464,698.230 ARCH | **$36,959** |
| distribution module account (CP + fee pool/outstanding rewards) | 115,302,678.954 ARCH | $44,177 |
| treasury module (x/rewards `TreasuryCollector`) | 45,253,663.343 ARCH | $17,338 |
| rewards module (contract reward collector) | 82,582.592 ARCH | $32 |
| IBC transfer escrow | **0** | $0 |
| gov module account | 0 | $0 |

Validator concentration: 18 bonded; largest DELIGHT 39.93M ARCH (18.0% of bonded).
All bonded validators: DELIGHT 39.9M, Alphabet 18.4M, Crouton 16.0M, Nodes.Guru 15.9M,
MZONDER 15.1M, NacionCrypto 14.8M, Crosnest 14.6M, REDELEGATE 14.1M, AM Solutions 13.9M,
TTT VN 12.5M, 0base.vc 12.2M, P-OPS 12.1M, Solva 10.3M, Architect 10.2M, … (full dump:
`ci-out/core_state.json` validators_bonded).

## 3. Cost to capture

To pass a proposal against no opposition: votes ≥ quorum × bonded, yes/(yes+no+abstain)
> 0.5. To pass against validators voting No with full turnout: yes > 50% of votes. To be
veto-proof: others cannot reach 33.4% of votes with NoWithVeto.

| threshold | ARCH needed | USD @ DL price | USD @ CoinGecko price |
|---|---|---|---|
| quorum-only (33.4% of bonded) | 74,103,883 | $28,391 | $27,224 |
| majority of cast votes (=50% bonded, full turnout) | 110,933,957 | $42,502 | $40,750 |
| veto-proof (66.6% bonded) | 147,764,030 | $56,613 | $54,280 |

**What capture actually pays:**
- `MsgCommunityPoolSpend` — immediate, permissionless once gov passes: **$36,959** (CP).
  Historically used twice (props #52/#53, Sep 2024), both **rejected**.
- Treasury (45.25M ARCH): **not gov-spendable.** In Archway v10.1.0 the `treasury` account
  is `rewardsTypes.TreasuryCollector`; the only code path touching it is a credit from the
  contract-reward collector (`x/rewards/keeper/distribution.go:255`). There is no
  spend/burn message for it. Not extractable by gov capture.
- Wasm contracts administered by the gov module: **0 of 9,644** contracts
  (`admin == archway10d07y265gmmuvt4z0w9aw880jnsr700j0f0puy` → 0 hits). Astrovault (429
  contracts, admin `archway1d78gwz…`), Eris (`archway1dpaaxgw…`), Liquid Finance
  (`archway1fepswjw…`), Balanced (`archway17j96tj3…`) are all **dev-administered**, so
  capture cannot migrate/drain them. The corpus's "Astrovault $111.9k + Eris/BackBone"
  are DefiLlama TVLs, not gov-reachable value.
- Software upgrade (`MsgSoftwareUpgrade`) could in principle rewrite state, but the
  upgrade must be adopted and run by validators — not an autonomous extraction path.

**Acquisition feasibility (the real blocker):**
- ARCH float sitting in on-chain pools is tiny: Astrovault pools hold ~1.97M ARCH ($754),
  Osmosis ARCH pools hold ~6.80M ARCH, Liquid Finance ~1.01M — together ~9.8M ARCH.
  Acquiring the 74M–148M ARCH needed **cannot be done on-chain** without moving price
  orders of magnitude; it requires CEX/OTC accumulation (not measurable here) in a token
  with a $0.45M market cap.
- Historical turnout on Archway is near-total: #59 (2025-09) 249.1M yes / 0 no;
  #60 (2026-01) 201.7M yes / 0 no; #52 rejected with 191.0M no vs 188.4M yes. Validators
  vote with essentially all delegated stake, so an attacker must out-vote most of the
  bonded set, not merely reach quorum.
- The attacker keeps the staked ARCH (unbonding 21 days, `1814400s`), so the true cost is
  market impact + 3-week price risk, not the full notional — but the impact of absorbing
  6–13% of total supply in a micro-cap is the dominant, unquantifiable cost.

## 4. Verdict

| scenario | cost | immediate extraction | EV |
|---|---|---|---|
| quorum-only (no validator opposition) | ≥$28.4k nominal + impact | $36.96k | thin positive on paper |
| vs. majority turnout | ≥$42.5k | $36.96k | negative |
| veto-proof | ≥$56.6k | $36.96k | negative |

Governance capture is **not a reliable standalone profit path** today: the only immediate
prize is the $36.96k community pool, the treasury and all major contracts are not
gov-controlled, turnout is high, and the ARCH needed is not purchasable on-chain.
It becomes rational only (a) under apathy, or (b) combined with the CWA-2026-006 minting
primitive (mint → stake → vote at zero token cost → CP + pool drain).
