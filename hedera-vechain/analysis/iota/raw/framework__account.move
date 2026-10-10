// Move bytecode v6
module 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b.account {
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::package;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::string;

struct ACCOUNT has drop {
	dummy_field: bool
}

struct Account has store, key {
	id: UID,
	alias: Option<String>
}

struct AccountRequest has drop {
	account: address
}

init(Arg0: ACCOUNT, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: ACCOUNT)
	1: MoveLoc[1](Arg1: &mut TxContext)
	2: Call package::claim_and_keep<ACCOUNT>(ACCOUNT, &mut TxContext)
	3: Ret
}

public new(Arg0: Option<String>, Arg1: &mut TxContext): Account {
B0:
	0: MoveLoc[1](Arg1: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: MoveLoc[0](Arg0: Option<String>)
	3: Pack[1](Account)
	4: Ret
}

public request(Arg0: &TxContext): AccountRequest {
B0:
	0: MoveLoc[0](Arg0: &TxContext)
	1: Call tx_context::sender(&TxContext): address
	2: Pack[2](AccountRequest)
	3: Ret
}

public request_with_account(Arg0: &Account): AccountRequest {
L1:	loc0: ID
B0:
	0: MoveLoc[0](Arg0: &Account)
	1: Call object::id<Account>(&Account): ID
	2: StLoc[1](loc0: ID)
	3: ImmBorrowLoc[1](loc0: ID)
	4: Call object::id_to_address(&ID): address
	5: Pack[2](AccountRequest)
	6: Ret
}

public receive<Ty0: store + key>(Arg0: &mut Account, Arg1: Receiving<Ty0>): Ty0 {
B0:
	0: MoveLoc[0](Arg0: &mut Account)
	1: MutBorrowField[0](Account.id: UID)
	2: MoveLoc[1](Arg1: Receiving<Ty0>)
	3: Call transfer::public_receive<Ty0>(&mut UID, Receiving<Ty0>): Ty0
	4: Ret
}

public account_address(Arg0: &Account): address {
B0:
	0: MoveLoc[0](Arg0: &Account)
	1: ImmBorrowField[0](Account.id: UID)
	2: Call object::uid_to_address(&UID): address
	3: Ret
}

public request_address(Arg0: &AccountRequest): address {
B0:
	0: MoveLoc[0](Arg0: &AccountRequest)
	1: ImmBorrowField[1](AccountRequest.account: address)
	2: ReadRef
	3: Ret
}

}
