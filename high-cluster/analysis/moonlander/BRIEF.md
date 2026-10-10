# BRIEF — Moonlander (Cronos + Cronos zkEVM) — $15.9M USDC

Read `analysis/CONVENTIONS.md` first. This is your per-protocol brief.

## Target

Moonlander = perp DEX + MLP liquidity pool + staking on Cronos EVM (25) and Cronos zkEVM (388).
Docs smart-contracts page verified.

| Chain | Contract | Address |
|---|---|---|
| Cronos | Moonlander (main diamond?) | `0xE6F6351fb66f3a35313fEEFF9116698665FBEeC9` |
| Cronos | MLP | `0xb4c70008528227e0545Db5BA4836d1466727DF13` |
| Cronos | FM (Full Moon) | `0x37888159581ac2CdeA5Fb9C3ed50265a19EDe8Dd` |
| Cronos | CM (Crescent Moon) | `0x5449239f7F6992D7d13fc4E02829aC90B2bEa6D1` |
| Cronos | StakedFmTracker / StakedFmDistributor | `0x7eC427359d3470128f2A6C3d4c141AF158ed3A04` / `0xB7Fe13C40D9E4cD4b549fD1766e4ef74ef06330d` |
| Cronos | FeeFmTracker / FeeFmDistributor | `0xbF438c48Eff2b47F4e77Ea72dbC6588aB4f849CC` / `0x6F27c8aCeD67424D3E7c7F42997489586b21F2f6` |
| Cronos | StakedMlpTracker / StakedMlpDistributor | `0x071788084370497ED1Ac19C6711bd1d4Af0E9034` / `0x8Dbebe40e6bE35cF1bE07b22Aa5fa11f4768917E` |
| Cronos zkEVM | Moonlander | `0x02ae2e56bfDF1ee4667405eE7e959CD3fE717A05` |
| Cronos zkEVM | MLP | `0xe8E4A973Bb36E1714c805F88e2eb3A89f195D04f` |

Live reads (Cronos block 99,056,996): the main contract `0xE6F6…eC9` holds **15,935,653.166386 USDC**
(`0xc21223249CA28397B4B6541dfFaEcC539BfF0c59`, 6 dec) ≈ **$15.94M**. MLP held 0 USDC at that block — check
all tokens for MLP and the zkEVM side, and re-read at your own block. FM/CM token prices from DefiLlama.

Finding context: "EIP-2535 diamond, 23 facets, no keyless source". So: enumerate the diamond via loupe
functions (`facets()`, `facetAddresses()`, `facetFunctionSelectors(address)`, `facetAddress(bytes4)`),
check `diamondCut` access control, and audit each facet's function set for unprotected value paths.
Cronos explorer source availability is poor — try `https://api.cronoscan.com/api?module=contract&action=getsourcecode&address=...`
(no key) and `https://explorer.cronos.org`, plus `eth_getCode`/bytecode inspection.

## Required audit surfaces

1. **Diamond admin**: `diamondCut` caller, owner, any unprotected `initialize`/`init` on facets (diamonds
   often leave facet initializers callable!). Test every facet's init/ownership function from a fresh EOA.
2. **MLP share math**: deposit/withdraw (mint/burn) pricing, `addLiquidity`/`removeLiquidity`, fees,
   cooldowns, lock periods; donation/inflation; who can pause; the 15.9M USDC in the diamond is the prize.
3. **Trading core**: open/close position, liquidations (permissionless? bonus?), funding, price feeds
   (Pyth + "Cronos Oracles" per docs) — check oracle freshness/mispricing and whether a position can be
   opened against a stale price to extract from the pool.
4. **Staking/trackers/distributors**: reward accounting, claim functions, who can deposit/withdraw;
   any unprivileged path that pays out more than entitled.
5. **zkEVM side**: same checks scaled down; verify funds actually present.
6. **Upgrade/withdraw authority**: owner roles, multisig?, emergency functions.

## Deliverable

- `analysis/moonlander/REPORT.md` + evidence (facet list dump, per-facet function selectors, state dumps).
- PoC in `poc-moonlander/test/`: fork Cronos (`CRONOS_RPC_URL` exists in CI, fallback
  `https://evm.cronos.org`). Test: facet initializer calls from fresh EOA, diamondCut, MLP mint/withdraw
  math, unauthorized withdrawals, stale-price trades. Negative results with revert evidence.
- CI: `bash /home/heisenberg/CA/ci/ci-run.sh high-cluster`; your log `ci-out/poc-moonlander.log`.
- Exact blocks; E-U/H-O/P/S amounts + USD; confidence; coverage statement (fully audited vs screened).
