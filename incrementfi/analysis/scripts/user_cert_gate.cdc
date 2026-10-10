import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735
import LendingComptroller from 0xf80cb737bfe7c792

// Test: can the comptroller's own UserCertificate satisfy callerAllowed for a market?
// This is the exact gate that LendingPool.seize() uses.
access(all) fun main(comptrollerAddr: Address, marketAddr: Address): [String] {
    let ref = getAccount(comptrollerAddr).capabilities.borrow<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath)
        ?? panic("no comptroller cap")
    let cert <- LendingComptroller.IssueUserCertificate()
    let certType = cert.getType().identifier
    let err = ref.callerAllowed(callerCertificate: <- cert, callerAddress: marketAddr)
    return [certType, err ?? "ALLOWED-NO-ERROR"]
}
