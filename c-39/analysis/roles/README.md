# C-39 — PulseX stack roles, feeTo / buy-and-burn, routers

## Roles (block 27,702,157)
| Role | Address | Type | Notes |
|---|---|---|---|
| V1 feeToSetter | `0x3a27c0a67D6bbc3DC024Af200bb309cB1FE1F091` | **EOA** (code size 0) | can `setFeeTo`/`setFeeToSetter` on both factories |
| V2 feeToSetter | same EOA | EOA | shared across V1/V2 |
| V1 feeTo | `0xD46BD969d995A122AD5B803A45d309021A647B87` | ERC-1967 proxy → impl `0x5f02fbb0f8d924e9b67c7daae523ff51175699f9` (`PLSXBuyAndBurnUpgradeable`, UUPS) | receives LP via `_mintFee` |
| V2 feeTo | `0xd6cA7ee047a6F45d20d2962E4394E070cF27724F` | same impl | same |
| BuyAndBurn owner | `0x1AAc90D3409609Dd61aB62ad72372bA9c4d24a40` | EOA (code size 0) | `onlyOwner`: setDevCut/setBounty/addAuth/toggleAnyAuth/upgrade |
| BuyAndBurn devAddr | `0x3239713576e11082CF9B9cDA9b77468Ea644c682` | EOA | receives `devCut=1429` (14.29%) of converted PLSX |
| BuyAndBurn authorized(0) | `0x30e22ab6e6B576e6A9c5dD73191237a9A5c72539` | EOA (code size 0) | only address besides owner able to call `convertLps` |

## `convertLps` is not externally callable
`convertLps(tokens0,tokens1)` requires `anyAuth || isAuth[msg.sender]`.
Live: `anyAuth() == false`, `isAuth(owner) == false`, `authorized(0)` = EOA. An arbitrary EOA calling it reverts
`PLSXBuyAndBurn: FORBIDDEN` (fork test `test_buyAndBurn_convertLps_is_gated`).
Even if `anyAuth` were toggled, an outsider would only earn `BOUNTY_FEE=10` (0.1%) for converting protocol-owned LP;
converted PLSX is burned/dev-cut, not sent to the caller.

## feeTo LP holdings (protocol-owned, P/S class)
`_mintFee` mints LP to feeTo on every mint/burn (V1 has an integer-division bug: `rootK.mul(4998/10000)==0`,
so denominator = `rootKLast`; feeTo is minted `totalSupply*(rootK-rootKLast)/rootKLast` — more than Uniswap's
1/6 rule). Sampled shares (block 27,702,1xx):

| Pair | feeTo LP share |
|---|---|
| V1 PLSX/WPLS `0x1b45…` | 0.49% |
| V1 WETH/WPLS `0x42ab…` | 1.77% |
| V1 DAI/WPLS `0xe560…` | 3.77% |
| V1 USDC/WPLS `0x6753…` | 3.29% |
| V1 HEX/WPLS `0xf1f4…` | 2.33% |
| V2 DAI/WPLS `0xae84…` | ~0.47% |
| V2 HEX/WPLS `0x19bb…` | ~0.34% |
| V2 WPLS/PLSX `0x149b…` | ~2.0% |

This value can only be moved by the isAuth EOA (converted to PLSX and burned) or by the owner (upgrade).
**No unprivileged path** to it was found (P/S).

## Routers
| Router | Factory | PLSX balance | WPLS | Notes |
|---|---|---|---|---|
| `0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02` (V1) | V1 | 0 | 0 | identical function set to V1-b |
| `0xaf5e33cb31A3454C950bee39ed1C76fd65b394cf` (V1) | V1 | 0 | 0 | reformatted duplicate; same 9971 fee math |
| `0x165C3410fC91EF562C50559f7d2289fEbed552d9` (V2) | V2 | **18.27 PLSX** | 0 | no `sweep`/`claim`; router never spends its own balance ⇒ stuck (S) |

- All three routers use the same 0.29% fee constants (`9971`/`10000`) matching the pair fee.
- No extra privileged/withdraw functions beyond the standard Uniswap V2 router surface.
- `factory.createPair` uses CREATE2 with fixed pair bytecode; `setFeeTo` requires the feeToSetter EOA (P).

## Verdict
All role-gated value (feeTo LP, feeTo balances, factory fee config) is **P/S**, not E-U. The only unprivileged
interactions are standard swaps/liquidity operations that pay their own way.
