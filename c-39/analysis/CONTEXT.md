# C-39 shared context (PulseChain / chainid 369)

Latest block at recon start: 27,701,912 (2026-10-03). Re-verify at your own latest block and record it.

## Rules (from SUBAGENT-BRIEF.md — binding)
- READ-ONLY on real chains. Never sign/send any tx. No `cast send`, no private keys. Fork-only PoCs.
- Write ONLY inside /home/heisenberg/CA/c-39/ (children: only your assigned subfolder).
- Do NOT run `bash /home/heisenberg/CA/ci/ci-run.sh` — the parent owns CI runs. Do not edit README.md/summary.json.
- Do not commit secrets. Keep local CPU light (RPC reads and small python batch scripts only).
- Cite address + latest block for every claim. Honest $0 results are fine; never inflate.

## Endpoints
- RPC: https://pulsechain-rpc.publicnode.com (fallback https://rpc.pulsechain.com)
- Blockscout API: https://api.scan.pulsechain.com/api/v2/...  (e.g. /smart-contracts/{addr}, /search?q=NAME, /addresses/{addr}/token-balances)
- GeckoTerminal: https://api.geckoterminal.com/api/v2/networks/pulsechain/dexes ; /dexes/{dex}/pools?page=N (pools include address, name, reserve_in_usd, volume_usd)
- Subgraphs: https://graph.pulsechain.com/subgraphs/name/pulsechain/{pulsex|pulsexv2|stableswap|<others>} (POST graphql)
- DefiLlama prices: https://coins.llama.fi/prices/current/pulsechain:{token}
- Multicall3 (check code first): 0xcA11bde05977b3631167028862bE2a173976CA11
- cast: `cast call <to> "sig()(type)" --rpc-url <rpc>`; `cast storage`; `cast code`.

## Verified PulseX stack addresses
- V1 factory: 0x1715a3E4A142d8b698131108995174F37aEBA10D (65,403 pairs; feeTo 0xD46BD969d995A122AD5B803A45d309021A647B87)
- V2 factory: 0x29eA7545DEf87022BAdc76323F373EA1e707C523 (189,582 pairs; feeTo 0xd6cA7ee047a6F45d20d2962E4394E070cF27724F)
- feeToSetter (both): 0x3a27c0a67D6bbc3DC024Af200bb309cB1FE1F091 — code size 0 ⇒ EOA
- V1 routers: 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02 and 0xaf5e33cb31A3454C950bee39ed1C76fd65b394cf (both factory()=V1 factory)
- V2 router: 0x165C3410fC91EF562C50559f7d2289fEbed552d9
- feeTo impl (both proxies): 0x5f02fbb0f8d924e9b67c7daae523ff51175699f9 = PLSXBuyAndBurnUpgradeable (UUPS, owner-gated; convertLps requires anyAuth||isAuth, pays 0.1% bounty)
- StableSwap 3pool: 0xe3acfa6c40d53c3faf2aa62d0a715c737071511c (USDT 0x0cb6f5a34ad42ec934882a05265a7d5f59b51a2f / USDC 0x15d38573d2feeb82e7ad5187ab8c1d52810b1f07 / DAI 0xefd766ccb38eaf1dfd701853bfce31359239f305), ~$0.94M
- PulseX pair fee = 0.29% (29/10000); pairs have NO migrator(); mint/burn take extra senderOrigin arg; V1 _mintFee denominator bug (rootK.mul(4998/10000)=0) mints feeTo LP = totalSupply*(rootK-rootKLast)/rootKLast.
- Source dumps: /home/heisenberg/CA/c-39/analysis/src_*.sol

## Other PulseChain venues in scope (dormant candidates)
Phux, 9inch, 9mm (V2/V3), SparkSwap, EazySwap, Velocimeter, WizardSwap, Dextop, PulseGun, Function Island, Liberty Swap, pDex.vision, Finvesta.
GeckoTerminal dex ids: phux, 9inch, 9mm-v2, 9mm-v3, sparkswap, eazyswap, velocimeter-pulsechain, wizardswap-pulsechain, dextop, pulsegun, function-island, liberty-swap, finvesta, pdex-vision, pulse-rate.

## What counts as extractable (E-U)
A permissionless call by any EOA/contract (no keys/whitelist) that moves value to the caller or a caller-chosen address, net of gas and capital costs. Holder-only withdrawals = H-O. Owner-only = P. Nobody = S.
