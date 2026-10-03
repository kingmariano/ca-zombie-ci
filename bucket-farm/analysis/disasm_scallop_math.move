// Move bytecode v6
module 7b2720e50e5fa5f2ceb95c82b20495b4eaf0c18f3adfdd7de125f6fc65230dbf.math {
use ad013d5fde39e15eabda32b3dbdafd67dac32b798ce63237c27a8f73339b9b6f::u64;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::accrue_interest;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::market;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::reserve;
use efe8b36d5b2e43728cc323298626b83177803521d195cfb11e15b910e892fddf::version;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 779b5c547976899f5474f3a5bc0db36ddf4697ad7e5a901db0415c2281d28162::wit_table;

public calc_coin_to_scoin(Arg0: &Version, Arg1: &mut Market, Arg2: TypeName, Arg3: &Clock, Arg4: u64): u64 {
L5:	loc0: u64
L6:	loc1: u64
L7:	loc2: u64
L8:	loc3: u64
L9:	loc4: u64
L10:	loc5: u64
B0:
	0: MoveLoc[0](Arg0: &Version)
	1: MoveLoc[1](Arg1: &mut Market)
	2: MoveLoc[2](Arg2: TypeName)
	3: MoveLoc[3](Arg3: &Clock)
	4: Call get_reserve_stats(&Version, &mut Market, TypeName, &Clock): u64 * u64 * u64 * u64
	5: StLoc[8](loc3: u64)
	6: StLoc[9](loc4: u64)
	7: StLoc[7](loc2: u64)
	8: StLoc[6](loc1: u64)
	9: CopyLoc[8](loc3: u64)
	10: LdU64(0)
	11: Gt
	12: BrFalse(23)
B1:
	13: MoveLoc[4](Arg4: u64)
	14: MoveLoc[8](loc3: u64)
	15: MoveLoc[6](loc1: u64)
	16: MoveLoc[7](loc2: u64)
	17: Add
	18: MoveLoc[9](loc4: u64)
	19: Sub
	20: Call u64::mul_div(u64, u64, u64): u64
	21: StLoc[5](loc0: u64)
	22: Branch(25)
B2:
	23: MoveLoc[4](Arg4: u64)
	24: StLoc[5](loc0: u64)
B3:
	25: MoveLoc[5](loc0: u64)
	26: StLoc[10](loc5: u64)
	27: CopyLoc[10](loc5: u64)
	28: LdU64(0)
	29: Gt
	30: BrFalse(32)
B4:
	31: Branch(34)
B5:
	32: LdU64(1)
	33: Abort
B6:
	34: MoveLoc[10](loc5: u64)
	35: Ret
}

public calc_scoin_to_coin(Arg0: &Version, Arg1: &mut Market, Arg2: TypeName, Arg3: &Clock, Arg4: u64): u64 {
L5:	loc0: u64
L6:	loc1: u64
L7:	loc2: u64
L8:	loc3: u64
B0:
	0: MoveLoc[0](Arg0: &Version)
	1: MoveLoc[1](Arg1: &mut Market)
	2: MoveLoc[2](Arg2: TypeName)
	3: MoveLoc[3](Arg3: &Clock)
	4: Call get_reserve_stats(&Version, &mut Market, TypeName, &Clock): u64 * u64 * u64 * u64
	5: StLoc[7](loc2: u64)
	6: StLoc[8](loc3: u64)
	7: StLoc[6](loc1: u64)
	8: StLoc[5](loc0: u64)
	9: MoveLoc[4](Arg4: u64)
	10: MoveLoc[5](loc0: u64)
	11: MoveLoc[6](loc1: u64)
	12: Add
	13: MoveLoc[8](loc3: u64)
	14: Sub
	15: MoveLoc[7](loc2: u64)
	16: Call u64::mul_div(u64, u64, u64): u64
	17: Ret
}

public get_reserve_stats(Arg0: &Version, Arg1: &mut Market, Arg2: TypeName, Arg3: &Clock): u64 * u64 * u64 * u64 {
B0:
	0: MoveLoc[0](Arg0: &Version)
	1: CopyLoc[1](Arg1: &mut Market)
	2: MoveLoc[3](Arg3: &Clock)
	3: Call accrue_interest::accrue_interest_for_market(&Version, &mut Market, &Clock)
	4: MoveLoc[1](Arg1: &mut Market)
	5: FreezeRef
	6: Call market::vault(&Market): &Reserve
	7: Call reserve::balance_sheets(&Reserve): &WitTable<BalanceSheets, TypeName, BalanceSheet>
	8: MoveLoc[2](Arg2: TypeName)
	9: Call wit_table::borrow<BalanceSheets, TypeName, BalanceSheet>(&WitTable<BalanceSheets, TypeName, BalanceSheet>, TypeName): &BalanceSheet
	10: Call reserve::balance_sheet(&BalanceSheet): u64 * u64 * u64 * u64
	11: Ret
}

}
