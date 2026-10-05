# C2-08 Sommelier — live evidence (CI run)

- Chain: sommelier-3 @ height 28116472 (2026-10-05T16:03:41.651252437Z)
- Gov params: quorum=0.500000000000000000 threshold=0.500000000000000000 veto=0.334000000000000000 voting=172800s deposit=172800s min_deposit=5000000000
- Bonded: 71,469,478 SOMM ($29,539 paper @ $0.000413); authority bloc 52,845,705 SOMM (73.94%, 4 validators); Foundation 52,743,992 (73.80%)
- PoA: safe_mode={'active': False, 'thaw_height': '0', 'bonded_authority_count': '4'} floor=0.670000000000000001 (multiplier live = 1)
- Capture thresholds: solo quorum 71,469,478 SOMM ($29,539); beat-plain-No 52,845,706 ($21,842); veto-proof 105,374,969 ($43,552)
- Public DEX SOMM ceiling: 2,094,341.84 SOMM (Osmosis 2,094,338.35 across 10 pools + Ethereum v2 3.49) = 2.93% of solo-quorum need
- Proceeds (paper): CP 110,069,733 SOMM = $45,493; cork-managed cellars $209,171; cellarfees $1,961.23; gravity module 36,864,615 SOMM
- Cork authority: somm1lcsjy2d5s33h0sddd8lpuqvwyz5ruz7ju4aeqa (single EOA, seq 191)
- Managed cellars: [{"chain_id": "10", "ids": ["0xC47bB288178Ea40bF520a91826a3DEE9e0DbFA4C"]}, {"chain_id": "56", "ids": []}, {"chain_id": "137", "ids": []}, {"chain_id": "5000", "ids": []}, {"chain_id": "8453", "ids": []}, {"chain_id": "42161", "ids": ["0x438087f7c226A89762a791F187d7c3D4a0e95ae6", "0xC47bB288178Ea40bF520a91826a3DEE9e0DbFA4C", "0x392B1E6905bb8449d26af701Cdea6Ff47bF6e5A8", "0x01a4A3E1E730D245F210EebC6aEE54F2381CAC63"]}, {"chain_id": "43114", "ids": []}, {"chain_id": "534352", "ids": ["0xd3BB04423b0c98aBc9d62f201212f44dC2611200"]}]
- Verdict: E-U $0.00 — capture requires >52.8M SOMM (authority bloc, veto-proof ~105.7M) but only 2,094,342 SOMM exists in all public DEX pools; authority bloc holds 73.9% of bonded; June-2026 drain attempt (prop 173) failed quorum+veto
