# Public PoCs, reproductions and analyses — Balancer V2 hack (2025-11-03)

## Downloaded into this directory

| file | source (verified HTTP 200 on 2026-10-04) | notes |
|---|---|---|
| `poc-raw-defihacklabs-BalancerV2_exp.sol` (19 KB) | https://raw.githubusercontent.com/SunWeb3Sec/DeFiHackLabs/main/src/test/2025-11/BalancerV2_exp.sol | **The canonical Foundry PoC.** Forks `mainnet` at `23717397 - 1`, deploys `AttackerC`, then `attC.attack(osETH_wETH, 67000, 30)` + `withdraw` and `attC.attack(wstETH_wETH, 100000000000, 25)` + `withdraw`. Ships `Helper.swapGivenOut` (vulnerable math with the `mulDown` annotated "precision loss here"), `get_trickAmt`, `get_index`, `concat_steps`. |
| `poc-raw-starkxun-CompleteExploit.sol` (10 KB) | https://raw.githubusercontent.com/starkxun/defi-poc-lab/main/src/Balancer/CompleteExploit.sol | Alternative complete reproduction using an **Aave V3 flash loan** (Chinese comments). |

Total raw PoC text: ~29 KB (other PoCs below are linked, not copied).

## More public repos / paths

- DeFiHackLabs README entry: https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/past/2025/README.md
  (`forge test --contracts ./src/test/2025-11/BalancerV2_exp.sol --via-ir -vvv`).
- `sanbir/evm-hack-registry` — most complete packaging found: PoC + write-up + **reconstructed verified sources**:
  - https://github.com/sanbir/evm-hack-registry/tree/main/2025-11-BalancerV2_exp
  - PoC: https://raw.githubusercontent.com/sanbir/evm-hack-registry/main/2025-11-BalancerV2_exp/test/BalancerV2_exp.sol
  - registry entry: https://raw.githubusercontent.com/sanbir/evm-hack-registry/main/2025-11-BalancerV2_exp/BalancerV2_exp.md
  - `sources/ComposableStablePool_93d199/`, `sources/ComposableStablePool_DACf5F/`, `sources/Vault_BA1222/`, `balancer-math/`, `anvil_state.json`, `output.txt` (fork run output).
- `Alacriity1/Defi-Hack-PoCs` — two attacker contracts plus annotated iterations:
  - https://raw.githubusercontent.com/Alacriity1/Defi-Hack-PoCs/main/src/Balancer/BalancerAttack.sol
  - https://raw.githubusercontent.com/Alacriity1/Defi-Hack-PoCs/main/src/Balancer/BalancerAttackerTwo.sol
  - `.../testing_with_comments_1st_iteration/BalancerAttack.sol`, `.../testing_with_comments_2nd_iteration/BalancerAttack.sol` + `BalancerAttackerTwo.sol` (same repo).
- `michaelshapkin/cel` (vendored "Exploit Laboratory"): `Exploit Laboratory/data/pocs/2025-11/BalancerV2_exp.sol`.
- `adamnmcc/sc-exp-llm`: `raw_web3_data/sol/2025-11/BalancerV2_exp.sol`.
- `kismp123/DeFi-Security-Incident`: `2025/2025-11-03_BalancerV2_PrecisionLoss_ARB.md` (Arbitrum side).
- `calc1f4r/Horus`: `DB/general/precision/precision-loss-rounding-vulnerabilities.md`.
- `novaondesk/aegis`: `docs/exploits/balancer-v2-rounding-2025-11-03.md`; `Auditware/AuditVault`: `hacks/rekt-2025-11-03-balancer.md`.
- `sekuba/ossification-dataset`: structured incident record `incidents/1/0x6ed07db1…json`.

## Analysis articles (primary)

- **Certora — "Breaking Down the Balancer Hack"**: https://www.certora.com/blog/breaking-down-the-balancer-hack
  (root cause, exact `_swapGivenOut`/`_upscale` quotes, BPT deficit, v3 unaffected, roundtrip/share-value properties that would have caught it).
- **BlockSec — "In-Depth Analysis: The Balancer V2 Exploit"**: https://blocksec.com/blog/in-depth-analysis-the-balancer-v2-exploit
  (three-swap iteration per loop, `trickAmt`, auxiliary solver derived from StableMath, "BAL#004" retries; confirms Balancer's preliminary report).
- **Check Point Research — "How an Attacker Drained $128M from Balancer…"**: https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/
  (attack ran in the **constructor**; +4,623 WETH/+6,851 osETH and +1,963 WETH/+4,259 wstETH internal balances; `0x8a4f75d6` withdrawal pseudo-code).
- **OpenZeppelin — "Understanding the Balancer v2 Exploit"**: https://www.openzeppelin.com/news/understanding-the-balancer-v2-exploit
  (history of the `_scalingFactors` override: MetaStable 2021-07-16 commit `059284e`, Linear 2021-09-01 commit `4e9e70a`, StablePhantom/CSP 2021-09-20 commit `f450760`; `17.98 -> 17` truncation).
- **CertiK — "Balancer Incident Analysis"**: https://www.certik.com/blog/balancer-incident-analysis
  (pool-2 worked example with exact BPT/wstETH/WETH amounts; `manageUserBalance()` withdrawal).
- **Unvariant — "Balancer Hack Explained"**: https://blog.unvariant.io/balancer-hack-explained/
  (isolates the `amountOut = 17` swap; simulation with/without `_upscaleUp` fix; Curve vs Balancer solver comparison).
- **Balancer — "Nov 3 Exploit Post-Mortem"**: https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020
  (official; three preconditions; only CSPs with BPT + rate providers vulnerable; MetaStable whitehat action).
- **Trail of Bits**: https://blog.trailofbits.com/2025/11/07/balancer-hack-analysis-and-guidance-for-the-defi-ecosystem/
  (audit-coverage angle; precision/rounding invariant guidance).
- **rektooor**: `Auditware/AuditVault` copy of the rekt post; original rekt article also on rekt.news.

## On-chain / explorer

- Exploit tx (Etherscan): https://etherscan.io/tx/0x6ed07db1a9fe5c0794d44cd36081d6a6df103fab868cdd75d581e3bd23bc9742
- Exploit tx (BlockSec Phalcon decoded trace): https://app.blocksec.com/explorer/tx/eth/0x6ed07db1a9fe5c0794d44cd36081d6a6df103fab868cdd75d581e3bd23bc9742
- Withdrawal tx: https://etherscan.io/tx/0xd155207261712c35fa3d472ed1e51bfcd816e616dd4f517fa5959836f5b48569
- Attacker EOA: https://etherscan.io/address/0x506d1f9efe24f0d47853adca907eb8d89ae03207
- Attacker contract: https://etherscan.io/address/0x54B53503c0e2173Df29f8da735fBd45Ee8aBa30d
- Solver helper: https://etherscan.io/address/0x679b362b9f38be63fbd4a499413141a997eb381e
- Beneficiary: https://etherscan.io/address/0xAa760D53541d8390074c61DEFeaba314675b8e3f
- Blockscout raw trace (used here): https://eth.blockscout.com/api/v2/transactions/0x6ed07db1a9fe5c0794d44cd36081d6a6df103fab868cdd75d581e3bd23bc9742/raw-trace
- Social: BlockSec https://x.com/BlockSecTeam/status/1986057732810518640 ; SlowMist https://x.com/SlowMist_Team/status/1986379316935205299 ; hklst4r https://x.com/hklst4r/status/1985872151077953827

## On-chain artifacts already collected locally

- `tx-deploy-raw.json`, `receipt-deploy-raw.json` (361 logs), `tx-withdraw-raw.json`, `receipt-withdraw-raw.json`
- `blockscout-rawtrace.json` (485-entry call tree), `trace-tree.tsv`
- `bs1.hex` / `bs2.hex` (raw batchSwap calldata), `bs1-decoded.txt` / `bs2-decoded.txt`
- `steps-correlated.csv` (all 226 steps matched 1:1 with the 226 `Swap` events)
- `onswap-critical.hex`, `onswap-pool1-first.hex` (pool-level onSwap calldata)
- `deployed-csp-src/` (verified deployed v5 source bundle) and `other-pools/` (MetaStable/Linear/BaseGeneralPool/ScalingHelpers)
