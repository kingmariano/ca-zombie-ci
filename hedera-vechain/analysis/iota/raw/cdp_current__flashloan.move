// Move bytecode v6
module cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1.flashloan {
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::memo;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::vault;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::version;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::witness;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::account;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::admin;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::vusd;

struct GlobalConfig has key {
	id: UID,
	default_fee_rate: Float,
	partner_fee_rates: VecMap<address, Float>,
	protected_vault_ids: VecSet<ID>
}

struct FlashLoanReceipt {
	loan_amount: u64,
	fee_amount: u64
}

err_flash_burn_not_enough() {
B0:
	0: LdConst[0](u64: 501)
	1: Abort
}

err_vault_is_protected() {
B0:
	0: LdConst[1](u64: 502)
	1: Abort
}

public create_config(Arg0: &AdminCap, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[1](Arg1: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: LdU64(5)
	3: Call float::from_bps(u64): Float
	4: Call vec_map::empty<address, Float>(): VecMap<address, Float>
	5: Call vec_set::empty<ID>(): VecSet<ID>
	6: Pack[0](GlobalConfig)
	7: Call transfer::share_object<GlobalConfig>(GlobalConfig)
	8: Ret
}

public set_fee_rate(Arg0: &mut GlobalConfig, Arg1: &AdminCap, Arg2: Option<address>, Arg3: u64) {
L4:	loc0: &address
B0:
	0: ImmBorrowLoc[2](Arg2: Option<address>)
	1: Call option::is_some<address>(&Option<address>): bool
	2: BrFalse(27)
B1:
	3: ImmBorrowLoc[2](Arg2: Option<address>)
	4: Call option::borrow<address>(&Option<address>): &address
	5: StLoc[4](loc0: &address)
	6: CopyLoc[0](Arg0: &mut GlobalConfig)
	7: ImmBorrowField[0](GlobalConfig.partner_fee_rates: VecMap<address, Float>)
	8: CopyLoc[4](loc0: &address)
	9: Call vec_map::contains<address, Float>(&VecMap<address, Float>, &address): bool
	10: BrFalse(19)
B2:
	11: MoveLoc[3](Arg3: u64)
	12: Call float::from_bps(u64): Float
	13: MoveLoc[0](Arg0: &mut GlobalConfig)
	14: MutBorrowField[0](GlobalConfig.partner_fee_rates: VecMap<address, Float>)
	15: MoveLoc[4](loc0: &address)
	16: Call vec_map::get_mut<address, Float>(&mut VecMap<address, Float>, &address): &mut Float
	17: WriteRef
	18: Branch(32)
B3:
	19: MoveLoc[0](Arg0: &mut GlobalConfig)
	20: MutBorrowField[0](GlobalConfig.partner_fee_rates: VecMap<address, Float>)
	21: MoveLoc[4](loc0: &address)
	22: ReadRef
	23: MoveLoc[3](Arg3: u64)
	24: Call float::from_bps(u64): Float
	25: Call vec_map::insert<address, Float>(&mut VecMap<address, Float>, address, Float)
	26: Branch(32)
B4:
	27: MoveLoc[3](Arg3: u64)
	28: Call float::from_bps(u64): Float
	29: MoveLoc[0](Arg0: &mut GlobalConfig)
	30: MutBorrowField[1](GlobalConfig.default_fee_rate: Float)
	31: WriteRef
B5:
	32: Ret
}

public protect_vault<Ty0>(Arg0: &mut GlobalConfig, Arg1: &AdminCap, Arg2: &Vault<Ty0>) {
L3:	loc0: ID
B0:
	0: MoveLoc[2](Arg2: &Vault<Ty0>)
	1: Call vault::id<Ty0>(&Vault<Ty0>): ID
	2: StLoc[3](loc0: ID)
	3: CopyLoc[0](Arg0: &mut GlobalConfig)
	4: ImmBorrowField[2](GlobalConfig.protected_vault_ids: VecSet<ID>)
	5: ImmBorrowLoc[3](loc0: ID)
	6: Call vec_set::contains<ID>(&VecSet<ID>, &ID): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut GlobalConfig)
	10: MutBorrowField[2](GlobalConfig.protected_vault_ids: VecSet<ID>)
	11: MoveLoc[3](loc0: ID)
	12: Call vec_set::insert<ID>(&mut VecSet<ID>, ID)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut GlobalConfig)
	15: Pop
B3:
	16: Ret
}

public flash_loan<Ty0>(Arg0: &GlobalConfig, Arg1: &Treasury, Arg2: &mut Vault<Ty0>, Arg3: &Option<AccountRequest>, Arg4: u64, Arg5: &mut TxContext): Coin<Ty0> * FlashLoanReceipt {
L6:	loc0: ID
L7:	loc1: &VecSet<ID>
L8:	loc2: address
L9:	loc3: &VecMap<address, Float>
L10:	loc4: Float
L11:	loc5: u64
L12:	loc6: Float
L13:	loc7: Coin<Ty0>
L14:	loc8: FlashLoanReceipt
B0:
	0: MoveLoc[1](Arg1: &Treasury)
	1: Call version::assert_valid_package(&Treasury)
	2: CopyLoc[0](Arg0: &GlobalConfig)
	3: ImmBorrowField[2](GlobalConfig.protected_vault_ids: VecSet<ID>)
	4: StLoc[7](loc1: &VecSet<ID>)
	5: CopyLoc[2](Arg2: &mut Vault<Ty0>)
	6: FreezeRef
	7: Call vault::id<Ty0>(&Vault<Ty0>): ID
	8: StLoc[6](loc0: ID)
	9: MoveLoc[7](loc1: &VecSet<ID>)
	10: ImmBorrowLoc[6](loc0: ID)
	11: Call vec_set::contains<ID>(&VecSet<ID>, &ID): bool
	12: BrFalse(14)
B1:
	13: Call err_vault_is_protected()
B2:
	14: CopyLoc[3](Arg3: &Option<AccountRequest>)
	15: Call option::is_some<AccountRequest>(&Option<AccountRequest>): bool
	16: BrFalse(30)
B3:
	17: MoveLoc[0](Arg0: &GlobalConfig)
	18: ImmBorrowField[0](GlobalConfig.partner_fee_rates: VecMap<address, Float>)
	19: StLoc[9](loc3: &VecMap<address, Float>)
	20: MoveLoc[3](Arg3: &Option<AccountRequest>)
	21: Call option::borrow<AccountRequest>(&Option<AccountRequest>): &AccountRequest
	22: Call account::request_address(&AccountRequest): address
	23: StLoc[8](loc2: address)
	24: MoveLoc[9](loc3: &VecMap<address, Float>)
	25: ImmBorrowLoc[8](loc2: address)
	26: Call vec_map::get<address, Float>(&VecMap<address, Float>, &address): &Float
	27: ReadRef
	28: StLoc[10](loc4: Float)
	29: Branch(36)
B4:
	30: MoveLoc[3](Arg3: &Option<AccountRequest>)
	31: Pop
	32: MoveLoc[0](Arg0: &GlobalConfig)
	33: ImmBorrowField[1](GlobalConfig.default_fee_rate: Float)
	34: ReadRef
	35: StLoc[10](loc4: Float)
B5:
	36: MoveLoc[10](loc4: Float)
	37: StLoc[12](loc6: Float)
	38: MoveLoc[2](Arg2: &mut Vault<Ty0>)
	39: CopyLoc[4](Arg4: u64)
	40: Call vault::split<Ty0>(&mut Vault<Ty0>, u64): Balance<Ty0>
	41: MoveLoc[5](Arg5: &mut TxContext)
	42: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	43: StLoc[13](loc7: Coin<Ty0>)
	44: CopyLoc[4](Arg4: u64)
	45: Call float::from(u64): Float
	46: MoveLoc[12](loc6: Float)
	47: Call float::mul(Float, Float): Float
	48: Call float::ceil(Float): u64
	49: StLoc[11](loc5: u64)
	50: MoveLoc[4](Arg4: u64)
	51: MoveLoc[11](loc5: u64)
	52: Pack[1](FlashLoanReceipt)
	53: StLoc[14](loc8: FlashLoanReceipt)
	54: MoveLoc[13](loc7: Coin<Ty0>)
	55: MoveLoc[14](loc8: FlashLoanReceipt)
	56: Ret
}

public flash_repay<Ty0>(Arg0: FlashLoanReceipt, Arg1: &mut Treasury, Arg2: &mut Vault<Ty0>, Arg3: Coin<Ty0>) {
L4:	loc0: u64
L5:	loc1: Balance<Ty0>
L6:	loc2: u64
L7:	loc3: Balance<Ty0>
B0:
	0: CopyLoc[1](Arg1: &mut Treasury)
	1: FreezeRef
	2: Call version::assert_valid_package(&Treasury)
	3: MoveLoc[3](Arg3: Coin<Ty0>)
	4: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	5: StLoc[7](loc3: Balance<Ty0>)
	6: MoveLoc[0](Arg0: FlashLoanReceipt)
	7: Unpack[1](FlashLoanReceipt)
	8: StLoc[4](loc0: u64)
	9: StLoc[6](loc2: u64)
	10: ImmBorrowLoc[7](loc3: Balance<Ty0>)
	11: Call balance::value<Ty0>(&Balance<Ty0>): u64
	12: MoveLoc[6](loc2: u64)
	13: CopyLoc[4](loc0: u64)
	14: Add
	15: Neq
	16: BrFalse(18)
B1:
	17: Call err_flash_burn_not_enough()
B2:
	18: MutBorrowLoc[7](loc3: Balance<Ty0>)
	19: MoveLoc[4](loc0: u64)
	20: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	21: StLoc[5](loc1: Balance<Ty0>)
	22: MoveLoc[2](Arg2: &mut Vault<Ty0>)
	23: MoveLoc[7](loc3: Balance<Ty0>)
	24: Call vault::join<Ty0>(&mut Vault<Ty0>, Balance<Ty0>)
	25: MoveLoc[1](Arg1: &mut Treasury)
	26: Call witness::witness(): VirtueCDP
	27: Call memo::flashloan(): String
	28: MoveLoc[5](loc1: Balance<Ty0>)
	29: Call vusd::collect<Ty0, VirtueCDP>(&mut Treasury, VirtueCDP, String, Balance<Ty0>)
	30: Ret
}

public fee_rate(Arg0: &GlobalConfig, Arg1: Option<address>): Float {
L2:	loc0: Float
B0:
	0: ImmBorrowLoc[1](Arg1: Option<address>)
	1: Call option::is_some<address>(&Option<address>): bool
	2: BrFalse(11)
B1:
	3: MoveLoc[0](Arg0: &GlobalConfig)
	4: ImmBorrowField[0](GlobalConfig.partner_fee_rates: VecMap<address, Float>)
	5: ImmBorrowLoc[1](Arg1: Option<address>)
	6: Call option::borrow<address>(&Option<address>): &address
	7: Call vec_map::get<address, Float>(&VecMap<address, Float>, &address): &Float
	8: ReadRef
	9: StLoc[2](loc0: Float)
	10: Branch(15)
B2:
	11: MoveLoc[0](Arg0: &GlobalConfig)
	12: ImmBorrowField[1](GlobalConfig.default_fee_rate: Float)
	13: ReadRef
	14: StLoc[2](loc0: Float)
B3:
	15: MoveLoc[2](loc0: Float)
	16: Ret
}

public loan_amount(Arg0: &FlashLoanReceipt): u64 {
B0:
	0: MoveLoc[0](Arg0: &FlashLoanReceipt)
	1: ImmBorrowField[3](FlashLoanReceipt.loan_amount: u64)
	2: ReadRef
	3: Ret
}

public fee_amount(Arg0: &FlashLoanReceipt): u64 {
B0:
	0: MoveLoc[0](Arg0: &FlashLoanReceipt)
	1: ImmBorrowField[4](FlashLoanReceipt.fee_amount: u64)
	2: ReadRef
	3: Ret
}

public repayment_amount(Arg0: &FlashLoanReceipt): u64 {
B0:
	0: CopyLoc[0](Arg0: &FlashLoanReceipt)
	1: Call loan_amount(&FlashLoanReceipt): u64
	2: MoveLoc[0](Arg0: &FlashLoanReceipt)
	3: Call fee_amount(&FlashLoanReceipt): u64
	4: Add
	5: Ret
}

Constants [
	0 => u64: 501
	1 => u64: 502
]
}
