// Move bytecode v6
module 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf.collector {
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;

struct PriceCollector<phantom Ty0> has drop {
	contents: VecMap<TypeName, Float>
}

public new<Ty0>(): PriceCollector<Ty0> {
B0:
	0: Call vec_map::empty<TypeName, Float>(): VecMap<TypeName, Float>
	1: PackGeneric[0](PriceCollector<Ty0>)
	2: Ret
}

public collect<Ty0, Ty1: drop>(Arg0: &mut PriceCollector<Ty0>, Arg1: Ty1, Arg2: Float) {
L3:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[3](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut PriceCollector<Ty0>)
	3: FreezeRef
	4: Call contents<Ty0>(&PriceCollector<Ty0>): &VecMap<TypeName, Float>
	5: ImmBorrowLoc[3](loc0: TypeName)
	6: Call vec_map::contains<TypeName, Float>(&VecMap<TypeName, Float>, &TypeName): bool
	7: Not
	8: BrFalse(15)
B1:
	9: MoveLoc[0](Arg0: &mut PriceCollector<Ty0>)
	10: MutBorrowFieldGeneric[0](PriceCollector.contents: VecMap<TypeName, Float>)
	11: MoveLoc[3](loc0: TypeName)
	12: MoveLoc[2](Arg2: Float)
	13: Call vec_map::insert<TypeName, Float>(&mut VecMap<TypeName, Float>, TypeName, Float)
	14: Branch(21)
B2:
	15: MoveLoc[2](Arg2: Float)
	16: MoveLoc[0](Arg0: &mut PriceCollector<Ty0>)
	17: MutBorrowFieldGeneric[0](PriceCollector.contents: VecMap<TypeName, Float>)
	18: ImmBorrowLoc[3](loc0: TypeName)
	19: Call vec_map::get_mut<TypeName, Float>(&mut VecMap<TypeName, Float>, &TypeName): &mut Float
	20: WriteRef
B3:
	21: Ret
}

public contents<Ty0>(Arg0: &PriceCollector<Ty0>): &VecMap<TypeName, Float> {
B0:
	0: MoveLoc[0](Arg0: &PriceCollector<Ty0>)
	1: ImmBorrowFieldGeneric[0](PriceCollector.contents: VecMap<TypeName, Float>)
	2: Ret
}

}
