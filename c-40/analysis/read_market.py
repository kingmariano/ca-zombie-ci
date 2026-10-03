#!/usr/bin/env python3
"""Read live balances of all Nostra Money Market contracts using batched JSON-RPC."""
import sys, json, subprocess, time; sys.path.insert(0, '.')
from sn import sn_keccak

RPC = "https://starknet-rpc.publicnode.com"
ZERO = "0x0000000000000000000000000000000000000000000000000000000000000000"

ASSETS = {
 "WBTC": ("0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac","0x0735d0f09a4e8bf8a17005fa35061b5957dcaa56889fc75df9e94530ff6991ea","0x05b7d301fa769274f20e89222169c0fad4d846c366440afc160aafadd6f88f0c","0x073132577e25b06937c64787089600886ede6202d085e6340242a5a32902e23e","0x036b68238f3a90639d062669fdec08c4d0bdd09826b1b6d24ef49de6d8141eaa","0x0491480f21299223b9ce770f23a2c383437f9fbf57abc2ac952e9af8cdb12c97"),
 "ETH": ("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7","0x01fecadfe7cda2487c66291f2970a629be8eecdcb006ba4e71d1428c2b7605c7","0x057146f6409deb4c9fa12866915dd952aa07c1eb2752e451d7f3b042086bdeb8","0x07170f54dd61ae85377f75131359e3f4a12677589bb7ec5d61f362915a5c0982","0x044debfe17e4d9a5a1e226dabaf286e72c9cc36abbe71c5b847e669da4503893","0x00ba3037d968790ac486f70acaa9a1cab10cf5843bb85c986624b4d0e5a82e74"),
 "USDC": ("0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8","0x002fc2d4b41cc1f03d185e6681cbd40cced61915d4891517a042658d61cba3b1","0x05dcd26c25d9d8fd9fc860038dcb6e4d835e524eb8a85213a8cda5b7fff845f6","0x06eda767a143da12f70947192cd13ee0ccc077829002412570a88cd6539c1d85","0x05f296e1b9f4cf1ab452c218e72e02a8713cee98921dad2d3b5706235e128ee4","0x063d69ae657bd2f40337c39bf35a870ac27ddf91e6623c2f52529db4c1619a51"),
 "DAIv0": ("0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3","0x022ccca3a16c9ef0df7d56cbdccd8c4a6f98356dfd11abc61a112483b242db90","0x04f18ffc850cdfa223a530d7246d3c6fc12a5969e0aa5d4a88f470f5fe6c46e9","0x02b5fd690bb9b126e3517f7abfb9db038e6a69a068303d06cf500c49c1388e20","0x005c4676bcb21454659479b3cd0129884d914df9c9b922c1c649696d2e058d70","0x066037c083c33330a8460a65e4748ceec275bbf5f28aa71b686cbc0010e12597"),
 "USDT": ("0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8","0x0360f9786a6595137f84f2d6931aaec09ceec476a94a98dcad2bb092c6c06701","0x0453c4c996f1047d9370f824d68145bd5e7ce12d00437140ad02181e1d11dc83","0x06669cb476aa7e6a29c18b59b54f30b8bfcfbb8444f09e7bbb06c10895bf5d7b","0x0514bd7ee8c97d4286bd481c54aa0793e43edbfb7e1ab9784c4b30469dcf9313","0x024e9b0d6bc79e111e6872bb1ada2a874c25712cf08dfc5bcf0de008a7cca55f"),
 "wstETH": ("0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2","0xca44c79a77bcb186f8cdd1a0cd222cc258bebc3bec29a0a020ba20fdca40e9","0x9377fdde350e01e0397820ea83ed3b4f05df30bfb8cf8055d62cafa1b2106a","0x7e2c010c0b381f347926d5a203da0335ef17aefee75a89292ef2b0f94924864","0x5eb6de9c7461b3270d029f00046c8a10d27d4f4a4c931a4ea9769c72ef4edbb","0x348cc417fc877a7868a66510e8e0d0f3f351f5e6b0886a86b652fcb30a3d1fb"),
 "LORDS": ("0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49","0x507eb06dd372cb5885d3aaf18b980c41cd3cd4691cfd3a820339a6c0cec2674","0x739760bce37f89b6c1e6b1198bb8dc7166b8cf21509032894f912c9d5de9cbd","0xd294e16a8d24c32eed65ea63757adde543d72bad4af3927f4c7c8969ff43d","0x2530a305dd3d92aad5cf97e373a3d07577f6c859337fb0444b9e851ee4a2dd4","0x35778d24792bbebcf7651146896df5f787641af9e2a3db06480a637fbc9fff8"),
 "STRK": ("0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d","0x26c5994c2462770bbf940552c5824fb0e0920e2a8a5ce1180042da1b3e489db","0x7c2e1e733f28daa23e78be3a4f6c724c0ab06af65f6a95b5e0545215f1abc1b","0x7c535ddb7bf3d3cb7c033bd1a4c3aac02927a4832da795606c0f3dbbc6efd17","0x40f5a6b7a6d3c472c12ca31ae6250b462c6d35bbdae17bd52f6c6ca065e30cf","0x1258eae3eae5002125bebf062d611a772e8aea3a1879b64a19f363ebd00947"),
 "nstSTRK": ("0x04619e9ce4109590219c5263787050726be63382148538f3f936c22aa87d2fc2","0x78a40c85846e3303bf7982289ca7def68297d4b609d5f588208ac553cff3a18","0x67a34ff63ec38d0ccb2817c6d3f01e8b0c4792c77845feb43571092dcf5ebb5","0x4b11c750ae92c13fdcbe514f9c47ba6f8266c81014501baa8346d3b8ba55342","0x0142af5b6c97f02cac9c91be1ea9895d855c5842825cb2180673796e54d73dc5","0x292be6baee291a148006db984f200dbdb34b12fb2136c70bfe88649c12d934b"),
 "UNO": ("0x0719b5092403233201aa822ce928bd4b551d0cdb071a724edd7dc5e5f57b7f34","0x01325caf7c91ee415b8df721fb952fa88486a0fc250063eafddd5d3c67867ce7","0x2a3a9d7bcecc6d3121e3b6180b73c7e8f4c5f81c35a90c8dd457a70a842b723","0x6757ef9960c5bc711d1ba7f7a3bff44a45ba9e28f2ac0cc63ee957e6cada8ea","0x7d717fb27c9856ea10068d864465a2a8f9f669f4f78013967de06149c09b9af","0x4b036839a8769c04144cc47415c64b083a2b26e4a7daa53c07f6042a0d35792"),
 "NSTR": ("0x00c530f2c0aa4c16a0806365b0898499fba372e5df7a7172dc6fe9ba777e8007","0x2589fc11f60f21af6a1dda3aeb7a44305c552928af122f2834d1c3b1a7aa626","0x46ab56ec0c6a6d42384251c97e9331aa75eb693e05ed8823e2df4de5713e9a4","0x2b674ffda238279de5550d6f996bf717228d316555f07a77ef0a082d925b782","0x6f8ad459c712873993e9ffb9013a469248343c3d361e4d91a8cac6f98575834","0x3e0576565c1b51fcac3b402eb002447f21e97abb5da7011c0a2e0b465136814"),
 "DAI": ("0x05574eb6b8789a91466f902c380d978e472db68170ff82a5b650b95a58ddf4ad","0x65bde349f553cf4bdd873e54cd48317eda0542764ebe5ba46984cedd940a5e4",ZERO,"0x184dd6328115c2d5f038792e427f3d81d9552e40dd675e013ccbf74ba50b979",ZERO,"0x06726ec97bae4e28efa8993a8e0853bd4bad0bd71de44c23a1cd651b026b00e7"),
 "EKUBO": ("0x075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87","0x6fd4a9efd0c884e0b29506169dd2fcad6b284d5bdbd46ede424abc26d71164","0x2360bd006d42c1a17d23ebe7ae246a0764dea4ac86201884514f86754ccc7b8","0x45863a5605ea7e77f2b043888a9efb1ff6e6b0fb9e62790ff987b2e084ca1f6","0x6b1063a4d5c32fef3486bf29d1719eb09481b52d31f7d86a50c64b0b8d5defb","0x73fa792a8ad45303db3651c34176dc419bee98bfe45791ab12f884201a90ae2"),
}
CM = "0x073f6addc9339de9822cab4dac8c9431779c09077f02ba7bc36904ea342dd9eb"

def batch(reqs, chunk=15):
    """reqs: list of (method, params). returns list of results."""
    out = []
    for i in range(0, len(reqs), chunk):
        part = reqs[i:i+chunk]
        body = json.dumps([{"jsonrpc":"2.0","id":j,"method":m,"params":p} for j,(m,p) in enumerate(part)])
        for attempt in range(3):
            r = subprocess.run(["curl","-s","-m","30","-X","POST","-H","Content-Type: application/json","-d",body,RPC],capture_output=True,text=True)
            try:
                resp = json.loads(r.stdout)
                if isinstance(resp, list) and len(resp)==len(part):
                    resp.sort(key=lambda x: x["id"])
                    out += resp
                    break
            except Exception:
                pass
            time.sleep(2)
        else:
            out += [{"error":{"message":"batch failed"}}]*len(part)
    return out

def ev(res):
    if res and "result" in res:
        r = res["result"]
        if isinstance(r, list) and len(r)>=2:
            return int(r[0],16) + (int(r[1],16)<<128)
        if isinstance(r, list) and len(r)==1:
            return int(r[0],16)
    return None

reqs = [("starknet_blockNumber",[])]
idx = {}
for name,(und,ib,ibc,nostra,coll,debt) in ASSETS.items():
    for label,addr in [("ib",ib),("ibc",ibc),("nostra",nostra),("coll",coll),("debt",debt)]:
        if addr == ZERO: continue
        idx[(name,label,"ts")] = len(reqs); reqs.append(("starknet_call",[{"contract_address":addr,"entry_point_selector":hex(sn_keccak("totalSupply")),"calldata":[]},"latest"]))
        idx[(name,label,"bal")] = len(reqs); reqs.append(("starknet_call",[{"contract_address":und,"entry_point_selector":hex(sn_keccak("balanceOf")),"calldata":[addr]},"latest"]))
        idx[(name,label,"owner")] = len(reqs); reqs.append(("starknet_call",[{"contract_address":addr,"entry_point_selector":hex(sn_keccak("owner")),"calldata":[]},"latest"]))
    idx[(name,"cm","bal")] = len(reqs); reqs.append(("starknet_call",[{"contract_address":und,"entry_point_selector":hex(sn_keccak("balanceOf")),"calldata":[CM]},"latest"]))
res = batch(reqs)
out = {"block": res[0].get("result"), "assets": {}}
for name,(und,ib,ibc,nostra,coll,debt) in ASSETS.items():
    d = {"underlying":und}
    for label in ["ib","ibc","nostra","coll","debt"]:
        if (name,label,"ts") in idx:
            d[label+"_totalSupply"] = ev(res[idx[(name,label,"ts")]])
            d[label+"_underlying_bal"] = ev(res[idx[(name,label,"bal")]])
            r = res[idx[(name,label,"owner")]]
            d[label+"_owner"] = r["result"][0] if "result" in r else None
        else:
            d[label] = None
    d["cm_underlying_bal"] = ev(res[idx[(name,"cm","bal")]])
    out["assets"][name] = d
    print(name, json.dumps(d))
json.dump(out, open("market_balances.json","w"), indent=1)
print("block:", out["block"])
