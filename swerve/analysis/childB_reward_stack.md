# Child B — Swerve secondary custody & reward stack (Ethereum mainnet)

**Date:** 2026-10-12 · **Blocks:** state at 26,173,833–26,173,849 · **Status:** read-only (no tx sent)
**Scope:** DAO proxy `0x2638d2680AB4914126ee05b9c5EE95bAC311A95E`, "burner" `0xcDEDb901181b4B90181424Ff581b627805186Ca7`, gauge `0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa`, TokenMinter `0x2c988c3974AD7E604E276AE0294a7228DEf67974`, GaugeController `0x0C4d90ca69104B4cb937fB21c8533c29554AE32c`, veSWRV `0xe5e7DdADD563018b0E692C1524b60b754FBD7f02`, SWRV `0xB8BAa0e4287890a5F79863aB62b7F175ceCbD433`, Aragon DAO apps `0xdff7beb0cbf54d6553e4702ae0ffa60718822478` / `0xCcE356A37930e075921b486C746Ba8ed6EBCF172` / `0x5daDBF4eD01CBA1AFD990518443033863c6e3Fd8`.
**Method:** `cast` reads + `eth_call` simulations over public RPC, `cast call --trace` for the decisive trace, Etherscan v2 logs/txlists (API key read from env at runtime, never written to files). Evidence files listed in the appendix.

## 0. Headline

1. **The 30,408.429720 USDT in the proxy is STUCK (S).** No caller, *including the admin EOA*, can move it: the only token-moving paths are `burn_coin`/`burn`/`burn_eth` via `burners[]`; `burners(USDT)=0x0`; and `set_burner(USDT, X≠0)` **always reverts** because USDT's `approve()` returns no data while Vyper 0.2.4 requires ≥32 bytes of returndata. Proven by simulation + mainnet trace + corroborating 2023 history (only DAI/USDC/TUSD burners could ever be installed).
2. **E-U = $0.00** across the whole secondary stack; **P = $0.00** today; **S = $30,383.84**.
3. The non-USDT part of the 2023 admin fees (**$93,149.88**) was already extracted in Apr–May 2023 by operator EOAs and sent to **Binance 14** (`0x28c6c062…`) and **OKX 7** (`0x5041ed75…`). It was **not burned**, and no Swerve contract retains it.
4. Governance context: an Aragon DAO whose votes are weighted by **veSWRV** previously held the proxy's admin roles. Votes #10/#11 (executed 2026-09-09 / 2026-09-16) moved all three proxy roles to a single EOA `0x996E539a…`. Capturing that DAO today costs ≈$109 (buy 140k SWRV ≈0.0427 WETH from the UniV2 pair) + a 4-year lock to match the incumbent's 140k ve, and yields ≈$0.

## 1. Proxy `0x2638d268` — who can move the 30,408 USDT?

### 1.1 State (block 26,173,833)

| Item | Value |
|---|---|
| `ownership_admin` / `parameter_admin` / `emergency_admin` | `0x996E539a1242a541f5909c6B20BbEf4CC63F34b1` (EOA, all three) |
| `future_ownership_admin` / `future_parameter_admin` / `future_emergency_admin` | same EOA |
| `burners(DAI)`, `burners(USDC)`, `burners(TUSD)` | `0xcDEDb901…` (**EOA**, `cast code`=0x) |
| `burners(USDT)`, `burners(0x0)` [ETH] | `0x000…0` |
| balances | **USDT 30,408.429720**; DAI 0; USDC 0; TUSD 0; swUSD 0; SWRV 0; ETH 0 (+ numerous $0 spam tokens) |
| allowances (proxy → 0xcDED) | DAI/USDC/TUSD = MAX_UINT256; **USDT = 0** |
| pool `0x3292…` state | `owner()=0x0`, `admin_fee()=0`, `future_admin_fee()=0`, `admin_actions_deadline()=0`, `transfer_ownership_deadline()=0`, `future_owner()=0x0` |

### 1.2 Full function map (all 20 functions; verified source = Curve "StableSwap Proxy" 0.2.4)

| Function | Gate | What it does | Moves value today? |
|---|---|---|---|
| `set_burner(token,burner)` | `ownership_admin` | approves `MAX` on token to burner | Can set DAI/USDC/TUSD burner (sim: SUCCESS from admin). **USDT → always reverts** (see 1.3) |
| `burn_coin(coin)` | **permissionless** | `Burner(burners[coin]).burn_coin(coin)` | All tested coins revert: USDT/0x1 → codeless call → Vyper revert; DAI/USDC → burner is EOA `0xcDED` → codeless call → revert |
| `burn(burner)` | **permissionless** | calls arbitrary `burner.burn()` | nothing to move; any callee runs in its own context and holds no USDT allowance |
| `burn_eth()` | **permissionless** | calls `burners[0].burn_eth(value=balance)` | proxy ETH = 0; `burners[0]=0x0`; reverts |
| `withdraw_admin_fees(pool)` | **permissionless** | `Curve(pool).withdraw_admin_fees()` | reverts: pool asserts `msg.sender==owner` (impl L631-632) and pool owner = 0x0 |
| `apply_transfer_ownership(pool)` | **permissionless** | `Curve(pool).apply_transfer_ownership()` | reverts: pool asserts owner (impl L611-612); `transfer_ownership_deadline()=0` |
| `apply_new_parameters / apply_new_fee` | **permissionless** | apply pending params | `apply_new_parameters` reverts (owner-gated L575-578, deadline=0); `apply_new_fee` not implemented on this impl → revert |
| `commit_transfer_ownership / revert_transfer_ownership` | `ownership_admin` | pool commit/revert | reverts: pool owner=0x0 (L599-600) |
| `commit_new_parameters / commit_new_fee / ramp_A / stop_ramp_A / revert_new_parameters` | `parameter_admin` | pool param control | `commit_new_parameters`/`revert_new_parameters` revert (owner=0x0, L556/L592); `commit_new_fee`/`ramp_A`/`stop_ramp_A` not implemented on this impl → revert |
| `set_aave_referral`, `donate_admin_fees` | `ownership_admin` | pool call | not implemented on this impl → revert |
| `kill_me` / `unkill_me` | `emergency_admin` / `emergency+ownership` | pause pool | pool-side owner-gated (impl L648-657) → revert |
| `commit_set_admins / apply_set_admins` | `ownership_admin` | rotate admins | no token power (sim: apply = no-op SUCCESS) |

Simulations from block 26,173,849 (`raw_sim1.txt`): `burn_coin(USDT|DAI|USDC|0x..1)` from `0x1111…` → revert; `burn_eth()` → revert; `burn(0xcDED)` → revert; `withdraw_admin_fees(pool)` → revert; `apply_transfer_ownership(pool)` → revert; `set_burner(USDT,0x1111)` from attacker → `Access denied`.

### 1.3 Proof that the USDT can never be approved/burned (S)

- `cast call <proxy> "set_burner(address,address)" USDT 0x1111… --from 0x996E539a… --rpc-url … --trace`:
  - sub-call `USDT.approve(0x1111…, MAX)` → **succeeds** and emits `Approval`;
  - then the proxy frame **reverts** (Vyper returndata check; TetherToken `approve` returns 0 bytes).
- Control simulations **from the same admin EOA**: `set_burner(DAI, 0x1111…)` SUCCESS, `set_burner(USDC, 0x1111…)` SUCCESS, `set_burner(TUSD, 0x1111…)` SUCCESS, `set_burner(USDT, 0x0)` SUCCESS (skips `approve`) — the failure is exactly the USDT non-standard return.
- Historical corroboration: on 2023-04-06, with $30.4k USDT at stake, the DAO vote (#9) set burners for **only** DAI/USDC/TUSD (3× `AddBurner`), i.e. USDT was (and remains) un-settable.
- No alternative mover exists: the proxy has no `transfer`/`approve` other than `set_burner`; no delegatecall; no selfdestruct; not upgradeable. Even a future compromised/rotated admin or malicious burner cannot move USDT because the allowance can never be created and `burn_coin` reaches USDT only through `burners[USDT]`.
- **Classification: S (stuck), confidence ~99%.**

### 1.4 Conditional P exposure (future inflows only)

Residual MAX allowances DAI/USDC/TUSD → EOA `0xcDED` remain. Any future DAI/USDC/TUSD sent to the proxy is instantly claimable by the keyholder of `0xcDED` via `transferFrom`; any USDT sent becomes equally stuck. `0xcDED` is a dormant EOA (0.0000264 ETH, 0 SWRV, unexpired veSWRV lock — see §2).

### 1.5 Can the permissionless wrappers come live again? No.

`withdraw_admin_fees` / `apply_transfer_ownership` / `apply_new_*=*` on the pool are all gated by `msg.sender == self.owner` (impl lines 631/611/576); `owner()=0x0` and `commit_transfer_ownership` is itself owner-gated (L599-600), so **no owner can ever be set again** and deadlines stay 0. Additionally `admin_fee()=0` so no fees can accrue. `GaugeController.n_gauges()=1` → no other pool for the proxy to target.

## 2. Where the 2023 admin fees went (the rest of the $123.6k)

| When (UTC) | Block / tx | Movement |
|---|---|---|
| 2023-03-25 00:16 | 16,900,860 / `0x1415fbfb…660b` | EOA `0x0e61a8fb…` calls the **permissionless** `proxy.withdraw_admin_fees(pool)` → pool→proxy: DAI 35,672.939887582151128379 · USDC 39,517.916704 · USDT 30,408.429720 · TUSD 17,979.498822327536008890 |
| 2023-04-06 22:31 | 16,992,516 / `0xbd4c9a22…7900` | EOA `0xcDED` calls Aragon `Voting.executeVote(9)`; script = Agent `0xCcE356…` executes: `GC.commit_transfer_ownership(0xdEaD)`; `proxy.set_burner(DAI→0xcDED)`; `(USDC)`; `(TUSD)`; `GC.apply_transfer_ownership()` → 3× `AddBurner`, and GaugeController `admin`/`future_admin` = `0xdEaD` |
| 2023-04-06 22:37 | 16,992,546/54/60 / `0xaa1710b2…`, `0x5e7853ea…`, `0x1b1ed5a7…` | EOA `0xcDED` calls `transferFrom(proxy → 0xcDED)` on DAI, USDC, TUSD (input selector `0x23b872dd`) for the full amounts |
| 2023-04-06 → 04-10 | 16,993,623→681; 17,013,987→17,014,118 | DAI and USDC: `0xcDED` → EOA `0x2cf2320e8bce67e2941fb9358ecf9b9147ab88f6` → **Binance 14** `0x28c6c06298d514db089934071355e5743bf21d60` |
| 2023-05-08 00:33 | 17,212,247 → 17,212,315 | TUSD 17,979.498822327536008890: `0xcDED` → EOA `0x4f9598ac9c2cf9cfb406c8baee6b6146df0c8efc` → **OKX 7** `0x5041ed759dd4afc3a72b8192c143f72f4724081a` |

- The "burner" `0xcDED` is **not a contract** — it is an EOA that the DAO vote whitelisted as `burners[token]`; the proxy approved it MAX and the EOA swept the balances with three `transferFrom` calls. **Nothing was burned**; no SWRV was bought with the fees.
- Vote context (Aragon `Voting` `0xdff7beb0…`, impl "Voting" v0.4.24, `token()=veSWRV`): #5/#6 (2023) never executed — `executeVote(5)` reverts `VOTING_CAN_NOT_EXECUTE`, `canExecute(5)=false`; #7 (apply ownership) and #8 (commit ownership→`0x2E322C04`) executed; #9 as above; #10 (commit admins→`0x996E539a`) executed 25,937,232 (2026-09-09); #11 (apply) executed 25,987,912 (2026-09-16). The **only** vote with `canExecute=true` is #3 (2020, `changeMinAcceptQuorumPct` intent): its script targets the Voting app itself with `execute(address,uint256,bytes)` — a function Aragon Voting does not implement — so `executeVote(3)` reverts `EVMCALLS_CALL_REVERTED`. Every other unexecuted vote has `canExecute=false` (checked #0,1,2,4,5,6).
- Operator governance behaviour: `0xcDED` accumulated 348,801.5575 SWRV (21 inbound txs from EOA `0x6cc5f688…`, 2023-03-12..16) and locked it in veSWRV on 2023-03-17 (block 16,837,892; unlock 2027-03-11) — days before executing vote #9. In 2026-09, EOA `0x996E539a` bought ~140k SWRV (Aave/Universal-Router flow, 2026-09-01/02), locked it (block 25,886,795; unlock 2030-08-29), proposed and executed votes #10/#11, and now holds 140,000/237,081.34 ve (59.1%).

## 3. Reward stack: gauge / minter / controller / veSWRV — E-U = $0

| Surface | Reachable? | Effect |
|---|---|---|
| `gauge.deposit(v, addr≠msg.sender)` | needs `approved_to_deposit[msg.sender][addr]` (victim opt-in) | no theft path |
| `gauge.withdraw(v)` | own balance only | safe (Vyper underflow reverts) |
| `gauge.user_checkpoint(addr)` | self or minter | accounting only |
| `gauge.claimable_tokens(addr)` | **anyone, any addr** | `_checkpoint` + returns claim; **no mint, no redirect** |
| `gauge.kick(addr)` | anyone but asserts lock expired/newer voting event AND `working_balances > 40% floor` | only resets the target's boost to the floor |
| `minter.mint(gauge)` | anyone | mints **to msg.sender** only, from msg.sender's own checkpointed claim |
| `minter.mint_many/mint_for` | `mint_for` needs `allowed_to_mint_for[msg.sender][_for]`, set by `_for` itself | no theft (mint goes to `_for` anyway) |
| `minter.toggle_approve_mint` | anyone (grants others rights over *yourself*) | no gain |
| `GaugeController` | admin = `0xdEaD` (renounced 2023-04-06) | weights/gauges frozen; `n_gauges=1` |
| `veSWRV` | admin = Agent app (DAO); locks/deadline mechanics standard | locked SWRV withdrawable only by each lock owner |
| SWRV `update_mining_parameters` | anyone | advances inflation epochs; no value |

Quantification of the SWRV side: DefiLlama returns no price; CoinGecko: **$0.00149904** (mcap $27.8k). On-chain market = UniV2 pair `0xC139D8450177C0B8c3788608518687b585f7Ae5a`: 345,874.4589 SWRV vs **0.0627732567 WETH** → marginal 1.815e-7 ETH ≈ **$0.000462** at WETH $2,545.13; the **entire WETH side is $159.77**, which bounds realizable SWRV value. Gauge: `totalSupply=274,199.686`, `working_supply=233,646.778`, inflation 9.5390e16/sec (LATE_RATE ≈ 3.0M SWRV/yr ≈ $4.5k/yr at CG) — all payable pro-rata to depositors only. veSWRV holds 2,861,114.46 SWRV (locked; not stranded value for third parties). **No mint path sends anyone else's tokens, and nothing in the stack is unprivileged-extractable: E-U = $0.**

## 4. Ownership / control graph (item 4)

- Proxy lifetime: 6 external txs total (deploy 10,797,189; `commit_set_admins`/`apply_set_admins` 10,797,883/886; `apply_new_parameters(pool)` 11,179,557 (+1 revert); `withdraw_admin_fees(pool)` 16,900,860) and 7 events (CommitAdmins/ApplyAdmins ×2, AddBurner ×3). Its only outgoing module calls: pool parameter/ownership wrappers and the 4 coins' `approve`. **Proxy is owner/minter/admin of nothing today** (pool ownership renounced to 0x0; not SWRV/veSWRV/gauge/minter/LP admin).
- Aragon DAO apps hold **0 ETH and no token history at all** (Voting/Agent/Vault). `Agent.execute` / `Vault.execute` called directly revert `APP_AUTH_FAILED`; the only `canExecute=true` vote (#3, 2020) reverts on execution (`EVMCALLS_CALL_REVERTED` — malformed script self-targeting Voting), all other unexecuted votes are `canExecute=false`. `Voting.token()=veSWRV` → capture cost ≈ $109 (buy 140k SWRV ≈ 0.0427 WETH from the UniV2 pair) + a 4-year lock to exceed the incumbent 140k ve (59.1% of the 237,081.34 ve total; §3) — payoff ≈ $0 (only `SWRV.set_name/set_admin` + veSWRV ownership + calls with no assets).
- `swUSD` LP token `0x77c6e4a5`: `minter` = the Swerve pool (set at deploy block 10,793,314); no owner; minter privileges (mint/burnFrom/transferFrom) are only reachable inside pool AMM functions → no secondary exploit.
- Adjacent, out of Swerve scope: the pool's delegation target `0xA5407eAE` **is Curve's legacy sUSD pool itself** (owner `0xeCb456EA…`, coins DAI/USDC/USDT/sUSD; holds ~2.2k each of DAI/USDC/USDT, 0 sUSD). Its ~$870 balance-vs-ledger surplus is Curve-side admin-fee value, not Swerve custody.

## 5. Quantification and classification

Prices used (DefiLlama `coins.llama.fi/prices/current`, 2026-10-12): DAI 1.00030937 · USDC 0.99974884 · USDT 0.99919128 · TUSD 0.99879949 · WETH 2,545.12674.

| Bucket | Amount | USD |
|---|---|---|
| **S — stuck forever (proxy USDT)** | 30,408.429720 USDT | **$30,383.84** |
| P — admin/operator controlled today | — | $0.00 |
| E-U — anyone can take | — | $0.00 |
| (historical) non-USDT fees already taken 2023: DAI 35,672.94 + USDC 39,517.92 + TUSD 17,979.50 → Binance 14 / OKX 7 | $93,149.88 | P-hist, gone |
| Total 2023 pull | $123,533.72 | of which $30,383.84 remains, stuck |

De-minimis parent-scope footnote: the pool itself still carries an unclaimable balance-vs-ledger difference (~0.319 DAI, 1.474 USDC, 1.921 USDT, 1.787 TUSD ≈ **$5.50**) — owner=0x0 means it can never be withdrawn; excluded from the totals above.

## Appendix — evidence files (all under `swerve/analysis/`)

- `raw_verify1.txt` (+`verify1.sh`) — state reads, allowances, prices inputs
- `raw_sim1.txt` (+`sim1.sh`) — eth_call simulations incl. `set_burner` variants, trace in transcript
- `raw_sim2.txt` (+`sim2.sh`) — vote executability checks (`canExecute`, `executeVote(3)`), unimplemented wrapper sims, vote-3 script decode
- `uniswap_check.sh` — SWRV/WETH pair reserves
- `eb/proxy_txlist.json`, `eb/proxy_logs.json`, `eb/proxy_tokentx.json` — proxy history/events/transfers
- `eb/cded_tokentx.json` — full ERC20 history of `0xcDED` (2023 fee pulls, SWRV accumulation, veSWRV lock)
- `eb/pool_txlist_range.json` — pool txs for the 2023 window

**Secondary-custody E-U = $0.00; P = $0.00; S = $30,383.84 (confidence: S 99%, E-U 95%, P 99%).**
