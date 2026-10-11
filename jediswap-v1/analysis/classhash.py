from starkware.starknet.services.api.contract_class import ContractClass
from starkware.starknet.core.os.class_hash import compute_class_hash

for name in ["Pair", "Factory", "PairProxy", "FactoryProxy"]:
    p = f"/tmp/opencode/build/{name}.json"
    cc = ContractClass.loads(open(p).read())
    print(name, hex(compute_class_hash(cc)))
