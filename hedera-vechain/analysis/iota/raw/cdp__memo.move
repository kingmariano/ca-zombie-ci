// Move bytecode v6
module cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1.memo {
use 0000000000000000000000000000000000000000000000000000000000000001::string;

public manage(): String {
B0:
	0: LdConst[0](vector<u8>: "man..)
	1: Call string::utf8(vector<u8>): String
	2: Ret
}

public donate(): String {
B0:
	0: LdConst[1](vector<u8>: "don..)
	1: Call string::utf8(vector<u8>): String
	2: Ret
}

public liquidate(): String {
B0:
	0: LdConst[2](vector<u8>: "liq..)
	1: Call string::utf8(vector<u8>): String
	2: Ret
}

public interest(): String {
B0:
	0: LdConst[3](vector<u8>: "int..)
	1: Call string::utf8(vector<u8>): String
	2: Ret
}

Constants [
	0 => vector<u8>: "manage" // interpreted as UTF8 string
	1 => vector<u8>: "donate" // interpreted as UTF8 string
	2 => vector<u8>: "liquidate" // interpreted as UTF8 string
	3 => vector<u8>: "interest" // interpreted as UTF8 string
]
}
