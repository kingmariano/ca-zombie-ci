import re, subprocess, json, os, sys

def strip_comments(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    src = re.sub(r'//[^\n]*', '', src)
    return src

FILES = {
 'diamondCut': 'MMDiamondCutFacet.sol',
 'loupe': 'MMDiamondLoupeFacet.sol',
 'view': 'ViewFacet.sol',
 'lend': 'LendFacet.sol',
 'collateral': 'CollateralFacet.sol',
 'borrow': 'BorrowFacet.sol',
 'noncollat': 'NonCollatBorrowFacet.sol',
 'admin': 'AdminFacet.sol',
 'liquidation': 'LiquidationFacet.sol',
 'ownership': 'MMOwnershipFacet.sol',
 'flashloan': 'FlashloanFacet.sol',
}
base='/tmp/opencode/alpaca/v2mm-repo/solidity/contracts/money-market/facets/'
result={}
for key, fn in FILES.items():
    src=strip_comments(open(base+fn).read())
    # find from 'function' to closing ')' that matches, then signature text
    sigs=[]
    for m in re.finditer(r'\bfunction\s+([A-Za-z0-9_]+)\s*\(', src):
        name=m.group(1)
        i=m.end()
        depth=1
        while i < len(src) and depth>0:
            ch=src[i]
            if ch=='(': depth+=1
            elif ch==')': depth-=1
            i+=1
        params=src[m.end():i-1]
        params=' '.join(params.split())
        sigs.append((name, params))
    result[key]=sigs
json.dump(result, open('source_sigs_raw.json','w'), indent=1)
print("extracted", {k:len(v) for k,v in result.items()})
