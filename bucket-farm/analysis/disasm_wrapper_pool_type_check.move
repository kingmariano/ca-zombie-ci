// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.pool_type_check {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::point;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::pool;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::state;
use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;

struct PoolTypeCheck has drop {
	dummy_field: bool
}

err_wrong_pool() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

public check_stake_response<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: &mut StakeResponse<Ty0>) {
L2:	loc0: TypeName
L3:	loc1: ID
B0:
	0: CopyLoc[1](Arg1: &mut StakeResponse<Ty0>)
	1: FreezeRef
	2: Call pool::stake_res_data<Ty0>(&StakeResponse<Ty0>): ID * address * u64 * TypeName
	3: StLoc[2](loc0: TypeName)
	4: Pop
	5: Pop
	6: StLoc[3](loc1: ID)
	7: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	8: Call point::pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	9: ImmBorrowLoc[3](loc1: ID)
	10: Call vec_map::get<ID, PoolState>(&VecMap<ID, PoolState>, &ID): &PoolState
	11: Call state::asset_type(&PoolState): String
	12: MoveLoc[2](loc0: TypeName)
	13: Call type_name::into_string(TypeName): String
	14: Neq
	15: BrFalse(17)
B1:
	16: Call err_wrong_pool()
B2:
	17: MoveLoc[1](Arg1: &mut StakeResponse<Ty0>)
	18: LdFalse
	19: Pack[0](PoolTypeCheck)
	20: Call pool::stake_res_add_witness<Ty0, PoolTypeCheck>(&mut StakeResponse<Ty0>, PoolTypeCheck)
	21: Ret
}

public check_unstake_response<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: &mut UnstakeResponse<Ty0>) {
L2:	loc0: TypeName
L3:	loc1: ID
B0:
	0: CopyLoc[1](Arg1: &mut UnstakeResponse<Ty0>)
	1: FreezeRef
	2: Call pool::unstake_res_data<Ty0>(&UnstakeResponse<Ty0>): ID * address * u64 * TypeName
	3: StLoc[2](loc0: TypeName)
	4: Pop
	5: Pop
	6: StLoc[3](loc1: ID)
	7: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	8: Call point::pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	9: ImmBorrowLoc[3](loc1: ID)
	10: Call vec_map::get<ID, PoolState>(&VecMap<ID, PoolState>, &ID): &PoolState
	11: Call state::asset_type(&PoolState): String
	12: MoveLoc[2](loc0: TypeName)
	13: Call type_name::into_string(TypeName): String
	14: Neq
	15: BrFalse(17)
B1:
	16: Call err_wrong_pool()
B2:
	17: MoveLoc[1](Arg1: &mut UnstakeResponse<Ty0>)
	18: LdFalse
	19: Pack[0](PoolTypeCheck)
	20: Call pool::unstake_res_add_witness<Ty0, PoolTypeCheck>(&mut UnstakeResponse<Ty0>, PoolTypeCheck)
	21: Ret
}

Constants [
	0 => u64: 0
]
}
