#!/usr/bin/env python3
"""Minimal read-only JSON-RPC helper with ABI encode/decode and batching."""
import json
import time
import eth_utils
from eth_abi import encode as abi_encode, decode as abi_decode
import requests

# name -> (input types, output types)
SIGS = {
    # diamond views
    "getCollateral": ([], ["address"]),
    "pauseState": ([], ["bool", "bool", "bool", "bool", "bool", "bool"]),
    "pauseState_9": ([], ["bool"] * 9),
    "liquidationTimeout": ([], ["uint256"]),
    "liquidatorShare": ([], ["uint256"]),
    "getMuonConfig": ([], ["uint256", "uint256", "uint256"]),
    "getMuonIds": ([], ["uint256", "(uint256,uint8)", "address"]),
    "getFeeCollector": ([], ["address"]),
    "getBalanceLimitPerUser": ([], ["uint256"]),
    "pendingQuotesValidLength": ([], ["uint256"]),
    "coolDownsOfMA": ([], ["uint256", "uint256", "uint256", "uint256"]),
    "isCrossPartyBModeActivated": ([], ["bool"]),
    "isLegacyDeallocateDeprecated": ([], ["bool"]),
    "owner": ([], ["address"]),
    "pendingOwner": ([], ["address"]),
    "forceCloseGapRatio": ([], ["uint256"]),
    "withdrawCooldownPeriod": ([], ["uint256"]),
    "getLiquidatorFee": ([], ["uint256"]),
    "balanceOf": (["address"], ["uint256"]),
    "allocatedBalanceOfPartyA": (["address"], ["uint256"]),
    "balanceInfoOfPartyA": (["address"], ["uint256"] * 9),
    "partyAStats": (["address"], ["bool"] + ["uint256"] * 13),
    "allocatedBalanceOfPartyB": (["address", "address"], ["uint256"]),
    "allocatedBalanceOfPartyBs": (["address", "address[]"], ["uint256[]"]),
    "balanceInfoOfPartyB": (["address", "address"], ["uint256"] * 9),
    "balanceInfoOfCrossPartyB": (["address"], ["uint256"] * 9),
    "allocatedBalanceOfCrossPartyB": (["address"], ["uint256"]),
    "isCrossPartyB": (["address"], ["bool"]),
    "balanceOfReserveVault": (["address"], ["uint256"]),
    "isPartyB": (["address"], ["bool"]),
    "getPartyBEmergencyStatus": (["address"], ["bool"]),
    "isPartyBLiquidated": (["address", "address"], ["bool"]),
    "isPartyALiquidated": (["address"], ["bool"]),
    "partyAPositionsCount": (["address"], ["uint256"]),
    "quotesLength": (["address"], ["uint256"]),
    "nonceOfPartyA": (["address"], ["uint256"]),
    "withdrawCooldownOf": (["address"], ["uint256"]),
    "isSuspended": (["address"], ["bool"]),
    "getRoleHash": (["string"], ["bytes32"]),
    "hasRole": (["address", "bytes32"], ["bool"]),
    "partyBLiquidationTimestamp": (["address", "address"], ["uint256"]),
    "partyBPositionsCount": (["address", "address"], ["uint256"]),
    # MultiAccount views
    "paused": ([], ["bool"]),
    "deusV3Address": ([], ["address"]),
    "getAccountsLength": (["address"], ["uint256"]),
    "withdrawFromAccount_ma": (["address", "uint256"], []),
    "depositForAccount_ma": (["address", "uint256"], []),
    "implementation": ([], ["address"]),
    "admin": ([], ["address"]),
    # Solver vault views
    "solver": ([], ["address"]),
    "signer": ([], ["address"]),
    "collateralTokenAddress": ([], ["address"]),
    "lockedBalance": ([], ["uint256"]),
    "depositLimit": ([], ["uint256"]),
    "currentDeposit": ([], ["uint256"]),
    "collateralTokenDecimals": ([], ["uint256"]),
    "withdrawalPeriod": ([], ["uint256"]),
    "lpToken": ([], ["address"]),
    "vaultToken": ([], ["address"]),
    "symmioAddress": ([], ["address"]),
    "minimumPaybackRatio": ([], ["uint256"]),
    "nextWithdrawRequestId": ([], ["uint256"]),
    "rebateToken": ([], ["address"]),
    "carbonTrustedAddress": ([], ["address"]),
    "totalReward": ([], ["uint256"]),
    "multiAccount": ([], ["address"]),
    "isKeeper": (["address"], ["bool"]),
    "hasDelegated": (["address"], ["bool"]),
    "requestToClosePositionSelector": ([], ["bytes4"]),
    "getOwners": ([], ["address[]"]),
    "getThreshold": ([], ["uint256"]),
    "VERSION": ([], ["string"]),
    "NAME": ([], ["string"]),
    # ERC20
    "decimals": ([], ["uint8"]),
    "totalSupply": ([], ["uint256"]),
    "name": ([], ["string"]),
    "symbol": ([], ["string"]),
}


def encode_call(name, args):
    base_name = name.split("_")[0]
    types = SIGS[name][0]
    args = [a.lower() if (t == "address" and isinstance(a, str)) else a for t, a in zip(types, args)]
    sig = base_name + "(" + ",".join(types) + ")"
    selector = eth_utils.keccak(text=sig)[:4]
    if args:
        return "0x" + (selector + abi_encode(types, args)).hex()
    return "0x" + selector.hex()


def decode_result(name, raw):
    if raw == "0x":
        return None
    types = ["(" + ",".join(t.strip("()") for t in thr) + ")" if t.startswith("(") else t for thr in []]
    # direct decode (no tuple wrapping needed for eth_abi with tuple strings)
    return abi_decode(SIGS[name][1], bytes.fromhex(raw[2:]))


class Rpc:
    MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"

    def __init__(self, url):
        self.url = url
        self._id = 0

    def _post(self, payloads, tries=9, base_delay=1.0):
        """POST JSON-RPC; robust to 429/5xx with exponential backoff + jitter."""
        import random
        delay = base_delay
        last = None
        for attempt in range(tries):
            try:
                r = requests.post(self.url, json=payloads, timeout=90)
                if r.status_code in (429, 500, 502, 503, 504, 521, 525):
                    raise RuntimeError(f"http {r.status_code}")
                data = r.json()
                if isinstance(data, dict) and data.get("error", {}).get("code") == 429:
                    raise RuntimeError("rpc 429")
                if isinstance(data, list) and data and all(isinstance(x, dict) and x.get("error", {}).get("code") == 429 for x in data):
                    raise RuntimeError("rpc batch 429")
                return data
            except Exception as e:
                last = e
                if attempt == tries - 1:
                    raise
                time.sleep(delay + random.uniform(0, 0.5))
                delay = min(delay * 1.7, 45)
        raise last

    def raw_call(self, to, data, frm=None, block="latest"):
        """eth_call with optional from; returns (ok, result_or_revert_data)."""
        tx = {"to": to, "data": data}
        if frm:
            tx["from"] = frm.lower()
        r = self._post({"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [tx, block]})
        if isinstance(r, dict) and "result" in r:
            return True, r["result"]
        return False, (r.get("error") if isinstance(r, dict) else r)

    def multicall(self, calls, block="latest", size=120):
        """Execute calls via Multicall3 aggregate3. calls: [(name,args,addr)]. Same order output."""
        out = []
        for start in range(0, len(calls), size):
            chunk = calls[start:start + size]
            encoded = []
            for name, args, addr in chunk:
                data = bytes.fromhex(encode_call(name, args)[2:])
                encoded.append((addr, True, data))
            sig = eth_utils.keccak(text="aggregate3((address,bool,bytes)[])")[:4]
            calldata = "0x" + (sig + abi_encode(["(address,bool,bytes)[]"], [encoded])).hex()
            raw = self._post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                              "params": [{"to": self.MULTICALL3, "data": calldata}, block]})
            if not isinstance(raw, dict) or "result" not in raw or raw["result"] == "0x":
                out.extend([None] * len(chunk))
                continue
            res = abi_decode(["(bool,bytes)[]"], bytes.fromhex(raw["result"][2:]))[0]
            for (name, args, addr), (ok, ret) in zip(chunk, res):
                if ok and ret:
                    try:
                        out.append(decode_result(name, "0x" + ret.hex()))
                    except Exception:
                        out.append(None)
                else:
                    out.append(None)
        return out

    def block_number(self):
        r = self._post({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})
        return int(r["result"], 16)

    def batch_call(self, calls, block="latest"):
        """calls: list of (name, args, address). Returns list of decoded results (None on revert)."""
        reqs = []
        for i, (name, args, addr) in enumerate(calls):
            reqs.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                         "params": [{"to": addr, "data": encode_call(name, args)}, block]})
        out = {}
        results = [None] * len(calls)
        # chunk to 100
        for start in range(0, len(reqs), 40):
            chunk = reqs[start:start + 40]
            resp = self._post(chunk)
            if isinstance(resp, dict):
                resp = [resp]
            for item in resp:
                i = item.get("id")
                if i is None:
                    continue
                if "result" in item and item["result"] not in (None, "0x"):
                    name = calls[i][0]
                    try:
                        results[i] = decode_result(name, item["result"])
                    except Exception:
                        results[i] = None
                else:
                    results[i] = None
        return results

    def eth_call(self, name, args, addr, block="latest"):
        return self.batch_call([(name, args, addr)], block)[0]

    def get_balance(self, addr, block="latest"):
        r = self._post({"jsonrpc": "2.0", "id": 1, "method": "eth_getBalance",
                        "params": [addr, block]})
        return int(r["result"], 16)

    def get_code(self, addr, block="latest"):
        r = self._post({"jsonrpc": "2.0", "id": 1, "method": "eth_getCode",
                        "params": [addr, block]})
        return r["result"]

    def get_storage_at(self, addr, slot, block="latest"):
        r = self._post({"jsonrpc": "2.0", "id": 1, "method": "eth_getStorageAt",
                        "params": [addr, hex(slot), block]})
        return r["result"]
