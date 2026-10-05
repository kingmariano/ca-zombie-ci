# C2-05 — source-code findings (Stride v34.1.0 live vs unreleased main)

All source read from `github.com/Stride-Labs/stride` tag **v34.1.0** (the version live on stride-1 per
`/cosmos/base/tendermint/v1beta1/node_info`: app `v34.1.0`, cosmos-sdk `v0.54.3`) and from `main`
(unreleased, forward-looking). No code executed; read-only review.

## 1. Governance params are standard gov v1 (live)
`cosmos.gov.v1.Query/Params` (gRPC, 2 nodes):
quorum 0.25 · threshold 0.50 · veto 0.334 · voting 432000s · maxDeposit 172800s ·
minDeposit 20,000,000,000 ustrd · minInitialDepositRatio 0.50 · burnVoteVeto true ·
expeditedVotingPeriod 86400s · expeditedThreshold 0.667 · **expeditedMinDeposit = 50,000,000 `stake`**
→ the expedited deposit denom does not exist on Stride, so expedited proposals cannot be funded.

## 2. Quorum denominator (cosmos-sdk v0.54.3 `x/gov/keeper/tally.go`)
`totalValPower` = Σ `validator.GetValidatorPower()` over bonded validators **at tally time**
(`IterateBondedValidatorsByPower`); `percentVoting = totalVotingPower / totalValPower`.
→ An attacker's own newly-bonded stake inflates the denominator:
`X/(B+X) ≥ 0.25` ⇒ **X ≥ B/3** (best case, no other votes). Live `B = 6,630,658.205459 STRD`
⇒ X ≥ 2,210,219.4 STRD.

## 3. Admin gating map (live v34.1.0) — `utils/admins.go`
```go
var Admins = map[string]bool{
    "stride1k8c2m5cn322akk5wy8lpt87dd2f4yh9azg7jlh": true, // F5 (2-of-3 multisig, seq 760)
    "stride10d07y265gmmuvt4z0w9aw880jnsr700jefnezl": true, // gov module
}
```
Messages gated by `utils.ValidateAdminAddress(msg.Creator)` in `ValidateBasic` (either admin, incl. gov):
`SetCommunityPoolRebate`, `UpdateInnerRedemptionRateBounds`, `CloseDelegationChannel`, `ResumeHostZone`,
`RebalanceValidators`, `AddValidators`, `DeleteValidator`, `ChangeValidatorWeights`, `ClearBalance`,
`RegisterHostZone`, `ToggleTradeController`.
Handler-level `ms.authority != msg.Authority` checks (gov only): `UpdateHostZoneParams` (changes only
`MaxMessagesPerIcaTx`), `DeprecateHostZone` (sets `Halted=true`), `CreateTradeRoute`/`DeleteTradeRoute`/`UpdateTradeRoute`.
Permissionless (no admin/authority check): `RestoreInterchainAccount` (requires an existing ICA; re-registers it).
**None of the live messages transfers ICA funds to an arbitrary address.**

## 4. Forward-looking (unreleased `main`) — proto comments verbatim
- `MsgUndelegateFromValidators`: *“Admin drain of a host zone's delegations. An empty validators list means every validator with a positive recorded delegation.”*
- `MsgTransferFromIca`: *“Admin ICA transfer of one of the four funded ICAs' balance (delegation, withdrawal, fee, redemption) to the Osmosis vault over the host's mapped channel to osmosis-1. The receiver and channel are hard-coded constants, not tx inputs.”*
- `MsgSweepTokensOffStride`: *“Batched sweep of holders' balances off Stride (implemented in the next PR).”*
Not present in v34.1.0 (`proto/stride/stakeibc/tx.proto` of v34.1.0 lacks them). Monitor for v35: if shipped with
the same admin gating (gov + F5), a future governance capture would no longer need a software upgrade.

## 4b. Staketia (stTIA v2) admin messages (live v34.1.0)
`x/staketia/types/msgs.go` gates several record-manipulation messages with `utils.ValidateAdminAddress`
(gov + F5): `MsgAdjustDelegatedBalance`, `MsgOverwriteDelegationRecord`, `MsgOverwriteUnbondingRecord`,
`MsgOverwriteRedemptionRecord` (plus operator/confirm messages). These can distort the stTIA redemption-rate
records; they do not move ICA principal to an arbitrary address. Same capture/key gate as §3 — latent P.

## 5. Host-side ICA allowlists (do not constrain the controller)
- Cosmos Hub `ibc/apps/interchain_accounts/host/v1/params`: `{"host_enabled":true,"allow_messages":["*"]}`.
- Celestia: `["/ibc.applications.transfer.v1.MsgTransfer","/cosmos.bank.v1beta1.MsgSend", staking msgs, distribution msgs, "/cosmos.gov.v1.MsgVote", feegrant msgs]`.
→ If the Stride controller code ever instructs an ICA to send funds out (e.g. after undelegating and waiting
out the host unbonding period), the host chains will execute it. The only defence is Stride chain code integrity.

## 6. Community pool mechanics
`MsgCommunityPoolSpend{authority=gov, recipient, amount}` executes at the end of the voting period when the
proposal passes; the recipient is arbitrary. Live CP = $12,370.68 (itemized in `ci-out/report.json`).
The distribution module account's larger bank balance (~$65k of stToken denoms) is *outstanding staker
rewards*, not CP; `MsgCommunityPoolSpend` cannot spend it.

## 7. Upgrade mechanics
Prop 284 (`Upgrade v34 Aquila`, passed 2026-09-20) = `MsgSoftwareUpgrade` with `plan.info = ""`.
Binaries are distributed off-chain (GitHub releases / team channels) and validators install them; a malicious
binary would have to be adopted by the validator set. Not an unprivileged path.
