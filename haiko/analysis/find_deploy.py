#!/usr/bin/env python3
"""Find deployment block + scan events for a Starknet contract."""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, block_number, selector_from_name  # noqa


def exists(addr, blk):
    r = rpc("starknet_getClassHashAt", {"block_id": {"block_number": blk}, "contract_address": addr})
    return "result" in r


def find_deploy_block(addr, lo=1, hi=None):
    hi = hi or block_number()
    if not exists(addr, hi):
        return None
    while lo < hi:
        mid = (lo + hi) // 2
        if exists(addr, mid):
            hi = mid
        else:
            lo = mid + 1
    return lo


if __name__ == "__main__":
    addr = sys.argv[1]
    db = find_deploy_block(addr)
    print("deployment block:", db)
