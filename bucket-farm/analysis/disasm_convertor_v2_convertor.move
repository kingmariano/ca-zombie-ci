// Move bytecode v6
module 75c86bc3ce3bb66c92b88a192d27a3334a72b54edc0d874c7850ffa97ce2820b.convertor {
use 3a4b399e18cec6129723c71605378bd554f53eb63afc1039f9af9a067a8847fa::bucket;
use bc858cb910b9914bee64fff0f9b38855355a040c49155a17b265d9086d256545::but;
use 6104e610f707fe5f1b3f34aa274c113a6b0523e63d5fb2069710e1c2d1f1fd1c::de_center;
use 6104e610f707fe5f1b3f34aa274c113a6b0523e63d5fb2069710e1c2d1f1fd1c::de_token;
use 0959a7135a3e96868aac57bb2ae493db76714815797349384671a62d256b1f6d::de_wrapper;
use 0959a7135a3e96868aac57bb2ae493db76714815797349384671a62d256b1f6d::reward_center;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::point;
use 1d627cecd34128bd6fe5a067a3a590d0f62fa514fe19d2a20a31205e3d51ea55::drop;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::account;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::float;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;

struct DROP_TO_BUT has drop {
	dummy_field: bool
}

struct ButConvertor has key {
	id: UID,
	versions: VecSet<u64>,
	conversion_rate: Float,
	is_public: bool,
	whitelist: VecSet<address>,
	reserve: Balance<BUT>
}

struct AdminCap has key {
	id: UID
}

struct ConvertEvent has copy, drop {
	drop_amount_in: u64,
	but_amount_out: u64
}

public package_version(): u64 {
B0:
	0: LdConst[0](u64: 1)
	1: Ret
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Pack[2](AdminCap)
	3: CopyLoc[0](Arg0: &mut TxContext)
	4: FreezeRef
	5: Call tx_context::sender(&TxContext): address
	6: Call transfer::transfer<AdminCap>(AdminCap, address)
	7: MoveLoc[0](Arg0: &mut TxContext)
	8: Call object::new(&mut TxContext): UID
	9: Call package_version(): u64
	10: Call vec_set::singleton<u64>(u64): VecSet<u64>
	11: LdU64(0)
	12: Call float::from(u64): Float
	13: LdFalse
	14: Call vec_set::empty<address>(): VecSet<address>
	15: Call balance::zero<BUT>(): Balance<BUT>
	16: Pack[1](ButConvertor)
	17: Call transfer::share_object<ButConvertor>(ButConvertor)
	18: Ret
}

public add_version(Arg0: &mut ButConvertor, Arg1: &AdminCap, Arg2: u64) {
B0:
	0: MoveLoc[0](Arg0: &mut ButConvertor)
	1: MutBorrowField[0](ButConvertor.versions: VecSet<u64>)
	2: MoveLoc[2](Arg2: u64)
	3: Call vec_set::insert<u64>(&mut VecSet<u64>, u64)
	4: Ret
}

public remove_version(Arg0: &mut ButConvertor, Arg1: &AdminCap, Arg2: u64) {
B0:
	0: MoveLoc[0](Arg0: &mut ButConvertor)
	1: MutBorrowField[0](ButConvertor.versions: VecSet<u64>)
	2: ImmBorrowLoc[2](Arg2: u64)
	3: Call vec_set::remove<u64>(&mut VecSet<u64>, &u64)
	4: Ret
}

public update_conversion_rate(Arg0: &mut ButConvertor, Arg1: &AdminCap, Arg2: u64, Arg3: u64) {
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: Call check_package_version(&ButConvertor)
	3: MoveLoc[2](Arg2: u64)
	4: MoveLoc[3](Arg3: u64)
	5: Call float::from_fraction(u64, u64): Float
	6: MoveLoc[0](Arg0: &mut ButConvertor)
	7: MutBorrowField[1](ButConvertor.conversion_rate: Float)
	8: WriteRef
	9: Ret
}

public add_whitelist(Arg0: &mut ButConvertor, Arg1: &AdminCap, Arg2: address) {
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: Call check_package_version(&ButConvertor)
	3: MoveLoc[0](Arg0: &mut ButConvertor)
	4: MutBorrowField[2](ButConvertor.whitelist: VecSet<address>)
	5: MoveLoc[2](Arg2: address)
	6: Call vec_set::insert<address>(&mut VecSet<address>, address)
	7: Ret
}

public remove_whitelist(Arg0: &mut ButConvertor, Arg1: &AdminCap, Arg2: address) {
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: Call check_package_version(&ButConvertor)
	3: MoveLoc[0](Arg0: &mut ButConvertor)
	4: MutBorrowField[2](ButConvertor.whitelist: VecSet<address>)
	5: ImmBorrowLoc[2](Arg2: address)
	6: Call vec_set::remove<address>(&mut VecSet<address>, &address)
	7: Ret
}

public toggle_is_public(Arg0: &mut ButConvertor, Arg1: &AdminCap) {
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: Call check_package_version(&ButConvertor)
	3: CopyLoc[0](Arg0: &mut ButConvertor)
	4: ImmBorrowField[3](ButConvertor.is_public: bool)
	5: ReadRef
	6: Not
	7: MoveLoc[0](Arg0: &mut ButConvertor)
	8: MutBorrowField[3](ButConvertor.is_public: bool)
	9: WriteRef
	10: Ret
}

public topup_reserve(Arg0: &mut ButConvertor, Arg1: Balance<BUT>) {
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: Call check_package_version(&ButConvertor)
	3: MoveLoc[0](Arg0: &mut ButConvertor)
	4: MutBorrowField[4](ButConvertor.reserve: Balance<BUT>)
	5: MoveLoc[1](Arg1: Balance<BUT>)
	6: Call balance::join<BUT>(&mut Balance<BUT>, Balance<BUT>): u64
	7: Pop
	8: Ret
}

public claim_drop_from_point_center(Arg0: &mut PointCenter<DROP>, Arg1: AccountRequest, Arg2: u64, Arg3: &Clock, Arg4: &mut TxContext): Coin<DROP> {
B0:
	0: MoveLoc[0](Arg0: &mut PointCenter<DROP>)
	1: MoveLoc[3](Arg3: &Clock)
	2: MoveLoc[1](Arg1: AccountRequest)
	3: MoveLoc[2](Arg2: u64)
	4: MoveLoc[4](Arg4: &mut TxContext)
	5: Call point::claim<DROP>(&mut PointCenter<DROP>, &Clock, AccountRequest, u64, &mut TxContext): Coin<DROP>
	6: Ret
}

public claim_drop_from_reward_center(Arg0: &mut RewardCenter<BUT, BUCKET, DROP>, Arg1: &DeWrapper<BUT, BUCKET>, Arg2: &Clock, Arg3: &mut TxContext): Coin<DROP> {
B0:
	0: MoveLoc[0](Arg0: &mut RewardCenter<BUT, BUCKET, DROP>)
	1: MoveLoc[1](Arg1: &DeWrapper<BUT, BUCKET>)
	2: MoveLoc[2](Arg2: &Clock)
	3: Call reward_center::claim<BUT, BUCKET, DROP>(&mut RewardCenter<BUT, BUCKET, DROP>, &DeWrapper<BUT, BUCKET>, &Clock): Balance<DROP>
	4: MoveLoc[3](Arg3: &mut TxContext)
	5: Call coin::from_balance<DROP>(Balance<DROP>, &mut TxContext): Coin<DROP>
	6: Ret
}

public early_unlock(Arg0: &mut ButConvertor, Arg1: &mut DeCenter<BUT, BUCKET>, Arg2: &mut DeWrapper<BUT, BUCKET>, Arg3: ID, Arg4: &Clock, Arg5: &mut TxContext): Coin<BUT> * DeTokenUpdateResponse<BUT, BUCKET> {
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: CopyLoc[5](Arg5: &mut TxContext)
	3: FreezeRef
	4: Call check_allowance(&ButConvertor, &TxContext)
	5: MoveLoc[0](Arg0: &mut ButConvertor)
	6: FreezeRef
	7: Call check_package_version(&ButConvertor)
	8: MoveLoc[2](Arg2: &mut DeWrapper<BUT, BUCKET>)
	9: MoveLoc[1](Arg1: &mut DeCenter<BUT, BUCKET>)
	10: LdFalse
	11: Pack[0](DROP_TO_BUT)
	12: MoveLoc[3](Arg3: ID)
	13: MoveLoc[4](Arg4: &Clock)
	14: MoveLoc[5](Arg5: &mut TxContext)
	15: Call de_wrapper::force_unlock_with_whitelist<BUT, BUCKET, DROP_TO_BUT>(&mut DeWrapper<BUT, BUCKET>, &mut DeCenter<BUT, BUCKET>, DROP_TO_BUT, ID, &Clock, &mut TxContext): Coin<BUT> * DeTokenUpdateResponse<BUT, BUCKET>
	16: Ret
}

public early_unlock_with_de_token(Arg0: &mut ButConvertor, Arg1: &mut DeCenter<BUT, BUCKET>, Arg2: DeToken<BUT, BUCKET>, Arg3: &Clock, Arg4: &mut TxContext): Coin<BUT> * DeTokenUpdateResponse<BUT, BUCKET> {
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: CopyLoc[4](Arg4: &mut TxContext)
	3: FreezeRef
	4: Call check_allowance(&ButConvertor, &TxContext)
	5: MoveLoc[0](Arg0: &mut ButConvertor)
	6: FreezeRef
	7: Call check_package_version(&ButConvertor)
	8: MoveLoc[1](Arg1: &mut DeCenter<BUT, BUCKET>)
	9: MoveLoc[2](Arg2: DeToken<BUT, BUCKET>)
	10: LdFalse
	11: Pack[0](DROP_TO_BUT)
	12: MoveLoc[3](Arg3: &Clock)
	13: MoveLoc[4](Arg4: &mut TxContext)
	14: Call de_center::force_unlock_with_whitelist<BUT, BUCKET, DROP_TO_BUT>(&mut DeCenter<BUT, BUCKET>, DeToken<BUT, BUCKET>, DROP_TO_BUT, &Clock, &mut TxContext): Coin<BUT> * DeTokenUpdateResponse<BUT, BUCKET>
	15: Ret
}

public convert_to_but(Arg0: &mut ButConvertor, Arg1: &mut PointCenter<DROP>, Arg2: Coin<DROP>, Arg3: &mut TxContext): Coin<BUT> {
L4:	loc0: u64
L5:	loc1: u64
B0:
	0: CopyLoc[0](Arg0: &mut ButConvertor)
	1: FreezeRef
	2: CopyLoc[3](Arg3: &mut TxContext)
	3: FreezeRef
	4: Call check_allowance(&ButConvertor, &TxContext)
	5: CopyLoc[0](Arg0: &mut ButConvertor)
	6: FreezeRef
	7: Call check_package_version(&ButConvertor)
	8: ImmBorrowLoc[2](Arg2: Coin<DROP>)
	9: Call coin::value<DROP>(&Coin<DROP>): u64
	10: StLoc[5](loc1: u64)
	11: CopyLoc[5](loc1: u64)
	12: Call float::from(u64): Float
	13: CopyLoc[0](Arg0: &mut ButConvertor)
	14: ImmBorrowField[1](ButConvertor.conversion_rate: Float)
	15: ReadRef
	16: Call float::mul(Float, Float): Float
	17: Call float::floor(Float): u64
	18: StLoc[4](loc0: u64)
	19: MoveLoc[1](Arg1: &mut PointCenter<DROP>)
	20: MoveLoc[2](Arg2: Coin<DROP>)
	21: LdFalse
	22: Pack[0](DROP_TO_BUT)
	23: Call point::burn_with_witness<DROP, DROP_TO_BUT>(&mut PointCenter<DROP>, Coin<DROP>, DROP_TO_BUT): u64
	24: Pop
	25: MoveLoc[5](loc1: u64)
	26: CopyLoc[4](loc0: u64)
	27: Pack[3](ConvertEvent)
	28: Call event::emit<ConvertEvent>(ConvertEvent)
	29: MoveLoc[0](Arg0: &mut ButConvertor)
	30: MutBorrowField[4](ButConvertor.reserve: Balance<BUT>)
	31: MoveLoc[4](loc0: u64)
	32: Call balance::split<BUT>(&mut Balance<BUT>, u64): Balance<BUT>
	33: MoveLoc[3](Arg3: &mut TxContext)
	34: Call coin::from_balance<BUT>(Balance<BUT>, &mut TxContext): Coin<BUT>
	35: Ret
}

check_package_version(Arg0: &ButConvertor) {
L1:	loc0: u64
L2:	loc1: &VecSet<u64>
B0:
	0: MoveLoc[0](Arg0: &ButConvertor)
	1: ImmBorrowField[0](ButConvertor.versions: VecSet<u64>)
	2: StLoc[2](loc1: &VecSet<u64>)
	3: Call package_version(): u64
	4: StLoc[1](loc0: u64)
	5: MoveLoc[2](loc1: &VecSet<u64>)
	6: ImmBorrowLoc[1](loc0: u64)
	7: Call vec_set::contains<u64>(&VecSet<u64>, &u64): bool
	8: BrFalse(10)
B1:
	9: Branch(12)
B2:
	10: LdConst[1](u64: 101)
	11: Abort
B3:
	12: Ret
}

check_allowance(Arg0: &ButConvertor, Arg1: &TxContext) {
L2:	loc0: bool
L3:	loc1: address
L4:	loc2: &VecSet<address>
B0:
	0: CopyLoc[0](Arg0: &ButConvertor)
	1: ImmBorrowField[3](ButConvertor.is_public: bool)
	2: ReadRef
	3: BrFalse(11)
B1:
	4: MoveLoc[0](Arg0: &ButConvertor)
	5: Pop
	6: MoveLoc[1](Arg1: &TxContext)
	7: Pop
	8: LdTrue
	9: StLoc[2](loc0: bool)
	10: Branch(21)
B2:
	11: MoveLoc[0](Arg0: &ButConvertor)
	12: ImmBorrowField[2](ButConvertor.whitelist: VecSet<address>)
	13: StLoc[4](loc2: &VecSet<address>)
	14: MoveLoc[1](Arg1: &TxContext)
	15: Call tx_context::sender(&TxContext): address
	16: StLoc[3](loc1: address)
	17: MoveLoc[4](loc2: &VecSet<address>)
	18: ImmBorrowLoc[3](loc1: address)
	19: Call vec_set::contains<address>(&VecSet<address>, &address): bool
	20: StLoc[2](loc0: bool)
B3:
	21: MoveLoc[2](loc0: bool)
	22: BrFalse(24)
B4:
	23: Branch(26)
B5:
	24: LdConst[2](u64: 102)
	25: Abort
B6:
	26: Ret
}

Constants [
	0 => u64: 1
	1 => u64: 101
	2 => u64: 102
]
}
