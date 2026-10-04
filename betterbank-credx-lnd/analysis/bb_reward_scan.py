#!/usr/bin/env python3
"""BetterBank reward-system live-state scan (read-only, PulseChain)."""
import json, sys
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc, batch
from Crypto.Hash import keccak
URL = "https://rpc.pulsechain.com"
def k(s):
    h = keccak.new(digest_bits=256); h.update(s.encode()); return "0x" + h.hexdigest()
def sel(s): return k(s)[:10]
def u(h):
    if not isinstance(h, str): return None
    if not h or h == '0x': return None
    return int(h, 16)
def b32(a): return a[2:].lower().rjust(64, '0')

BLOCK = int(rpc(URL, "eth_blockNumber", []), 16)
print("block", BLOCK)

WRAPPER   = "0x9361841a51bd90999fac8382abecf976273141f7"
REDEEMER  = "0x6bbc91c980780c393e9dac11ec58684191de611d"
PDAIF     = "0xbc91e5ae4ce07d0455834d52a9a4df992e12fe12"
PLSF      = "0x30be72a397667fdfd641e3e5bd68db657711eb20"
PLSXF     = "0x47c3038ad52e06b9b4aca6d672ff9ff39b126806"
ESTEEM    = "0xdbb8fd196e804d05bb8047dd3e91a9245b7819a7"
MINTER_ORACLE = "0xcd424ed62c18df5d15f23799091597c99406b700"
ORACLE    = "0x5c717b63105b9ef7ea5b7b521581c23c7193fd88"
UNKNOWN = {
 "0xff98af981c113488b91934e8af779194cc1b53ad": "tok_ff98",
 "0xc8ccaec1e239c8591cbb8715bd0a43dd4c9cc95a": "tok_c8cc",
 "0xddbe64f89268026027d7823d1141846d546d6bac": "tok_ddbe",
 "0x2070ea9c18df743b3fdf37485fccc390a3694eb9": "tok_2070",
 "0xefd766ccb38eaf1dfd701853bfce31359239f305": "dai2_efd7",
}
FAVORS = {"PDAIF": PDAIF, "PLSF": PLSF, "PLSXF": PLSXF}
PAIRS = {
 "PDAIF/DAI": "0xa0126ac1364606bafb150653c7bc9f1af4283dfa",
 "PLSF/WPLS": "0xdca85efdce177b24de8b17811cec007fe5098586",
 "PLSXF/PLSX": "0x24264d580711474526e8f2a8ccb184f6438bb95c",
 "unk1/WPLS": "0xb75e32eb2994b9632d16d157c55731d2fc792b17",
 "unk2/DAI": "0x6a7e018d334b8cc9116010d8779cb5b4b0143adc",
 "unk3/PLSX": "0xa1cbdc3d9cab3d9259ed18993f3ce224e2f333c9",
 "unk4/DAI2": "0xedcb808ddc390844049b1af42c8163e0e5c54405",
}

calls = []; labels = []
def C(to, sig, *args):
    data = sel(sig) + "".join(b32(a) if a.startswith('0x') else hex(a)[2:].rjust(64,'0') for a in args)
    calls.append(("eth_call", [{"to": to, "data": data}, "latest"]))
    labels.append((sig, to))

def strc(to, sig, *args):
    data = sel(sig) + "".join(b32(a) if a.startswith('0x') else hex(a)[2:].rjust(64,'0') for a in args)
    calls.append(("eth_call", [{"to": to, "data": data}, "latest"]))
    labels.append((sig, to))

# wrapper
C(WRAPPER, "owner()")
strc(WRAPPER, "uniswapRouter()")
for n, a in FAVORS.items(): C(WRAPPER, "isFavorToken(address)", a)
for a, n in UNKNOWN.items(): C(WRAPPER, "isFavorToken(address)", a)

# favor tokens
for n, a in FAVORS.items():
    C(a, "owner()")
    strc(a, "esteem()")
    strc(a, "esteemMinter()")
    C(a, "isBuyWrapper(address)", WRAPPER)
    C(a, "isMinter(address)", REDEEMER)
    C(a, "bonusRate()")
    C(a, "treasuryBonusRate()")
    C(a, "sellTax()")
    C(a, "totalSupply()")
    for pn, p in PAIRS.items():
        C(a, "isMarketPair(address)", p)

# esteem
C(ESTEEM, "owner()")
C(ESTEEM, "totalSupply()")
for n, a in FAVORS.items(): C(ESTEEM, "isMinter(address)", a)
C(ESTEEM, "isMinter(address)", REDEEMER)

# redeemer
C(REDEEMER, "owner()")
strc(REDEEMER, "esteem()")
C(REDEEMER, "paused()")
C(REDEEMER, "esteemRate()")
C(REDEEMER, "redeemRate()")
C(REDEEMER, "treasuryBonusRate()")
C(REDEEMER, "startTime()")
for n, a in FAVORS.items():
    C(REDEEMER, "favorTokens(address)", a)
    strc(REDEEMER, "priceOracles(address)", a)
    strc(REDEEMER, "getLatestTokenPrice(address)", a)
for a, n in UNKNOWN.items():
    C(REDEEMER, "favorTokens(address)", a)
    strc(REDEEMER, "getLatestTokenPrice(address)", a)

ALLTOK = {**FAVORS, **{nm: ad for ad, nm in UNKNOWN.items()}}
# minter oracle
for n, a in ALLTOK.items():
    strc(MINTER_ORACLE, "priceOracles(address)", a)
    strc(MINTER_ORACLE, "getTokenTWAP(address)", a)

# oracle contract
strc(ORACLE, "pair()")
for n, a in ALLTOK.items():
    strc(ORACLE, "getLatestPrice(address)", a)

# token metadata for unknowns
for a, n in UNKNOWN.items():
    strc(a, "symbol()"); strc(a, "name()"); strc(a, "decimals()"); strc(a, "totalSupply()")

res = batch(URL, calls)
out = {"block": BLOCK, "results": {}}
def dec_str(hexstr):
    try:
        b = bytes.fromhex(hexstr[2:]); ln = int.from_bytes(b[32:64],'big'); return b[64:64+ln].decode()
    except Exception: return None
for (sig, to), r in zip(labels, res):
    key = f"{to}:{sig}"
    if sig in ("symbol()", "name()"):
        out["results"][key] = dec_str(r) if r and r != '0x' else None
    elif r and r != '0x':
        out["results"][key] = u(r)
    else:
        out["results"][key] = None

# pretty print key facts
print("\n--- wrapper")
for n,a in FAVORS.items(): print("isFavorToken", n, out["results"].get(f"{WRAPPER}:isFavorToken(address)", '?'))
print("owner", out["results"].get(f"{WRAPPER}:owner()"))
print("router", out["results"].get(f"{WRAPPER}:uniswapRouter()"))
print("\n--- tokens")
for n,a in FAVORS.items():
    print(n, "esteem", out["results"].get(f"{a}:esteem()"), "esteemMinter", out["results"].get(f"{a}:esteemMinter()"),
          "isBuyWrapper", out["results"].get(f"{a}:isBuyWrapper(address)"), "isMinter(redeemer)", out["results"].get(f"{a}:isMinter(address)"),
          "bonusRate", out["results"].get(f"{a}:bonusRate()"), "totalSupply", out["results"].get(f"{a}:totalSupply()"))
print("\n--- esteem isMinter")
for n,a in FAVORS.items(): print("  minter", n, out["results"].get(f"{ESTEEM}:isMinter(address)"))
print("  minter redeemer", out["results"].get(f"{ESTEEM}:isMinter(address)"))
print("\n--- redeemer")
print("paused", out["results"].get(f"{REDEEMER}:paused()"), "esteemRate", out["results"].get(f"{REDEEMER}:esteemRate()"),
      "redeemRate", out["results"].get(f"{REDEEMER}:redeemRate()"), "owner", out["results"].get(f"{REDEEMER}:owner()"))
for n,a in FAVORS.items():
    print(" ", n, "favorTokens", out["results"].get(f"{REDEEMER}:favorTokens(address)"),
          "priceOracle", out["results"].get(f"{REDEEMER}:priceOracles(address)"),
          "price", out["results"].get(f"{REDEEMER}:getLatestTokenPrice(address)"))
print("\n--- minter oracle twaps")
for n,a in list(FAVORS.items()):
    print(" ", n, "oracle", out["results"].get(f"{MINTER_ORACLE}:priceOracles(address)"), "twap", out["results"].get(f"{MINTER_ORACLE}:getTokenTWAP(address)"))
print("\n--- oracle contract pair", out["results"].get(f"{ORACLE}:pair()"))
for n,a in list(FAVORS.items()):
    print(" ", n, "getLatestPrice", out["results"].get(f"{ORACLE}:getLatestPrice(address)"))
print("\n--- unknowns")
for n,a in UNKNOWN.items():
    print(" ", n, a, "symbol", out["results"].get(f"{a}:symbol()"), "favorToken?", out["results"].get(f"{REDEEMER}:favorTokens(address)"))
json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_reward_state.json','w'), indent=1)
print("saved")
