// Move bytecode v6
module d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f.admin {
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;

struct AdminCap has store, key {
	id: UID
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Pack[0](AdminCap)
	3: MoveLoc[0](Arg0: &mut TxContext)
	4: FreezeRef
	5: Call tx_context::sender(&TxContext): address
	6: Call transfer::transfer<AdminCap>(AdminCap, address)
	7: Ret
}

}
