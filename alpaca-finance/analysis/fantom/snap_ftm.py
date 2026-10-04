#!/usr/bin/env python3
"""Fantom Alpaca state snapshot (read-only eth_call batch)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from snap import rpc_batch, enc_call, dec_addr, dec_uint, dec_int, dec_bool, dec_str, words, show

FTM = "ftm"
BLOCK = None

VAULTS = [
    ("ibFTM",   "0xc1018f4Bba361A1Cc60407835e156595e92EF7Ad", "0x95bBd366FaA1D7F29484Cc33Cd5c89905fd29a12",
     [("USDC-WFTM",   "0x29A7929520ADdC7D3000a81129d4E5Aa7a571f49", 10, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c"),
      ("BOO-WFTM",    "0xFf16996ad66a378856a8034c08bb9C09fF877f78", 0,  "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0xEc7178F4C41f346b2721907F5cF7628E388A7a58"),
      ("ETH-WFTM",    "0x1CcA30728F7a82B517Fa174a1163503946054d04", 13, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0xf0702249F4D3A25cD3DED7859a165693685Ab577"),
      ("ALPACA-WFTM", "0xB82B93FcF1818513889c0E1F3628484Ce5017A14", 38, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0xF66D2bf736c05723b62E833A5DD747E24855ff99"),
      ("BTC-WFTM",    "0x871C7dBdE0a3dB46dAa552C83fD79f8Cf76D63FD", 12, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0xFdb9Ab8B9513Ad9E419Cf19530feE49d412C3Ee3"),
      ("fUSDT-WFTM",  "0xE30faE0cFD9E994179e3E63AAbCC239d32E9D6Ed", 9,  "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x5965E53aa80a0bcF1CD6dbDd72e6A9b2AA047410"),
      ("DAI-WFTM",    "0x19f510971FD2c9d1cd6EaEACEC6DC04A3fBA51A6", 11, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0xe120ffBDA0d14f3Bb6d6053E90E63c572A66a428"),
      ("MIM-WFTM",    "0x20ACAA67a589e0947E11bA24EDA9D4eAc96f013C", 19, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x6f86e65b255c9111109d2D2325ca2dFc82456efc"),
      ("TOMB-WFTM",   "0x77d23aFF927f3d46e51D449372c957B3CBBFB40e", 0,  "0xcc0a87F7e7c693042a9Cc703661F5060c80ACb43", "0x2A651563C9d3Af67aE0388a5c8F89b867038089e"),
      ("TSHARE-WFTM", "0x5BbD947bb67f3CB55bA7C01A8DB0B21c5d5A4b03", 1,  "0xcc0a87F7e7c693042a9Cc703661F5060c80ACb43", "0x4733bc45eF91cF7CcEcaeeDb794727075fB209F2"),
      ("USDC-WFTM-3x-SPK1", "0x792E8192F2fbdBb5c1e36F312760Fe01D0d7aB92", 10, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c"),
      ("USDC-WFTM-3x-SPK2", "0x0e807E2F50dfe8616636083Ba5ecef97280338cf", 10, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c")],
     "0x472Bd78dacF64F5A9262a422829178ec001c9796"),
    ("ibUSDC",  "0x831332f94C4A0092040b28ECe9377AfEfF34B25a", "0xE986679b06E9D4c72C5B504c86Eb64d546710Aa6",
     [("WFTM-USDC",  "0xabE59308AC72f04b1a2D04175d5247ba981075a6", 10, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c"),
      ("TUSD-USDC",  "0x26e2f780247C895b466F63e0412c5b449E881c33", 29, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x12692B3bf8dd9Aa1d2E721d1a79efD0C244d7d96"),
      ("WFTM-USDC-3x-SPK1", "0xceCD803b048b66a75bc64f8AA8139cAB97c421C8", 10, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c"),
      ("BOO-USDC",   "0x5875796B385caCC467C2BFdD794e1B43bAC78f7a", 39, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0xf8Cb2980120469d79958151daa45Eb937c6E1EeD6"),
      ("WFTM-USDC-3x-SPK2", "0xBF94404D6ad9986532d25950585e5855b4c30d2c", 10, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c")],
     "0x62Dd4B5874F6205D12e8b6228116322F32cD3EA5"),
    ("ibALPACA", "0x2E7f32e38EA5a5fcb4494d9B626d2d393B176B1E", "0x23ff13d43702cA95a6369736dBFf6Ea718b5F0b0",
     [("WFTM-ALPACA", "0x66C293f55f06DC556B961240184902C07d25C1f2", 38, "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD", "0xF66D2bf736c05723b62E833A5DD747E24855ff99")],
     "0xcf8b56F16024Ef0feB3Ddcb85Ec5879bf593E372"),
    ("ibTOMB",  "0x60dDe8BBE160fe033fACB3446Cf7795cC575B171", "0x83875cB3B520275183c5c383C8745199293Cd89C",
     [("WFTM-TOMB",  "0x995e502BA378d855925a238606c6df63E471E419", 0, "0xcc0a87F7e7c693042a9Cc703661F5060c80ACb43", "0x2A651563C9d3Af67aE038a8a5c8F89b867038089e")],
     "0x46AD1C4F5D7542AeDf57dE7a8Bf0765233A4457f"),
]
# fix typo'd tomb lp addr
VAULTS[3][3][0] = ("WFTM-TOMB", "0x995e502BA378d855925a238606c6df63E471E419", 0, "0xcc0a87F7e7c693042a9Cc703661F5060c80ACb43", "0x2A651563C9d3Af67aE0388a5c8F89b867038089e")

MINIFL = "0x838B7F64Fa89d322C563A6f904851A13a164f84C"
TIMELOCK = "0xafD1eb025bf584a11112A3FC790bd715eD9A98b1"
REWARDER = "0x7EEAA96bf1aBaA206615046c0991E678a2b12Da1"
PROXYADMIN_CFG = "0xA625AB01B08ce023B2a342Dbb12a16f2C8489A8F"

calls = []   # (label, chain, call)
def add(label, to, sig, args=(), chain=FTM, frm=None):
    c = enc_call(to, sig, args)
    if frm: c["from"] = frm
    calls.append((label, chain, c))

# ---- vault state
for name, v, cfg, workers, debt in VAULTS:
    add(f"{name}.totalToken", v, "totalToken()")
    add(f"{name}.totalSupply", v, "totalSupply()")
    add(f"{name}.vaultDebtVal", v, "vaultDebtVal()")
    add(f"{name}.vaultDebtShare", v, "vaultDebtShare()")
    add(f"{name}.reservePool", v, "reservePool()")
    add(f"{name}.fairLaunchPoolId", v, "fairLaunchPoolId()")
    add(f"{name}.nextPositionID", v, "nextPositionID()")
    add(f"{name}.lastAccrueTime", v, "lastAccrueTime()")
    add(f"{name}.owner", v, "owner()")
    add(f"{name}.token", v, "token()")
    add(f"{name}.decimals", v, "decimals()")
    tok = None
    add(f"{name}.config", v, "config()")
    add(f"{name}.debtToken", v, "debtToken()")
    # config
    add(f"cfg.{name}.owner", cfg, "owner()")
    add(f"cfg.{name}.getFairLaunchAddr", cfg, "getFairLaunchAddr()")
    add(f"cfg.{name}.getTreasuryAddr", cfg, "getTreasuryAddr()")
    add(f"cfg.{name}.getWNativeRelayer", cfg, "getWNativeRelayer()")
    add(f"cfg.{name}.getWrappedNativeAddr", cfg, "getWrappedNativeAddr()")
    add(f"cfg.{name}.getKillBps", cfg, "getKillBps()")
    add(f"cfg.{name}.getKillTreasuryBps", cfg, "getKillTreasuryBps()")
    add(f"cfg.{name}.isWorkerStable", cfg, "isWorkerStable(address)", [workers[0][1]])
    # workers
    for wname, w, pid, chef, lp in workers:
        add(f"w.{name}.{wname}.operator", w, "operator()")
        add(f"w.{name}.{wname}.owner", w, "owner()")
        add(f"w.{name}.{wname}.totalShare", w, "totalShare()")
        add(f"w.{name}.{wname}.pid", w, "pid()")
        add(f"w.{name}.{wname}.lpToken", w, "lpToken()")
        add(f"w.{name}.{wname}.baseToken", w, "baseToken()")
        add(f"w.{name}.{wname}.farmingToken", w, "farmingToken()")
        add(f"cfg.{name}.isWorker.{wname}", cfg, "isWorker(address)", [w])
        add(f"cfg.{name}.acceptDebt.{wname}", cfg, "acceptDebt(address)", [w])
        add(f"chef.{wname}.userInfo", chef, "userInfo(uint256,address)", [pid, w])
        add(f"lp.{name}.{wname}.balanceOf.worker", lp, "balanceOf(address)", [w])
        add(f"lp.{name}.{wname}.totalSupply", lp, "totalSupply()")
        add(f"lp.{name}.{wname}.token0", lp, "token0()")
        add(f"lp.{name}.{wname}.token1", lp, "token1()")
        add(f"lp.{name}.{wname}.getReserves", lp, "getReserves()")

# ---- MiniFL
add("minifl.owner", MINIFL, "owner()")
add("minifl.poolLength", MINIFL, "poolLength()")
add("minifl.totalAllocPoint", MINIFL, "totalAllocPoint()")
add("minifl.alpacaPerSecond", MINIFL, "alpacaPerSecond()")
add("minifl.maxAlpacaPerSecond", MINIFL, "maxAlpacaPerSecond()")
add("minifl.ALPACA", MINIFL, "ALPACA()")
add("minifl.alpacaBalance", MINIFL, "ALPACA()")  # placeholder replaced below
for i in range(9):
    add(f"minifl.pool.{i}.info", MINIFL, "poolInfo(uint256)", [i])
    add(f"minifl.pool.{i}.stakingToken", MINIFL, "stakingToken(uint256)", [i])
    add(f"minifl.pool.{i}.rewarder", MINIFL, "rewarder(uint256)", [i])
    add(f"minifl.pool.{i}.isDebtTokenPool", MINIFL, "isDebtTokenPool(uint256)", [i])

# ---- timelock / admin
add("timelock.admin", TIMELOCK, "admin()")
add("timelock.pendingAdmin", TIMELOCK, "pendingAdmin()")
add("timelock.delay", TIMELOCK, "delay()")
add("proxyadmincfg.codesize?", PROXYADMIN_CFG, "owner()")
add("rewarder.owner", REWARDER, "owner()")
add("rewarder.operator", REWARDER, "operator()")
add("rewarder.rewardToken", REWARDER, "rewardToken()")
add("rewarder.stakingToken", REWARDER, "stakingToken()")

# run
print(f"total calls: {len(calls)}", file=sys.stderr)
res = rpc_batch(FTM, [c for _, _, c in calls])
decoded = {}
raw = {}
for (label, chain, _), r in zip(calls, res):
    if "result" in r and r["result"] not in (None, "0x"):
        raw[label] = r["result"]
    else:
        raw[label] = None
        decoded[label] = ("ERR", (r.get("error") or {}).get("message", r.get("error")) if isinstance(r.get("error"), dict) else r.get("error"))
        continue
    h = r["result"]
    # decode heuristics per label
    try:
        if label.endswith("userInfo"):
            w = words(h)
            decoded[label] = (dec_uint(w[0]), dec_int(w[1]))
        elif label.endswith(".info"):
            w = words(h)
            decoded[label] = [dec_uint(x) for x in w]
        elif label.endswith("getReserves"):
            w = words(h)
            decoded[label] = [dec_uint(x) for x in w][:2]
        elif label.endswith(".owner") or label.endswith(".admin") or label.endswith("pendingAdmin") or label.endswith("token") or label.endswith(".stakingToken") or label.endswith("rewarder") or label.endswith("operator") or label.endswith("lpToken") or label.endswith("baseToken") or label.endswith("farmingToken") or label.endswith("token0") or label.endswith("token1") or label.endswith("getFairLaunchAddr") or label.endswith("getTreasuryAddr") or label.endswith("getWNativeRelayer") or label.endswith("getWrappedNativeAddr") or label.endswith(".ALPACA") or label.endswith("rewardToken"):
            decoded[label] = dec_addr(h)
        elif label.endswith("isWorker") or label.endswith("acceptDebt") or label.endswith("isWorkerStable") or label.endswith("isDebtTokenPool"):
            decoded[label] = dec_bool(h)
        else:
            decoded[label] = dec_uint(h)
    except Exception as e:
        decoded[label] = ("DECODE_ERR", str(e), h)

out = {"block": None, "decoded": decoded, "raw": raw}
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw", "04_snapshot_ftm.json"), "w") as f:
    json.dump(out, f, indent=1)
for k in sorted(decoded):
    print(f"{k} = {decoded[k]}")
