import LendingComptroller from 0x9d9e2b1dcdc98155

access(all) fun main(): String {
    let c <- LendingComptroller.IssueUserCertificate()
    destroy c
    return "CREATED"
}
