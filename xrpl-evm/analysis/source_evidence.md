# Source-level evidence — XRPL EVM / cosmos/evm exposure

All excerpts fetched 2026-10-04 from public GitHub. Read-only.

## 1. What the deployed node runs

`xrplevm/node` v11.2.0 `go.mod` (https://github.com/xrplevm/node/blob/v11.2.0/go.mod):

```
github.com/cosmos/evm v0.6.0
...
replace (
	github.com/cosmos/cosmos-sdk => github.com/xrplevm/cosmos-sdk v0.53.6-xrplevm.1
	github.com/cosmos/evm => github.com/xrplevm/evm v0.6.3-xrplevm.1
)
```

Official release binary `node_11.2.0_Linux_amd64.tar.gz` (sha256
`300a6579bd0fbda56d9837bb3976e08068cb6d29289f273b19a04652869c3ac5`) build info:

```
dep github.com/cosmos/evm v0.6.0
=>  github.com/xrplevm/evm v0.6.3-xrplevm.1 h1:HcmAPkTLnHPtT93OZnKK6lg6rgtcuX5I09V0q9Asn1U=
```

and the binary contains both guard strings (see `binary_buildinfo.txt`):

```
state balance underflow for %s: have=%s sub=%s
state balance overflow for %s: have=%s add=%s
```

Live `node_info` (cosmos-api.xrplevm.org): `exrp` version **11.2.0**, git commit
`40336cc1eb1beeff86b854961e97534dd88c0dbf` — identical to the v11.2.0 tag commit.

## 2. Version lineage vs fix floors

| Release line | cosmos/evm fork pin | SubBalance underflow guard (GHSA-7g4w) | AddBalance overflow + atomic Commit (GHSA-367m) |
|---|---|---|---|
| node v10.1.0 (mainnet at Aug-20..23) | `xrplevm/evm-priv-jul2026 v0.6.1-xrplevm.1` (private) | **NO** (public twin `xrplevm/evm v0.6.1-xrplevm.1` lacks it) | NO (private July fix addressed the ERC20 advisory only) |
| node v10.2.0 (mainnet Aug-23..Sep-21) | `xrplevm/evm-ghsa-aug-2026 v0.6.2-august-2026-hotfix-xrplevm.1` (private) | YES (based on v0.6.2) | YES (combined hotfix, per team post-mortem) |
| node v10.2.1 | `...hotfix-xrplevm.2` | YES | YES |
| node v11.1.0 / v11.1.1 | `xrplevm/evm v0.6.1-xrplevm.1 / .2` | **NO** | NO |
| node v11.2.0 (mainnet now) | `xrplevm/evm v0.6.3-xrplevm.1` | YES | YES |

Fix floors: cosmos/evm **v0.6.2** (GHSA-7g4w-cg88-2cq2) and **v0.6.3**
(GHSA-367m-g444-9mg3). Upstream v0.6.3/v0.7.3 released 2026-09-03.

The v11.1.x node line was never scheduled on mainnet: the only software-upgrade
proposals are #33 (v10.1.0, height 6,856,000, Jul-16), #26 (v10.0.0), #25
(v9.0.0), and #38 (v11.2.0, height 7,823,200, passed Sep-21). Mainnet went
v10.2.0 -> v11.2.0.

## 3. Guards in `xrplevm/evm v0.6.3-xrplevm.1` (deployed)

`x/vm/statedb/state_object.go`:

```go
func (s *stateObject) SubBalance(amount *uint256.Int) uint256.Int {
	if amount.IsZero() { return *(s.Balance()) }
	balance := s.Balance()
	if balance.Lt(amount) {
		panic(fmt.Sprintf("state balance underflow for %s: have=%s sub=%s", ...))
	}
	...
}

func (s *stateObject) AddBalance(amount *uint256.Int) uint256.Int {
	...
	newBalance, overflowed := new(uint256.Int).AddOverflow(s.Balance(), amount)
	if overflowed {
		panic(fmt.Sprintf("state balance overflow for %s: have=%s add=%s", ...))
	}
	return s.SetBalance(newBalance)
}
```

`x/vm/statedb/statedb.go` `Commit()` stages writes in `s.ctx.CacheContext()` and
only publishes (`writeCache()`) after the whole dirty set succeeded (atomic
commit, GHSA-367m fix).

## 4. Pre-v0.6.2 code (mainnet during the Aug-20..23 window, public twin)

`xrplevm/evm v0.6.1-xrplevm.1` `x/vm/statedb/state_object.go`:

```go
func (s *stateObject) SubBalance(amount *uint256.Int) uint256.Int {
	if amount.IsZero() { return *(s.Balance()) }
	return s.SetBalance(new(uint256.Int).Sub(s.Balance(), amount))   // unchecked wrap
}
func (s *stateObject) AddBalance(amount *uint256.Int) uint256.Int {
	if amount.IsZero() { return *(s.Balance()) }
	return s.SetBalance(new(uint256.Int).Add(s.Balance(), amount))   // unchecked wrap
}
```

So the version-level claim in the lead ("producing blocks on a vulnerable
cosmos/evm version below the fix floor during the window") is TRUE for the
statedb code — but the exploit was not reachable because of the configuration
gates below.

## 5. Precompile address map (v0.6.3-xrplevm.1, `x/vm/types/precompiles.go`)

```
0x...0100 P256       0x...0800 Staking      0x...0804 Bank
0x...0400 Bech32     0x...0801 Distribution 0x...0805 Gov
                     0x...0802 ICS20        0x...0806 Slashing
                     0x...0803 Vesting
```

Live `active_static_precompiles` (current, at halt height 7,360,028, and at
7,330,000 during the exploit window — all identical):
`0x100, 0x400, 0x804, 0x805` only. Staking, distribution, ICS20, vesting and
slashing precompiles are NOT active.

## 6. Denom configuration (`xrplevm/node v11.2.0 app/app.go`, same in v10.1.0)

```go
).WithDefaultEvmCoinInfo(evmtypes.EvmCoinInfo{
	Denom:         BaseDenom,      // "axrp"
	ExtendedDenom: BaseDenom,      // identity conversion, 18 decimals
	DisplayDenom:  Denom,          // "xrp"
	Decimals:      18,
})
```

Bond denom is `poa` (proof-of-authority, permissioned validator set). Staking
bank events therefore never carry the EVM denom `axrp`, so the StateDB balance
handler cannot mirror a delegation into EVM balances.

## 7. Vesting module absent

- `app/app.go` at v10.1.0, v10.2.0 and v11.2.0 contains zero references to
  `vesting` (module not in the module manager / interface registry).
- Read-only simulation of `/cosmos.vesting.v1beta1.MsgCreateVestingAccount`
  returns `unable to resolve type URL ... tx parse error` (message unregistered).
- Full account scan: 24,237 accounts (25 pages), histogram
  `{BaseAccount: 24228, ModuleAccount: 9}`, **0 vesting accounts**.

## 8. ERC20 / ICS20 gates (GHSA-367m path)

- Live `permissionless_registration = false` (also false at height 7,330,000).
- Governance proposal #35 ("ERC20 Registration Parameter Update", passed
  2026-08-15, MsgUpdateParams) set it false.
- All 9 registered token pairs are `OWNER_MODULE`; none user-registered.
- The x/erc20 IBC middleware is wired (`app.go: transferStack = erc20.NewIBCMiddleware(...)`),
  so the *plumbing* exists — but step 1 of the exploit (permissionless
  registration of a malicious native ERC20) is closed, and the deployed
  v0.6.3-xrplevm.1 contains the atomic-commit fix.

## 9. Upstream advisories / patch timeline

| Advisory | Published | Affected | Patched |
|---|---|---|---|
| GHSA-7g4w-cg88-2cq2 "Balance underflow in EVM StateDB" | 2026-08-28 | <0.6.2, >=0.7.0 <0.7.2 | 0.6.2 / 0.7.2 (released 2026-08-19) |
| GHSA-367m-g444-9mg3 "Non-atomic StateDB commit" | 2026-09-03 | >=0.6.0 <0.6.3, >=0.7.0 <0.7.3 | 0.6.3 / 0.7.3 (released 2026-09-03) |

Cosmos post-mortem: https://github.com/cosmos/security/blob/main/communications/cosmos_evm_GHSA-7g4w-cg88-2cq2_post_mortem.md
XRPL EVM incident report: https://www.xrplevm.org/blog/xrpl-evm-preventive-response-to-cosmos-evm-incident

## 10. Bridge custody (exit routes / backing)

- Native denom `axrp` supply = 1,559,956.920994 XRP (bank module, current and
  byte-identical at halt height 7,360,028).
- XRPL mainnet Axelar gateway `rfmS3zqrQrka8wVyhXifEeyTwe8AMz2Yhw` holds
  1,579,718.084690 XRP (validated ledger) — consistent backing, no unbacked mint.
- EVM-side bridge contracts hold dust: Axelar ITS `0xB5FB4BE0...` 1.800000063
  XRP; AxelarGasService `0x2d5d7d31...` 3.035374451 XRP; Wormhole Core/WTT/
  Executor/GuardianGov 0 XRP and no indexed token balances.
- Module accounts (transfer, erc20, poa, fee_collector, etc.) hold 0 balances.
