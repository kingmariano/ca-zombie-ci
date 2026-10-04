# H-47 Progress Notes (checkpoint)

## Confirmed facts
### Rho Markets (Scroll, chainid 534352) — block 35,269,xxx
- Comptroller (Unitroller proxy) 0x8a67AB98A291d1AEA2E1eB0a79ae4ab7f2D76041 -> impl 0xFF833B7db57Bb4eEC4FFb79C302d7D955326423A
- Oracle (new) 0x653C2D3A1E4Ac5330De3c9927bb9BDC51008f9d5 -> impl 0xB14dF613F4b30fFfFE9811a11f2931De011391D9 (PriceOracleV2, onlyOwner setters)
- Old oracle proxy 0x3E1AbD0731c9397f92beC0fbA6918628013F7C6F -> impl 0x7fE3b7831B1b66463c23d291Fbd559bd2761cBD9
- Admin 0x2a9c973a2f5Cb494eA84Fd0811aA7701f4d56401 (timelock?)
- pauseGuardian/borrowCapGuardian/supplyCapGuardian 0x7A2123Ea7687b1c59A4a64450b445256F1a7AFFb
- 16 markets; cash mostly dust; rylstETH cash 0.2e18 (~$578), runiETH 0.001 (~$3), rSCR 39.73 (~$1), rUSDC $0.02, rUSDe $0.096
- Empty-market protection: 4 markets totalSupply=1, CF=0, mint+borrow paused (0x00B4,0x1D73,0x76DC,0x8698)
- rylstETH + runiETH: borrowPaused=true
- Oracle prices: ETH $2687.67, WBTC(0x76DC) $84818, wstETH $3346, weETH $2969, USDC/USDT ~$1.0
- 0x1D73 (seeded WBTC mkt) oracle price = ETH-scale ($2687) -> config decimals mismatch but CF=0/paused
- closeFactor 0.5, liqIncentive 1.1, transferPaused=false, seizePaused=false
- Dedaub audit: empty-market/donation class was addressed by redeemUnderlying validation + seeding markets

### Velocore V2
- Linea: factory(old) 0xBe6c6A389b82306e88d74d1692B67285A9db9A47 (46 pools), factory(new/hub) 0xaA18cDb16a4DD88a59f4c2f45b5c91d009549e06, vault diamond 0x1d0188c4B276A09366D05d6Be06aF61a73bC7535
- zkSync: factory 0xf55150000aac457eCC88b34dA9291e3F6E7DB165 (70 pools), vault 0xf5E67261CB357eDb6C7719fEFAFaaB280cB5E2A6
- Telos: factory 0x5123EE9A02b7435988D4B120633d045EF6a0159B (20 pools), vault 0x0117A9094c29e5A3D24ae608264Ce63B15b631d9
- ALL pools on all 3 chains: fee1e9 == 0 (verified per-pool CSV)
- Original exploit pool: 0xe2c67A9B15e9E7FF8A9Cb0dFb8feE5609923E5DB (USDC-ETH VLP), drained, holds 0 USDC / 0 ETH
- Vault Linea holds 23464 wei USDC + 0.000116 ETH (dust)
- Authorizers: Linea 0x0978112d4ea277ad7fbf9f89268deeddeb743996; zkSync 0xe6d4c953a094fbc1dbf0d46f51c2b56ab51e9780; Telos 0xdf7142efe69ae90831911d6ae6a043e80a87db61
- Treasury EOA (all chains) 0x1234561fed41dd2d867a038bbdb857f291864225 (codesize 0, 0.6 ETH) holds:
  - setParam role (actionId 0x610b3247...) on Linea pools + Telos pools (canPerform true)
  - setFee role (0x5284f336) + setDecay (0x4221ced2) on Linea factory 0xBe6c
- DEFAULT_ADMIN_ROLE was revoked from treasury at Linea block 1,120,272 (0x111610)
- Attacker canPerform(setParam) = false on all chains
- EOA 0x6ecc3ddf76e42dd2ff681dc926eb885d8651ee54 holds role 0x797528e3 (unidentified)
- Deployed pool source == repo (Altcoin-Cash/velocore-contracts master, Nov-2023): velocore__execute has NO caller check; fee=0 kills effectiveFee1e9 (line 171-176), so underflow path dead
- setParam has bug: require(fee1e9 <= 0.1e9) checks OLD value, so new fee can be any uint32 when old is 0 (privileged only)

## TODO
1. Fetch RErc20Delegate source 0x441f85c5d607c254475B97B760cb944970d8Bec4 -> verify redeemUnderlying patch
2. Comptroller token balances (Blockscout) + liquidateBorrowAllowed whitelist check
3. Velocore pool balances per chain (find Telos $1.3k, Linea $5.78, zkSync $2.06)
4. Build CI PoC:
   - Velocore: original exploit at historical block (works) vs latest block (fails, fee=0); latent test: impersonate treasury, setParam to re-enable fee, exploit works again
   - Rho: oracle check + empty-market precondition checks + redeem/donation no-profit test
5. README.md + summary.json
