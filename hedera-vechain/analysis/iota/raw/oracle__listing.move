// Move bytecode v6
module 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf.listing {
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;

struct ListingCap has store, key {
	id: UID,
	aggregater_map: VecMap<TypeName, ID>
}

err_already_listed() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call vec_map::empty<TypeName, ID>(): VecMap<TypeName, ID>
	3: Pack[0](ListingCap)
	4: MoveLoc[0](Arg0: &mut TxContext)
	5: FreezeRef
	6: Call tx_context::sender(&TxContext): address
	7: Call transfer::transfer<ListingCap>(ListingCap, address)
	8: Ret
}

public(friend) register<Ty0>(Arg0: &mut ListingCap, Arg1: ID): TypeName {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut ListingCap)
	3: ImmBorrowField[0](ListingCap.aggregater_map: VecMap<TypeName, ID>)
	4: ImmBorrowLoc[2](loc0: TypeName)
	5: Call vec_map::contains<TypeName, ID>(&VecMap<TypeName, ID>, &TypeName): bool
	6: BrFalse(8)
B1:
	7: Call err_already_listed()
B2:
	8: MoveLoc[0](Arg0: &mut ListingCap)
	9: MutBorrowField[0](ListingCap.aggregater_map: VecMap<TypeName, ID>)
	10: CopyLoc[2](loc0: TypeName)
	11: MoveLoc[1](Arg1: ID)
	12: Call vec_map::insert<TypeName, ID>(&mut VecMap<TypeName, ID>, TypeName, ID)
	13: MoveLoc[2](loc0: TypeName)
	14: Ret
}

Constants [
	0 => u64: 0
]
}
