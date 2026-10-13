# Independent adversarial verification — SharkSwap (Base, chain 8453)

**Block pinned: 52,559,481** (`0x321fe79`; supplementary `latest` reads up to 52,560,002). Factory `0x57592D44…5a8B`, `allPairsLength()=52`.
**Mandate: falsify** the claim "an unprivileged attacker can extract $0 live". **Result: NOT FALSIFIED.** Two minor corrections to the claim's rationale, no live path found.

Method: fresh eth_call/eth_getCode/eth_getLogs/eth_getTransactionCount/eth_getBalance reads only (publicnode / dRPC / mainnet.base.org, no keys, batched ≤10). Mint semantics verified with an `eth_call` **stateOverride injected-code helper** (executes mint + balanceOf/ totalSupply reads inside one call; no transaction ever sent). Free-RPC quirks handled: publicnode now rejects pinned historical blocks ("archive"), dRPC caps batches at 3, base.org rate-limits 25 req/s.

## 1. Excess scan (the skim test) — all 52 pairs
Enumerated every `allPairs(i)` (all report `factory()` = SharkSwap factory), read `token0/token1/getReserves` plus `balanceOf(pair)` for both tokens: **104/104 slots have balance == reserve. max excess = 0 wei.** No pair is even under-reserved. `skim()` is stock V2 and would pay excess to any caller — there is none. (Pair source in evidence is a verbatim UniswapV2Pair fork; no extra functions.)

## 2. Dormant LP lock — verified
`0x1239660af62d515bfecd4ee09c58d2cd32504605`: **code `0x` (no EIP-7702 delegation), nonce 0, 0 ETH.** It holds LP in exactly **2 of 52** pairs:

| pair | totalSupply | dormant | share |
|---|---|---|---|
| WETH/DAI `0xae45f7eb…` | 549,958,667,623,406,279,680 | 549,901,036,781,258,816,259 | **99.9895%** |
| WETH/USDbC `0x9ccc7afe…` | 559,977,273,825,232 | 550,074,455,174,827 | **98.2316%** |

Other "top" pairs: WETH/wDAI#1 LP is 100%−1000 wei with EOA `0x27160d3b…`; WETH/wDAI#2 LP 100%−1000 wei with feeTo EOA `0xbe4ec628…`.

**Approvals:** allowance(dormant, S) = 0 on all 4 top LP tokens for 12 spenders (2 routers, feeTo, feeToSetter, both team EOAs, the pairs, zero-address). Permit is supported, but `nonces(dormant)=0` on all four LP tokens — **no EIP-2612 permit was ever consumed**; with on-chain nonce 0, no allowance can exist unless the (presumed destroyed) key signed an unused permit (unobservable; only residual risk). Approval logs for owner=dormant: 0 events in last 10k blocks (archive limits prevented longer scan).

**"Contract" LP holders are all EIP-7702 delegated EOAs** (23-byte designators) delegating to ERC-1271 smart-account code (`0x7702cb55…` 3,318 B; `0x63c0c19a…` 11,185 B) — no permissionless pull/redeem; ≤ ~$2.4 at stake, key-controlled.

## 3. Public-mint audit — only mxapemx, and its drain is ~$0
Probed `mint(address,uint256)`, `mint(uint256)`, `mint()` from a fresh EOA on **all 38 tokens** in the 52 pairs, and bytecode-scanned all 38 for `mint(address)`, `mintTo`, `mintFor`, `issue`, `mintTokens`, `freeMint`, `mint(address,uint256,bytes)`, `mintReward` — **zero hits**. Every token reverts except **mxapemx** `0xfef74fba…` (wDAI#1 = AccessControl role, wDAI#2/fakeWETH = Ownable, TOP = `TaxToken.sol::onlyAuthorized`, SARF = plain revert; WETH's empty success is only its payable fallback).

mxapemx mint is genuinely public and **credits balances** (helper probe: +1e18 / +1e24 to recipient, totalSupply increases, no payment). Drain path: mint 1e27 mxapemx → swap into pair `0x95238e13…` (reserves 5,000,000 TOP / 10,000,000 mxapemx) → ~**4,950,348 TOP** out (V2 math). But TOP's sell-side liquidity is dust:

- **Maverick "TOP/USDC" pool `0x657ed2d5…`: on-chain 4 wei USDC + 43.96 TOP** — GeckoTerminal's claimed ~$16.9M reserve is **not backed**.
- iziswap TOP/MT pool: 10,025 TOP + 0.0098 MT ≈ **$0.0000234** counter-side (MT is real, $0.002384).
- UniV4 ~$5.63 / Curve ~$0.83 (GT-only, unverified); all other TOP pools ≤$0.05; llama has no TOP price.
- mxapemx's other pools: 9mm WETH side = 0.000000000017 ETH; Alien pool ≈ $3e-7.

**⇒ mxapemx-mint drain yields ≈ $0** (provable on-chain bound <$0.0001; <~$10 even if every unverified GT dust pool is real).

## Corrections to the claim (not falsifiers)
1. **"96.2% of LP burned"** not reproduced: current USD-weighted dormant share ≈ 85% (≈90.9% with prior ownership.json totals); per-pool numbers are exact.
2. **"TOP unpriced/untraded"** is imprecise: TOP has nominal listings/prices, but the largest-looking venue is empty and all real sellable liquidity is dust — the $0 conclusion survives on better evidence.

## Confidence & residual risk
**High (≥95%) that no unprivileged live extraction exists at block 52,559,481**, bounded by all-52-pair zero excess, the 2-of-52 dormant LP confinement, zero allowances/permit-nonces, and the only public mint having no valuable counterparty venue. Residual risks: (a) an unused pre-signed permit if the burn key survived (unobservable); (b) ~$6 of unverified dust venues; (c) post-block donations/pool creations change state by definition — nothing at the pinned block extracts.

Machine-readable evidence: `sharkswap-dex/analysis/independent-verify.json`.
