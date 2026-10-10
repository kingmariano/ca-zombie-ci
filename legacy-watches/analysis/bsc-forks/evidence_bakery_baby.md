# BakerySwap + BabySwap (BSC) — evidence (2026-10-10)

## BakerySwap
- Factory `0x01bF7C66c6BD861915CdaaE475042d3c4BaE16A7` (3,087 pairs, block 126,836,301), feeTo `0x5f19cb3b105d28c1e3cb6202d3b892bf30a52f5d`.
- Router `0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F` — factory() verified.
- BAKE `0xE02dF9e3e622DeBdD69fb838bB799E3F168902c5` ("BakeryToken"): price **$0.0002659** (DefiLlama, 2026-10-10);
  `mint()/mintTo()` **onlyOwner** (owner 0x20ec291bb8459b6145317e7126532ce7ece5056f) → P inflation risk (standard BEP20 design).
- Top pair BETH/WETH `0xfb72d7c0f1643c96c197a98e5f36ebcf7597d0e3`: 411.81 WETH / 370.08 BETH ≈ $2.06M; excess 0; LP 378.17e18, no burn;
  feeTo holds 0.2943 LP = 0.078% ≈ $1.6k (P).
- Excess scan: 160/3,087 sampled → **0 hits** (full scan in CI).
- MasterChef `0x6a8dbbfbb5a57d07d14e63e757fb80b4a7494f81` ("CommonMaster", token()=BAKE, poolLength 36, owner 0x957f3282ba5a4eb96c5d672f94a7038561475b49):
  - holds **1,386,025.86 BAKE** (≈ $368 at $0.000266)
  - claim logic verified from source: rewards via `pendingToken(_pair,_user)` computed from `poolUserInfoMap[_pair][user].amount` (depositors only);
    `emergencyUnstake(_pair,_amount)` returns **only the caller's own staked LP** (`_amount = min(_amount, userInfo.amount)`).
  - => unclaimed BAKE is depositor-claimable only ✓ (no public drain).
- Note: the address often labelled "BakerySwap MasterChef" `0x20eC291bB8459BF2962daB2D78eeb03fbcd44De2` has **no code** on BSC (empty).

## BabySwap
- Factory `0x86407bEa2078ea5f5EB5A52B2caA963bC1F889Da` (1,769 pairs, block 126,837,164) — VERIFIED; given addresses confirmed.
- Router `0x325E343f1dE602396E256B67eFd1F61C3A6B38BD` — factory() verified == 0x8640... ✓.
- BABY `0x53E562b9B7E5E94b81f10e96Ee70Ad06df3D2657` ("BabyToken"): totalSupply 1B; `mint/mintFor` **onlyOwner** (owner 0x5da29e4afe94784fde4b7a62c5cd8a8aebcfd6e4) → P.
- MasterChef `0xdfAa0e08e357dB0153927C7EaBB492d1F60aC730` (verified `MasterChef`, cake()=BABY, poolLength 200, owner 0x48fcafa24c5599d521447713efb4eeeea3af99ff):
  - **BABY balance = 0** → no unclaimed rewards to take.
  - claim logic standard (deposit/withdraw/emergencyWithdraw + pendingCake per userInfo) — depositors only.
- Top pair USDT/WBNB `0x04580ce6dee076354e96fed53cb839de9efb5f3f`: 103,526.30 USDT / 138.14 WBNB ≈ $206.8k; excess 0.
- Full 1,769-pair excess scan: **173 hits, all verified, all dust** (prices 1e-8..null; top FEG hits ≈ $1.7e-7 total:
  FEG is $8e-11 — Pancake FEG/WBNB pool holds 3.72 WBNB vs 3.39e13 FEG). `skim()` simulations succeed but value ≈ 0.
- Underwater total $15.54 (normal post-swap drift; no phantom pattern).
- feeTo `0x6bef4238761aee8ea773405d60ba93cd183d41d3`: 102.71 LP of USDT/WBNB = 4.69% ≈ $9.7k (P).
