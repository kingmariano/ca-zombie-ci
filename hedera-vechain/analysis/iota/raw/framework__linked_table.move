// Move bytecode v6
module 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b.linked_table {
use 0000000000000000000000000000000000000000000000000000000000000002::dynamic_field;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000001::option;

struct LinkedTable<Ty0: copy + drop + store, phantom Ty1: store> has store, key {
	id: UID,
	size: u64,
	head: Option<Ty0>,
	tail: Option<Ty0>
}

struct Node<Ty0: copy + drop + store, Ty1: store> has store {
	prev: Option<Ty0>,
	next: Option<Ty0>,
	value: Ty1
}

err_table_not_empty() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_table_is_empty() {
B0:
	0: LdConst[1](u64: 1)
	1: Abort
}

public new<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut TxContext): LinkedTable<Ty0, Ty1> {
B0:
	0: MoveLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: LdU64(0)
	3: Call option::none<Ty0>(): Option<Ty0>
	4: Call option::none<Ty0>(): Option<Ty0>
	5: PackGeneric[0](LinkedTable<Ty0, Ty1>)
	6: Ret
}

public front<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>): &Option<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	2: Ret
}

public back<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>): &Option<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	2: Ret
}

public push_front<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>, Arg1: Ty0, Arg2: Ty1) {
L3:	loc0: Option<Ty0>
L4:	loc1: Option<Ty0>
L5:	loc2: Option<Ty0>
L6:	loc3: Ty0
L7:	loc4: Option<Ty0>
B0:
	0: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	2: CopyLoc[1](Arg1: Ty0)
	3: Call option::swap_or_fill<Ty0>(&mut Option<Ty0>, Ty0): Option<Ty0>
	4: StLoc[5](loc2: Option<Ty0>)
	5: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	6: ImmBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	7: Call option::is_none<Ty0>(&Option<Ty0>): bool
	8: BrFalse(13)
B1:
	9: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	10: MutBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	11: CopyLoc[1](Arg1: Ty0)
	12: Call option::fill<Ty0>(&mut Option<Ty0>, Ty0)
B2:
	13: Call option::none<Ty0>(): Option<Ty0>
	14: StLoc[7](loc4: Option<Ty0>)
	15: ImmBorrowLoc[5](loc2: Option<Ty0>)
	16: Call option::is_some<Ty0>(&Option<Ty0>): bool
	17: BrFalse(33)
B3:
	18: MoveLoc[5](loc2: Option<Ty0>)
	19: Call option::destroy_some<Ty0>(Option<Ty0>): Ty0
	20: StLoc[6](loc3: Ty0)
	21: CopyLoc[1](Arg1: Ty0)
	22: Call option::some<Ty0>(Ty0): Option<Ty0>
	23: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	24: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	25: CopyLoc[6](loc3: Ty0)
	26: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	27: MutBorrowFieldGeneric[3](Node.prev: Option<Ty0>)
	28: WriteRef
	29: MoveLoc[6](loc3: Ty0)
	30: Call option::some<Ty0>(Ty0): Option<Ty0>
	31: StLoc[3](loc0: Option<Ty0>)
	32: Branch(35)
B4:
	33: Call option::none<Ty0>(): Option<Ty0>
	34: StLoc[3](loc0: Option<Ty0>)
B5:
	35: MoveLoc[3](loc0: Option<Ty0>)
	36: StLoc[4](loc1: Option<Ty0>)
	37: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	38: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	39: MoveLoc[1](Arg1: Ty0)
	40: MoveLoc[7](loc4: Option<Ty0>)
	41: MoveLoc[4](loc1: Option<Ty0>)
	42: MoveLoc[2](Arg2: Ty1)
	43: PackGeneric[1](Node<Ty0, Ty1>)
	44: Call dynamic_field::add<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0, Node<Ty0, Ty1>)
	45: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	46: ImmBorrowFieldGeneric[4](LinkedTable.size: u64)
	47: ReadRef
	48: LdU64(1)
	49: Add
	50: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	51: MutBorrowFieldGeneric[4](LinkedTable.size: u64)
	52: WriteRef
	53: Ret
}

public push_back<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>, Arg1: Ty0, Arg2: Ty1) {
L3:	loc0: Option<Ty0>
L4:	loc1: Option<Ty0>
L5:	loc2: Option<Ty0>
L6:	loc3: Ty0
L7:	loc4: Option<Ty0>
B0:
	0: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	2: Call option::is_none<Ty0>(&Option<Ty0>): bool
	3: BrFalse(8)
B1:
	4: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	5: MutBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	6: CopyLoc[1](Arg1: Ty0)
	7: Call option::fill<Ty0>(&mut Option<Ty0>, Ty0)
B2:
	8: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	9: MutBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	10: CopyLoc[1](Arg1: Ty0)
	11: Call option::swap_or_fill<Ty0>(&mut Option<Ty0>, Ty0): Option<Ty0>
	12: StLoc[5](loc2: Option<Ty0>)
	13: ImmBorrowLoc[5](loc2: Option<Ty0>)
	14: Call option::is_some<Ty0>(&Option<Ty0>): bool
	15: BrFalse(31)
B3:
	16: MoveLoc[5](loc2: Option<Ty0>)
	17: Call option::destroy_some<Ty0>(Option<Ty0>): Ty0
	18: StLoc[6](loc3: Ty0)
	19: CopyLoc[1](Arg1: Ty0)
	20: Call option::some<Ty0>(Ty0): Option<Ty0>
	21: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	22: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	23: CopyLoc[6](loc3: Ty0)
	24: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	25: MutBorrowFieldGeneric[5](Node.next: Option<Ty0>)
	26: WriteRef
	27: MoveLoc[6](loc3: Ty0)
	28: Call option::some<Ty0>(Ty0): Option<Ty0>
	29: StLoc[3](loc0: Option<Ty0>)
	30: Branch(33)
B4:
	31: Call option::none<Ty0>(): Option<Ty0>
	32: StLoc[3](loc0: Option<Ty0>)
B5:
	33: MoveLoc[3](loc0: Option<Ty0>)
	34: StLoc[7](loc4: Option<Ty0>)
	35: Call option::none<Ty0>(): Option<Ty0>
	36: StLoc[4](loc1: Option<Ty0>)
	37: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	38: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	39: MoveLoc[1](Arg1: Ty0)
	40: MoveLoc[7](loc4: Option<Ty0>)
	41: MoveLoc[4](loc1: Option<Ty0>)
	42: MoveLoc[2](Arg2: Ty1)
	43: PackGeneric[1](Node<Ty0, Ty1>)
	44: Call dynamic_field::add<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0, Node<Ty0, Ty1>)
	45: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	46: ImmBorrowFieldGeneric[4](LinkedTable.size: u64)
	47: ReadRef
	48: LdU64(1)
	49: Add
	50: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	51: MutBorrowFieldGeneric[4](LinkedTable.size: u64)
	52: WriteRef
	53: Ret
}

public borrow<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>, Arg1: Ty0): &Ty1 {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[2](LinkedTable.id: UID)
	2: MoveLoc[1](Arg1: Ty0)
	3: Call dynamic_field::borrow<Ty0, Node<Ty0, Ty1>>(&UID, Ty0): &Node<Ty0, Ty1>
	4: ImmBorrowFieldGeneric[6](Node.value: Ty1)
	5: Ret
}

public borrow_mut<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>, Arg1: Ty0): &mut Ty1 {
B0:
	0: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	2: MoveLoc[1](Arg1: Ty0)
	3: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	4: MutBorrowFieldGeneric[6](Node.value: Ty1)
	5: Ret
}

public prev<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>, Arg1: Ty0): &Option<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[2](LinkedTable.id: UID)
	2: MoveLoc[1](Arg1: Ty0)
	3: Call dynamic_field::borrow<Ty0, Node<Ty0, Ty1>>(&UID, Ty0): &Node<Ty0, Ty1>
	4: ImmBorrowFieldGeneric[3](Node.prev: Option<Ty0>)
	5: Ret
}

public next<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>, Arg1: Ty0): &Option<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[2](LinkedTable.id: UID)
	2: MoveLoc[1](Arg1: Ty0)
	3: Call dynamic_field::borrow<Ty0, Node<Ty0, Ty1>>(&UID, Ty0): &Node<Ty0, Ty1>
	4: ImmBorrowFieldGeneric[5](Node.next: Option<Ty0>)
	5: Ret
}

public remove<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>, Arg1: Ty0): Ty1 {
L2:	loc0: Option<Ty0>
L3:	loc1: Option<Ty0>
L4:	loc2: Ty1
B0:
	0: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	2: CopyLoc[1](Arg1: Ty0)
	3: Call dynamic_field::remove<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): Node<Ty0, Ty1>
	4: UnpackGeneric[1](Node<Ty0, Ty1>)
	5: StLoc[4](loc2: Ty1)
	6: StLoc[2](loc0: Option<Ty0>)
	7: StLoc[3](loc1: Option<Ty0>)
	8: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	9: ImmBorrowFieldGeneric[4](LinkedTable.size: u64)
	10: ReadRef
	11: LdU64(1)
	12: Sub
	13: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	14: MutBorrowFieldGeneric[4](LinkedTable.size: u64)
	15: WriteRef
	16: ImmBorrowLoc[3](loc1: Option<Ty0>)
	17: Call option::is_some<Ty0>(&Option<Ty0>): bool
	18: BrFalse(28)
B1:
	19: CopyLoc[2](loc0: Option<Ty0>)
	20: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	21: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	22: ImmBorrowLoc[3](loc1: Option<Ty0>)
	23: Call option::borrow<Ty0>(&Option<Ty0>): &Ty0
	24: ReadRef
	25: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	26: MutBorrowFieldGeneric[5](Node.next: Option<Ty0>)
	27: WriteRef
B2:
	28: ImmBorrowLoc[2](loc0: Option<Ty0>)
	29: Call option::is_some<Ty0>(&Option<Ty0>): bool
	30: BrFalse(40)
B3:
	31: CopyLoc[3](loc1: Option<Ty0>)
	32: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	33: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	34: ImmBorrowLoc[2](loc0: Option<Ty0>)
	35: Call option::borrow<Ty0>(&Option<Ty0>): &Ty0
	36: ReadRef
	37: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	38: MutBorrowFieldGeneric[3](Node.prev: Option<Ty0>)
	39: WriteRef
B4:
	40: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	41: ImmBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	42: Call option::borrow<Ty0>(&Option<Ty0>): &Ty0
	43: ImmBorrowLoc[1](Arg1: Ty0)
	44: Eq
	45: BrFalse(50)
B5:
	46: MoveLoc[2](loc0: Option<Ty0>)
	47: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	48: MutBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	49: WriteRef
B6:
	50: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	51: ImmBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	52: Call option::borrow<Ty0>(&Option<Ty0>): &Ty0
	53: ImmBorrowLoc[1](Arg1: Ty0)
	54: Eq
	55: BrFalse(61)
B7:
	56: MoveLoc[3](loc1: Option<Ty0>)
	57: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	58: MutBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	59: WriteRef
	60: Branch(63)
B8:
	61: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	62: Pop
B9:
	63: MoveLoc[4](loc2: Ty1)
	64: Ret
}

public pop_front<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>): Ty0 * Ty1 {
L1:	loc0: Ty0
B0:
	0: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	2: Call option::is_none<Ty0>(&Option<Ty0>): bool
	3: BrFalse(5)
B1:
	4: Call err_table_is_empty()
B2:
	5: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	6: ImmBorrowFieldGeneric[0](LinkedTable.head: Option<Ty0>)
	7: Call option::borrow<Ty0>(&Option<Ty0>): &Ty0
	8: ReadRef
	9: StLoc[1](loc0: Ty0)
	10: CopyLoc[1](loc0: Ty0)
	11: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	12: MoveLoc[1](loc0: Ty0)
	13: Call remove<Ty0, Ty1>(&mut LinkedTable<Ty0, Ty1>, Ty0): Ty1
	14: Ret
}

public pop_back<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>): Ty0 * Ty1 {
L1:	loc0: Ty0
B0:
	0: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	2: Call option::is_none<Ty0>(&Option<Ty0>): bool
	3: BrFalse(5)
B1:
	4: Call err_table_is_empty()
B2:
	5: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	6: ImmBorrowFieldGeneric[1](LinkedTable.tail: Option<Ty0>)
	7: Call option::borrow<Ty0>(&Option<Ty0>): &Ty0
	8: ReadRef
	9: StLoc[1](loc0: Ty0)
	10: CopyLoc[1](loc0: Ty0)
	11: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	12: MoveLoc[1](loc0: Ty0)
	13: Call remove<Ty0, Ty1>(&mut LinkedTable<Ty0, Ty1>, Ty0): Ty1
	14: Ret
}

public contains<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>, Arg1: Ty0): bool {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[2](LinkedTable.id: UID)
	2: MoveLoc[1](Arg1: Ty0)
	3: Call dynamic_field::exists_with_type<Ty0, Node<Ty0, Ty1>>(&UID, Ty0): bool
	4: Ret
}

public length<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>): u64 {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[4](LinkedTable.size: u64)
	2: ReadRef
	3: Ret
}

public is_empty<Ty0: copy + drop + store, Ty1: store>(Arg0: &LinkedTable<Ty0, Ty1>): bool {
B0:
	0: MoveLoc[0](Arg0: &LinkedTable<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[4](LinkedTable.size: u64)
	2: ReadRef
	3: LdU64(0)
	4: Eq
	5: Ret
}

public destroy_empty<Ty0: copy + drop + store, Ty1: store>(Arg0: LinkedTable<Ty0, Ty1>) {
L1:	loc0: UID
L2:	loc1: u64
B0:
	0: MoveLoc[0](Arg0: LinkedTable<Ty0, Ty1>)
	1: UnpackGeneric[0](LinkedTable<Ty0, Ty1>)
	2: Pop
	3: Pop
	4: StLoc[2](loc1: u64)
	5: StLoc[1](loc0: UID)
	6: MoveLoc[2](loc1: u64)
	7: LdU64(0)
	8: Neq
	9: BrFalse(11)
B1:
	10: Call err_table_not_empty()
B2:
	11: MoveLoc[1](loc0: UID)
	12: Call object::delete(UID)
	13: Ret
}

public drop<Ty0: copy + drop + store, Ty1: drop + store>(Arg0: LinkedTable<Ty0, Ty1>) {
B0:
	0: MoveLoc[0](Arg0: LinkedTable<Ty0, Ty1>)
	1: UnpackGeneric[0](LinkedTable<Ty0, Ty1>)
	2: Pop
	3: Pop
	4: Pop
	5: Call object::delete(UID)
	6: Ret
}

public insert_front<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>, Arg1: Option<Ty0>, Arg2: Ty0, Arg3: Ty1) {
L4:	loc0: Option<Ty0>
L5:	loc1: Ty0
L6:	loc2: Option<Ty0>
L7:	loc3: Option<Ty0>
L8:	loc4: Ty0
B0:
	0: ImmBorrowLoc[1](Arg1: Option<Ty0>)
	1: Call option::is_none<Ty0>(&Option<Ty0>): bool
	2: BrFalse(8)
B1:
	3: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	4: MoveLoc[2](Arg2: Ty0)
	5: MoveLoc[3](Arg3: Ty1)
	6: Call push_back<Ty0, Ty1>(&mut LinkedTable<Ty0, Ty1>, Ty0, Ty1)
	7: Branch(66)
B2:
	8: MoveLoc[1](Arg1: Option<Ty0>)
	9: Call option::destroy_some<Ty0>(Option<Ty0>): Ty0
	10: StLoc[5](loc1: Ty0)
	11: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	12: FreezeRef
	13: CopyLoc[5](loc1: Ty0)
	14: Call prev<Ty0, Ty1>(&LinkedTable<Ty0, Ty1>, Ty0): &Option<Ty0>
	15: ReadRef
	16: StLoc[7](loc3: Option<Ty0>)
	17: ImmBorrowLoc[7](loc3: Option<Ty0>)
	18: Call option::is_none<Ty0>(&Option<Ty0>): bool
	19: BrFalse(25)
B3:
	20: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	21: MoveLoc[2](Arg2: Ty0)
	22: MoveLoc[3](Arg3: Ty1)
	23: Call push_front<Ty0, Ty1>(&mut LinkedTable<Ty0, Ty1>, Ty0, Ty1)
	24: Branch(66)
B4:
	25: MoveLoc[7](loc3: Option<Ty0>)
	26: Call option::destroy_some<Ty0>(Option<Ty0>): Ty0
	27: StLoc[8](loc4: Ty0)
	28: CopyLoc[2](Arg2: Ty0)
	29: Call option::some<Ty0>(Ty0): Option<Ty0>
	30: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	31: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	32: CopyLoc[5](loc1: Ty0)
	33: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	34: MutBorrowFieldGeneric[3](Node.prev: Option<Ty0>)
	35: WriteRef
	36: CopyLoc[2](Arg2: Ty0)
	37: Call option::some<Ty0>(Ty0): Option<Ty0>
	38: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	39: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	40: CopyLoc[8](loc4: Ty0)
	41: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	42: MutBorrowFieldGeneric[5](Node.next: Option<Ty0>)
	43: WriteRef
	44: MoveLoc[8](loc4: Ty0)
	45: Call option::some<Ty0>(Ty0): Option<Ty0>
	46: StLoc[6](loc2: Option<Ty0>)
	47: MoveLoc[5](loc1: Ty0)
	48: Call option::some<Ty0>(Ty0): Option<Ty0>
	49: StLoc[4](loc0: Option<Ty0>)
	50: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	51: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	52: MoveLoc[2](Arg2: Ty0)
	53: MoveLoc[6](loc2: Option<Ty0>)
	54: MoveLoc[4](loc0: Option<Ty0>)
	55: MoveLoc[3](Arg3: Ty1)
	56: PackGeneric[1](Node<Ty0, Ty1>)
	57: Call dynamic_field::add<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0, Node<Ty0, Ty1>)
	58: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	59: ImmBorrowFieldGeneric[4](LinkedTable.size: u64)
	60: ReadRef
	61: LdU64(1)
	62: Add
	63: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	64: MutBorrowFieldGeneric[4](LinkedTable.size: u64)
	65: WriteRef
B5:
	66: Ret
}

public insert_back<Ty0: copy + drop + store, Ty1: store>(Arg0: &mut LinkedTable<Ty0, Ty1>, Arg1: Option<Ty0>, Arg2: Ty0, Arg3: Ty1) {
L4:	loc0: Option<Ty0>
L5:	loc1: Option<Ty0>
L6:	loc2: Ty0
L7:	loc3: Option<Ty0>
L8:	loc4: Ty0
B0:
	0: ImmBorrowLoc[1](Arg1: Option<Ty0>)
	1: Call option::is_none<Ty0>(&Option<Ty0>): bool
	2: BrFalse(8)
B1:
	3: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	4: MoveLoc[2](Arg2: Ty0)
	5: MoveLoc[3](Arg3: Ty1)
	6: Call push_front<Ty0, Ty1>(&mut LinkedTable<Ty0, Ty1>, Ty0, Ty1)
	7: Branch(66)
B2:
	8: MoveLoc[1](Arg1: Option<Ty0>)
	9: Call option::destroy_some<Ty0>(Option<Ty0>): Ty0
	10: StLoc[8](loc4: Ty0)
	11: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	12: FreezeRef
	13: CopyLoc[8](loc4: Ty0)
	14: Call next<Ty0, Ty1>(&LinkedTable<Ty0, Ty1>, Ty0): &Option<Ty0>
	15: ReadRef
	16: StLoc[5](loc1: Option<Ty0>)
	17: ImmBorrowLoc[5](loc1: Option<Ty0>)
	18: Call option::is_none<Ty0>(&Option<Ty0>): bool
	19: BrFalse(25)
B3:
	20: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	21: MoveLoc[2](Arg2: Ty0)
	22: MoveLoc[3](Arg3: Ty1)
	23: Call push_back<Ty0, Ty1>(&mut LinkedTable<Ty0, Ty1>, Ty0, Ty1)
	24: Branch(66)
B4:
	25: MoveLoc[5](loc1: Option<Ty0>)
	26: Call option::destroy_some<Ty0>(Option<Ty0>): Ty0
	27: StLoc[6](loc2: Ty0)
	28: CopyLoc[2](Arg2: Ty0)
	29: Call option::some<Ty0>(Ty0): Option<Ty0>
	30: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	31: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	32: CopyLoc[6](loc2: Ty0)
	33: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	34: MutBorrowFieldGeneric[3](Node.prev: Option<Ty0>)
	35: WriteRef
	36: CopyLoc[2](Arg2: Ty0)
	37: Call option::some<Ty0>(Ty0): Option<Ty0>
	38: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	39: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	40: CopyLoc[8](loc4: Ty0)
	41: Call dynamic_field::borrow_mut<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0): &mut Node<Ty0, Ty1>
	42: MutBorrowFieldGeneric[5](Node.next: Option<Ty0>)
	43: WriteRef
	44: MoveLoc[8](loc4: Ty0)
	45: Call option::some<Ty0>(Ty0): Option<Ty0>
	46: StLoc[7](loc3: Option<Ty0>)
	47: MoveLoc[6](loc2: Ty0)
	48: Call option::some<Ty0>(Ty0): Option<Ty0>
	49: StLoc[4](loc0: Option<Ty0>)
	50: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	51: MutBorrowFieldGeneric[2](LinkedTable.id: UID)
	52: MoveLoc[2](Arg2: Ty0)
	53: MoveLoc[7](loc3: Option<Ty0>)
	54: MoveLoc[4](loc0: Option<Ty0>)
	55: MoveLoc[3](Arg3: Ty1)
	56: PackGeneric[1](Node<Ty0, Ty1>)
	57: Call dynamic_field::add<Ty0, Node<Ty0, Ty1>>(&mut UID, Ty0, Node<Ty0, Ty1>)
	58: CopyLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	59: ImmBorrowFieldGeneric[4](LinkedTable.size: u64)
	60: ReadRef
	61: LdU64(1)
	62: Add
	63: MoveLoc[0](Arg0: &mut LinkedTable<Ty0, Ty1>)
	64: MutBorrowFieldGeneric[4](LinkedTable.size: u64)
	65: WriteRef
B5:
	66: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
]
}
