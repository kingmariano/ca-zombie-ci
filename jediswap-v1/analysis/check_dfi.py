import json
from starkware.starknet.services.api.contract_class import ContractClass
from starkware.starknet.core.os.class_hash import compute_class_hash
targets = [("Pair","prog_pair_impl","0x2b39bc3f4c1fd5bef8b7d21504c44e0da59cf27b350551b13d913da52e40d3b"),
           ("Factory","prog_factory_impl","0x2580632f25bbee45da5a1a1ef49d03a984f78dde4019069aa9f25aac06f941a"),
           ("PairProxy","prog_pair_proxy","0x7b5cd6a6949cc1730f89d795f2442f6ab431ea6c9a5be00685d50f97433c5eb"),
           ("FactoryProxy","prog_factory_proxy","0x26fe8ea36ec7703569cfe4693b05102940bf122647c4dbf0abc0bb919ce27bd")]
for name, onchain, expected in targets:
    d = json.load(open(f"/tmp/opencode/build/{name}_dfi.json"))
    oc = json.load(open(f"/home/heisenberg/CA/jediswap-v1/analysis/{onchain}.json"))
    cdata = [int(x,16) for x in d["program"]["data"]]; odata=[int(x,16) for x in oc["data"]]
    same_data = cdata == odata
    ch = d["program"]["hints"]; oh = oc["hints"]
    hint_same = json.dumps(ch, sort_keys=True) == json.dumps(oh, sort_keys=True)
    d["program"]["debug_info"] = None
    cc = ContractClass.loads(json.dumps(d))
    h = hex(compute_class_hash(cc))
    print(f"{name}: data_same={same_data} hints_same={hint_same} hash={h} match={h==expected}")
    if not hint_same:
        for pc in sorted(set(ch)&set(oh), key=lambda x:int(x)):
            if ch[pc]!=oh[pc]:
                print("   first hint diff pc", pc); print("    c:", json.dumps(ch[pc])[:200]); print("    o:", json.dumps(oh[pc])[:200]); break
