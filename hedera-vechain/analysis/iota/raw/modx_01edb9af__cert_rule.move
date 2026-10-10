// Move bytecode v6
module 1edb9afe0663b8762d2e0a18923df8bee98d28f3a60ac56ff67a27bbf53a7ac.cert_rule {
use 0000000000000000000000000000000000000000000000000000000000000002::iota;
use 346778989a9f57480ec3fee15f2cd68409c73a62112d40a3efd13987997be68c::cert;
use 346778989a9f57480ec3fee15f2cd68409c73a62112d40a3efd13987997be68c::native_pool;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::collector;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::result;

struct CertRule has drop {
	dummy_field: bool
}

public feed(Arg0: &mut PriceCollector<CERT>, Arg1: &PriceResult<IOTA>, Arg2: &NativePool, Arg3: &Metadata<CERT>) {
L4:	loc0: Float
L5:	loc1: Float
B0:
	0: MoveLoc[1](Arg1: &PriceResult<IOTA>)
	1: Call result::aggregated_price<IOTA>(&PriceResult<IOTA>): Float
	2: StLoc[5](loc1: Float)
	3: MoveLoc[2](Arg2: &NativePool)
	4: MoveLoc[3](Arg3: &Metadata<CERT>)
	5: MoveLoc[5](loc1: Float)
	6: Call float::to_scaled_val(Float): u128
	7: CastU64
	8: Call native_pool::from_shares(&NativePool, &Metadata<CERT>, u64): u64
	9: CastU128
	10: Call float::from_scaled_val(u128): Float
	11: StLoc[4](loc0: Float)
	12: MoveLoc[0](Arg0: &mut PriceCollector<CERT>)
	13: LdFalse
	14: Pack[0](CertRule)
	15: MoveLoc[4](loc0: Float)
	16: Call collector::collect<CERT, CertRule>(&mut PriceCollector<CERT>, CertRule, Float)
	17: Ret
}

}
