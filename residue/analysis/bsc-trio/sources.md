# Sources used (bsc-trio / H2-03)

All URLs below are public and keyless, or API endpoints accessed at runtime with keys
read from `/home/heisenberg/CA/.env` (no keys are written into any file in this folder).

## Explorers / APIs

- Etherscan V2 API (BSC, chainid=56) — contract source/ABI for:
  - SKYDAO token `0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c` (verified, `SKYDAO`)
  - Controller `0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c` (unverified)
  - Config `0x85870c50677c142f5e37930915d8984cce7623e1` (unverified)
  - Pair `0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8` (verified, `PancakePair`)
  - FIST `0xc9882def23bc42d53895b8361d0b1edc7570bc6a` (verified, `FistStandard`)
  - MSN `0xd8b3ef86afce18edba91fed481abe22f173597c1` (verified, `MSNToken`)
  - Delegate `0x63c0c19a282a1b52b07dd5a65b58948a07dae32b` (verified, `EIP7702StatelessDeleGator`)
  - Sibling MSN `0xaf51951df5782fa6eb529c173b10a973e4871f92` (verified, `MSN`)
  - URL pattern: `https://api.etherscan.io/v2/api?chainid=56&module=contract&action=getsourcecode&address=<addr>&apikey=$ETHERSCANV2_API_KEY`
- Covalent GoldRush API (BSC) — token transfer histories and archive balances:
  - `https://api.covalenthq.com/v1/bsc-mainnet/address/<addr>/transfers_v2/?contract-address=0x55d398326f99059fF775485246999027B3197955&key=$GOLD_RUSH_API_KEY`
  - `https://api.covalenthq.com/v1/bsc-mainnet/address/0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c/balances_v2/?block-height=124932859&key=$GOLD_RUSH_API_KEY`
- DefiLlama price API:
  - `https://coins.llama.fi/prices/current/bsc:0x55d398326f99059fF775485246999027B3197955`

## RPCs (keyless unless noted)

- `https://bsc-rpc.publicnode.com` (public; used for `eth_call`/`eth_getCode` reads until rate-limited)
- `https://bsc.drpc.org` (public; rate-limited during fork setup)
- Keyed dRPC `https://lb.drpc.org/ogrpc?network=bsc&dkey=…` (key read from `.env` at runtime; used only for reads and local anvil forking — never written to files)
- Local anvil fork (`http://127.0.0.1:8545`) for behavioural probes (read-only against BSC)

## Incident reports / web (SKYDAO exploit, 2026-09-30)

- Blackpaper incident BP-1306: https://blackpaper.wiki/incident/BP-1306/
- 0xposed radar: https://0xposed.io/radar/skydao-burn-from-pair-premature-sync-drains-pancakeswap-pool
- Tozvan: https://tozvan.com/hacks/skydao-pair-exploit
- Cabal Desk: https://cabaldesk.com/articles/skydao-discovers-expensive-difference-between-smart-chain-actual-smart-198/
- Monitoring Room: https://monitoringroom.com/situation/crypto-hack/skydao
- BscScan exploit tx: https://bscscan.com/tx/0x8e3016674ea8e5d2ad3af422ae5328f5a1f448e6b5a93d5d773e358bd2e440eb

## Internal campaign files (lead source, re-verified on-chain)

- `/home/heisenberg/CA/zombie_hunt/ZOMBIE-HUNT-II.md` (H2-03 lead section)
- `/home/heisenberg/CA/legacy-watches/ci/steps/bsc-forks_enum.py` (FstSwap deployment registry: factory/router/token addresses)
- `/home/heisenberg/CA/legacy-watches/analysis/llama/fstswap.json` (DefiLlama protocol snapshot)

## Tooling

- foundry `cast` 1.7.1 (`disassemble`, `call`, `sig`, `to-dec`, `from-wei`, `storage`, `receipt`, `balance`)
- heimdall-rs v0.9.2 (decompiler) — `heimdall decompile … --include-sol`
- anvil (local fork; `--auto-impersonate`) + `debug_traceTransaction` (callTracer)
- `panoramix` (attempted; only produced the fallback — not relied upon)
- 4byte.directory (`https://www.4byte.directory/api/v1/signatures/?hex_signature=0x…`, browser User-Agent required)
