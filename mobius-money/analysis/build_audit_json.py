#!/usr/bin/env python3
"""Build gauges-audit.json from locally cached live reads (no network)."""
import json

A = "."
CASES = [
    ("0xdAA2ab880b7f3D5697e6F85e63c28b9120AA9E07", "0xd7bf6946b740930c60131044bd2f08787e1ddbd4", "MobLP", ["CELO"]),
    ("0xD38e76E17E66b562B61c149Ca0EE53CEa1145733", "0x846b784ab5302155542c1b3952b54305f220fd84", "MobLP", []),
    ("0x1A8938a37093d34581B21bAd2AE7DC1c19150C05", "0x8cd0e2f11ed2e896a8307280deeee15b27e46bbe", "MobLP", []),
    ("0xd1B3C05FE24bda6F52e704daf1ACBa8c440d8573", "0x635aec36c4b61bac5eb1c3eee191147d006f8a21", "MobLP", ["CELO"]),
    ("0xe2d6095685248F38Ae9fef1b360D772b78Ea19D1", "0xc7a4c6ef4a16dc24634cc2a951ba5fec4398f7e0", "MobLP", []),
    ("0x52517feb1Fc6141d5CF6718111C7Cc0FD764fA5d", "0xf5b454cf47caca418d95930aa03975ee4bf409bc", "MobLP", ["CELO"]),
    ("0x27D9Bfa5F864862BeDC23cFab7e00b6b94488CC6", "0xafee90ab6a2d3b265262f94f6e437e7f6d94e26e", "MobLP", ["CELO"]),
    ("0x1A648004d8AB84eE34d2D1cd2F2A7a7828D6939F", "0x68095d768b3c78919c6048f52cc68267ad2b37fd", "MobLP", []),
    ("0x1250D6dd3B51D20c14a8ECb10CC2dd713967767e", "0x57f008172cf89b972db3db7dd032e66be4af1a8c", "mobLP", ["POOF", "MOO"]),
    ("0xCF34F4ec5DC9E09428A4f4a45475f6277694166c", "0x2642ab16bfb7a8b36ee42c9cba2289c4ca9f33b9", "MobLP", ["POOF", "MOO"]),
    ("0x5489b2F0A1992b889F47601D71E068Fd15c63f26", "0x4d6b17828d0173668e8eb730106444556a98c0f9", "MobLP", ["POOF", "MOO"]),
    ("0x2459BDb59a3BF6Ab6C412Ac0b220e7CDA1D4ea26", "0x18d71b8664e69d6dd61c79247dbf12bfaaf66c10", "MobLP", ["POOF", "MOO"]),
    ("0xF2ae5c2D2D2eD13dd324C0942163054fc4A3D4d9", "0x730e677f39c4ca96012c394b9da09a025e922f81", "MobLP", []),
    ("0xc96AeeaFF32129da934149F6134Aa7bf291a754E", "0x39b6f09ef97db406ab78d869471adb2384c494e3", "MobLP", ["CELO"]),
    ("0x487c30CB18AA9Ced435911E2B414e0E85D7E52bB", "0x4ff08e2a4e7114af4b575aef9250144f95790982", "MobLP", ["CELO"]),
    ("0x127b524c74C2162Ee4BB2e42d8d2eB9050C0293E", "0x20d7274c5af4f9de6e8c93025e44af3979d9ab2b", "MobLP", ["CELO"]),
    ("0x0A125D473cd3b1968e728DDF7d424c928C09222A", "0x68b239b415970dd7a5234a9701cbb5bfab544c7c", "MobLP", ["CELO"]),
    ("0xE1f9D952EecC07cfEFa69df9fBB0cEF260957119", "0x274dd2df039f1f6131419c82173d97770e6af6b7", "MobLP", ["CELO"]),
    ("0xE965Dd2B957448CaE3291048A9944fC2F3a693D8", "0x9da9a2dafd92c41a2d03adb7255014cb341b7e59", "MobLP", []),
    ("0x73fDa87297627Fe985bc1D40c7d68868C2624D67", "0xbd8be270141cfb652c68e4c3647e7fcf8533471c", "MobLP", []),
    ("0x4E3E91b61c6cA47cF3664aA88Ee3f690e3E41185", "0xb1dd4e9ad1edcd0d4b8ee270187a1465316625b4", "MobLP", []),
    ("0xE7195E651Cc47853f0054d85c8ADFc79D532929f", "0x07e137e5605e15c93f22545868fa70cecfcbbffe", "MobLP", ["POOF", "MOO"]),
    ("0xD0d57a6689188F854F996BEAE0Cb1949FDB5FF86", "0xaffd8d6b5e5a0e25034dd3d075532f9ce01c305c", "MobLP", ["POOF", "MOO"]),
    ("0xCAEd243de23264Bdd8297c6eECcF320846eee18A", "0xec8e37876fd9de919b58788b87a078e546149f87", "MobLP", ["POOF", "MOO"]),
    ("0x107F94409746E8c8E6eFF139A100D17D9ca7FdfE", "0x9438e7281d7e3e99a9dd21e0ead9c6a254e17ab2", "MobLP", ["CELO"]),
    ("0x7ed927E685d7196Ff2e7Bc48c5cB5e8af88c9332", "0xe10fd4788a76d19ba0110b1bfda5e13d35ed4359", "MobLP", []),
    ("0x70AE7265545f001cb015399D672B85D8f2CaCA72", "0x4730ff6bc3008a40cf74d660d3f20d5b51646da0", "MobLP", []),
]
CELO = "0x471ece3750da237f93b8e339c536989b8978a438"
TOK = {
    "CELO": {"address": CELO, "dec": 18, "price": 0.09380045113532264,
             "price_src": "DefiLlama celo:0x471E.. ts 1791829384 conf 0.99"},
    "POOF": {"address": "0x00400fcbf0816bebb94654259de7273f4a05c762", "dec": 18, "price": 0.00002247,
             "price_src": "DexScreener ubeswap POOF liq $54 (2026-10-12)"},
    "MOO": {"address": "0x17700282592d6917f6a73d0bf8accf4d578c131e", "dec": 18, "price": 0.0002403,
            "price_src": "DexScreener ubeswap MOO liq $474 (2026-10-12)"},
}
GAUGE_BAL_POOMOO = {  # read at ~block 79923216-79925000 (session)
    "0x1250d6dd3b51d20c14a8ecb10cc2dd713967767e": {"POOF": 326448286969508183, "MOO": 450325235409841530},
    "0xcf34f4ec5dc9e09428a4f4a45475f6277694166c": {"POOF": 255236900083009933537, "MOO": 277361406541613519479},
    "0x5489b2f0a1992b889f47601d71e068fd15c63f26": {"POOF": 526695538627570523441, "MOO": 564122521173482621581},
    "0x2459bdb59a3bf6ab6c412ac0b220e7cda1d4ea26": {"POOF": 31384116164530422997, "MOO": 87747857024987716720},
    "0xe7195e651cc47853f0054d85c8adfc79d532929f": {"POOF": 17889455228369593665, "MOO": 24196871555388433396},
    "0xd0d57a6689188f854f996beae0cb1949fdb5ff86": {"POOF": 414792637895394764256, "MOO": 378939629827900169417},
    "0xcaed243de23264bdd8297c6eeccf320846eee18a": {"POOF": 99299291512223469378, "MOO": 65231993078347455300},
}


def main():
    raw = json.load(open(f"{A}/gauge-claims-raw.json"))
    cl = json.load(open(f"{A}/gauge-claimables-raw.json"))
    pm = json.load(open(f"{A}/gauge-claimables-poomoo.json"))
    rcb = json.load(open(f"{A}/rc_poomoo_balances_tmp.json"))
    sup = json.load(open(f"{A}/lp_supplies_tmp.json"))
    ls = json.load(open(f"{A}/live-state.json"))
    tk = json.load(open(f"{A}/tokens.json"))
    raw["gauge_calls"] = {k.lower(): v for k, v in raw["gauge_calls"].items()}
    raw["token_balances"] = {k.lower(): v for k, v in raw["token_balances"].items()}
    raw["reward_contract_calls"] = {k.lower(): v for k, v in raw["reward_contract_calls"].items()}
    by_lp = {p["lpToken"].lower(): p for p in ls["pools"].values() if p.get("lpToken")}
    dec = lambda x: int(x, 16) if isinstance(x, str) and x not in ("0x", "") else None
    def ad(x):
        if not isinstance(x, str) or x in ("0x", ""): return None
        return "0x" + x[-40:]
    out = {
        "meta": {
            "chain": "celo", "chain_id": 42220,
            "generated": "2026-10-12",
            "blocks": {"live_scan": raw.get("block"), "block_number": 79922881,
                       "claimables_participants": cl.get("block")},
            "rpc": "https://forno.celo.org (keyless, read-only)",
            "gauge_implementation": "Vyper 0.2.12 Liquidity Gauge v3 (Curve fork, 'Mobius Finance'); verified source on Blockscout, source sha256(ec0c072bc3ea87bd..) identical for 0xdAA2/0xc96A/0x107F/0x1250; GitHub mobiusAMM/mobi-dao-contracts contracts/gauges/LiquidityGaugeV3.vy",
            "prices": {k: {kk: vv for kk, vv in v.items() if kk != "address"} for k, v in TOK.items()},
        },
        "classification": {
            "E-U": [],  # attacker-profitable, unprivileged
            "H-O": [],  # only stakers/LP holders can recover
            "S": [],    # stuck / privileged-only
        },
        "gauges": {},
    }
    tot_celo = tot_poof = tot_moo = tot_usd = 0
    staked_usd = 0
    for g, lp, sym, rtoks in CASES:
        gl = g.lower()
        c = raw["gauge_calls"][gl]
        killed = dec(c["is_killed()"]) == 1
        infl = dec(c["inflation_rate()"])
        rc = ad(c["reward_contract()"])
        rcd = raw["reward_contract_calls"].get(rc.lower(), {}) if rc else {}
        entry = {
            "lp": lp, "stakedLP": str(dec(c["totalSupply()"])), "gaugeSymbol": sym,
            "killed": killed, "gaugeInflationRate": str(infl),
            "controller": ad(c["controller()"]), "minter": ad(c["minter()"]),
            "votingEscrow": ad(c["voting_escrow()"]), "admin": ad(c["admin()"]),
            "futureAdmin": ("0x6c0d6fba3bcdb224278474e8d524f19c6bb55850" if gl in (
                "0x1a648004d8ab84ee34d2d1cd2f2a7a7828d6939f", "0x1250d6dd3b51d20c14a8ecb10cc2dd713967767e",
                "0xe965dd2b957448cae3291048a9944fc2f3a693d8", "0x73fda87297627fe985bc1d40c7d68868c2624d67",
                "0x4e3e91b61c6ca47cf3664aa88ee3f690e3e41185") else (ad(c["admin()"]) if c.get("admin()") else None)),
            "lastClaim_gauge": str(dec(c["last_claim()"])),
            "rewardTokens": [], "rewardContract": None,
            "stakedLPValueUSD": None, "remainingClaimableUSD": 0.0, "notes": [],
        }
        if rc:
            entry["rewardContract"] = {
                "address": rc, "type": "Synthetix-style StakingRewards (unverified bytecode; selectors identified via 4byte)",
                "stakingToken": ad(rcd.get("stakingToken()")), "rewardsToken": ad(rcd.get("rewardsToken()")),
                "periodFinish": str(dec(rcd.get("periodFinish()"))),
                "lastUpdateTime": str(dec(rcd.get("lastUpdateTime()"))),
                "rewardRate": str(dec(rcd.get("rewardRate()"))),
                "getRewardForDuration": str(dec(rcd.get("getRewardForDuration()"))),
                "totalSupply_stakedLP": str(dec(rcd.get("totalSupply()"))),
                "gaugeStake": str(dec((rcd.get("balanceOf(gauge)") or {}).get(g))),
                "gaugeUserRewardPerTokenPaid": str(dec((rcd.get("userRewardPerTokenPaid(gauge)") or {}).get(g))),
                "rewardPerTokenStored": str(dec(rcd.get("rewardPerTokenStored()"))),
                "earned_gauge_now": "0",
                "owner": ad(rcd.get("owner()")), "rewardsDistribution": ad(rcd.get("rewardsDistribution()")),
            }
        # reward tokens
        for tname in rtoks:
            t = TOK[tname]
            item = {"symbol": tname, "address": t["address"], "priceUSD": t["price"], "priceSource": t["price_src"]}
            if tname == "CELO":
                gbal = dec(raw["token_balances"][gl]["CELO_gauge"])
                clg = cl["gauges"].get(gl, {})
                item["gaugeBalance"] = str(gbal)
                item["claimable_allKnownClaimants"] = clg.get("sum_claimable_wei")
                item["residual_unattributed"] = clg.get("residual_wei")
                item["n_claimants"] = clg.get("n_claimable")
                item["rcBalance"] = str(dec(rcd.get("CELO_balance"))) if rcd else None
                usd = (gbal / 1e18) * t["price"]
                item["claimableUSD"] = round(usd, 4)
                entry["remainingClaimableUSD"] += usd
                tot_celo += gbal
            else:
                gbal = GAUGE_BAL_POOMOO[gl][tname]
                pmg = pm["gauges"].get(g, {}).get("tokens", {}).get(tname, {})
                item["gaugeBalance"] = str(gbal)
                item["claimable_currentHolders"] = pmg.get("sum_claimable_wei")
                item["residual_exStakers_or_dust"] = str(gbal - int(pmg.get("sum_claimable_wei", 0)))
                rcbal = None
                if rc and rcb.get(rc.lower()):
                    rcbal = int(rcb[rc.lower()][tname + "_balance"])
                    item["rcBalance"] = str(rcbal)
                usd = (gbal / 1e18) * t["price"]
                item["claimableUSD"] = round(usd, 4)
                entry["remainingClaimableUSD"] += usd
                if tname == "POOF": tot_poof += gbal
                else: tot_moo += gbal
            entry["rewardTokens"].append(item)
        tot_usd += entry["remainingClaimableUSD"]
        # staked LP usd
        pool = by_lp.get(lp.lower()); s = sup.get(lp, sup.get(lp.lower()))
        if pool and s:
            tvl = 0.0
            for tok, bal in zip(pool["tokens"], pool["balances"]):
                e = tk.get(tok.lower(), {}); pr = e.get("llama_price")
                if pr is not None:
                    tvl += bal / 10 ** e.get("decimals", 18) * pr
            usd = dec(c["totalSupply()"]) / s * tvl
            entry["stakedLPValueUSD"] = round(usd, 2)
            staked_usd += usd
        entry["notes"].append("all external reward streams ended (periodFinish 2021-2022); earned(gauge)=0")
        if not killed:
            entry["notes"].append("gauge NOT killed -> MOBI emissions still accrue (value ~0)")
        out["gauges"][g] = entry

    out["totals"] = {
        "gaugeCELO_wei": str(tot_celo), "gaugeCELO_USD": round(tot_celo / 1e18 * TOK["CELO"]["price"], 2),
        "gaugePOOF_wei": str(tot_poof), "gaugeMOO_wei": str(tot_moo),
        "claimable_external_USD": round(tot_usd, 4),
        "stakedLPValueUSD_estimate": round(staked_usd, 2),
        "votingEscrow_lockedMOBI_wei": "66407864730943943602645442",
        "mobi_priceUSD": 0.000003453,
        "mobi_price_src": "DexScreener ubeswap MOBI/CELO liq $1415 pair 0x0B81CF47C8F97275d14C006E537D5101b6C87300",
    }
    out["classification"]["E-U"] = [
        {"item": "gauge claim paths", "reason": "claim_rewards pays only to _addr / rewards_receiver[_addr]; fresh-address test claimable_reward=0; claim_rewards(any) sim succeeds but moves nothing else"},
        {"item": "gauge withdraw/kick/set_rewards", "reason": "withdraw only own balance; kick only adjusts working_balances; set_rewards/set_killed admin (GaugeProxy) only"},
        {"item": "reward contracts", "reason": "guards confirmed via eth_call: notifyRewardAmount only rewardsDistribution, setRewardsDuration/updatePeriodFinish only owner, recoverERC20 blocks staking token; earned(gauge)=0 all RCs"},
        {"item": "Minter/mint", "reason": "mint sends only msg.sender's accrued MOBI; mint_for needs approval; MOBI.mint restricted to Minter (random-caller sim reverts); MOBI ~$0"},
        {"item": "burner 0x84c991", "reason": "withdrawETH() callable by anyone but balance 0; holds no tokens (checked CELO/MOBI/cUSD + Blockscout token list + native)"},
        {"item": "GaugeProxy.accept_transfer_ownership(gauge)", "reason": "permissionless but all 27 gauges have future_admin==admin==GaugeProxy; no pending two-step transfer to exploit"},
    ]
    out["classification"]["H-O"] = [
        {"item": "3,566.513523 CELO unclaimed rewards", "usd": round(tot_celo / 1e18 * TOK["CELO"]["price"], 2),
         "detail": "100% attributed (residual=0) to 300+ claimant addresses across 10 gauges; each recovers own claim_data via claim_rewards()/withdraw(true)"},
        {"item": "staked LP tokens", "usd_estimate": round(staked_usd, 2),
         "detail": "withdrawable only by stakers 1:1 through gauge withdraw(); LP held by StakingRewards (recoverERC20 blocks staking token)"},
        {"item": "POOF/MOO gauge balances", "usd": round((tot_poof / 1e18 * TOK["POOF"]["price"]) + (tot_moo / 1e18 * TOK["MOO"]["price"]), 4),
         "detail": "claimable by current holders + exited stakers (residual = stored claim_data)"},
    ]
    out["classification"]["S"] = [
        {"item": "reward-contract dust CELO (~5.13 CELO)", "usd": round(5.1349 * TOK["CELO"]["price"], 2),
         "detail": "leftover balances in RCs after streams ended; recoverable only by RC owners (recoverERC20 allows reward token: eth_call as owner returns success), else stuck"},
        {"item": "reward-contract dust MOO (~11,038 MOO)", "usd": round(11038.06 * TOK["MOO"]["price"], 2),
         "detail": "same as above; owners are Safes/EOA 0xd7f77169 Quirk: GaugeProxy.accept_transfer_ownership permissionless (no effect today)"},
        {"item": "donations sent directly to gauges", "usd": 0,
         "detail": "not counted by reward_integral (balance diff only during claim call) -> permanently stuck if ever sent"},
    ]
    out["minter"] = {
        "address": "0x5F0200CA03196D5b817E2044a0Bb0D837e0A7823", "token": "0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B (MOBI)",
        "controller": "0x7530E03056D3a8eD0323e61091ea2f17a1aC5C25",
        "verified": True, "type": "Curve TokenMinter fork (Vyper ^0.2.4)",
        "mint": "mint(gauge)/mint_many mint only msg.sender accrued; mint_for requires toggle_approve_mint; assert gauge_types(gauge)>=0",
        "mobi_token_admin": "0x6c0d6Fba3bcdb224278474E8d524F19c6BB55850 (EOA, no code) is MOBI admin; MOBI minter is the Minter contract",
        "mobi_mint_guard_test": "mint(address,uint256) from 0x..dEaD reverts (restricted to Minter)",
        "mobi_priceUSD": 0.000003453,
        "abuse_value": "MOBI ~= $0 (no DefiLlama feed; Ubeswap pool liq $1.4k); gauge inflation_rate>0 on 16 gauges but is_killed gates rate=0",
    }
    out["votingEscrow"] = {
        "address": "0xd813a846aA9D572140d7ABBB4eFaC8cD786b4c0E", "verified": True, "type": "Curve VotingEscrow fork",
        "totalSupply_veMOBI": "277458493571829369924860", "supply_lockedMOBI": "66407864730943943602645442",
        "mobi_balanceOf_VE": "66407864730943943602645442",
        "celo_balanceOf_VE": "0",
        "other_tokens": "none (Blockscout token-balances lists only MOBI)",
        "admin": "0x6c0dFba3bcdb224278474E8d524F19c6BB55850 (EOA)", "future_admin": "0x0",
        "withdraw_logic": "standard Curve: assert unlock time reached, votes/point updates; no extra assets; admin cannot seize locks",
    }
    out["otherContracts"] = {
        "0x4ea77424da100ac856ece3ddfabd8b528570ca0d": {"type": "EOA (no code)", "role": "owner() of pool 0x81b6a3d9f725ab5d706d9e552b128bc5bb0b58a1 (paused; LP 0x57f00817.. = gauge 0x1250 underlying)"},
        "0x6c0d6Fba3bcdb224278474E8d524F19c6BB55850": {"type": "EOA (no code)", "role": "VotingEscrow admin, MOBI token admin, devaddr on several pools"},
        "0x84c991aF33B6D1F14D65E50d37828FD9F744625a": {"type": "contract (1774 bytes, UNVERIFIED)", "owner": "0x6BE0fF2BED16a50169f941DafEf6be050182f88c (EOA)",
            "selectors": ["transfer", "transferFrom", "withdrawToken(address[])", "withdrawETH()", "owner/renounce/transferOwnership", "0x89afcb44"],
            "balances": "native 0; CELO 0; MOBI 0; cUSD 0; Blockscout token-balances empty",
            "guard_tests": "withdrawETH() succeeds from 0x..dEaD (permissionless) but contract holds 0; withdrawToken([CELO]) from 0x..dEaD reverts 'transfer value exceeded balance of sender'"},
        "GaugeProxy_0x0a3Ac12422C95F84b5bD18A6d9904d132a161C68": {"type": "contract (verified? no; source in mobiusAMM/mobi-dao-contracts contracts/GaugeProxy.vy)",
            "ownership_admin": "0x7d9Af9dF33D6CAB895B4cF3422D790cbE98B48c8 (Timelock)", "emergency_admin": "0x16E319d8dAFeF25AAcec0dF0f1E349819D36993c (Gnosis Safe, 4 owners)",
            "quirk": "accept_transfer_ownership(gauge) has no access check, but every gauge has future_admin==admin==GaugeProxy (checked all 27), so no takeover"},
        "GaugeController_0x7530E03056D3a8eD0323e61091ea2f17a1aC5C25": {"admin": "0x7d9Af9dF.. Timelock", "n_gauges": 27, "voting_escrow": "0xd813a846.."},
        "RC_owners": {"mostly": "0x16E319d8dAFeF25AAcec0dF0f1E349819D36993c (Safe)", "MOO-gauges": "0x313bc86d3d6e86ba164b2b451cb0d9cfa7943e5c (owner 0xd7f77169d5E6a32C5044052F9a49eb94697b25ED EOA)", "recoverERC20": "allows reward token (CELO eth_call as owner succeeded); blocks staking token"},
    }
    json.dump(out, open(f"{A}/gauges-audit.json", "w"), indent=1)
    print("wrote gauges-audit.json ; total external claimable USD", round(tot_usd, 4), "; stakedUSD", round(staked_usd, 2))


if __name__ == "__main__":
    main()
