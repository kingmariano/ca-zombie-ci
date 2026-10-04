#!/usr/bin/env python3
"""Fetch verified sources (Etherscan V2, chainid 999) for Nest core contracts.
Saves raw get_source_code responses to analysis/nest_src/<label>__<addr>.json.
Also resolves EIP-1967 impl/admin slots for proxies via hl_rpc.
Never prints the API key.
"""
import json, os, re, sys, time, urllib.request, urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hl_rpc import rpc, storage, block_number

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "nest_src")
os.makedirs(OUT, exist_ok=True)

ENV = "/home/heisenberg/CA/.env"
KEY = None
for line in open(ENV):
    if line.startswith("ETHERSCANV2_API_KEY="):
        KEY = line.split("=", 1)[1].strip().strip('"').strip("'")
if not KEY:
    sys.exit("no ETHERSCANV2_API_KEY in .env")

CONTRACTS = [
    # (label, address)
    ("NEST_token", "0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035"),
    ("VotingEscrow_proxy", "0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074"),
    ("VotingEscrow_impl", "0xAB7517EEd99B3e4Ae640FFe997236A92ca18D968"),
    ("Voter_proxy", "0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901"),
    ("Voter_impl", "0xc5A2F1A950dD3E383132fc89a4EBD3CFe66c2799"),
    ("Minter_proxy", "0x574f6865140e6929bDed24596D78a8D9c07E356d"),
    ("Minter_impl", "0xEaAA90ba5A9229F7dB273abb3CcaE33a50eC5FFC"),
    ("PairFactory_proxy", "0x889Fd0aDA8453C7619cD7f11E9029a1f0848Fdf5"),
    ("PairFactory_impl", "0xBa717129344552D510B392E947c45915807301aC"),
    ("Pair_impl", "0xc8e091a600Da73E27B1101F319A760e2C0740082"),
    ("GaugeFactoryV2_proxy", "0x15eb3987A7edC464e5A4d3bC3A9b8E84b8ceE2C7"),
    ("GaugeFactory_impl", "0x9Eb42a8596836A68F47c014B74e5239d5BdB55Df"),
    ("GaugeFactoryV3_proxy", "0x09D1A533032319557196F87dFf831FF46204c49d"),
    ("GaugeV2_impl", "0x90ec77Ad5cC0E723ee502c9cb54C3652D9d7636E"),
    ("GaugeV3_impl", "0x0EF3aa4F8E509d580ee0A1fd0E14c4B66A72655F"),
    ("GaugeRewader_proxy", "0xfF0124cf664240e5573282511042d7033C3f22eA"),
    ("GaugeRewader_impl", "0x4158958Bf30C818491b36020f4b709404ce645Ee"),
    ("GaugeRewader_impl_live", "0x992df0C4831c7e84dB7c942528270d83b0737081"),
    ("CompoundEmissionExtension_impl_live", "0x8b3f6eb2C9bFBEE74CFC5372eb88a6353EA0a887"),
    ("BribeVeNESTRewardToken_impl_live", "0x19534E5eeEc9E60Be9b954B1179CC0c6870A2785"),
    ("CustomBribeRewardRouter_impl_live", "0xE4a0c5BDDe5097b7F06Bf2b3ed4E91C5ce136dFE"),
    ("FeesVaultFactory_proxy", "0x705C76e29977Ed52cd93d390A7BBcC61189724C0"),
    ("FeesVaultFactory_impl", "0x798561d239A46991377b934da48DDA0cF985aBbF"),
    ("FeesVault_impl", "0x7B12E8Ed9740d9d190b498A9AAc3584D81C7cf03"),
    ("BribeFactory_proxy", "0x638e382300Ee2ece790164DAfAF7a9f16045621b"),
    ("BribeFactory_impl", "0xb63363E5C71148f4f6cc75d4EE1b7dcfc997a1CB"),
    ("Bribe_impl", "0xd073c875AC73C5b93ec142675bB6A40134C3Cc64"),
    ("ManagedNFTManager_proxy", "0x843d31e601b38F7207864457f0fB38E14441E792"),
    ("ManagedNFTManager_impl", "0x481f9d30a70A90F6b50E4D1052323A8e79802972"),
    ("CompoundVeNESTStrategy_impl", "0xb3B7F4f4B380ce53259170654Eed32c89B3BF5B5"),
    ("CompoundVeNESTStrategyFactory_proxy", "0x98fe2510DFcAdb52431C2A651E1ecfC46196fa87"),
    ("CompoundVeNESTStrategyFactory_impl", "0xC3fF1e8E73559f07C269031DC239f6eE42b6bBe4"),
    ("CompoundEmissionExtension_proxy", "0x1c925056A1a657a4cb70D677D8C21028233cA05D"),
    ("CompoundEmissionExtension_impl", "0x550040864D272392D7c14Ab9bCFF4159952F881a"),
    ("VeNestDistributor_proxy", "0x22350F14c6ee70992f1bbc7498e4C291B8B7682f"),
    ("VeNestDistributor_impl", "0x6D87bAD7b75499b84e3e28E618B43840F56ACd9A"),
    ("NestRaise_proxy", "0xcd78D1A27320FeE9A03860172649b92A10aA3867"),
    ("NestRaise_impl", "0x891ACb9f28985a40687d12d24F711824D00E98A5"),
    ("VeNestSplitMerklAirdrop_proxy", "0xB97B9217B55F322F7105f34777Af9F63B3b720A6"),
    ("VeNestSplitMerklAirdrop_impl", "0x84daBa9c04733da41b9ff3b44F14CFa9C18d567D"),
    ("SingelTokenVirtualRewarder_impl", "0xAF24Cf0Dd121B89DF98b9FAD2E05821bd08069DF"),
    ("RouterV2", "0xfDb34624506e9A0624AF60F85ebd9E44A0FD2a17"),
    ("UniswapV2PartialRouter", "0x3aED39FcD5742c3044faE2fdf0C307D2F205636F"),
    ("RouterV2PathProvider_proxy", "0xFF5a9613C6bcfF56da96d068326A9Bb998A67c9B"),
    ("RouterV2PathProvider_impl", "0x6d3cD36518c6800F6aa9d1Fd54276b5dd0Fee1c0"),
    ("PairAPI_proxy", "0x7D01900dE6101F842b01F5301910Dc401FbDcb79"),
    ("PairAPI_impl", "0x4f0EC8880749F6F080515F1907964312220D97E3"),
    ("RewardAPI_proxy", "0xf822375D86F74a147a3a4b2661E68376cD1EC677"),
    ("RewardAPI_impl", "0xbfa705DbF2a72077F6C66230C901f54A3788BC7D"),
    ("VeNFTAPI_proxy", "0x0cCbeFa11FfF9A37c8a14914F548B0664dD22b19"),
    ("VeNFTAPI_impl", "0x862B14C353fE6789492de96ee2c42c31BF92a774"),
    ("BribeVeNESTRewardToken_proxy", "0x224240310337462bdE7fEE244A6e07E35a231f47"),
    ("BribeVeNESTRewardToken_impl", "0xa2E33F280d93621d967d273e33998Da4935104BC"),
    ("CustomBribeRewardRouter_proxy", "0x1Eb78Fb533e480436a2e10CA01F5e828A28b3DFb"),
    ("CustomBribeRewardRouter_impl", "0x6e18a9B2fDB7915eCE11ef61aB59D43E611E7Eb5"),
    ("GetInformationAggregator_proxy", "0xa6857656500eEf32D434F1a6c11C08B290672b98"),
    ("GetInformationAggregator_impl", "0x39B16A40263c68Bd25401281E8e9FE9e1D68e12A"),
    ("Utils_proxy", "0xf9159f2e75163436e52986878B65a16b3eA8Cf81"),
    ("Utils_impl", "0x29290C57C883156f972f35D8b110613680a27D60"),
    ("ProxyAdmin", "0xb688d5e73777DfaaDbD7c5Fe98Aee6F35CF20124"),
    ("VeArtProxyStatic", "0xBB3EB334412a8a7e8336cCBA98bdce5694708cE0"),
    ("VeArtProxy", "0xF00037084e1C359f2Be067016C5E00CB945C494d"),
    # Algebra CL
    ("AlgebraFactory_proxy", "0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3"),
    ("AlgebraFactory_impl", "0xd99930FAE54B3Fbc237eB330527501237bB1B59E"),
    ("CLPoolDeployer", "0x3842CE04380B8655A3A47Ed87eA0D311ADCa161F"),
    ("CLVault", "0x15E408A37cE4D13218202C0054B0f485E38F5768"),
    ("CLVaultFactory", "0x0136B1cde62210EA99a7c0482B9b6626809cc964"),
    ("AlgebraBasePluginV1", "0x974f1Be2b28c455ee29af20152C112fEeE85e3C1"),
    ("BasePluginV1Factory", "0x9F0B3984cE2496bDf9DB89701dF6BAc425FaAdD8"),
    ("SwapRouter", "0xaA26B8e5Cadd04430c32787eCC3AA325e99681e9"),
    ("NonfungiblePositionManager", "0xEAF58788a405F3253814b4559391a22bE8616250"),
    ("CLProxyAdmin", "0x45727c03B46970C64E4039B546E6bd1F9c9d92ab"),
    ("TickLens", "0x44f1292f550e33b2ecd346ac8746E405a351c2C5"),
    ("Quoter", "0x89C3aB4F5342498e9EdAC5C43C07e9Bd9AE4DB78"),
    ("QuoterV2", "0xBea20609A4772311c5b81F814Cd4f9ECaEF5DFAd"),
]

EIP1967_IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
EIP1967_ADMIN = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"


def fetch(addr):
    url = ("https://api.etherscan.io/v2/api?chainid=999&module=contract&action=getsourcecode"
           f"&address={addr}&apikey={KEY}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read())
        except Exception as e:
            if attempt == 4:
                return {"error": str(e)}
            time.sleep(2 * (attempt + 1))


def main():
    bn = block_number()
    print("block:", bn)
    # slots for proxies
    slot_res = {}
    for label, addr in CONTRACTS:
        for slotname, slot in (("impl", EIP1967_IMPL), ("admin", EIP1967_ADMIN)):
            v = storage(addr, slot, hex(bn))
            if v and int(v, 16) != 0:
                slot_res.setdefault(label, {})[slotname] = "0x" + v[-40:]
    print("slots:", json.dumps(slot_res, indent=1))
    manifest = {"block": bn, "slots": slot_res, "fetched": {}}
    for label, addr in CONTRACTS:
        path = os.path.join(OUT, f"{label}__{addr}.json")
        if os.path.exists(path) and os.path.getsize(path) > 200:
            try:
                d = json.load(open(path))
                if d.get("status") == "1":
                    print(f"skip {label} (cached)")
                    manifest["fetched"][label] = {"address": addr, "file": os.path.basename(path), "cached": True,
                                                  "name": d["result"][0].get("ContractName"),
                                                  "verified": bool(d["result"][0].get("SourceCode"))}
                    continue
            except Exception:
                pass
        d = fetch(addr)
        json.dump(d, open(path, "w"))
        status = d.get("status")
        name = ""
        verified = False
        res0 = d.get("result")
        if isinstance(res0, list) and res0 and isinstance(res0[0], dict):
            res0 = res0[0]
        elif not isinstance(res0, dict):
            res0 = {}
        name = res0.get("ContractName") or ""
        verified = bool(res0.get("SourceCode"))
        manifest["fetched"][label] = {"address": addr, "file": os.path.basename(path),
                                      "status": status, "name": name, "verified": verified}
        print(f"{label:42s} {addr} status={status} name={name} verified={verified} src_len={len(res0.get('SourceCode') or '')}")
        time.sleep(0.3)
    json.dump(manifest, open(os.path.join(OUT, "_manifest.json"), "w"), indent=1)
    print("done")


if __name__ == "__main__":
    main()
