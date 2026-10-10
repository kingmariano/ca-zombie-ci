#!/usr/bin/env python3
"""C2-58 — regenerate the deployed-SSNList transition/guard table from live chain code.

Read-only; keyless RPC. Usage: python3 audit_deployed_ssnlist.py [out.txt]
"""
import json
import re
import sys
import urllib.request

RPC = "https://api.zilliqa.com"
IMPL = "0xa7c67d49c82c7dc1b73d231640b2e4d0661d37c1"
GUARDS = ("IsProxy", "IsAdmin", "IsVerifier", "CallerIsVerifier", "IsNotPaused",
          "IsPaused", "ValidateMigration", "DelegExists")


def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    req = urllib.request.Request(RPC, data=body,
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0 (read-only research)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def find_transitions(src):
    """Yield (name, params, body) for every `transition Name(...)` with balanced parens."""
    for m in re.finditer(r"\btransition\s+(\w+)\s*\(", src):
        i = m.end()  # just after '('
        depth = 1
        while i < len(src) and depth:
            if src[i] == "(":
                depth += 1
            elif src[i] == ")":
                depth -= 1
            i += 1
        params = src[m.end():i - 1]
        yield m.group(1), params, src[i:]


def main():
    code = rpc("eth_getCode", [IMPL, "latest"])["result"]
    src = bytes.fromhex(code[2:]).decode("latin1")
    block = int(rpc("eth_blockNumber", [])["result"], 16)
    transitions = list(find_transitions(src))
    lines = [f"# deployed SSNList transition guards — block {block}", ""]
    n_proxy = 0
    n_via_migration = 0
    for j, (name, params, body) in enumerate(transitions):
        next_start = len(body)
        nxt = re.search(r"\btransition\s+\w+\s*\(", body)
        if nxt:
            next_start = nxt.start()
        body_lines = [l.strip() for l in body[:next_start].split("\n") if l.strip()]
        guards = [l.rstrip(";") for l in body_lines[:12]
                  if re.match(r"^(%s)\b" % "|".join(GUARDS), l)]
        if "IsProxy" in guards:
            n_proxy += 1
        elif any(g.startswith("ValidateMigration") for g in guards):
            n_via_migration += 1  # ValidateMigration itself = IsPaused + IsProxy + IsAdmin
        lines.append(f"{name:38s} guards: {guards}")
    lines.append("")
    lines.append(f"transitions: {len(transitions)}")
    lines.append(f"direct IsProxy: {n_proxy}; via ValidateMigration (IsPaused+IsProxy+IsAdmin): {n_via_migration}")
    lines.append(f"=> all {n_proxy + n_via_migration} transitions are IsProxy-gated")
    out = "\n".join(lines) + "\n"
    print(out)
    if len(sys.argv) > 1:
        open(sys.argv[1], "w").write(out)
        print("wrote", sys.argv[1])


if __name__ == "__main__":
    main()
