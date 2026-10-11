import json
from starkware.starknet.services.api.contract_class import ContractClass
from starkware.starknet.core.os.class_hash import compute_class_hash

def load_compiled(name):
    d = json.load(open(f"/tmp/opencode/build/{name}.json"))
    return d

def strip_debug(d):
    if isinstance(d, dict) and "program" in d and isinstance(d["program"], dict):
        d["program"]["debug_info"] = None
    return d

for name, onchain in [("Pair","prog_pair_impl"),("Factory","prog_factory_impl"),
                      ("PairProxy","prog_pair_proxy"),("FactoryProxy","prog_factory_proxy")]:
    d = load_compiled(name)
    oc = json.load(open(f"/home/heisenberg/CA/jediswap-v1/analysis/{onchain}.json"))
    # 1) class hash after stripping debug info
    cc = ContractClass.loads(json.dumps(strip_debug(d)))
    print(name, "stripped hash:", hex(compute_class_hash(cc)))
    # 2) compare data
    cdata = d["program"]["data"]; odata = oc["data"]
    same_data = (len(cdata)==len(odata)) and all(int(a,16)==int(b,16) for a,b in zip(cdata,odata))
    print("   data len:", len(cdata), "vs", len(odata), "identical:", same_data)
    if not same_data:
        # find first diff
        for i,(a,b) in enumerate(zip(cdata,odata)):
            if int(a,16)!=int(b,16):
                print("   first data diff at", i, a, b); break
    # 3) hints
    ch = d["program"]["hints"]; oh = oc["hints"]
    print("   hints count:", len(ch), "vs", len(oh))
    common = set(ch)&set(oh)
    print("   common pcs:", len(common))
    diffs = 0
    for pc in sorted(common, key=lambda x:int(x)):
        if ch[pc] != oh[pc]:
            diffs += 1
            if diffs<=2: print("   hint diff at pc", pc, ch[pc][:80], "||", oh[pc][:80])
    print("   hint content diffs:", diffs)
    only_c = set(ch)-set(oh); only_o = set(oh)-set(ch)
    print("   hints only compiled:", len(only_c), "only onchain:", len(only_o))
    if only_c: print("     only_c sample:", sorted(only_c, key=lambda x:int(x))[:5])
    if only_o: print("     only_o sample:", sorted(only_o, key=lambda x:int(x))[:5])
