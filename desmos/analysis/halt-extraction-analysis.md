# C2-10 Desmos — does a halt enable value extraction? (analysis)

Conclusion: **no — a halt is a pure liveness/DoS event on this chain; extractable value = $0.** Reasoning, path by path:

1. **No state transitions while halted.** The attacker cannot move funds; block production stops. The malicious contract/ack only causes divergence or a panic; there is no theft primitive in CWA-2025-001/002 or ISA-2025-001 (both are availability bugs — "crash the chain", "slow down block production", "chain halt").
2. **IBC timeouts refund the sender.** If packets in flight time out during a halt, refunds go back to the original senders (escrow/burn semantics). An attacker holding a pending packet gets their own funds back; no counterparty loss.
3. **No on-chain lending/liquidation market to front-run.** Desmos has no lending protocol; the wasm contracts hold negligible native value (see `COST-MODEL.md`: sample contracts ≈ 3 DSM total; full scan in CI). A halt cannot prevent a profitable liquidation for the attacker or trigger bad debt to seize.
4. **Governance cannot execute during a halt.** Proposals are delayed, not accelerated. A halt does not help a capture attempt (it freezes the very tally/execution the attacker would need).
5. **DSM's backing is unaffected.** The 41.37M DSM IBC escrow on Desmos (backing Osmosis DSM) is not at risk from a halt; redeemability is restored when blocks resume.
6. **Cross-venue manipulation is bounded by ~$7.3k of observable DSM liquidity.** A halt could cause a temporary DSM price dip on Osmosis; without any DSM perp/short venue and with total pool counter-value ≈ $7.3k, the maximum theoretical trading gain is bounded by that depth, is not reproducible (no short leg), and is dwarfed by the attacker's own funds at risk. Not a credible extraction path.
7. **Validator downtime slashing pause** (halting stops the missed-block counter) is a validator-side concern, not an external-unprivileged profit path.

Residual: extortion/ransom is out of scope (illegal, off-chain, not measurable as extractable value). The DoS itself is real and cheap — a CRIT availability finding — but it is not monetizable on-chain.

Category: **DoS = $0 extractable** (confidence: high).
