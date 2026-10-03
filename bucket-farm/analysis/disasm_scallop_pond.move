// Move bytecode v6
module 7b2720e50e5fa5f2ceb95c82b20495b4eaf0c18f3adfdd7de125f6fc65230dbf.pond {
use ce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::buck;
use ce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::pipe;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::market;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::mint;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::redeem;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::reserve;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::version;
use 7b2720e50e5fa5f2ceb95c82b20495b4eaf0c18f3adfdd7de125f6fc65230dbf::math;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;

struct SCALLOP_POND has drop {
	dummy_field: bool
}

struct ScallopPond<phantom Ty0> has key {
	id: UID,
	balance: Balance<MarketCoin<Ty0>>
}

struct AdminCap has store, key {
	id: UID
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Pack[2](AdminCap)
	3: MoveLoc[0](Arg0: &mut TxContext)
	4: FreezeRef
	5: Call tx_context::sender(&TxContext): address
	6: Call transfer::transfer<AdminCap>(AdminCap, address)
	7: Ret
}

public create<Ty0>(Arg0: &AdminCap, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[1](Arg1: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call balance::zero<MarketCoin<Ty0>>(): Balance<MarketCoin<Ty0>>
	3: PackGeneric[0](ScallopPond<Ty0>)
	4: Call transfer::share_object<ScallopPond<Ty0>>(ScallopPond<Ty0>)
	5: Ret
}

public supply<Ty0>(Arg0: &AdminCap, Arg1: &mut ScallopPond<Ty0>, Arg2: &mut BucketProtocol, Arg3: &Version, Arg4: &mut Market, Arg5: &Clock, Arg6: u64, Arg7: &mut TxContext) {
L8:	loc0: OutputCarrier<Ty0, SCALLOP_POND>
L9:	loc1: Balance<Ty0>
L10:	loc2: Coin<MarketCoin<Ty0>>
B0:
	0: MoveLoc[2](Arg2: &mut BucketProtocol)
	1: MoveLoc[6](Arg6: u64)
	2: Call buck::output<Ty0, SCALLOP_POND>(&mut BucketProtocol, u64): OutputCarrier<Ty0, SCALLOP_POND>
	3: StLoc[8](loc0: OutputCarrier<Ty0, SCALLOP_POND>)
	4: LdFalse
	5: Pack[0](SCALLOP_POND)
	6: MoveLoc[8](loc0: OutputCarrier<Ty0, SCALLOP_POND>)
	7: Call pipe::destroy_output_carrier<Ty0, SCALLOP_POND>(SCALLOP_POND, OutputCarrier<Ty0, SCALLOP_POND>): Balance<Ty0>
	8: StLoc[9](loc1: Balance<Ty0>)
	9: MoveLoc[3](Arg3: &Version)
	10: MoveLoc[4](Arg4: &mut Market)
	11: MoveLoc[9](loc1: Balance<Ty0>)
	12: CopyLoc[7](Arg7: &mut TxContext)
	13: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	14: MoveLoc[5](Arg5: &Clock)
	15: MoveLoc[7](Arg7: &mut TxContext)
	16: Call mint::mint<Ty0>(&Version, &mut Market, Coin<Ty0>, &Clock, &mut TxContext): Coin<MarketCoin<Ty0>>
	17: StLoc[10](loc2: Coin<MarketCoin<Ty0>>)
	18: MoveLoc[1](Arg1: &mut ScallopPond<Ty0>)
	19: MutBorrowFieldGeneric[0](ScallopPond.balance: Balance<MarketCoin<Ty0>>)
	20: MoveLoc[10](loc2: Coin<MarketCoin<Ty0>>)
	21: Call coin::put<MarketCoin<Ty0>>(&mut Balance<MarketCoin<Ty0>>, Coin<MarketCoin<Ty0>>)
	22: Ret
}

public withdraw<Ty0>(Arg0: &AdminCap, Arg1: &mut ScallopPond<Ty0>, Arg2: &mut BucketProtocol, Arg3: &Version, Arg4: &mut Market, Arg5: &Clock, Arg6: u64, Arg7: &mut TxContext) {
L8:	loc0: InputCarrier<Ty0, SCALLOP_POND>
L9:	loc1: Coin<Ty0>
L10:	loc2: Coin<MarketCoin<Ty0>>
L11:	loc3: u64
B0:
	0: CopyLoc[3](Arg3: &Version)
	1: CopyLoc[4](Arg4: &mut Market)
	2: Call type_name::get<Ty0>(): TypeName
	3: CopyLoc[5](Arg5: &Clock)
	4: MoveLoc[6](Arg6: u64)
	5: Call math::calc_coin_to_scoin(&Version, &mut Market, TypeName, &Clock, u64): u64
	6: StLoc[11](loc3: u64)
	7: MoveLoc[1](Arg1: &mut ScallopPond<Ty0>)
	8: MutBorrowFieldGeneric[0](ScallopPond.balance: Balance<MarketCoin<Ty0>>)
	9: MoveLoc[11](loc3: u64)
	10: CopyLoc[7](Arg7: &mut TxContext)
	11: Call coin::take<MarketCoin<Ty0>>(&mut Balance<MarketCoin<Ty0>>, u64, &mut TxContext): Coin<MarketCoin<Ty0>>
	12: StLoc[10](loc2: Coin<MarketCoin<Ty0>>)
	13: MoveLoc[3](Arg3: &Version)
	14: MoveLoc[4](Arg4: &mut Market)
	15: MoveLoc[10](loc2: Coin<MarketCoin<Ty0>>)
	16: MoveLoc[5](Arg5: &Clock)
	17: MoveLoc[7](Arg7: &mut TxContext)
	18: Call redeem::redeem<Ty0>(&Version, &mut Market, Coin<MarketCoin<Ty0>>, &Clock, &mut TxContext): Coin<Ty0>
	19: StLoc[9](loc1: Coin<Ty0>)
	20: LdFalse
	21: Pack[0](SCALLOP_POND)
	22: MoveLoc[9](loc1: Coin<Ty0>)
	23: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	24: Call pipe::input<Ty0, SCALLOP_POND>(SCALLOP_POND, Balance<Ty0>): InputCarrier<Ty0, SCALLOP_POND>
	25: StLoc[8](loc0: InputCarrier<Ty0, SCALLOP_POND>)
	26: MoveLoc[2](Arg2: &mut BucketProtocol)
	27: MoveLoc[8](loc0: InputCarrier<Ty0, SCALLOP_POND>)
	28: Call buck::input<Ty0, SCALLOP_POND>(&mut BucketProtocol, InputCarrier<Ty0, SCALLOP_POND>)
	29: Ret
}

public claim<Ty0>(Arg0: &AdminCap, Arg1: &mut ScallopPond<Ty0>, Arg2: &BucketProtocol, Arg3: &Version, Arg4: &mut Market, Arg5: &Clock, Arg6: &mut TxContext): Coin<Ty0> {
L7:	loc0: Coin<MarketCoin<Ty0>>
L8:	loc1: u64
L9:	loc2: u64
L10:	loc3: u64
B0:
	0: MoveLoc[2](Arg2: &BucketProtocol)
	1: Call buck::borrow_pipe<Ty0, SCALLOP_POND>(&BucketProtocol): &Pipe<Ty0, SCALLOP_POND>
	2: Call pipe::output_volume<Ty0, SCALLOP_POND>(&Pipe<Ty0, SCALLOP_POND>): u64
	3: StLoc[10](loc3: u64)
	4: CopyLoc[3](Arg3: &Version)
	5: CopyLoc[4](Arg4: &mut Market)
	6: Call type_name::get<Ty0>(): TypeName
	7: CopyLoc[5](Arg5: &Clock)
	8: MoveLoc[10](loc3: u64)
	9: Call math::calc_coin_to_scoin(&Version, &mut Market, TypeName, &Clock, u64): u64
	10: StLoc[9](loc2: u64)
	11: CopyLoc[1](Arg1: &mut ScallopPond<Ty0>)
	12: ImmBorrowFieldGeneric[0](ScallopPond.balance: Balance<MarketCoin<Ty0>>)
	13: Call balance::value<MarketCoin<Ty0>>(&Balance<MarketCoin<Ty0>>): u64
	14: MoveLoc[9](loc2: u64)
	15: Sub
	16: StLoc[8](loc1: u64)
	17: MoveLoc[1](Arg1: &mut ScallopPond<Ty0>)
	18: MutBorrowFieldGeneric[0](ScallopPond.balance: Balance<MarketCoin<Ty0>>)
	19: MoveLoc[8](loc1: u64)
	20: CopyLoc[6](Arg6: &mut TxContext)
	21: Call coin::take<MarketCoin<Ty0>>(&mut Balance<MarketCoin<Ty0>>, u64, &mut TxContext): Coin<MarketCoin<Ty0>>
	22: StLoc[7](loc0: Coin<MarketCoin<Ty0>>)
	23: MoveLoc[3](Arg3: &Version)
	24: MoveLoc[4](Arg4: &mut Market)
	25: MoveLoc[7](loc0: Coin<MarketCoin<Ty0>>)
	26: MoveLoc[5](Arg5: &Clock)
	27: MoveLoc[6](Arg6: &mut TxContext)
	28: Call redeem::redeem<Ty0>(&Version, &mut Market, Coin<MarketCoin<Ty0>>, &Clock, &mut TxContext): Coin<Ty0>
	29: Ret
}

entry claim_to<Ty0>(Arg0: &AdminCap, Arg1: &mut ScallopPond<Ty0>, Arg2: &BucketProtocol, Arg3: &Version, Arg4: &mut Market, Arg5: &Clock, Arg6: address, Arg7: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &mut ScallopPond<Ty0>)
	2: MoveLoc[2](Arg2: &BucketProtocol)
	3: MoveLoc[3](Arg3: &Version)
	4: MoveLoc[4](Arg4: &mut Market)
	5: MoveLoc[5](Arg5: &Clock)
	6: MoveLoc[7](Arg7: &mut TxContext)
	7: Call claim<Ty0>(&AdminCap, &mut ScallopPond<Ty0>, &BucketProtocol, &Version, &mut Market, &Clock, &mut TxContext): Coin<Ty0>
	8: MoveLoc[6](Arg6: address)
	9: Call transfer::public_transfer<Coin<Ty0>>(Coin<Ty0>, address)
	10: Ret
}

}
