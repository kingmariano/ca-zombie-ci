#!/usr/bin/env python3
"""CI gate tests: re-verify the H2-08 closure on live Flow mainnet (read-only).
1) external create LendingPool.PoolCertificate -> must fail (language rule)
2) comptroller UserCertificate vs callerAllowed -> must be rejected
3) comptroller market list snapshot
Writes results to ci-out/gate_tests.txt (also returned via stdout).
"""
import json, base64, urllib.request, urllib.error, sys, os

ENDPOINT = "https://rest-mainnet.onflow.org/v1/scripts"

def enc(v): return base64.b64encode(json.dumps(v).encode()).decode()

def run(script_text, args=None):
    body = json.dumps({"script": base64.b64encode(script_text.encode()).decode(),
                       "arguments": [enc(a) for a in (args or [])]}).encode()
    req = urllib.request.Request(ENDPOINT, data=body, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            d = json.loads(r.read())
        if isinstance(d, str):
            return ("OK", base64.b64decode(d).decode())
        return ("HTTP-ERR", json.dumps(d)[:1500])
    except urllib.error.HTTPError as e:
        return ("HTTP-%d" % e.code, e.read().decode()[:1500])

T1 = """import LendingPool from 0x67539e86cbe9b261
access(all) fun main(): String {
    let c <- create LendingPool.PoolCertificate()
    destroy c
    return "CREATED"
}"""

T2 = """import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735
import LendingComptroller from 0xf80cb737bfe7c792
access(all) fun main(comptrollerAddr: Address, marketAddr: Address): [String] {
    let ref = getAccount(comptrollerAddr).capabilities.borrow<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath)
        ?? panic("no comptroller cap")
    let cert <- LendingComptroller.IssueUserCertificate()
    let certType = cert.getType().identifier
    let err = ref.callerAllowed(callerCertificate: <- cert, callerAddress: marketAddr)
    return [certType, err ?? "ALLOWED-NO-ERROR"]
}"""

T3 = """import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735
access(all) fun main(comptrollerAddr: Address): [Address] {
    let ref = getAccount(comptrollerAddr).capabilities.borrow<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath)
        ?? panic("no comptroller cap")
    return ref.getAllMarkets()
}"""

def main():
    out = []
    height = json.loads(urllib.request.urlopen("https://rest-mainnet.onflow.org/v1/blocks?height=sealed", timeout=60).read())[0]["header"]["height"]
    out.append("sealed_height=%s" % height)
    s, b = run(T1)
    out.append("T1_external_create_PoolCertificate: status=%s\n%s" % (s, b))
    s, b = run(T2, [{"type": "Address", "value": "0xf80cb737bfe7c792"}, {"type": "Address", "value": "0x7492e2f9b4acea9a"}])
    out.append("T2_usercert_vs_callerAllowed: status=%s\n%s" % (s, b))
    s, b = run(T3, [{"type": "Address", "value": "0xf80cb737bfe7c792"}])
    out.append("T3_markets: status=%s\n%s" % (s, b))
    text = "\n\n".join(out)
    os.makedirs("ci-out", exist_ok=True)
    open("ci-out/gate_tests.txt", "w").write(text)
    print(text)

if __name__ == "__main__":
    main()
