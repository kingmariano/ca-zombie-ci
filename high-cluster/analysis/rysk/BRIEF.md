# BRIEF — Rysk V12 (HyperEVM + Ethereum) — ~$15.7M live in MarginPools

Read `analysis/CONVENTIONS.md` first. This is your per-protocol brief.

## Target

Rysk V12 = on-chain options (covered calls / cash-secured puts) with RFQ auction; "collateral remains
locked in smart contracts". Docs: https://docs.rysk.finance (important-contracts page verified).

| Chain | Contract | Address |
|---|---|---|
| HyperEVM (999) | MarginPool (collateral storage) | `0x24a44f1dc25540c62c1196FfC297dFC951C91aB4` |
| HyperEVM | Rysk (transaction processor) | `0x8C8bcb6D2c0E31c5789253EcC8431cA6209B4E35` |
| HyperEVM | MMarket (MM accounting) | `0x691a5fc3a81a144e36c6C4fBCa1fC82843c80d0d` |
| Ethereum (1) | MarginPool | `0x684404F2AEBAD87a6803F13741B1d638Bfe2C671` |
| Ethereum | Rysk | `0x7A3dDEac7A0AE6dfA9391C764499A3564F3c2AAd` |
| Ethereum | MMarket | `0xc01c9EF5de5862354adD9501a29e8765cFF01c32` |

Live reads (HyperEVM block 48,164,311): MarginPool holds 10,305,400.00003 USDC
(`0xb88339CB7199b77E23DB6E890353E22632Ba630f`) + 3,446,022.500105 USD₮0
(`0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb`) ≈ $13.75M. Ethereum MarginPool: 1,907,750 USDC ≈ $1.91M.
DefiLlama `rysk-v12` = $35.25M — find where the difference is (other tokens? option collateral elsewhere?
MMarket? "Rysk Premium" products?) and reconcile before quoting a number.

Finding context: "non-ERC4626 vaults, unverified source, 3-of-5 Safe" — check whether source is verified
via Etherscan V2 (chainid 999 and 1); if unverified, decompile (e.g. `heimdall`/`panoramix` if available,
or bytecode-level function-selector analysis) and say so. Find the owner: likely a 3-of-5 Safe — identify
it, check modules/guard/threshold, and who the signers are (public info only).

## Required audit surfaces

1. **Vault/collateral math**: how deposits/withdrawals and collateral locking work (non-ERC4626);
   share accounting if any; settlement at expiry; premium transfer; who can trigger settlement and where
   the money goes. Look for: rounding, donation, first-depositor, forced settlement, expired-option drains.
2. **RFQ settlement path**: makers sign quotes? Verify signature validation (who can call execute/settle,
   what binds a quote to amounts/recipient). Any unprivileged path that moves collateral to a caller?
3. **Admin/upgrade**: owner, upgradeability (EIP-1967), pausing, fee withdrawal, rescue functions.
4. **Cross-chain reconciliation**: HyperEVM + Ethereum totals; verify each token balance of every
   Rysk-related contract (MarginPool, Rysk, MMarket; also check for other pools/vaults in docs/app).
5. **Latent vs live**: if the extraction requires an admin action, quantify separately (P) and say what
   state change would arm it.

## Deliverable

- `analysis/rysk/REPORT.md` + evidence JSONs (`analysis/rysk/`).
- PoC in `poc-rysk/test/`: fork tests on HyperEVM and Ethereum. For every candidate path: execute on fork
  or prove the gate with the live value. Negative results table mandatory.
- CI: `bash /home/heisenberg/CA/ci/ci-run.sh high-cluster`; your log `ci-out/poc-rysk.log`.
- Exact block numbers; E-U/H-O/P/S split with amounts + USD; confidence; coverage statement.
