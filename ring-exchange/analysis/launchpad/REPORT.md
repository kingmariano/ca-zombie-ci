# RingLaunchpad 0xc38f2fd561d748ce74a5f9ce09b89d2cf421fb56 — permissionless-mint de-risk (H-31, HyperEVM chain 999)

**Date:** 2026-10-04 · **Status:** read-only on mainnet (no transactions sent) · fork PoC on local anvil only · evidence at block **47,621,191** (0x0f79d51f0a490456e8ce01e2a0832bfa336b66f2d0fdb360ceb46fe19abab868) unless stated.

## TL;DR

| Question | Answer |
|---|---|
| Is there a permissionless call path that causes `fwWHYPE.mint(...)`? | **YES, in code and executable** — `deploy()` (`0x4ef98097`), `deployWETH()`, `deployETH()` call `IFewWrappedToken(wrappedWETH).mint(address(this), pairAmount)` from any caller. |
| Can an unprivileged attacker capture the minted fwWHYPE? | **NO.** Recipient is hard-coded `address(this)`; the tokens are immediately deposited as liquidity into a *freshly created* pair with `to = address(this)`. The launchpad holds 100% of that pair's LP and exposes **no** function to move LP or fwWHYPE. |
| E-U (external-unprivileged extractable) | **$0** — high confidence |
| H-O (holder-recoverable) | $0 (contract custodies no user funds) |
| P (owner privileges) | owner EOA `0x9336D0C8…` can `setThreshold` (≤1000 ether), `transferOwnership`, `renounceOwnership`; the same EOA holds `MINTER_ROLE` on Few Core directly (can mint any amount to any address) — this is a **key/custody risk, not a contract-logic E-U path**. |
| S (stuck) | Native accidentally sent to `receive()` is unrecoverable (matches SlowMist N2). |
| Permissionless-mint-and-dump into Ring pools | **Not possible via this contract.** The only fwWHYPE it can mint is permanently locked in its own LP. |

The ~$4.8M of real wrapper collateral (fwWHYPE ≈ 20,217.5 WHYPE ≈ $1.81M at $89.73 + fwUETH 1,109.47 UETH ≈ $2.99M) is **not reachable through this contract**.

---

## 1. Source provenance — proven, not inferred

The HyperEVM contract is **unverified** on Etherscan (chain 999), but it is *byte-equivalent* to the verified Ethereum `RingLaunchpad`:

- HyperEVM runtime code (`eth_getCode`, block 47,621,191, re-fetched): **10,507 bytes**; trailing metadata = `…64736f6c634300081a0033` (solc 0.8.26) + ipfs hash **`46b6eb636edef678542bf33254b37e7543af08cb400da87491ec1ad685b70c62`**.
- Ethereum **verified** contract `RingLaunchpad 0x8814a2aa2384d65672c7dc0650454e56f62fba8b` (Etherscan V2 chain 1, ContractName `RingLaunchpad`, compiler v0.8.26+commit.8a97fa7a, optimizer on, runs 10000, evmVersion paris): runtime **10,507 bytes**, **identical metadata ipfs hash**.
- Byte diff HYPE-vs-ETH: **20 runs × 20 bytes = exactly 400 differing bytes — all four immutables only** (weth, uniswapRouter, wrappedWETH, wrappingFactory; each appears 5× as a 20-byte address embedded in code). **No other byte differs.**
- Constructor args decoded from the deployment input (tx `0x7e27e54efae54f48f9688ade5447c5b6a5c2e4cb9aedcf16d4de22936f0298db`, block 8,636,029, deployer `0xa3142fdc1050289a95858799aa921cb1d6ace65d`): uniswapRouter `0xcdCC42Ec…`, weth `0x5555…5555`, wrappedWETH `0x9e1148bC…`, wrappingFactory `0x6B65ed73…`; hard-coded `threshold = 10e18`.
- After deployment the deployer called `transferOwnership` (`0xf2fde38b`, block 8,636,639) → owner today = `0x9336D0C82299Da0ab178271792954ADFD6f10fD7`.
- Source files extracted to `eth_src/` (Etherscan V2 sources JSON = `eth_launchpad_src.json`). SlowMist audit `RingLaunchpad` (2024-11-27) confirms the same design (`launchpad-slowmist.pdf`/`.txt`); its audited repo `github.com/Few-Protocol/ring-launchpad` is now 404, but the byte-match to the verified deployment makes the repo irrelevant for provenance.

**Selectors in the deployed dispatcher (all 15 map 1:1 to the verified source; no hidden selector):**
`08af5431` MAX_THRESHOLD(), `3fc8cef3` weth(), `41164416` deployETH(…), `42cde4e8` threshold(), `4ef98097` deploy(…), `715018a6` renounceOwnership(), `735de9f7` uniswapRouter(), `8bfe95f4` wrappedWETH(), `8da5cb5b` owner(), `902d55a5` TOTAL_SUPPLY(), `933166e1` creators(address), `960bfe04` setThreshold(uint256), `b214d85e` wrappingFactory(), `bee0bd8e` deployWETH(…), `f2fde38b` transferOwnership(address) + `receive()`.

## 2. Function-by-function table (simulated live from random `0x1111…1111` via `eth_call`, never sent)

| Selector | Function | Access control | Effect | Simulated result (live RPC) |
|---|---|---|---|---|
| `0x4ef98097` | `deploy(string,string,uint256)` | **permissionless** (nonReentrant) | `fwWHYPE.mint(address(this), pairAmount)`; `new Token` (1e27 to launchpad); `FewFactory.createToken`; `wrap(1e27)`; `addLiquidity(fwWHYPE, wrappedToken, …, to = address(this))`; records `creators[token]` | **SUCCESS** from random → returns token `0xC3396a6f…`, wrapped `0x729aB101…`; `InvalidParameters()` `0xe5239090` for empty name/symbol, name>32, pairAmount=0, pairAmount>threshold(1e19). Gas (fork): **5,037,243**; real-chain `eth_estimateGas`: **5,222,330** (fits only in a 30M big block) |
| `0xbee0bd8e` | `deployWETH(string,string,uint256,uint256,address)` | permissionless | `deploy` + optionally pulls `buyAmount` WETH from `msg.sender`, wraps, swaps for the *new* wrappedToken, `unwrapTo(recipient)` | buyAmount=0 **SUCCESS**; buyAmount>0 without balance/allowance **reverts** (SafeERC20 `transferFrom`) |
| `0x41164416` | `deployETH(string,string,uint256,address)` | permissionless, payable | `deploy` + optionally `WETH.deposit(msg.value)`, swaps, `unwrapTo(recipient)` | value=0 **SUCCESS**; value=1000 wei **SUCCESS** (buy path executes) |
| `0x960bfe04` | `setThreshold(uint256)` | **onlyOwner** | sets `threshold` (≤ MAX_THRESHOLD 1e21) | random → revert `0x118cdaa7` `OwnableUnauthorizedAccount(0x1111…)` |
| `0xf2fde38b` | `transferOwnership(address)` | onlyOwner | transfer ownership | random → `0x118cdaa7` |
| `0x715018a6` | `renounceOwnership()` | onlyOwner | renounce | random → `0x118cdaa7` |
| `0x42cde4e8` | `threshold()` | view | 1e19 (10 fwWHYPE cap per `deploy`) | `10000000000000000000` |
| `0x08af5431` | `MAX_THRESHOLD()` | view | 1e21 (1000 ether) | `1000000000000000000000` |
| `0x902d55a5` | `TOTAL_SUPPLY()` | view | 1e27 | `1000000000000000000000000000` |
| `0x735de9f7` | `uniswapRouter()` | view | 0xcdCC42Ec… | matches |
| `0x3fc8cef3` | `weth()` | view | 0x5555…5555 WHYPE | matches |
| `0x8bfe95f4` | `wrappedWETH()` | view | 0x9e1148bC… fwWHYPE | matches |
| `0xb214d85e` | `wrappingFactory()` | view | 0x6B65ed73… FewFactory | matches |
| `0x8da5cb5b` | `owner()` | view | 0x9336D0C8… EOA | matches |
| `0x933166e1` | `creators(address)` | view | (origin, sender) info only | (0,0) for random |
| — | `receive()` | permissionless | accepts native, no withdrawal | funds sent are stuck (audit N2) |

**Direct cross-check:** `fwWHYPE.mint(0x1111…, 1)` via `eth_call` **succeeds from the launchpad address** and **reverts from a random address** (`CoreRef: Caller is not a minter`), matching `hasRole(MINTER_ROLE 0x9f2df0…, launchpad) = true`. Live `MINTER_ROLE` holders: launchpad `0xc38f2fd5…` and EOA `0x9336D0C8…` (governor Timelock does **not** have it). Launchpad's live fwWHYPE/router allowances and balances are all **0**, native 0.

## 3. Why the mint cannot be captured (the gate)

Verified source (excerpt, `contracts/RingLaunchpad.sol`):

```solidity
IFewWrappedToken(wrappedWETH).mint(address(this), pairAmount);      // L69  recipient = launchpad, never caller
token = address(new Token(name, symbol));                          // L71
wrappedToken = IFewWrappingFactory(wrappingFactory).createToken(token); // L72
IERC20(token).approve(wrappedToken, TOTAL_SUPPLY);
IFewWrappedToken(wrappedToken).wrap(TOTAL_SUPPLY);                 // L75
IERC20(wrappedWETH).approve(uniswapRouter, pairAmount);
IERC20(wrappedToken).approve(uniswapRouter, TOTAL_SUPPLY);
IUniswapV2Router02(uniswapRouter).addLiquidity(
    wrappedWETH, wrappedToken, pairAmount, TOTAL_SUPPLY,
    pairAmount, TOTAL_SUPPLY,
    address(this),                                                 // L87  LP minted to the launchpad itself
    block.timestamp);
```

Gate chain (all verified on-chain):

1. **Mint recipient is hard-coded `address(this)`** — the caller gets 0 fwWHYPE. The wrappedToken is always a *freshly created* wrapper of a fresh `Token`, so the pair `(fwWHYPE, wrappedToken)` is always new; the attacker cannot route the mint into an existing pair.
2. **LP goes to `address(this)`** — the launchpad holds 100% of the pair's LP. It has **no** removeLiquidity/burn/transfer/arbitrary-call function; the LP cannot be moved by anyone, including the owner (owner functions are only `setThreshold`/`transferOwnership`/`renounceOwnership`; the contract is not upgradeable, no delegatecall, no selfdestruct). LP `transferFrom` would need an allowance that never exists; pair `permit` needs the launchpad's signature (contract cannot sign).
3. **Closed system:** the only way to take fwWHYPE out of the pair is to sell wrappedToken into it; the only way to get wrappedToken is to buy it from that same pair (its entire 1e27 supply is inside the wrapper/pair) — i.e. you must first pay in at least the same AMM value. Round trip is a **net loss = fees**.
4. `pairAmount ≤ threshold = 1e19` (10 fwWHYPE) per call — moot given the lock, but it also caps any hypothetical exposure.

**Fork proof (local anvil forking HyperEVM RPC at block 47,620,747; no mainnet tx sent):**

- `deploy("ZTEST","ZT",1)` from `0x1111…1111` → status 1, **gasUsed 5,037,243**.
  - `fwWHYPE.Mint` event emitted (amount 1, to = launchpad); fwWHYPE `totalSupply` 1,185,217,534,192,860,677,230,517 → +1.
  - New pair `0xFeCD5d875e01516510Cfb0Ae37D434C956ade829`: reserves = **1 wei fwWHYPE / 1e27 wrapped**.
  - **LP totalSupply 31,622,766,001,683; LP balance launchpad = 31,622,776,600,683; LP balance attacker = 0.**
  - Launchpad fwWHYPE balance after = **0**; launchpad allowance to router = **0**.
  - Attacker `removeLiquidity` → revert `ds-math-sub-underflow` (holds no LP).
- **Best-case buy-out/sell-back round trip by the attacker:** wrapped 1,000,000 wei WHYPE → 1,000,000 fwWHYPE → bought **999,998,996,991,978,944,855,622,010 (≈100% of the new token supply)** for all 1,000,000 fwWHYPE → sold all back → received **999,999 fwWHYPE** → **net −1 wei (a loss)**; the pool's locked fwWHYPE grew 1 → 2 wei. The minted subsidy is not recoverable; the attacker donates value to it.

## 4. Router 0xcdCC42Ec0ECB7B5F9e4A5FE1Df99EeB1BDf46a00 (constructor arg)

- **Etherscan-verified** on chain 999 as **`UniswapV2Router02`**, solc v0.6.6+commit.6c089d02, optimizer runs 10000; `factory()` = `0x4AfC2e4cA0844ad153B090dc32e207c1DD74a8E4` (Ring's verified `SwapV2Factory`), `WETH()` = WHYPE `0x5555…5555`; standard function set (addLiquidity/removeLiquidity/swaps/permit-era helpers), **no owner, no pause, no sweep** (Etherscan source; `owner()` reverts). 
- Deployed by Ring deployer `0xa3142fdc1050289a95858799aa921cb1d6ace65d` at block 8,635,907 (23 blocks before the launchpad); **25 lifetime txs, all `addLiquidity` (`0xe8e33700`) from Ring EOAs `0x9336D0C8…` and `0x4f0aa590…`.** It is Ring's own earlier router, nobody else controls it beyond the shared factory (factory `feeTo=0`).

## 5. Quantification & classification

- **E-U = $0 (high confidence).** There is no unprivileged path that yields the attacker any fwWHYPE, LP, or other asset. The permissionless mint is a value *sink* (gas + locked liquidity), not a source.
- **Latent/per-call figures (for completeness, unreachable):** per call mints ≤ 10 fwWHYPE. Nominal face at WHYPE $89.73 = **$897.30**; pro-rata collateral value = 10 × (20,217.534 / 1,185,217.534) × $89.73 ≈ **$15.31** (wrapper backing at block 47,621,191 is 1.7058%). Global wrapper collateral cap ≈ 20,217.534 WHYPE ≈ **$1.81M**; the minted tokens never become redeemable claims because they cannot leave the pair. The combined "~$4.8M" wrapper collateral (fwWHYPE + fwUETH) is untouched by this contract.
- **No minted-by-launchpad tokens in circulation:** the launchpad has only **2 lifetime txs** (create + transferOwnership), **0 `TokenDeployed` events, 0 `Mint` events as minter**, and holds **0 LP** in all 5 existing Ring pairs. The unbacked fwWHYPE in the Ring pool came from the **EOA** minter `0x9336D0C8…` (separate, privileged/P track).
- **H-O $0 / P (owner) / S (mis-sent native).**

## 6. Verdict

> **No permissionless mint-and-dump path exists via 0xc38f2fd561d748ce74a5f9ce09b89d2cf421fb56.**
> The function `deploy()` is permissionless and does mint fwWHYPE, but the tokens are minted to the launchpad itself and are irrevocably locked as liquidity in a fresh pair whose LP tokens are also held by the launchpad, which exposes no exit. Every possible extraction route reduces to paying equivalent value into the same locked pool. **E-U = $0**, high confidence.

What would change the verdict: (a) discovering a *write* path to the launchpad's LP (none — verified source has 15 selectors, all accounted for; no delegatecall/upgrade); (b) compromise of owner EOA `0x9336D0C8…` or its direct `MINTER_ROLE` (that is a key-compromise scenario, out of scope here); (c) a future HyperEVM/contract change (contract is immutable).

## 7. Methodology & evidence files

- Mainnet reads: HyperEVM RPC `https://rpc.hyperliquid.xyz/evm`, Etherscan V2 chain 999; explicit block 47,621,191. No sends; all `cast call`/`eth_call`/`eth_estimateGas`.
- Fork PoC: local `anvil --fork-url <HyperEVM RPC>` (chain 999), impersonated random address; sends executed only against the local fork.
- Files: `eth_launchpad_src.json`, `eth_src/` (verified source), `hype_runtime.hex`, `eth_runtime.hex` (metadata/bite-diff proof), `creation_minter_input.hex`/`creation_minter.json` (constructor args), `router_src.json`/`router_src_raw.txt`, `deploy_receipt.json`, `poi_state.txt`, `trace.json` (callTracer of the live `deploy` eth_call), `launchpad-slowmist.pdf`/`.txt`, plus searches in `../` shared evidence.
- Caveats: the SlowMist audit predates the HyperEVM deployment (audit: "not deployed to mainnet") and audited threshold=100 ether; deployed code sets 10 ether — logic otherwise byte-matched to the verified on-chain source. The audit's N1 ("malicious creation of liquidity", acknowledged) matches the behavior found here and its acknowledged rationale ("users need to pay gas") is consistent with the lock.
