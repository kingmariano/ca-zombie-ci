#!/usr/bin/env python3
"""Generate the main table + summary.json from ci-out/results.json."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "ci-out", "results.json")))
rows = res["rows"]

# manual per-row display metadata (custody summary + evidence line)
EXTRA = {
 "fiamma": ("Fiamma BitVM2 bridge federation (BTC custody not published)", "bridge-api.fiammachain.io HTTP 522; fiammachain.io DNS dead; adapter last good 2026-03-18"),
 "bluemove-dex": ("AMM pools of 0x3f2d9f72...; stable-swap pools of 0x5a7eca40...", "Sui dynamic-field enumeration at latest checkpoint"),
 "jediswap-v1": ("factory 0xdad44c13... + all pair reserves", "Starknet get_all_pairs + get_reserves (balanceOf-verified layout)"),
 "10kswap": ("factory 0x1c0a36e2... + all pair reserves", "Starknet allPairsLength/allPairs/getReserves"),
 "sft-protocol": ("lending pool 0x147122D1EBdA76E4910ccdC53aEb6a58605Eb58E", "Filecoin eth_getBalance; miner enumeration API ww8.sftproject.io DNS-dead"),
 "armada": ("program ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d (24 CLP vaults + token vaults)", "getProgramAccounts (disc account:ClpVault) + vault token accounts"),
 "dojoswap-amm": ("factory inj1pc2vxcmnyzawnwkf03n2ggvt997avtuwagqngk + pair pools", "Injective LCD terraswap pairs + pool queries"),
 "ergodex": ("P2S contract 5vSUZRZbdVbnk4sJWjg2uhL94VZWRg4iatK9VgMChufz...", "Ergo explorer balance/total (unspent boxes)"),
 "hliquity": ("troveManager 0x...5c9f66 -> activePool 0x...5c9f0b; staking 0x...5c9f30", "Hedera Hashio eth_call/eth_getBalance"),
 "shadelend": ("Lend Vault Registry V3 secret1wj2czeeknya2n6jag7kpfxlm28dw7q96dgqmfs; Stability Pool secret1wdxqz26...", "securesecrets API DNS-dead; all public Secret LCD/RPC dead"),
 "jet-v1": ("vault authority 7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8 (21k token accounts)", "Solana getTokenAccountsByOwner/getProgramAccounts"),
 "lenfi": ("9 v1/v2 script addresses + LENFI staking addr (aada adapter)", "Koios address_info + address_assets at tip"),
 "caviarnine-lsu-pool": ("component_rdx1cppy08xgra5tv5melsjtj79c0ngvrlmzl8hhs7vwtzknp9xxs63mfp (82 LSU resources)", "Radix Gateway entity details + LSU->XRD redemption"),
 "omm": ("lending pool data provider cx5f9a6ca11b2b761a469965cedab40ada9e503cb5", "ICON ctz.solidwallet.io getAllReserveData"),
 "taiga-acala": ("Acala module account 23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9 (tapio)", "Acala RPC orml Tokens.Accounts storage keys"),
 "01": ("vault owner HjHSNe8hhvZ8hKCRrhKg1DGiGPd9NYQbUjT1SQRDo4kZ", "Solana getTokenAccountsByOwner (34 accounts)"),
 "ocean-one": ("Ocean One Mixin app custody (address not public)", "events.ocean.one DNS dead; adapter TVL source dead since 2024-01-21"),
 "moria-protocol": ("loan contract rvtgwvmtp4hy5k9alcwc5yt69k4jnshevdwapq43w7hp8m7hwj60szuun6naf", "BCH Fulcrum get_balance/listunspent (6 servers) + history"),
 "margined-protocol": ("10 Osmosis + 8 Neutron vault contracts", "CosmWasm LCD info/total_assets (Osmosis publicnode, Neutron polkachu)"),
 "suidollar-basis": ("USDC vault (package not published; 0x0 placeholder in repo)", "suidollar.io DNS dead; DefiLlama sunset 2025-10-21"),
 "hashmix-fil": ("pool 0x587A7eaE9b461ad724391Aa7195210e0547eD11d", "Filecoin eth_getBalance; fvm.hashmix.org API 502"),
 "fountain-protocol": ("3 comptrollers: 0xA7684aE7.., 0x1C0C3079.., 0x7c4d0c83..", "Oasis Emerald eth_call getAllMarkets/getCash/totalBorrows"),
}

def ev_line(r):
    e = r.get("evidence", {})
    parts = []
    for k in ("block", "ledger_state", "pairs", "pair_count", "pairs_parsed", "amm_pools_parsed",
              "vaults", "accounts", "confirmed_sats", "history_entries", "pool_fil", "total_lovelace",
              "cash_usd_contract_oracle", "discriminator_seed"):
        if e.get(k) is not None:
            parts.append(f"{k}={e[k]}")
    for k in ("reserves", "fungibles", "market_detail", "orml_tokens_scaled", "lsu_redemption",
              "comptrollers", "cash_plus_borrows_by_market"):
        if k in e and hasattr(e[k], "__len__"):
            parts.append(f"{k}:{len(e[k])}")
    return ", ".join(parts)

out = []
out.append("| # | Protocol | Chain | Status | Live custody $ | Key custody accounts/contracts | Evidence (latest) | Conf |")
out.append("|---|---|---|---|---|---|---|---|")
ranked = sorted(rows, key=lambda r: -(r.get("live_usd") or 0))
for i, r in enumerate(ranked, 1):
    usd = r.get("live_usd")
    usd_s = f"${usd:,.0f}" if usd and usd >= 1 else ("$0" if not usd else f"${usd:,.2f}")
    cust, ev = EXTRA.get(r["slug"], ("; ".join(r.get("custody", [])), ev_line(r)))
    if ev_line(r) and ev is None:
        ev = ev_line(r)
    status = r["status"].replace("LIVE-FUNDED", "**LIVE-FUNDED**").replace("DRAINED", "DRAINED/$0")
    out.append(f"| {i} | {r['protocol']} | {r['chain']} | {status} | {usd_s} | {cust} | {ev} | {r['confidence']} |")

md = "\n".join(out)
open(os.path.join(ROOT, "analysis", "table.md"), "w").write(md)
print(md)
