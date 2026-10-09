#!/usr/bin/env python3
"""Build table.json: current delegates table for both Enjin templates, verified on-chain.

Uses history.json (parsed Etherscan logs) + live `cast` reads via rpc.sh.
No secrets are written; rpc.sh sources the env at runtime.
"""
import json, subprocess, os, datetime

BASE = os.path.dirname(os.path.abspath(__file__))
TPL = {
    'nft': '0x13fa4b9a6c2f2604c919f96f456e3b50e968b157',
    'ft':  '0x268c039a3127d3107c014f0dc6c390a53e6db27f',
}
INT_SELECTORS = {  # template-internal dispatcher (checked BEFORE the delegates table)
    'nft': {
        '0x48ff15b3': 'acceptManager()',
        '0x7457bbf7': 'pendingManager()',
        '0x8d0a3a08': 'removeManager()',
        '0xa0a2daf0': 'delegates(bytes4)',
        '0xba0e930a': 'transferManager(address)',
        '0xd5009584': 'getManager()',
    },
}
INT_SELECTORS['ft'] = INT_SELECTORS['nft']

# Audit annotations for current delegate contracts
DELEGATE_INFO = {
    '0x24591e792a404e5bd48ac0f694339d807b02cfd2': {
        'name': 'ERC721 "wrapper adapter" implementation (original)',
        'publicSelectors': ['0x01ffc9a7 supportsInterface(bytes4)', '0x06fdde03 name()',
            '0x081812fc getApproved(uint256)', '0x095ea7b3 approve(address,uint256)',
            '0x18160ddd totalSupply()', '0x23b872dd transferFrom(address,address,uint256)',
            '0x2f745c59 tokenOfOwnerByIndex(address,uint256)', '0x42842e0e safeTransferFrom(address,address,uint256)',
            '0x4f6ccce7 tokenByIndex(uint256)', '0x6352211e ownerOf(uint256)',
            '0x70a08231 balanceOf(address)', '0x95d89b41 symbol()',
            '0xa22cb465 setApprovalForAll(address,bool)', '0xb88d4fde safeTransferFrom(address,address,uint256,bytes)',
            '0xc87b56dd tokenURI(uint256)', '0xe985e9c5 isApprovedForAll(address,address)',
            '0xfe4b84df initialize(uint256)'],
        'accessControl': {
            'initialize(uint256)': 'NO CALLER CHECK — writes ctx slot1 (=pendingManager on the template) = msg.sender, ctx slot2 = id, gated only by ctx-slot2==0 (always true when slot2 is a mapping base). THIS WAS THE TAKEOVER VECTOR. Currently NOT routed on either template (replaced by reverting stub 0x73497e1c).',
            'transferFrom/safeTransferFrom/approve/setApprovalForAll': 'standard ERC721 owner/approved checks; after a valid transfer it calls ctx-slot1 (0 on the template; PA proxy on live shells) with 0x41c1df0e gateway args. Template holds no item storage/assets, so not exploitable on the template itself.',
            'views (balanceOf/ownerOf/name/...)': 'view, no state change',
        },
    },
    '0x75512f843d8d22593d7256708ef80a22b97baf5e': {
        'name': 'ERC20 "wrapper adapter" implementation (original)',
        'publicSelectors': ['0x01ffc9a7 supportsInterface(bytes4)', '0x06fdde03 name()',
            '0x095ea7b3 approve(address,uint256)', '0x18160ddd totalSupply()',
            '0x23b872dd transferFrom(address,address,uint256)', '0x313ce567 decimals()',
            '0x70a08231 balanceOf(address)', '0x95d89b41 symbol()',
            '0xa9059cbb transfer(address,uint256)', '0xdd62ed3e allowance(address,address)',
            '0xfe4b84df initialize(uint256)'],
        'accessControl': {
            'initialize(uint256)': 'NO CALLER CHECK — same storage-slot collision as the ERC721 adapter (writes ctx slot1 = msg.sender, ctx slot2 = id). Currently NOT routed on either template (replaced by reverting stub 0x73497e1c).',
            'transfer/transferFrom/approve': 'standard ERC20 balance/allowance checks; transfer path may call ctx-slot1 with 0xf95d7da3 gateway args on live shells.',
            'views': 'view, no state change',
        },
    },
    '0x04866013862349a6a19a04c8a1590ea2cf026134': {
        'name': 'Function-router manager (updateContract) implementation',
        'publicSelectors': ['0x48ff15b3 acceptManager()', '0x61455567 updateContract(address,string,string)',
            '0x7457bbf7 pendingManager()', '0x8d0a3a08 removeManager()',
            '0xa0a2daf0 delegates(bytes4)', '0xba0e930a transferManager(address)', '0xd5009584 getManager()'],
        'accessControl': {
            'updateContract(address,string,string)': 'MANAGER-ONLY: reads ctx slot0 and requires msg.sender == manager ("Sender is not manager.") — verified by eth_call from an unprivileged address on both templates. Only the current manager (0x7083ddec...) can register/replace delegates.',
            'other selectors': 'only reachable if called directly on the impl (act on its own storage); when delegatecalled from the templates only 0x61455567 is routed.',
        },
    },
    '0x99294e5e8dd62fa0092a85ab37e8b5c44ec29758': {
        'name': 'Attacker adapter ("MaliciousShellLogic"); guards "only pwn"',
        'publicSelectors': ['0x23b872dd (used as transferFrom(address,address,uint256))', '0x6453dcf6 stealNFT(address,address,uint256)'],
        'accessControl': {
            'both': 'CALLER-GATED: require(msg.sender == 0x7083ddecE38216C7741fa76c75326Bea744ED321, "only pwn"); then calls 0xfaaFDc07..0xf95d7da3 / 0x41c1df0e (PA gateway) with attacker-chosen args. No storage writes (single SLOAD of ctx slot2 used as an argument).',
        },
    },
    '0x73497e1c3070a031e1ee05fdeaaeb73c9dd8fcb5': {
        'name': 'Reverting stub registered for initialize(uint256) ("lock")',
        'publicSelectors': ['n/a (tiny assembly stub, no selector dispatch)'],
        'accessControl': {
            'via template': 'REVERTS "locked" when delegatecalled by either template (checks address(this) is one of the two templates, then reverts).',
            'direct call': 'when called directly (address(this) != template) it writes its OWN slot1/slot2 and returns — a decoy; no effect on templates.',
        },
    },
    '0x6561d8a6dd7e184308555b21b115ebe122136036': {
        'name': 'Reverting stub registered for acceptManager() ("lock")',
        'publicSelectors': ['n/a (tiny assembly stub, always reverts)'],
        'accessControl': {
            'any': 'ALWAYS REVERTS "locked". Additionally shadowed: acceptManager() is dispatched by the template internally before the delegates table is consulted.',
        },
    },
}

def run(*args):
    r = subprocess.run([os.path.join(BASE, 'rpc.sh'), *args], capture_output=True, text=True)
    return r.stdout.strip(), r.returncode

def main():
    hist = json.load(open(os.path.join(BASE, 'history.json')))
    latest_block = int(run('block-number')[0])
    out = {
        'generatedAt': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'latestBlock': latest_block,
        'eventTopic0': '0x3234040ce3bd4564874e44810f198910133a1b24c4e84aac87edbf6b458f5353',
        'templates': {},
        'delegateContracts': DELEGATE_INFO,
        'externalManager': {},
    }
    for label, addr in TPL.items():
        rows = hist[label]
        cur = {}
        total_events = len(rows)
        for r in rows:
            cur.setdefault(r['selector'], {'firstBlock': r['block']})
            c = cur[r['selector']]
            c.update(delegate=r['new'], signature=r['signature'], lastBlock=r['block'],
                     lastTx=r['tx'], lastOld=r['old'])
        # on-chain verification
        for sel, c in cur.items():
            val, rc = run('call', addr, 'delegates(bytes4)(address)', sel)
            c['onchain'] = val
            c['onchainVerified'] = (val.lower() == c['delegate'].lower())
            c['shadowedByInternalDispatcher'] = (sel in INT_SELECTORS[label])
            c['note'] = 'shadowed: selector handled internally by the template; delegates-table entry is never used' if sel in INT_SELECTORS[label] else ''
        # storage context
        slot0, _ = run('storage', addr, '0')
        slot1, _ = run('storage', addr, '1')
        slot2, _ = run('storage', addr, '2')
        out['templates'][label] = {
            'address': addr,
            'eventsTotal': total_events,
            'selectorsEverRegistered': len(cur),
            'managerSlot0': '0x' + slot0[-40:],
            'pendingManagerSlot1': '0x' + slot1[-40:],
            'slot2Raw': slot2,
            'internalSelectors': INT_SELECTORS[label],
            'table': [dict(selector=s, **c) for s, c in sorted(cur.items())],
        }
    # external manager contract (current manager of both templates)
    mgr = '0x7083ddece38216c7741fa76c75326bea744ed321'
    slots = {i: run('storage', mgr, str(i))[0] for i in range(5)}
    out['externalManager'] = {
        'address': mgr,
        'note': 'Current manager of BOTH templates (attacker orchestrator). All its state-changing public functions require msg.sender == slot0 owner (owner-gated), so unprivileged users cannot make it act as manager.',
        'ownerSlot0': '0x' + slots[0][-40:],
        'payoutSlot1': '0x' + slots[1][-40:],
        'slots': slots,
        'publicSelectors': ['0x1f318cc3', '0x35faa416 sweep()', '0x63bd1d4a payout()', '0x8da5cb5b owner()',
            '0x991cef43', '0x9ac92217', '0xab2786f5(uint256,uint256,uint256)', '0xba0bba40 setup()',
            '0xbc197c81 onERC1155BatchReceived(...)', '0xd7b96d4e locker()', '0xd98787c9', '0xdb606d80',
            '0xe3bc4005', '0xf23a6e61 onERC1155Received(...)', '0xf7d9430e(uint256,uint256,uint256)',
            '0xf83d08ba lock()', '0xfe2cdc13(uint256,uint256)'],
        'accessControl': 'sweep/ab2786f5/setup/f7d9430e/lock/fe2cdc13 all start with `require(slot0 == msg.sender)`; view getters otherwise.',
    }
    with open(os.path.join(BASE, 'table.json'), 'w') as f:
        json.dump(out, f, indent=2)
    print('wrote table.json')
    for label in TPL:
        t = out['templates'][label]
        print(f"{label}: {t['eventsTotal']} events, {t['selectorsEverRegistered']} distinct selectors, manager={t['managerSlot0']}, allVerified={all(c['onchainVerified'] for c in t['table'])}")

if __name__ == '__main__':
    main()
