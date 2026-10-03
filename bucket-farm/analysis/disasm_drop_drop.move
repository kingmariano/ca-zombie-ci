// Move bytecode v6
module 1d627cecd34128bd6fe5a067a3a590d0f62fa514fe19d2a20a31205e3d51ea55.drop {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::admin;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::point;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::url;

struct DROP has drop {
	dummy_field: bool
}

init(Arg0: DROP, Arg1: &mut TxContext) {
L2:	loc0: AdminCap<DROP>
L3:	loc1: CoinMetadata<DROP>
B0:
	0: MoveLoc[0](Arg0: DROP)
	1: LdU8(9)
	2: LdConst[0](vector<u8>: "DRO..)
	3: LdConst[1](vector<u8>: "Buc..)
	4: LdConst[2](vector<u8>: "Par..)
	5: LdConst[3](vector<u8>: "htt..)
	6: Call url::new_unsafe_from_bytes(vector<u8>): Url
	7: Call option::some<Url>(Url): Option<Url>
	8: CopyLoc[1](Arg1: &mut TxContext)
	9: Call coin::create_currency<DROP>(DROP, u8, vector<u8>, vector<u8>, vector<u8>, Option<Url>, &mut TxContext): TreasuryCap<DROP> * CoinMetadata<DROP>
	10: StLoc[3](loc1: CoinMetadata<DROP>)
	11: LdFalse
	12: CopyLoc[1](Arg1: &mut TxContext)
	13: Call point::new<DROP>(TreasuryCap<DROP>, bool, &mut TxContext): PointCenter<DROP> * AdminCap<DROP>
	14: StLoc[2](loc0: AdminCap<DROP>)
	15: Call transfer::public_share_object<PointCenter<DROP>>(PointCenter<DROP>)
	16: MoveLoc[2](loc0: AdminCap<DROP>)
	17: CopyLoc[1](Arg1: &mut TxContext)
	18: FreezeRef
	19: Call tx_context::sender(&TxContext): address
	20: Call transfer::public_transfer<AdminCap<DROP>>(AdminCap<DROP>, address)
	21: MoveLoc[3](loc1: CoinMetadata<DROP>)
	22: MoveLoc[1](Arg1: &mut TxContext)
	23: FreezeRef
	24: Call tx_context::sender(&TxContext): address
	25: Call transfer::public_transfer<CoinMetadata<DROP>>(CoinMetadata<DROP>, address)
	26: Ret
}

Constants [
	0 => vector<u8>: "DROP" // interpreted as UTF8 string
	1 => vector<u8>: "Bucket Drop Token" // interpreted as UTF8 string
	2 => vector<u8>: "Participate in Bucket Protocol Simple Staking to earn drop token and $BUT" // interpreted as UTF8 string
	3 => vector<u8>: "https://aqua-natural-grasshopper-705.mypinata.cloud/ipfs/QmUC11CQt8jGhh5P4xd6NxqKgMNTEvZt2Jfkuu1J7WrRP8" // interpreted as UTF8 string
]
}
