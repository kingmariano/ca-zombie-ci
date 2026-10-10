# H2-02 high-cluster — shared conventions for all child agents

**Finding:** H2-02 — large live-TVL protocols with no extraction path found yet.
**Parent deliverable:** `/home/heisenberg/CA/high-cluster/README.md` + `summary.json`.
**CI repo:** public. Everything you write inside `/home/heisenberg/CA/high-cluster/` may become public
(it is rsynced to branch `high-cluster` of `github.com/kingmariano/ca-zombie-ci`).
**NEVER write secrets, keyed RPC URLs, private keys or API keys into any file here.** Use keyless
public endpoints only in saved files. If a secret slips into a file, redact it and tell the parent immediately.

## Mission (same as parent)

Determine rigorously how much an **external, unprivileged attacker** can extract, live on-chain, right now.
"External unprivileged" = no admin/owner/operator/governance keys, no protocol privileges, no whitelist,
no insider access. Only public contracts, public mempool, public liquidity, own capital / flash loans.

Every number must be split into:
- **E-U**: extractable by external unprivileged attacker (headline)
- **H-O**: holder/user-only recoverable (self-service withdrawals)
- **P**: privileged/governance/key-holder only
- **S**: stuck/bricked (nobody can move it)

An honest "$0, here is the proof" is a successful outcome. Never inflate.

## Hard rules

1. **Read-only on real networks.** Never sign/send a tx to any real chain. No `cast send` to mainnet.
   All PoC execution happens on **forks only, inside GitHub Actions** (see CI below).
2. No secrets in files (see above).
3. **Write only inside `/home/heisenberg/CA/high-cluster/`** — your `analysis/<name>/` and `poc-<name>/` dirs.
   Never modify another child's dirs, `README.md`, `summary.json`, or files outside the folder.
4. **Do not spawn further subagents.**
5. Keep the local machine light: RPC reads, `cast call`, small scripts, web fetches are fine.
   **All forge compile/test work runs in CI** (`bash /home/heisenberg/CA/ci/ci-run.sh high-cluster`).
6. Verify every address/role/balance on-chain at an explicit latest block; record block numbers.
   The H2-02 finding text is a lead source, not ground truth. Re-verify everything.
7. No destructive/disruptive actions against live systems. Measurement only.

## Folder layout

```
high-cluster/
├── analysis/<name>/REPORT.md    <- YOUR dossier (the main written deliverable)
├── analysis/<name>/*.json|*.md  <- raw state dumps, call logs, evidence
├── poc-<name>/                  <- YOUR foundry project (foundry.toml + lib/forge-std pre-created)
│   ├── src/                     <- interfaces/harness contracts
│   └── test/*.t.sol             <- fork tests
├── ci-out/<name>.log            <- CI test output (written by CI, do not edit)
└── ci/run.sh                    <- runs ALL poc-*/ projects; per-project logs; never fails
```

CI: `bash /home/heisenberg/CA/ci/ci-run.sh high-cluster` from anywhere. It rsyncs the whole folder to the
public repo, dispatches the workflow, waits, and writes `ci-log.txt` + `ci-artifacts/`. Runs are serialized
by a lock, so concurrent children are safe but each run may wait for the previous one. Your results appear in
`ci-out/<name>.log` (also uploaded as artifact). Put a `SKIP` file inside `poc-<name>/` to temporarily skip
your project. Do not run more than needed; batch tests.

Foundry notes:
- `lib/forge-std` is already vendored in every `poc-*/`. Do not `forge install`.
- In tests: `vm.createSelectFork(vm.envOr("HYPEREVM_RPC_URL", string("https://rpc.hyperliquid.xyz/evm")))`.
  The env vars `CRONOS_RPC_URL`, `BSC_RPC_URL` etc. exist in CI; for the chains below use the public
  fallbacks given here (keyless).
- Solc 0.8.24, evm_version cancun are preset. Keep each project's suite < 20 min.
- Prefer reading live state inside the test (`IERC20(token).balanceOf(...)`) over hardcoding amounts.

## Chains, public RPCs, explorers (all keyless)

| Chain | id | Public RPC | Explorer API |
|---|---|---|---|
| HyperEVM | 999 | `https://rpc.hyperliquid.xyz/evm` | Etherscan V2 `chainid=999` (verified sources); web `https://hyperevmscan.io` |
| Ink | 57073 | `https://rpc-gel.inkonchain.com` | Blockscout `https://explorer.inkonchain.com/api/v2` |
| Cronos | 25 | `https://evm.cronos.org` | `https://cronoscan.com` (Etherscan-clone; API V1 may need key — use web/RPC), Blockscout-style `https://explorer.cronos.org` |
| Cronos zkEVM | 388 | `https://mainnet.zkevm.cronos.org` | `https://explorer.zkevm.cronos.org` |
| Flare | 14 | `https://flare-api.flare.network/ext/C/rpc` | Blockscout `https://flare-explorer.flare.network/api/v2` |
| Plume | 98866 | `https://rpc.plume.org` | Blockscout `https://explorer.plume.org/api/v2` |
| Citrea | 4114 | `https://rpc.mainnet.citrea.xyz` | `https://explorer.mainnet.citrea.xyz` |
| XDC | 50 | `https://rpc.xinfin.network` | Etherscan V2 `chainid=50`; web `https://xdcscan.com` |
| MegaETH | 6343 | `https://carrot.megaeth.com/rpc` | Blockscout `https://megaeth.blockscout.com/api/v2` |
| Abstract | 2741 | `https://api.mainnet.abs.xyz` | Etherscan V2 `chainid=2741`; web `https://abscan.org` |
| Flow EVM | 747 | `https://mainnet.evm.nodes.onflow.org` | Blockscout `https://evm.flowscan.io/api/v2` |
| BSC | 56 | `https://bsc-rpc.publicnode.com` | Etherscan V2 `chainid=56` |
| Ethereum | 1 | `https://ethereum-rpc.publicnode.com` | Etherscan V2 `chainid=1` |

**Etherscan V2** base: `https://api.etherscan.io/v2/api?chainid=<id>&...`. The API key lives in
`/home/heisenberg/CA/.env` (`ETHERSCANV2_API_KEY`, value has surrounding quotes — strip them) and in CI as
`$ETHERSCANV2_API_KEY`. Use it for reads only; **never copy it into any file in this folder**.

Useful Etherscan V2 modules: `contract/getsourcecode` (source+ABI), `contract/getabi`,
`account/balance`, `account/tokentx`, `logs/getLogs`, `token/tokenholderlist`.
Blockscout v2 endpoints: `/api/v2/addresses/{a}`, `/api/v2/addresses/{a}/token-balances`,
`/api/v2/addresses/{a}/transactions`, `/api/v2/tokens/{t}/holders`, `/api/v2/search?q=`,
`/api/v2/smart-contracts/{a}`.

Prices: DefiLlama `https://coins.llama.fi/prices/current/<chain>:<token>,...` (chain keys: `hyperevm`,
`ink`, `cronos`, `flare`, `plume`, `ethereum`, `bsc`, `xdai`... verify by response; fall back to
`https://api.llama.fi/protocol/<slug>` TVL and web prices).

## Dossier requirements (analysis/<name>/REPORT.md)

1. Target + chain(s) + status line ("read-only; PoC fork-verified only; no mainnet transactions").
2. Live-state table: every relevant address, code check (`eth_getCode` non-empty), roles
   (`owner()/admin()/guardian()` etc.), balances (exact amounts), block number(s).
3. Mechanism: exact terms with deployed-code references (verified source if available, else bytecode-level
   analysis; say which).
4. Attacker model: exact call paths, preconditions, gating checks with live values, costs (gas, flash fees).
5. PoC: fork tests in `poc-<name>/test/`, pass/fail counts, key numbers, CI run URL(s). If no exploitable
   path, prove the revert/closure for each candidate path (negative results are deliverables).
6. Verdict: E-U / H-O / P / S with exact token amounts + USD (state price source/time), confidence
   (high/medium/low) + what would change the verdict. **State coverage: fully audited / screened /
   unreachable**, and list what was NOT checked.
7. Files index + methodology + caveats.

Also save raw evidence (JSON dumps, call transcripts) under `analysis/<name>/`.

## Confidence bar

- **high**: path executed end-to-end on a fork of the live chain state, or every gate proven closed with
  exact live reads; amounts from live balances.
- **medium**: static analysis of verified source + live state, one unproven assumption (e.g. oracle
  behavior, off-chain component).
- **low**: unverified bytecode, assumptions on off-chain infra, or incomplete enumeration. Say so.
