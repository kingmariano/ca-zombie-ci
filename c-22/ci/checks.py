#!/usr/bin/env python3
"""C2-22 Fulcrom — CI live checks (read-only JSON-RPC).

Never prints RPC URLs or secrets. Writes results to stdout; run.sh tees to ci-out/checks.txt.
"""
import json
import os
import sys
import time
import urllib.request

CRONOS = os.environ.get("CRONOS_RPC_URL") or "https://evm.cronos.org"
ZKSYNC = "https://mainnet.era.zksync.io"
ZKEVM = "https://mainnet.zkevm.cronos.org"

ADDR = {
    "cronos_vault": "0x8C7Ef34aa54210c76D6d5E475f43e0c11f876098",
    "cronos_orderbook_impl": "0x1b0e19329f1d895372bdb16c0229172aa10cd32a",
    "cronos_position_router_impl": "0x8b4d2dd548114d77a98400176325e853c5174e5e",
    "cronos_timelock": "0x880a34751D8452df466ae27Ac341F987f0dAf3AE",
    "cronos_shorts_tracker": "0xd996bE6DBdEaa8429Ff9E2D86725197Eb663148a",
    "cronos_flp_manager": "0x6148107BcAC794d3fC94239B88fA77634983891F",
    "wcroz": "0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23",
    "zksync_vault": "0x7d5b0215EF203D0660BC37d5D09d964fd6b55a1E",
    "zksync_timelock": "0x88CA1fB542A8c45cCcb0ee43042bAC616319761b",
    "zkevm_vault": "0xdDDf221d5293619572616574Ff46a2760f162075",
}

SEL = {
    "isLeverageEnabled": "0x3e72a262",
    "isSwapEnabled": "0x351a964d",
    "increasePosition": "0x48d91abf",
    "errors": "0xfed1a606",
    "gov": "0x12d43a51",
    "isGlobalShortDataReady": "0x9a11178f",
    "shortsTrackerAveragePriceWeight": "0x64e6617f",
    "enableLeverage": "0x6d63c1d0",
    "setIsLeverageEnabled": "0xcd2b1230",
    "updateGlobalShortData": "0xf3238cec",
}

DEAD = "0x000000000000000000000000000000000000dEaD"
DEAD32 = "000000000000000000000000000000000000000000000000000000000000dEaD"


def rpc(url, method, params, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(
                url, data=body,
                headers={"Content-Type": "application/json", "User-Agent": "c2-22-checks/1.0"},
            )
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read())
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1)
    return {"error": {"message": f"transport: {last}"}}


def eth_call(url, to, data, frm=DEAD):
    res = rpc(url, "eth_call", [{"from": frm, "to": to, "data": data}, "latest"])
    if "error" in res:
        err = res["error"]
        return f"REVERT/ERR: {err.get('message', '')} | data={str(err.get('data', ''))[:400]}"
    return res.get("result")


def pad32(hex_no0x):
    return hex_no0x.rjust(64, "0")


def addr_arg(a):
    return pad32(a.lower().replace("0x", ""))


def uint_arg(v):
    return pad32(hex(v)[2:])


def bool_arg(b):
    return pad32("1" if b else "0")


def decode_error_string(hexdata):
    """Decode Error(string) revert data if present."""
    if not hexdata or not isinstance(hexdata, str):
        return None
    h = hexdata[2:] if hexdata.startswith("0x") else hexdata
    try:
        raw = bytes.fromhex(h)
    except ValueError:
        return None
    marker = bytes.fromhex("08c379a0")
    i = raw.find(marker)
    if i < 0:
        return None
    body = raw[i + 4:]
    if len(body) < 64:
        return None
    ln = int.from_bytes(body[32:64], "big")
    s = body[64:64 + ln]
    try:
        return s.decode()
    except Exception:  # noqa: BLE001
        return repr(s)


def extract_err_str(res):
    if not isinstance(res, str):
        return None
    m = res.find("data=")
    if m >= 0:
        return decode_error_string(res[m + 5:].strip())
    return None


def check(label, url, to, data, frm=DEAD):
    res = eth_call(url, to, data, frm)
    dec = extract_err_str(res) if isinstance(res, str) and res.startswith("REVERT") else None
    print(f"{label}: {res}")
    if dec:
        print(f"{label} -> decoded: {dec!r}")
    return res


def scan_orderbook_string():
    """Reconstruct the Solidity-split revert string from deployed runtime code."""
    res = rpc(CRONOS, "eth_getCode", [ADDR["cronos_orderbook_impl"], "latest"])
    code_hex = res.get("result", "0x")
    code = bytes.fromhex(code_hex[2:])
    prefix = b"OrderBook: account cannot be a c"
    controls = [b"OrderBook: non-existent order", b"OrderBook: insufficient execution fee"]
    print(f"orderbook_impl code bytes: {len(code)}")
    # note: Solidity splits revert strings longer than 32 bytes into a 32-byte
    # PUSH32 chunk plus an SHL-encoded tail, so a naive ASCII scan of long strings
    # fails; the short control below is stored contiguously.
    print(f"control string '{controls[0].decode()}' present: {controls[0] in code}")
    print(f"control (long, split) '{controls[1].decode()}' naive-scan present: {controls[1] in code}")
    i = code.find(prefix)
    print(f"account-check prefix present at: {i}")
    full = None
    if i >= 0:
        for j in range(i + len(prefix), min(i + 160, len(code) - 12)):
            if code[j] == 0x66:  # PUSH7
                val = int.from_bytes(code[j + 1:j + 8], "big")
                if code[j + 8] == 0x60 and code[j + 10] == 0x1B:  # PUSH1 shift, SHL
                    shift = code[j + 9]
                    tail = ((val << shift) & ((1 << 256) - 1)).to_bytes(32, "big").rstrip(b"\x00")
                    if tail == b"ontract":
                        full = prefix + tail
                        break
    print(f"reconstructed full string: {full!r}")
    print(f"FULL account-check string present: {full == b'OrderBook: account cannot be a contract'}")


def scan_router_selector():
    res = rpc(CRONOS, "eth_getCode", [ADDR["cronos_position_router_impl"], "latest"])
    code = res.get("result", "0x")
    sel = SEL["updateGlobalShortData"][2:]
    print(f"updateGlobalShortData selector {SEL['updateGlobalShortData']} in PositionRouter impl: {sel in code}")
    res2 = rpc(CRONOS, "eth_getCode", ["0xbb8a54f0e488f3e4698b49855327732a5d8255ec", "latest"])
    code2 = res2.get("result", "0x")
    print(f"updateGlobalShortData selector in PositionManager impl: {sel in code2}")


def main():
    print("=== C2-22 Fulcrom CI checks (read-only) ===")
    print(f"cronos rpc: {'<redacted>' if os.environ.get('CRONOS_RPC_URL') else CRONOS}")
    print(f"time: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}")

    b1 = rpc(CRONOS, "eth_blockNumber", [])
    b2 = rpc(ZKSYNC, "eth_blockNumber", [])
    b3 = rpc(ZKEVM, "eth_blockNumber", [])
    print(f"cronos block: {b1.get('result')} ({int(b1['result'], 16) if 'result' in b1 else 'n/a'})")
    print(f"zksync block: {b2.get('result')}")
    print(f"zkevm block: {b3.get('result')}")

    print("\n-- Cronos live state --")
    check("Vault.isLeverageEnabled", CRONOS, ADDR["cronos_vault"], SEL["isLeverageEnabled"])
    check("Vault.isSwapEnabled", CRONOS, ADDR["cronos_vault"], SEL["isSwapEnabled"])
    check("Vault.errors(28)", CRONOS, ADDR["cronos_vault"], SEL["errors"] + uint_arg(28))
    check("Vault.gov", CRONOS, ADDR["cronos_vault"], SEL["gov"])
    check("ShortsTracker.isGlobalShortDataReady", CRONOS, ADDR["cronos_shorts_tracker"], SEL["isGlobalShortDataReady"])
    check("FlpManager.shortsTrackerAveragePriceWeight", CRONOS, ADDR["cronos_flp_manager"], SEL["shortsTrackerAveragePriceWeight"])
    check(
        "Vault.increasePosition(dead, WCRO, WCRO, 1e18, true) [expect leverage guard]",
        CRONOS, ADDR["cronos_vault"],
        SEL["increasePosition"] + DEAD32 + addr_arg(ADDR["wcroz"]) + addr_arg(ADDR["wcroz"]) + uint_arg(10**18) + bool_arg(True),
    )
    check(
        "Timelock.enableLeverage(vault) from dead [expect Timelock: forbidden]",
        CRONOS, ADDR["cronos_timelock"], SEL["enableLeverage"] + addr_arg(ADDR["cronos_vault"]),
    )
    check(
        "ShortsTracker.updateGlobalShortData from dead [expect forbidden]",
        CRONOS, ADDR["cronos_shorts_tracker"],
        SEL["updateGlobalShortData"] + DEAD32 + addr_arg(ADDR["wcroz"]) + addr_arg(ADDR["wcroz"]) + bool_arg(False) + uint_arg(10**18) + uint_arg(0) + bool_arg(True),
    )

    print("\n-- Cronos deployed-bytecode guard evidence --")
    scan_orderbook_string()
    scan_router_selector()

    print("\n-- zkSync Era live state --")
    check("Vault.isLeverageEnabled", ZKSYNC, ADDR["zksync_vault"], SEL["isLeverageEnabled"])
    check("Vault.errors(28)", ZKSYNC, ADDR["zksync_vault"], SEL["errors"] + uint_arg(28))
    check(
        "Vault.increasePosition(dead, WETH, WETH, 1e18, true) [expect leverage guard]",
        ZKSYNC, ADDR["zksync_vault"],
        SEL["increasePosition"] + DEAD32 + addr_arg("0x5aea5775959fbc2557cc8789bc1bf90a239d9a91") + addr_arg("0x5aea5775959fbc2557cc8789bc1bf90a239d9a91") + uint_arg(10**18) + bool_arg(True),
    )
    check(
        "Timelock.enableLeverage(vault) from dead",
        ZKSYNC, ADDR["zksync_timelock"], SEL["enableLeverage"] + addr_arg(ADDR["zksync_vault"]),
    )

    print("\n-- Cronos zkEVM (chain 388, sunsetting; RPC mainnet.zkevm.cronos.org) --")
    c = rpc(ZKEVM, "eth_getCode", [ADDR["zkevm_vault"], "latest"])
    code = c.get("result", "n/a")
    print(f"zkEVM vault code: {'0x (EMPTY)' if code == '0x' else f'{len(code)//2 - 1} bytes'}")
    if code not in ("0x", "n/a"):
        check("zkEVM Vault.isLeverageEnabled", ZKEVM, ADDR["zkevm_vault"], SEL["isLeverageEnabled"])
        check(
            "zkEVM Vault.increasePosition(dead, WCRO, WCRO, 1e18, true) [expect leverage guard]",
            ZKEVM, ADDR["zkevm_vault"],
            SEL["increasePosition"] + DEAD32 + addr_arg(ADDR["wcroz"]) + addr_arg(ADDR["wcroz"]) + uint_arg(10**18) + bool_arg(True),
        )

    print("\n=== checks complete ===")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001
        print(f"FATAL: {e}", file=sys.stderr)
        sys.exit(1)
