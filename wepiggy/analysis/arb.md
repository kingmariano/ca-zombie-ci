# WePiggy — Arbitrum One (chainid 42161) deployment, full market state

**Snapshot:** block **512,965,180** (2026-10-08 ~18:32 UTC), via `https://arb1.arbitrum.io/rpc` + `https://arbitrum-one.public.blastapi.io` (read-only eth_call only).

## How the comptroller was found

1. **DefiLlama registry** — `registries/compound.js` in DefiLlama-Adapters (raw GitHub) has the fork's per-chain registry:
   `arbitrum: { comptroller: '0xaa87715E858b482931eB2f6f92E504571588390b', cether: '0x17933112E9780aBd0F27f2B7d9ddA9E840D43159' }`.
   (Same comptroller address also appears for okexchain/harmony — same deployer+nonce pattern, different proxy bytecode per chain; Ethereum's `0x0C8c1ab0…` is not the Arbitrum one.)
2. **On-chain confirmation:**
   - `getAllMarkets()` returns 6 markets, first = `0x17933112…` = registry's cether → matches.
   - `pETH.comptroller()` returns `0xaa87715E858b482931eB2f6f92E504571588390b` → definitive.
   - `pETH.symbol()` = `pETH`, `underlying()` reverts (native-token market, expected).
3. Dead ends: `github.com/WePiggy/wepiggy-contracts` `networks.js` has no Arbitrum entry (repo is Ethereum-era); `arbiscan.io` returned HTTP 403 to non-browser clients; WePiggy docs/app not needed once on-chain confirmation passed.

## Deployment facts

| Item | Value |
|---|---|
| Comptroller (Unitroller proxy) | `0xaa87715E858b482931eB2f6f92E504571588390b` |
| Oracle | `0x04d2944394b70d6e56fcf1cad3aa6b5a43ec8a5c` |
| Owner (fork-specific; `admin()` reverts) | `0x46d7090ba5acfe0e2f83ec012ddfcdb5a3af7f48` |
| pauseGuardian | `0xeb0908806595d06643e15ad9af62dfd0653b570c` |
| closeFactor / liquidationIncentive | 0.5 / 1.08 |
| Markets | 6, all `isListed = true` |
| Last interest accrual (`accrualBlockNumber`) | ~26.12M → **2022-09-23** (markets dormant ~4 years) |

**ABI note (important for tooling):** this WePiggy fork renames the Compound pause getters — `pTokenMintGuardianPaused(address)=0x7a617e26`, `pTokenBorrowGuardianPaused(address)=0xb41dcb58`, `transferGuardianPaused()=0x87f76303` (source: `wepiggy-contracts/contracts/comptroller/ComptrollerStorage.sol`). Standard Compound selectors (`mintGuardianPaused`, `borrowGuardianPaused`, `admin`, `comptrollerImplementation`) **revert** on this deployment and were read with the correct selectors instead.

## Markets (all 6, at block 512,965,180)

Token units; USD = DefiLlama prices (oracle prices in parentheses, all within ~1% of DefiLlama). Supply value = `totalSupply * exchangeRateStored / 1e18`.

| Symbol | cToken | Cash | Supply value | Borrows | Reserves | CF | mint/borrow paused | borrowCap | Oracle price |
|---|---|---|---|---|---|---|---|---|---|
| pETH | `0x17933112…d43159` | 11.0830 ETH ($26,989) | 3.3651 ETH ($8,195) | 0.0688 ETH | 7.7868 ETH | 0.80 | false / false | 0 | $2,436.73 |
| pWBTC | `0x3393cd22…ca48a1` | 0.337018 WBTC ($27,368) | 0.234588 WBTC ($19,050) | 0.002254 WBTC | 0.104684 WBTC | 0.80 | false / false | 0 | $81,222.86 |
| pUSDC | `0x2bf852e2…17786b` | 12,169.32 USDC ($12,165) | 6,440.42 USDC ($6,438) | 2,017.09 USDC | 7,745.998 USDC | 0.90 | false / false | 0 | $0.9999 |
| pUSDT | `0xb65ab7e1…6f007c` | 11,278.03 USDT ($11,270) | 9,202.26 USDT ($9,196) | 1,970.73 USDT | 4,046.50 USDT | 0.90 | false / false | 0 | $0.9992 |
| pLINK | `0x8f87c9c6…90ccc7` | 115.5807 LINK ($1,430) | 23.7542 LINK ($294) | 3.9853 LINK | 95.8118 LINK | 0.60 | false / false | 0 | $12.2859 |
| pDAI | `0xde39adfb…5f1905` | 3,738.29 DAI ($3,738) | 2,033.63 DAI ($2,034) | 891.372 DAI | 2,596.03 DAI | 0.90 | false / false | 0 | $0.9996 |

**Totals (DefiLlama prices):** cash ≈ **$82,961**, supply claims ≈ $45,206, borrows ≈ $5,277, reserves ≈ $43,032. (DefiLlama reports Arbitrum TVL $84,313 — consistent.)

`transferGuardianPaused = false`, `seizeGuardianPaused = false`; all per-market mint/borrow pauses false; all borrowCaps 0 (uncapped).

## Donation-candidate analysis (Hundred-Finance empty-market class)

**None.** No market is empty or near-empty:

- Every market has non-zero `totalSupply` (smallest: pLINK, `totalSupply = 113,254,229,008` raw = 1,132.54 pLINK, supply value **$293.92** against cash **$1,430.13** — the only market with supply value under $1k, but still far from the ≈0 needed to make a donation-inflation attack profitable; and the attacker would have to already own the float for a donation to profit them).
- pETH ($8.2k supply vs $27.0k cash) and pWBTC ($19.1k vs $27.4k) are the next-smallest supply/cash ratios; all others ≥0.5.
- **No pending/unaccrued donation:** for every market, `(cash + borrows − reserves) × 1e18 / totalSupply` equals `exchangeRateStored` exactly (delta = 0.0 at 12 dp), so no one has donated underlying without the exchange rate catching up.
- Markets have been dormant since 2022-09-23 (accrual block ~26.12M vs current 512.97M); oracle prices are still live and current, but no protocol interaction has occurred for ~4 years.
- Note: in pETH/pLINK/pDAI/pUSDC, most cash belongs to **reserves** (admin) rather than depositors.

**Closest watch-list entry if the parent case needs one:** pLINK — cash 115.5807 LINK ($1,430.13), supply value 23.7542 LINK ($293.92), CF 0.60, unpaused, borrowCap 0, last accrual 2022-09-23. Not exploitable in the empty-market class as-is (non-zero supply, consistent exchange rate).

## Files

- `arb-markets.json` — raw helper dump (all getters, per-market raw integers), patched with corrected pause getters + owner.
- `arb-summary.json` — derived token-unit/USD values, consistency deltas, candidate flags.
- `enum_chunked.py` — chunked-batch driver (public RPC 429-safe), read-only.

Read-only throughout: `eth_call` / `eth_getStorageAt` only; no signing, no transactions.
