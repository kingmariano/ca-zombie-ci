// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.admin {
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;

struct AdminCap<phantom Ty0> has store, key {
	id: UID
}

public destroy<Ty0>(Arg0: AdminCap<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: AdminCap<Ty0>)
	1: UnpackGeneric[0](AdminCap<Ty0>)
	2: Call object::delete(UID)
	3: Ret
}

public(friend) new<Ty0>(Arg0: &mut TxContext): AdminCap<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: PackGeneric[0](AdminCap<Ty0>)
	3: Ret
}

}
