#!/usr/bin/env python3
"""Live read-only gate verification for StarGate (VeChain mainnet, keyless endpoints).

For each candidate extraction path, run a Thor clause *simulation* (accounts/*)
with an unprivileged caller and record the raw request/response as evidence.
No transaction is ever signed or sent.
"""
import json, subprocess, os, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(BASE, 'raw')
SIM_URL = 'https://mainnet.vechain.org/accounts/*'

STARGATE = '0x03c557be98123fdb6fad325328ac6eb77de7248c'
NFT = '0x1856c533ac2d94340aaa8544d35a5c1d4a21dee7'
ATTACKER = '0x0000000000000000000000000000000000000001'
STAKER = None  # resolved at runtime

def sel(sig):
    return subprocess.run(['cast', 'sig', sig], capture_output=True, text=True).stdout.strip()

def enc_uint(n):
    return hex(n)[2:].rjust(64, '0')

def enc_addr(a):
    return a[2:].lower().rjust(64, '0')

def enc_bytes(b):
    b = b[2:] if b.startswith('0x') else b
    return enc_uint(len(b) // 2) + b.ljust(64, '0') + '0' * 64

def simulate(to, data, caller, value='0x0', label=''):
    body = {
        "clauses": [{"to": to, "data": data, "value": value}],
        "caller": caller,
        "gas": 30000000,
        "gasPrice": "0x0",
    }
    p = subprocess.run(['curl', '-s', '--max-time', '30', '-X', 'POST', SIM_URL,
                        '-H', 'Content-Type: application/json',
                        '-d', json.dumps(body)], capture_output=True, text=True)
    try:
        resp = json.loads(p.stdout)
    except Exception:
        resp = p.stdout
    rec = {"label": label, "request": body, "response": resp}
    return rec

def main():
    global STAKER
    # resolve protocol staker + a few reads
    chain = json.load(open(os.path.join(RAW, 'sg_account.json')))
    # getProtocolStakerContract() via simulation (recorded)
    rec = simulate(STARGATE, sel('getProtocolStakerContract()'), ATTACKER, label='read getProtocolStakerContract')
    STAKER = '0x' + rec['response'][0]['data'][-40:]
    evidence = [rec]

    def add(label, to, data, caller, value='0x0'):
        r = simulate(to, data, caller, value=value, label=label)
        evidence.append(r)
        out = r['response']
        if isinstance(out, list):
            out = out[0]
            print(f"{label:55s} reverted={out.get('reverted')} vmError={out.get('vmError','')[:60]} data={str(out.get('data'))[:80]}")
            return out
        else:
            print(f"{label:55s} RAW={str(out)[:80]}")
            return out

    print('STAKER =', STAKER)
    # ---------- candidate unprivileged extraction paths ----------
    # 1. attacker unstakes someone else's NFT (EXITED delegation token 43203)
    add('E1 unstake(other token) attacker', STARGATE, sel('unstake(uint256)') + enc_uint(43203), ATTACKER)
    # 2. attacker delegates someone else's NFT
    add('E2 delegate(other token) attacker', STARGATE, sel('delegate(uint256,address)') + enc_uint(43203) + enc_addr('0x1e5b7e7b833f493347287f17bec6c836dc757948'), ATTACKER)
    # 3. attacker requests exit for someone else's NFT
    add('E3 requestDelegationExit(other) attacker', STARGATE, sel('requestDelegationExit(uint256)') + enc_uint(43203), ATTACKER)
    # 4. attacker migrates a legacy node it does not own
    add('E4 migrateAndDelegate(legacy 1) attacker', STARGATE, sel('migrateAndDelegate(uint256,address)') + enc_uint(1) + enc_addr('0x1e5b7e7b833f493347287f17bec6c836dc757948'), ATTACKER)
    # 5. attacker claims someone else's rewards (pays owner; should be allowed but to owner)
    add('E5 claimRewards(other token 45385) attacker', STARGATE, sel('claimRewards(uint256)') + enc_uint(45385), ATTACKER)
    # 6. attacker tries to upgrade
    add('E6 upgradeToAndCall attacker', STARGATE, sel('upgradeToAndCall(address,bytes)') + enc_addr(ATTACKER) + enc_uint(0x40) + enc_uint(0), ATTACKER)
    # 7. attacker tries to drain NFT contract balance (admin only)
    add('E7 NFT.transferBalance(1) attacker', NFT, sel('transferBalance(uint256)') + enc_uint(1), ATTACKER)
    # 8. attacker mints via NFT directly (onlyStargate)
    add('E8 NFT.mint(1,attacker) attacker', NFT, sel('mint(uint8,address)') + enc_uint(1) + enc_addr(ATTACKER), ATTACKER)
    # 9. attacker burns someone's NFT directly (onlyStargate)
    add('E9 NFT.burn(43203) attacker', NFT, sel('burn(uint256)') + enc_uint(43203), ATTACKER)
    # 10. attacker boost() someone else's token (pays own VTHO)
    add('E10 NFT.boost(other token) attacker', NFT, sel('boost(uint256)') + enc_uint(43203), ATTACKER)
    # 11. native staker withdrawDelegation of StarGate's delegation (EXITED) - attacker caller
    add('E11 Staker.withdrawDelegation(37920) attacker', STAKER, sel('withdrawDelegation(uint256)') + enc_uint(37920), ATTACKER)
    # 12. same call from StarGate caller (proves withdrawable + caller-gated by identity)
    add('E12 Staker.withdrawDelegation(37920) caller=StarGate', STAKER, sel('withdrawDelegation(uint256)') + enc_uint(37920), STARGATE)
    # 13/14. roles: who holds UPGRADER / ADMIN on Stargate now
    upg = '0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3'
    zero = '0x' + '00' * 32
    add('R1 hasRole(UPGRADER, admin 0xba04) ', STARGATE, sel('hasRole(bytes32,address)') + upg[2:] + enc_addr('0xba04313060012a2c8623b2b3cb6d4c5e2b1becea'), ATTACKER)
    add('R2 hasRole(UPGRADER, deployer 0x7850)', STARGATE, sel('hasRole(bytes32,address)') + upg[2:] + enc_addr('0x78508681ee16a0973b6c03ec7ac9987cdf81a404'), ATTACKER)
    add('R3 hasRole(ADMIN(0), 0xba04)', STARGATE, sel('hasRole(bytes32,address)') + zero[2:] + enc_addr('0xba04313060012a2c8623b2b3cb6d4c5e2b1becea'), ATTACKER)
    # 15. claimableRewards of the token we claim
    add('V1 claimableRewards(45385)', STARGATE, sel('claimableRewards(uint256)') + enc_uint(45385), ATTACKER)
    # 16. getDelegationStatus(43203) (EXITED)
    add('V2 getDelegationStatus(43203)', STARGATE, sel('getDelegationStatus(uint256)') + enc_uint(43203), ATTACKER)
    # 17. NFT reads
    add('V3 NFT.getStargate()', NFT, sel('getStargate()'), ATTACKER)
    add('V4 NFT.paused()', NFT, sel('paused()'), ATTACKER)
    add('V5 SG.paused()', STARGATE, sel('paused()'), ATTACKER)
    add('V6 SG.getMaxClaimablePeriods()', STARGATE, sel('getMaxClaimablePeriods()'), ATTACKER)

    json.dump(evidence, open(os.path.join(RAW, 'live_gate_simulations.json'), 'w'), indent=1)
    print('evidence saved:', os.path.join(RAW, 'live_gate_simulations.json'))

if __name__ == '__main__':
    main()
