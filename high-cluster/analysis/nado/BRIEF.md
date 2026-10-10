# BRIEF — Nado Spot (Ink) — ~$53M CLOB

Read `analysis/CONVENTIONS.md` first. This is your per-protocol brief.

## Target

Nado = CLOB DEX (spot + perps + money market) on Ink (chain 57073), "off-chain sequencer + on-chain
settlement". Docs: https://docs.nado.xyz (contracts page verified). **Source available**:
https://github.com/nadohq/nado-contracts — clone/read it (use the deployed addresses below; verify
deployed bytecode matches the repo or at least review repo logic + check deployed selectors).

Mainnet contracts (Ink):
| Contract | Address |
|---|---|
| Quote (USDT0, 6 dec) | `0x0200C29006150606B650577BBE7B6248F58470c1` |
| Querier | `0x68798229F88251b31D534733D6C4098318c9dff8` |
| Clearinghouse | `0xD218103918C19D0A10cf35300E4CfAfbD444c5fE` |
| Endpoint | `0x05ec92D78ED421f3D3Ada77FFdE167106565974E` |
| OffchainExchange | `0x8373C3Aa04153aBc0cfD28901c3c971a946994ab` |
| SpotEngine | `0xFcD94770B95fd9Cc67143132BB172EB17A0907fE` |
| PerpEngine | `0xF8599D58d1137fC56EcDd9C16ee139C8BDf96da1` |
| Verifier | `0x9aCdC66459A323Fbb6eB77C5AA96a30234feCf17` |
| WithdrawPool | `0x09fb495AA7859635f755E827d64c4C9A2e5b9651` |
| Deployer EOA | `0xC1cC56caB60e832665E6c3780BfEBe3C1C971603` |

Live balances already confirmed (Blockscout, ~block 39,000,000s — re-read at your own block):
- Clearinghouse holds: 34,295,707.29 USD₮0; 112.77 kBTC (`0x73E0C0d45E048D25Fc26Fa3159b0aA04BfA4Db98`, 8 dec);
  1,900.68 WETH (`0x4200000000000000000000000000000000000006`); 2,373,714.93 USDC
  (`0x2D270e6886d130D724215A266106e6832161EAEd`); 116.41 XAUT0; and xStocks (wNVDAx/wSPYx/wGOOGLx/wQQQx/
  wAAPLx/wTSLAx/wMETAx/wMSFTx — verify addresses). Total ≈ $53M at current prices.
- WithdrawPool holds only ~54,047 USD₮0 — the interesting question is who can drain the Clearinghouse.

## Required audit surfaces

1. **Endpoint / EIP-712 signature validation** — the core surface. Read the repo:
   - EIP-712 domain, typehashes for each execute (place order, cancel, withdraw collateral, transfer quote,
     liquidate, mint/burn NLP, link signer). Check nonce handling (per-subaccount? per-signer?).
   - **Fast-withdraw**: `WithdrawPool` pays out against a `Verifier` signature. Verify: what is signed
     (amount, subaccount, nonce, recipient?), replay protection, signature malleability, aggregated-pubkey
     paths, who can call, whether an attacker can submit someone else's valid signature to a different
     recipient (recipient binding), expiry/deadline handling, chainid/domain replay across chains.
   - Check whether execute types can be replayed across subaccounts, or a signature for one action
     reinterpreted as another (type confusion / digest collision).
2. **On-chain permissionless entrypoints**: `Clearinghouse.deposit/withdraw`, `Endpoint` tx submission
   (if `submitTransactions` is callable by anyone with signed txs — is signature verified on-chain?),
   engine direct calls (are SpotEngine/PerpEngine mutators gated to Clearinghouse?), oracle update txs
   (permissionless price push? who is allowed?).
3. **Nonce / replay / ordering**: on-chain nonce increments; can a signed tx be replayed twice; can a
   cancelled order still fill; `filledAmounts` over-fill protection in OffchainExchange.
4. **Off-chain sequencer trust**: what an attacker can do with only on-chain calls (no sequencer access).
   Anything that lets an unprivileged party force settlements, liquidations, or withdrawals is in scope.
5. **Money market / socialized loss**: interest accrual, liquidations, insurance fund location.
6. **Deployed-vs-repo check**: confirm the deployed contracts' code hash matches the repo build if feasible
   (at least selector-level checks); note any divergence.

## Deliverable

- `analysis/nado/REPORT.md` (CONVENTIONS.md §Dossier) + raw evidence JSONs.
- PoC in `poc-nado/test/`: fork of Ink; test the fast-withdraw validation, nonce replay, unauthorized
  withdraw/engine mutation, EIP-712 domain checks. Prove closed gates with live values, or extract on fork.
- Note the finding's "active bounty" context; the deliverable is an honest extraction estimate.
- CI: `bash /home/heisenberg/CA/ci/ci-run.sh high-cluster`; your log `ci-out/poc-nado.log`.
- Exact block numbers; confidence; coverage (fully audited vs screened). Do not send mainnet txs.
