#!/usr/bin/env python3
"""Assemble state.json + REPORT.md from raw evidence files.

Read-only wrt chain; writes state.json and REPORT.md in this directory.
"""
import json
import os
from datetime import datetime, timezone

D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw")

CHAINS = {
    "base": dict(id=8453, dec=6, token="USDC",
                 diamond="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43",
                 mas=["0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86"],
                 explorer="blockscout"),    "arb": dict(id=42161, dec=6, token="USDC",
                diamond="0x8F06459f184553e5d04F07F868720BDaCAB39395",
                mas=["0x141269E29a770644C34e05B127AB621511f20109"],
                explorer="etherscan"),
    "mantle": dict(id=5000, dec=18, token="USDe",
                   diamond="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5",
                   mas=["0xECbd0788bB5a72f9dFDAc1FFeAAF9B7c2B26E456"],
                   explorer="etherscan"),
    "blast": dict(id=81457, dec=18, token="USDB",
                  diamond="0x3d17f073cCb9c3764F105550B0BCF9550477D266",
                  mas=["0x083267D20Dbe6C2b0A83Bd0E601dC2299eD99015",
                       "0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e"],
                  explorer="etherscan"),
}

PAUSE_NAMES_9 = ["globalPaused", "liquidationPaused", "accountingPaused",
                 "partyBActionsPaused", "partyAActionsPaused", "internalTransferPaused",
                 "externalTransferPaused", "emergencyMode", "partyBOpenPositionsPaused"]
PAUSE_NAMES_7 = ["globalPaused", "liquidationPaused", "accountingPaused",
                 "partyBActionsPaused", "partyAActionsPaused", "internalTransferPaused",
                 "emergencyMode"]


def load(name, default=None):
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        return default
    with open(p) as f:
        return json.load(f)


def h(x, dec):
    if x is None:
        return None
    return round(x / 10 ** dec, 9)


def main():
    state = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "campaign": "IntentX / SYMMIO live state reconstruction (read-only)",
        "notes": [
            "All amounts in human units. SYMMIO internal accounting is 18-dec; token balances use token decimals.",
            "Deposit/withdraw event amounts are in collateral token decimals.",
        ],
        "chains": {},
    }
    for chain, cfg in CHAINS.items():
        dec = cfg["dec"]
        st = load(f"static_{chain}.json", {})
        agg = load(f"agg_{chain}.json", {})
        acc = load(f"accounts_{chain}.json")
        roles = load(f"roles_{chain}.json", {})
        c = {"chain_id": cfg["id"], "collateral": cfg["token"], "collateral_decimals": dec,
             "diamond": cfg["diamond"], "multiaccounts": cfg["mas"],
             "blocks": {"static": st.get("block"), "accounts": (acc or {}).get("block"),
                        "roles": roles.get("block")}}
        mas_extra = load(f"intentx_mas_{chain}.json")
        if mas_extra:
            c["multiaccounts"] = mas_extra["mas"]
        if acc and acc.get("diamond_lifetime"):
            c["diamond_lifetime_events"] = acc["diamond_lifetime"]
        dv = st.get("diamond_views", {})
        pause = dv.get("pauseState_9") or dv.get("pauseState")
        pnames = PAUSE_NAMES_9 if dv.get("pauseState_9") else PAUSE_NAMES_7
        c["pause_state"] = dict(zip(pnames, pause)) if pause else None
        c["config"] = {
            "owner": dv.get("owner"), "pending_owner": dv.get("pendingOwner"),
            "liquidation_timeout": dv.get("liquidationTimeout"),
            "liquidator_share": h(dv.get("liquidatorShare"), 18),
            "balance_limit_per_user": h(dv.get("getBalanceLimitPerUser"), 18),
            "pending_quotes_valid_length": dv.get("pendingQuotesValidLength"),
            "cooldowns_of_ma_raw": dv.get("coolDownsOfMA"),
            "cooldowns_of_ma_names": ["withdrawCooldownPeriod_s", "forceCancelCooldown_s",
                                      "forceCancelCloseCooldown_s", "forceCloseFirstCooldown_s"],
            "is_cross_partyB_mode": dv.get("isCrossPartyBModeActivated"),
            "getMuonIds": dv.get("getMuonIds"),
            "getFeeCollector_fn": dv.get("getFeeCollector"),
            "fee_collector_from_events": agg.get("fee_collector_latest"),
            "fee_collector_events": agg.get("fee_collector_events"),
            "diamond_native_balance_wei": (st.get("balances") or {}).get("diamond_native"),
            "diamond_collateral_balance_token": h((st.get("balances") or {}).get("diamond_collateral"), dec),
        }
        c["collateral_token"] = st.get("collateral_token")
        c["multiaccount_state"] = st.get("multiaccounts")
        c["extra_token_balances"] = st.get("extra_token_balances")
        # coverage / events
        c["event_coverage"] = agg.get("counts")
        dep = agg.get("deposits", {})
        wd = agg.get("withdrawals", {})
        c["event_totals"] = {
            "deposited_token": h(sum(r.get("deposit_units", 0) for r in dep.values()), dec),
            "withdrawn_token": h(sum(r.get("withdraw_units", 0) for r in wd.values()), dec),
            "deposit_accounts": len(dep), "withdraw_accounts": len(wd),
            "accounts_created": len(agg.get("accounts", {})),
        }
        # partyB list
        pb_list = []
        if acc:
            for pb in acc.get("partyB_registered", []):
                info = (acc.get("partyB_status") or {}).get(pb, {})
                alloc = ((acc.get("partyB_allocations") or {}).get(pb) or {}).get("total")
                pb_list.append({
                    "partyB": pb,
                    "isPartyB": info.get("isPartyB"),
                    "emergency": info.get("emergency"),
                    "is_cross": info.get("is_cross"),
                    "reserve_vault": h(info.get("reserve_vault"), 18),
                    "allocated_total_token": h(alloc, 18),
                    "allocated_total_units18": alloc,
                })
        c["partyB"] = pb_list
        # top partyA
        top = []
        if acc:
            det = acc.get("top_details", {})
            ranked = sorted(det.items(), key=lambda kv: -((kv[1].get("free") or 0) + (kv[1].get("allocated") or 0)))[:60]
            for a, d in ranked:
                bi = d.get("balance_info") or {}
                top.append({
                    "account": a, "user": d.get("user"), "name": d.get("name"),
                    "free": h(d.get("free"), 18), "allocated": h(d.get("allocated"), 18),
                    "locked_total": h(sum(bi.get(k, 0) for k in
                                          ("locked_cva", "locked_lf", "locked_partyAmm", "locked_partyBmm")), 18),
                    "pending_locked_total": h(sum(bi.get(k, 0) for k in
                                                  ("pending_cva", "pending_lf", "pending_partyAmm", "pending_partyBmm")), 18),
                    "deposit_token": h(d.get("deposit_units"), dec),
                    "withdraw_token": h(d.get("withdraw_units"), dec),
                    "positions_count": d.get("positions_count"),
                    "quotes_length": d.get("quotes_length"),
                    "is_liquidated": d.get("is_liquidated"),
                    "is_suspended": d.get("is_suspended"),
                    "withdraw_cooldown_ts": d.get("withdraw_cooldown"),
                })
        c["top_partyA"] = top
        # reconciliation
        if acc:
            free_t = acc.get("free_total")
            alloc_t = acc.get("allocated_total")
            pb_t = acc.get("partyB_allocated_total")
            diamond_bal_token = h(acc.get("diamond_collateral_balance"), dec)
            diamond_bal18 = acc.get("diamond_collateral_balance")
            if diamond_bal_token is not None:
                diamond_bal18 = int(round(diamond_bal_token * 10 ** 18))
            recon = {
                "sum_free_18": free_t, "sum_allocated_18": alloc_t,
                "sum_partyB_allocated_18": pb_t,
                "sum_partyA_free_alloc_token": h((free_t or 0) + (alloc_t or 0), 18),
                "sum_partyB_allocated_token": h(pb_t, 18),
                "diamond_collateral_balance_token": diamond_bal_token,
                "diamond_collateral_balance_18": diamond_bal18,
                "unaccounted_18": (diamond_bal18 - ((free_t or 0) + (alloc_t or 0) + (pb_t or 0)))
                if diamond_bal18 is not None else None,
                "unaccounted_token": h((diamond_bal18 - ((free_t or 0) + (alloc_t or 0) + (pb_t or 0)))
                                       if diamond_bal18 is not None else None, 18),
                "partyB_alloc_errors": acc.get("partyB_alloc_errors"),
            }
            c["reconciliation"] = recon
        # live roles
        c["roles"] = {
            "live": roles.get("live_role_holders"),
            "candidate_roles": roles.get("candidate_roles"),
        }
        # recent flows
        flows = load(f"{chain}_diamond_tokentx_recent.json")
        if flows:
            outs = {}
            ins = {}
            for x in flows:
                v = int(x["value"]) / 10 ** int(x["tokenDecimal"])
                if x["from"].lower() == cfg["diamond"].lower():
                    outs[x["to"]] = outs.get(x["to"], 0) + v
                if x["to"].lower() == cfg["diamond"].lower():
                    ins[x["from"]] = ins.get(x["from"], 0) + v
            c["recent_transfers"] = {
                "count": len(flows),
                "window": [flows[-1].get("timeStamp"), flows[0].get("timeStamp")],
                "top_out": sorted(outs.items(), key=lambda kv: -kv[1])[:15],
                "top_in": sorted(ins.items(), key=lambda kv: -kv[1])[:10],
            }
        state["chains"][chain] = c

    state["extras_base"] = load("extras_base.json")
    state["fee_collector_balances"] = load("fee_collectors.json")
    state["partyB_owners"] = load("partyB_owners.json")
    state["ma_emitters_base"] = load("ma_emitters_base.json")
    state["working_tree_note"] = (
        "This worktree was relocated by the orchestrator from /home/heisenberg/CA/intentx to "
        "/tmp/opencode/ca-zombie-ci-intentx/intentx during collection; all raw evidence is in "
        "analysis/state/raw/.")
    state["solver_vault"] = {
        "proxy": "0x7785fE35F6510D111063579AA14F7D28aD84512A",
        "implementation_current": "0x0b2e5F8e002BC88a18fC85f69F7B7864bB5B7bfD",
        "lp_token": "0xB6d340Af68279326402139C30934317929535D32",
        "solver": "0xB49Cae38c96f6425Ce4A46e8220549C6a13362bE",
        "collateral": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        "depositLimit_token": 200000, "currentDeposit_token": 0, "lockedBalance": 0,
        "lp_token_totalSupply": 0, "usdc_balance": 0, "withdrawal_period_s": 604800,
        "deployer": "0xf1d63df1CD64a3f3A8F440bAba619dbB4baBB020",
        "source_repo": "github.com/Intent-X/solver-deposit-vault",
    }
    with open(os.path.join(D, "state.json"), "w") as f:
        json.dump(state, f, indent=1, default=str)

    # ---- REPORT.md ----
    L = []
    A = L.append
    A("# IntentX (SYMMIO) — Live On-Chain State & Accounting Reconstruction")
    A("")
    A(f"Generated: {state['generated_at']}  ")
    A("Method: read-only RPC (`eth_call`, `eth_getLogs` via Multicall3), Blockscout & Etherscan V2 & GoldRush log APIs. "
      "No transactions were signed or sent.")
    A("")
    A("## Executive summary")
    A("")
    A("| chain | diamond | diamond collateral | partyA free+allocated | partyB allocated | unaccounted | paused? |")
    A("|---|---|---|---|---|---|---|")
    for chain, c in state["chains"].items():
        r = c.get("reconciliation") or {}
        ps = c.get("pause_state") or {}
        paused = "nothing paused" if ps and not any(ps.values()) else \
                 (", ".join(k for k, v in ps.items() if v) if ps else "n/a")
        A(f"| {chain} | `{c['diamond']}` | {(r.get('diamond_collateral_balance_token') if r else None):,} {c['collateral']} "
          f"| {(r.get('sum_partyA_free_alloc_token') if r else None):,} | {(r.get('sum_partyB_allocated_token') if r else None):,} "
          f"| {(r.get('unaccounted_token') if r else None):,} | {paused} |"
          if r else f"| {chain} | `{c['diamond']}` | pending | pending | pending | pending | {paused} |")
    A("")
    A("## Per-chain detail")
    for chain, c in state["chains"].items():
        A(f"### {chain} (chain id {c['chain_id']}, collateral {c['collateral']})")
        A("")
        A(f"- Blocks read: static={c['blocks'].get('static')}, accounts={c['blocks'].get('accounts')}, roles={c['blocks'].get('roles')}")
        ps = c.get("pause_state")
        A(f"- pauseState: {json.dumps(ps)}")
        cfg = c.get("config") or {}
        A(f"- owner: `{cfg.get('owner')}`; liquidationTimeout={cfg.get('liquidation_timeout')}s; "
          f"liquidatorShare={cfg.get('liquidator_share')}; balanceLimitPerUser={cfg.get('balance_limit_per_user')}; "
          f"crossPartyBMode={cfg.get('is_cross_partyB_mode')}")
        A(f"- cooldownsOfMA {cfg.get('cooldowns_of_ma_names')}: {cfg.get('cooldowns_of_ma_raw')}")
        A(f"- feeCollector (from SetFeeCollector events): `{cfg.get('fee_collector_from_events')}` "
          f"events={json.dumps(cfg.get('fee_collector_events'))}")
        A(f"- diamond native balance: {cfg.get('diamond_native_balance_wei')} wei")
        A(f"- event coverage: {json.dumps(c.get('event_coverage'))}")
        et = c.get("event_totals")
        if et:
            A(f"- lifetime deposited (events): {et['deposited_token']:,} {c['collateral']}; withdrawn: {et['withdrawn_token']:,} {c['collateral']}")
        dl = c.get("diamond_lifetime_events")
        if dl:
            A(f"- diamond-own events (all funding paths): deposits {dl['deposit_token']:,} {c['collateral']} "
              f"({dl['deposit_count']} events), withdrawals {dl['withdraw_token']:,} "
              f"({dl['withdraw_count']} events), through block {dl['events_latest_block']}")
        r = c.get("reconciliation")
        if r:
            A("")
            A("**Reconciliation (all values in token units, 1:1 to USD)**")
            A("")
            A(f"| item | value |")
            A(f"|---|---|")
            A(f"| diamond collateral balance | {r['diamond_collateral_balance_token']:,} |")
            A(f"| sum partyA free (all {r.get('free_accounts','?')} accounts) | {h(r['sum_free_18'], cfg_dec(chain)):,} |")
            A(f"| sum partyA allocated | {h(r['sum_allocated_18'], cfg_dec(chain)):,} |")
            A(f"| sum partyB allocated | {r['sum_partyB_allocated_token']:,} |")
            A(f"| **unaccounted (protocol/fees/liquidator residual)** | **{r['unaccounted_token']:,}** |")
            A("")
        pbs = c.get("partyB") or []
        if pbs:
            A("**PartyB (hedgers) with live allocated balances**")
            A("")
            A("| partyB | isPartyB | allocated total | emergency | reserve vault |")
            A("|---|---|---|---|---|")
            for p in pbs:
                A(f"| `{p['partyB']}` | {p['isPartyB']} | {(p['allocated_total_token'] or 0):,} | {p['emergency']} | {p['reserve_vault']} |")
            A("")
        tps = c.get("top_partyA") or []
        if tps:
            A(f"**Top partyA accounts by live free+allocated ({len(tps)})**")
            A("")
            A("| account | user | name | free | allocated | deposit(lifetime) | withdraw(lifetime) | positions | liquidated |")
            A("|---|---|---|---|---|---|---|---|---|")
            for t in tps[:30]:
                A(f"| `{t['account']}` | `{t['user']}` | {t.get('name') or ''} | {(t['free'] or 0):,.4f} | {(t['allocated'] or 0):,.4f} "
                  f"| {(t['deposit_token'] or 0):,.2f} | {(t['withdraw_token'] or 0):,.2f} | {t['positions_count']} | {t['is_liquidated']} |")
            A("")
        rl = (c.get("roles") or {}).get("live")
        if rl:
            A("**Live roles (hasRole at pinned block)**")
            A("")
            A("| role | holder | grant block |")
            A("|---|---|---|")
            for x in rl:
                A(f"| {x['role']} | `{x['user']}` | {x['grant_block']} |")
            A("")

    A("## Solver deposit vault (OnChainSymmioVault/OnChainSymmioVaultV2)")
    A("")
    sv = state["solver_vault"]
    A(f"- proxy `{sv['proxy']}` (current impl `{sv['implementation_current']}`), solver/hedger `{sv['solver']}`")
    A(f"- LP token `{sv['lp_token']}` (smUSD): totalSupply=0, USDC in vault=0, currentDeposit=0, depositLimit=200,000")
    A("- Conclusion: the solver deposit vault is empty and no LP claims exist on-chain; nothing withdrawable there.")
    A("")
    A("## Auxiliary contracts on Base")
    A("")
    eb = state.get("extras_base") or {}
    if eb:
        A("| name | address | USDC | INTX | native ETH |")
        A("|---|---|---|---|---|")
        for n, i in (eb.get("contracts") or {}).items():
            A(f"| {n} | `{i['address']}` | {h(i.get('usdc'), 6)} | {h(i.get('intx'), 18)} | {h(i.get('native_balance'), 18)} |")
        A("")
    A("## Recent diamond outflows (protocol funds leaving)")
    A("")
    for chain, c in state["chains"].items():
        rt = c.get("recent_transfers")
        if not rt:
            continue
        A(f"### {chain} — last {rt['count']} transfers (timestamps {rt['window'][0]}..{rt['window'][1]})")
        A("")
        A("| recipient | amount |")
        A("|---|---|")
        for a, v in rt["top_out"]:
            A(f"| `{a}` | {v:,.4f} |")
        A("")
    A("## What a normal user can still withdraw")
    A("")
    for chain, c in state["chains"].items():
        ps = c.get("pause_state") or {}
        r = c.get("reconciliation") or {}
        ws = load(f"withdraw_sim_{chain}.json")
        A(f"### {chain}")
        A("")
        A(f"- pause flags blocking accounting/withdrawals: "
          f"{', '.join(k for k, v in ps.items() if v) if ps else 'n/a'}"
          f"{' (none)' if ps and not any(ps.values()) else ''}")
        if r:
            A(f"- partyA free balances (immediately withdrawable, before cooldown checks): "
              f"{h(r.get('sum_free_18'), cfg_dec(chain)):,} {c['collateral']}")
        A(f"- withdrawal path: user EOA (owner of the partyA account) -> "
          f"MultiAccount[{'/'.join(c['multiaccounts'])}].withdrawFromAccount(account, amount) -> partyA account -> diamond.withdrawTo(owner, amount).")
        A(f"- deallocate/withdraw cooldown: {c['config'].get('cooldowns_of_ma_raw')} "
          f"={dict(zip(c['config'].get('cooldowns_of_ma_names') or [], c['config'].get('cooldowns_of_ma_raw') or []))}")
        if ws:
            for s in ws["samples"][:4]:
                tests = s.get("tests") or []
                first = tests[0] if tests else {}
                A(f"- simulated withdrawFromAccount for `{s['account']}` (free {s['free_token']:,.4f}) from owner `{s['owner']}`: "
                  f"{'would SUCCEED' if first.get('ok') else 'REVERTED: ' + str(first.get('ret'))[:120]}")
        else:
            A("- (withdraw simulation not available yet)")
        A("")
    A("## Methodology & coverage")
    A("")
    A("- Base MultiAccount discovery: all `DepositForAccount`/`WithdrawFromAccount` emitters were enumerated via full-range "
      "`eth_getLogs`, then filtered to those targeting the IntentX diamond (`symmioAddress()`) or observed as " 
      "`Deposit`-event senders on the diamond; 22 MultiAccount proxies remain (see state.json `multiaccounts`).")
    A("- Account universe: union of (a) all partyA accounts seen in MA `AddAccount`/`DeployContract` events, "
      "(b) users in the diamond's `Deposit(sender,user,amount)`/`Withdraw(sender,user,amount)` events for the full chain history.")
    A("- Lifetime deposit/withdraw totals per account come from the diamond's own deposit/withdraw events (all funding paths).")
    A("- All balance reads use pinned blocks (see `blocks` per chain in state.json).")
    A("- Residual = diamond collateral balance - (partyA free + partyA allocated + partyB allocated). "
      "It includes protocol fees, liquidator shares retained in the diamond, and any rounding.")
    A("")
    with open(os.path.join(D, "REPORT.md"), "w") as f:
        f.write("\n".join(L))
    print("state.json and REPORT.md written")


def cfg_dec(chain):
    return CHAINS[chain]["dec"]


if __name__ == "__main__":
    main()
