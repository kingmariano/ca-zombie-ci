// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.privilege {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::admin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;

struct Privilege<phantom Ty0, phantom Ty1> has store, key {
	id: UID
}

public new<Ty0, Ty1>(Arg0: &AdminCap<Ty0>, Arg1: &mut TxContext): Privilege<Ty0, Ty1> {
B0:
	0: MoveLoc[1](Arg1: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: PackGeneric[0](Privilege<Ty0, Ty1>)
	3: Ret
}

public create<Ty0, Ty1>(Arg0: &AdminCap<Ty0>, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap<Ty0>)
	1: MoveLoc[1](Arg1: &mut TxContext)
	2: Call new<Ty0, Ty1>(&AdminCap<Ty0>, &mut TxContext): Privilege<Ty0, Ty1>
	3: Call transfer::share_object<Privilege<Ty0, Ty1>>(Privilege<Ty0, Ty1>)
	4: Ret
}

public destroy<Ty0, Ty1>(Arg0: Privilege<Ty0, Ty1>, Arg1: &AdminCap<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: Privilege<Ty0, Ty1>)
	1: UnpackGeneric[0](Privilege<Ty0, Ty1>)
	2: Call object::delete(UID)
	3: Ret
}

}
