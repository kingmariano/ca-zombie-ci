// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.wrapper {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::pool;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;

struct WrapperRule has drop {
	dummy_field: bool
}

struct StakeRequestWrapper<phantom Ty0, phantom Ty1> {
	req: StakeRequest<Ty0>
}

struct UnstakeRequestWrapper<phantom Ty0, phantom Ty1> {
	req: UnstakeRequest<Ty0>
}

err_wrong_pool_type() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

public wrap_stake_request<Ty0, Ty1>(Arg0: StakeRequest<Ty0>): StakeRequestWrapper<Ty0, Ty1> {
L1:	loc0: TypeName
B0:
	0: ImmBorrowLoc[0](Arg0: StakeRequest<Ty0>)
	1: Call pool::stake_req_data<Ty0>(&StakeRequest<Ty0>): ID * address * u64 * TypeName
	2: StLoc[1](loc0: TypeName)
	3: Pop
	4: Pop
	5: Pop
	6: Call type_name::get<Ty1>(): TypeName
	7: MoveLoc[1](loc0: TypeName)
	8: Neq
	9: BrFalse(11)
B1:
	10: Call err_wrong_pool_type()
B2:
	11: MoveLoc[0](Arg0: StakeRequest<Ty0>)
	12: PackGeneric[0](StakeRequestWrapper<Ty0, Ty1>)
	13: Ret
}

public fulfill_stake<Ty0, Ty1>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: StakeRequestWrapper<Ty0, Ty1>, Arg2: Coin<Ty1>): StakeResponse<Ty0> {
L3:	loc0: StakeRequest<Ty0>
L4:	loc1: StakeResponse<Ty0>
B0:
	0: MoveLoc[1](Arg1: StakeRequestWrapper<Ty0, Ty1>)
	1: UnpackGeneric[0](StakeRequestWrapper<Ty0, Ty1>)
	2: StLoc[3](loc0: StakeRequest<Ty0>)
	3: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	4: MoveLoc[3](loc0: StakeRequest<Ty0>)
	5: MoveLoc[2](Arg2: Coin<Ty1>)
	6: Call pool::fulfill_stake<Ty0, Ty1>(&mut DegenPool<Ty0, Ty1>, StakeRequest<Ty0>, Coin<Ty1>): StakeResponse<Ty0>
	7: StLoc[4](loc1: StakeResponse<Ty0>)
	8: MutBorrowLoc[4](loc1: StakeResponse<Ty0>)
	9: LdFalse
	10: Pack[0](WrapperRule)
	11: Call pool::stake_res_add_witness<Ty0, WrapperRule>(&mut StakeResponse<Ty0>, WrapperRule)
	12: MoveLoc[4](loc1: StakeResponse<Ty0>)
	13: Ret
}

public wrap_unstake_request<Ty0, Ty1>(Arg0: UnstakeRequest<Ty0>): UnstakeRequestWrapper<Ty0, Ty1> {
L1:	loc0: TypeName
B0:
	0: ImmBorrowLoc[0](Arg0: UnstakeRequest<Ty0>)
	1: Call pool::unstake_req_data<Ty0>(&UnstakeRequest<Ty0>): ID * address * u64 * TypeName
	2: StLoc[1](loc0: TypeName)
	3: Pop
	4: Pop
	5: Pop
	6: Call type_name::get<Ty1>(): TypeName
	7: MoveLoc[1](loc0: TypeName)
	8: Neq
	9: BrFalse(11)
B1:
	10: Call err_wrong_pool_type()
B2:
	11: MoveLoc[0](Arg0: UnstakeRequest<Ty0>)
	12: PackGeneric[1](UnstakeRequestWrapper<Ty0, Ty1>)
	13: Ret
}

public fulfill_unstake<Ty0, Ty1>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: UnstakeRequestWrapper<Ty0, Ty1>, Arg2: &mut TxContext): Coin<Ty1> * UnstakeResponse<Ty0> {
L3:	loc0: Coin<Ty1>
L4:	loc1: UnstakeRequest<Ty0>
L5:	loc2: UnstakeResponse<Ty0>
B0:
	0: MoveLoc[1](Arg1: UnstakeRequestWrapper<Ty0, Ty1>)
	1: UnpackGeneric[1](UnstakeRequestWrapper<Ty0, Ty1>)
	2: StLoc[4](loc1: UnstakeRequest<Ty0>)
	3: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	4: MoveLoc[4](loc1: UnstakeRequest<Ty0>)
	5: MoveLoc[2](Arg2: &mut TxContext)
	6: Call pool::fulfill_unstake<Ty0, Ty1>(&mut DegenPool<Ty0, Ty1>, UnstakeRequest<Ty0>, &mut TxContext): Coin<Ty1> * UnstakeResponse<Ty0>
	7: StLoc[5](loc2: UnstakeResponse<Ty0>)
	8: StLoc[3](loc0: Coin<Ty1>)
	9: MutBorrowLoc[5](loc2: UnstakeResponse<Ty0>)
	10: LdFalse
	11: Pack[0](WrapperRule)
	12: Call pool::unstake_res_add_witness<Ty0, WrapperRule>(&mut UnstakeResponse<Ty0>, WrapperRule)
	13: MoveLoc[3](loc0: Coin<Ty1>)
	14: MoveLoc[5](loc2: UnstakeResponse<Ty0>)
	15: Ret
}

Constants [
	0 => u64: 0
]
}
