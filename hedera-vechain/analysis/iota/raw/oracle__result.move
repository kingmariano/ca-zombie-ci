// Move bytecode v6
module 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf.result {
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;

struct PriceResult<phantom Ty0> has copy, drop {
	aggregated_price: Float
}

public(friend) new<Ty0>(Arg0: Float): PriceResult<Ty0> {
B0:
	0: MoveLoc[0](Arg0: Float)
	1: PackGeneric[0](PriceResult<Ty0>)
	2: Ret
}

public aggregated_price<Ty0>(Arg0: &PriceResult<Ty0>): Float {
B0:
	0: MoveLoc[0](Arg0: &PriceResult<Ty0>)
	1: ImmBorrowFieldGeneric[0](PriceResult.aggregated_price: Float)
	2: ReadRef
	3: Ret
}

}
