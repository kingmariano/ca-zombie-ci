# CHILD BRIEF — C2-55 non-EVM custody cluster (zombie-hunt II)

You are a child subagent of the C2-55 deep-dive (`non-evm-cluster`). Your parent owns
`/home/heisenberg/CA/non-evm-cluster/`. **You must first read `/home/heisenberg/CA/ci/SUBAGENT-BRIEF.md` in full and
follow it exactly** (hard rules: read-only on real networks; no signing/sending; no secrets in files;
write only inside your assigned subfolder below; no `git add/commit/push` in `/home/heisenberg/CA`;
children of children are FORBIDDEN — you are one level deep, do not spawn subagents).

## Your mission (same as parent's, scoped to your chain)

Determine **rigorously how much an external, unprivileged attacker can extract, live, right now** from the
abandoned/legacy custody in your assigned protocols. "External unprivileged" = no admin/owner/operator keys,
no whitelist, only public contracts, public mempools and the attacker's own capital (incl. flash loans).
An honest "$0, here is the proof" is a successful outcome. Never inflate.

Classify every target: **E-U** (extractable by external unprivileged), **H-O** (holder/user-only recoverable),
**P** (privileged/governance-only), **S** (stuck/bricked). Give exact token amounts + USD (state price source
and time), confidence (high/medium/low), and the gate that closes/opens each path.

## Deliverables (write ONLY here)

```
/home/heisenberg/CA/non-evm-cluster/analysis/<chain>/<protocol>/
├── REPORT.md        # findings: addresses, live balances (+block/slot/lt refs), audit, paths, classification
├── *.json/*.csv     # raw state dumps (NO secrets, NO keyed URLs — use keyless endpoints only)
└── scripts/*.py|sh  # small read-only scripts used (keyless)
```

Report format per protocol: target → live funds (token, amount, USD, ref) → mechanism/audit notes →
candidate unprivileged paths tried + result (exact revert/gate) → classification E-U/H-O/P/S → confidence →
blockers. Keep it exact; cite addresses/block heights/lt.

**Do NOT run `bash /home/heisenberg/CA/ci/ci-run.sh`** (parent runs CI centrally). If you need a heavy job
(bulk enumeration, big scan), write the script to your `scripts/` dir and note it in your REPORT as "CI candidate".

## Chain access (keyless, use these; if one is flaky retry/backoff)

- **Cardano**: Koios `https://api.koios.rest/api/v1/...` (POST endpoints; rate-limited — space calls ~1/s,
  retry on 000). Minswap market API `https://api-mainnet-prod.minswap.org` (POST /v1/pools/metrics). Explorer
  fallback: cardanoscan.io / cexplorer.io HTML via firecrawl. Price: `https://coins.llama.fi/prices/current/coingecko:cardano`.
- **TON**: toncenter `https://toncenter.com/api/v2/...` (runMethod, getAddressInformation, getTransactions);
  tonapi `https://tonapi.io/v2/...` (accounts, jettons, events, run method GET /v2/accounts/{a}/methods/{m});
  DeDust API `https://api.dedust.io/v2/pools`. Price: `coingecko:the-open-network`.
- **Algorand**: algod `https://mainnet-api.algonode.cloud/v2/...` (accounts, applications, dryrun);
  indexer `https://mainnet-idx.algonode.cloud/v2/...`. Price: `coingecko:algorand`.
- **NEAR**: RPC `https://rpc.mainnet.near.org` (jsonrpc `query` view_account/call_function/view_state,
  `EXPERIMENTAL_tx_status`, `tx`); explorer API `https://api.nearblocks.io/v1/...`. Price: `coingecko:near`.
- **MultiversX**: `https://api.multiversx.com/...` (accounts, tokens, vm-values/query, transactions).
  Price: `coingecko:elrond-erd-2`.

NEVER write keyed RPC URLs (with api key in URL) into any file. Keyless public endpoints only.

## Method requirements

1. Enumerate targets by events/factories/documented addresses, not blog lists. State selection criteria + counts.
2. Verify live reality: contract/account exists, current balance, admin/authority state, paused/closed flags.
3. Measure live value exactly (raw amounts + USD at stated price/time + block/slot/lt).
4. Prove or close each candidate path: trace the call/message/dry-run. If a path is closed, name the exact gate
   (code check, op-code auth, missing method, version gate) and where it lives (source line or on-chain code).
5. Separate E-U / H-O / P / S in every number.
6. Note negative results (dead ends) with evidence.
7. Prefer chain-native simulation where available (Algorand dryrun, TON run-method/emulator, NEAR view calls,
   Cardano script evaluation via koios? if not possible, static + UTxO reasoning).

## Scoped assignments

- **child-cardano-2**: Djed (Cardano stablecoin; find live contracts, balances, audit) + Minswap V2 / stableswap
  legacy checks + independent re-verification of parent's Minswap V1 balance numbers.
- **child-ton**: DeDust (v2 native vault `EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_` ~1.83M TON;
  jetton vaults; volatile/stable pools; legacy v1 contracts) + UTONIC (TON liquid staking; locate contracts).
- **child-algorand**: Folks Finance (all legacy Algorand app versions; v1 lending pools, xALGO) + Pact (AMM app IDs).
- **child-near**: Ref Finance/Rhea legacy (boost farms, v1 farms) + Veax + Spin + Tonic contracts.
- **child-multiversx**: MultiversX remnants (legacy xExchange/Maiar farm/legacy delegation contracts with funds).

## Evidence bar

Every headline number must have: contract/account id + method/state read + raw value + block/slot/lt + timestamp.
Confidence honest. If you cannot reach something, say so with the exact failure.
