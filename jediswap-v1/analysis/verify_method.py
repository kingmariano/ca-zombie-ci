import json, base64, gzip
from starkware.starknet.services.api.contract_class import ContractClass
from starkware.starknet.core.os.class_hash import compute_class_hash

def decode_program(cc):
    raw = base64.b64decode(cc["program"])
    try: raw = gzip.decompress(raw)
    except Exception: pass
    return json.loads(raw)

for name, h in [("pair_impl","0x2b39bc3f4c1fd5bef8b7d21504c44e0da59cf27b350551b13d913da52e40d3b"),
                ("factory_impl","0x2580632f25bbee45da5a1a1ef49d03a984f78dde4019069aa9f25aac06f941a"),
                ("pair_proxy","0x7b5cd6a6949cc1730f89d795f2442f6ab431ea6c9a5be00685d50f97433c5eb"),
                ("factory_proxy","0x26fe8ea36ec7703569cfe4693b05102940bf122647c4dbf0abc0bb919ce27bd")]:
    d = json.load(open(f"/home/heisenberg/CA/jediswap-v1/analysis/class_{name}.json"))
    prog = decode_program(d)
    obj = {"program": prog, "entry_points_by_type": d["entry_points_by_type"]}
    if isinstance(d.get("abi"), str):
        try: obj["abi"] = json.loads(d["abi"])
        except Exception: obj["abi"] = None
    else:
        obj["abi"] = d.get("abi")
    cc = ContractClass.loads(json.dumps(obj))
    print(name, "computed:", hex(compute_class_hash(cc)), "expected:", h)
