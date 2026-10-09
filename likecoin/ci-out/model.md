# C2-29 LikeCoin capture model — live at h 27049046 (2026-10-08T17:50:42.820923772Z)

## State
- bonded: **612,235,423.15 LIKE**; not bonded: 496,147,229.92; supply: 1,467,694,529.01
- community pool (fee-pool accounting): **79,981,046.28 LIKE**; distribution module: 106,693,809.66 (extra unreachable: 26,712,763.38)
- IBC escrows: 11,163,090.31 LIKE; liquid float: 241,454,975.96 LIKE
- bonded validators: 3 of 131: Civic Liker 讚賞公民 212,397,485, Oldcat 203,589,620, Yasu 196,248,318

## Capture economics
- gov: quorum 0.4, threshold 0.5, veto 0.334; min deposit 100,000 LIKE; voting 7d; unbonding 21d
- solo-quorum stake: **408,156,948.77 LIKE** ($602,785 at v3 price) — DEX inventory 2,673,595.45 LIKE (153x)
- veto-proof stake: 1,224,470,846.31 LIKE (> total supply: impossible)
- min-deposit acquisition cost: $111.57 (refundable; burned only on veto)
- CP nominal at v3 price: $118,119.78; **realizable dump: $2,577.16** (2.18% of nominal)

## Top LIKE pools (Osmosis)
- pool 555 (Pool): 1,521,946.98 LIKE / counterpart $1,493.29
- pool 553 (Pool): 772,992.26 LIKE / counterpart $749.33
- pool 1242 (Pool): 378,534.59 LIKE / counterpart $371.33
- pool 559 (Pool): 100.18 LIKE / counterpart $0.09
- pool 2567 (Pool): 13.14 LIKE / counterpart $0.03
- pool 551 (Pool): 8.23 LIKE / counterpart $0.00

Verdict: capture requires the 3 bonded validators' cooperation; solo-quorum is not executable (408.16M LIKE vs 2.69M AMM inventory); prize realizable ~$2,577 (v2 tokens dead post-migration). Uneconomic confirmed.
