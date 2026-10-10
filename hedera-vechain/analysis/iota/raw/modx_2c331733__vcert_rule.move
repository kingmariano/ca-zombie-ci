// Move bytecode v6
module 2c3317331b7a1daa69588fb0ab73c1335dba3cb29aa3d3fdc8e80985654312cc.vcert_rule {
use 0000000000000000000000000000000000000000000000000000000000000002::iota;
use e4abf8b6183c106282addbfb8483a043e1a60f1fd3dd91fb727fa284306a27fd::cert;
use e4abf8b6183c106282addbfb8483a043e1a60f1fd3dd91fb727fa284306a27fd::native_pool;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::collector;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::result;

struct VCertRule has drop {
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
	14: Pack[0](VCertRule)
	15: MoveLoc[4](loc0: Float)
	16: Call collector::collect<CERT, VCertRule>(&mut PriceCollector<CERT>, VCertRule, Float)
	17: Ret
}

}
