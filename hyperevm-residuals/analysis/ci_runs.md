# CI runs — hyperevm-residuals (H-32 Nest / H-33 Hybra)

| # | Purpose | Run URL | Result | Notes |
|---|---|---|---|---|
| 1 | Baseline HyperEVM fork tests + live-state snapshot (Nest + Hybra pools) | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37182609586 | **success** | 2/2 forge tests PASS; snapshot block 47,618,983: Nest pools $26,572,727.67 / Hybra pools $823,812.14; artifact `result-hyperevm-residuals` |
| 2 | PoC suite v1 (5 gate/mitigation tests) + snapshot | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37189620212 | failure (4/7) | 2 baseline tests hit official-RPC rate limits; `test_hybra_gHYBR_shares_preDepositRatio` surfaced the live gHYBR deposit revert (VE.deposit_for panic 0x11). Passing: collectProtocolFees owner-gate, gHYBR backing, FeesVault gate, adapter undercount. Snapshot block 47,627,341: Nest $26,664,638.99 / Hybra $828,632.30 |
| 3 | PoC suite v2 (dRPC + threads=1) | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37190249062 | 6/7 (test-bug only) | All gate/mitigation tests PASS; `test_hybra_gHYBR_shares_preDepositRatio` failed on an over-strict sanity bound (gHYBR ratio is ~0.106 shares/HYBR, not ~1). Snapshot block 47,628,054: Nest $27,820,970.09 / Hybra $748,250.92 |
| 4 | PoC suite v3 (final) | _pending_ | _pending_ | expected 7/7 PASS |
