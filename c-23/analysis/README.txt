C-23 analysis artefacts (read-only research, Ethereum mainnet)

Incident / mechanics
- DeFiHackLabs_1inch_exp.sol        public exploit PoC (2025-03) this work's PoC is adapted from
- Settlement_old.sol                vulnerable Settlement source (1inch/limit-order-settlement @934a8e7)
- ResolverExample.sol               1inch example resolver (the trusting resolveOrders pattern)
- 1inch_blog.html                   1inch post-incident statement ("Vulnerability in obsolete 1inch contract")
- fusion_protocol_v1_README.md      v1 repo README (no multichain deployment table -> Ethereum-only)

Deployed target (0xA88800CD213dA5Ae406ce248380802BD53b47647)
- etherscan_Settlement_src.json     Etherscan V2 getsourcecode (verified Settlement, solc 0.8.17)
- etherscan_Settlement_src.sol      raw verified source blob
- settlement_sources/               all 24 source files; contracts__Settlement.sol contains the
                                    vulnerable Yul overflow (unchecked add(ptr+interactionOffset+interactionLength))
- etherscan_victim_src.json         TrustedVolumes resolver 0xB02F (unverified)

Successor check
- etherscan_2Ad500_eth_src.json     0x2Ad500… Ethereum Settlement v2 (solc 0.8.23): no vulnerable pattern
- etherscan_2Ad500_bnb_src.json     0x2Ad500… BNB SimpleSettlement: no vulnerable pattern / no resolveOrders
- 2Ad500_eth_src.raw / 2Ad500_bnb_src.raw

Enumeration
- settlement_senders.json           unique top-level settleOrders callers (Blockscout paging)
- bs_tokentx_senders_to_settlement.json  448 ERC-20 senders to Settlement + per-sender transfer counts
- sender_code_scan.json             eth_getCode scan of those senders; 14 with resolveOrders selector
- candidate_contracts_meta.json     Blockscout metadata (all unverified)
- candidate_balances_bs.json / candidate_balances_full.json / candidate_balances_raw.json
- candidate_tokens.json, candidate_drain_txs.json, remaining_candidate_drain_txs.json
- enumerate_senders.py, enumerate_balances.py, value_confirmed.py   scripts used
- confirmed_valuation.json          complete balances + DefiLlama prices for the 7 confirmed victims
- balances_run.log

Approvals
- analysis_approvals_settlement.json   all 11 Approval(spender=Settlement) events, all history

Traces (live exploitation evidence)
- trace_26106881.json               callTracer of tx 0x41259d1b… (block 26,106,881, 2026-10-02):
                                    bot 0xE08D97e1 -> Settlement.settleOrders -> resolveOrders(0x5623B873)
                                    with resolverArg = owner 0xEe230d…, data = 87 zero bytes
- trace_bot_7a359544.json           bot drain of 0x7a359544 (2025-11-02, UNI), resolverArg 0xC97567…
- trace_bot_e789c556.json           bot drain of 0xe789c556 (2026-04-07, YIELDX), resolverArg 0x9108813F…
- blockscout_internal_p1.json       internal calls involving Settlement (page 1)

Notes
- All addresses/blocks/amounts in README.md are cited from these artefacts or from direct eth_call at
  explicit block numbers (26,109,263 for live state; 21,982,110 for the historical reproduction).
- No secrets are stored here; scripts read keys from the environment only.
