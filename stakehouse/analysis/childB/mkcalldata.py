#!/usr/bin/env python3
"""ABI calldata builder for the Stakehouse target functions (analysis only, correct static-tuple encoding)."""
import sys
from eth_utils import keccak as k

def pad32(v: int) -> bytes: return (v & ((1<<256)-1)).to_bytes(32, "big")
def enc_bytes(b: bytes) -> bytes:
    return pad32(len(b)) + b + b"\x00" * ((32 - len(b) % 32) % 32)
def selector(sig: str) -> bytes: return k(text=sig)[:4]

def sweep_words(withdrawal_index, validator_index, recipient, amount):
    return pad32(withdrawal_index)+pad32(validator_index)+pad32(recipient)+pad32(amount)

def final_sweep_words(wi, vi, recipient, amount_gwei, slot, block):
    return sweep_words(wi, vi, recipient, amount_gwei)+pad32(slot)+pad32(block)

def sig_words(deadline, v, r, s):
    return pad32(deadline)+pad32(v)+r+s

def beacon_report(a, bls: bytes):
    """Encodes the ETH2DataReport struct (dynamic) starting at its own head; a = dict of fields."""
    bls_off = 9*32
    wc_off = bls_off + len(enc_bytes(bls))
    head = (pad32(bls_off) + pad32(wc_off) + pad32(1 if a.get("slashed") else 0) +
            pad32(a["active_balance"]) + pad32(a["effective_balance"]) +
            pad32(a["exit_epoch"]) + pad32(a["activation_epoch"]) +
            pad32(a["withdrawal_epoch"]) + pad32(a["checkpoint_epoch"]))
    return head + enc_bytes(bls) + enc_bytes(a.get("wc", b"\x22"*32))

def fw_report_calldata(**kw):
    g = dict(total=32*10**18, unreported=[], bls=b"\x11"*48,
             final=(7, 8, 0x1111111111111111111111111111111111111111, 32*10**9, 100, 200),
             br=dict(slashed=False, active_balance=32*10**9, effective_balance=32*10**9,
                     exit_epoch=3, activation_epoch=1, withdrawal_epoch=100, checkpoint_epoch=200),
             sig=(1_000_000_000, 27, b"\x33"*32, b"\x44"*32))
    g.update(kw)
    bls = g["bls"]
    ur = b"".join(sweep_words(1000+i, 2000+i, 0x9999999999999999999999999999999999999999, 10**9+i)
                  for i in range(g["unreported"] if isinstance(g["unreported"], int) else len(g["unreported"])))
    ur_enc = pad32(g["unreported"] if isinstance(g["unreported"], int) else len(g["unreported"])) + ur
    final_enc = final_sweep_words(*g["final"])
    br_enc = beacon_report({**g["br"], "wc": (0x2222222222222222222222222222222222222222).to_bytes(20,"big")}, bls)
    sig_enc = sig_words(*g["sig"])
    head_size = (1 + 1 + 1 + 6 + 1 + 4) * 32  # total + bls_off + ur_off + finalSweep(6) + br_off + sig(4)
    o_bls = head_size
    o_ur = o_bls + len(enc_bytes(bls))
    o_br = o_ur + len(ur_enc)
    head = (pad32(g["total"]) + pad32(o_bls) + pad32(o_ur) + final_enc + pad32(o_br) + sig_enc)
    body = head + enc_bytes(bls) + ur_enc + br_enc
    return selector("reportFinalSweepAndWithdraw(uint256,bytes,(uint256,uint256,address,uint256)[],((uint256,uint256,address,uint256),uint256,uint256),(bytes,bytes,bool,uint64,uint64,uint64,uint64,uint64,uint64),(uint256,uint8,bytes32,bytes32))") + body

def tr_ragequit(**kw):
    g = dict(stakehouse=0x3333333333333333333333333333333333333333, bls=b"\x11"*48,
             recipient=0x4444444444444444444444444444444444444444,
             br=dict(slashed=False, active_balance=32*10**9, effective_balance=32*10**9,
                     exit_epoch=3, activation_epoch=1, withdrawal_epoch=100, checkpoint_epoch=200),
             sig=(1_000_000_000, 27, b"\x33"*32, b"\x44"*32))
    g.update(kw)
    head_size = (1 + 1 + 1 + 1 + 4) * 32
    o_bls = head_size
    o_br = o_bls + len(enc_bytes(g["bls"]))
    head = pad32(g["stakehouse"]) + pad32(o_bls) + pad32(g["recipient"]) + pad32(o_br) + sig_words(*g["sig"])
    body = head + enc_bytes(g["bls"]) + beacon_report(dict(g["br"], wc=(0x2222222222222222222222222222222222222222).to_bytes(20,"big")), g["bls"])
    return selector("rageQuitKnot(address,bytes,address,(bytes,bytes,bool,uint64,uint64,uint64,uint64,uint64,uint64),(uint248,uint8,bytes32,bytes32))") + body

def tr_multiparty(**kw):
    g = dict(stakehouse=0x3333333333333333333333333333333333333333, bls=b"\x11"*48,
             recipient=0x4444444444444444444444444444444444444444,
             br=dict(slashed=False, active_balance=32*10**9, effective_balance=32*10**9,
                     exit_epoch=3, activation_epoch=1, withdrawal_epoch=100, checkpoint_epoch=200),
             sig=(1_000_000_000, 27, b"\x33"*32, b"\x44"*32))
    g.update(kw)
    head_size = (1 + 1 + 1 + 1 + 4) * 32
    o_bls = head_size
    o_br = o_bls + len(enc_bytes(g["bls"]))
    head = pad32(g["stakehouse"]) + pad32(o_bls) + pad32(g["recipient"]) + pad32(o_br) + sig_words(*g["sig"])
    body = head + enc_bytes(g["bls"]) + beacon_report(dict(g["br"], wc=(0x2222222222222222222222222222222222222222).to_bytes(20,"big")), g["bls"])
    return selector("multipartyRageQuitWithAssistant(address,bytes,address,(bytes,bytes,bool,uint64,uint64,uint64,uint64,uint64,uint64),(uint248,uint8,bytes32,bytes32))") + body

def tr_voluntary(**kw):
    g = dict(stakehouse=0x3333333333333333333333333333333333333333, bls=b"\x11"*48,
             br=dict(slashed=False, active_balance=32*10**9, effective_balance=32*10**9,
                     exit_epoch=3, activation_epoch=1, withdrawal_epoch=100, checkpoint_epoch=200),
             sig=(1_000_000_000, 27, b"\x33"*32, b"\x44"*32))
    g.update(kw)
    head_size = (1 + 1 + 1 + 4) * 32  # stakehouse + bls_off + br_off + sig(4)
    o_bls = head_size
    o_br = o_bls + len(enc_bytes(g["bls"]))
    head = pad32(g["stakehouse"]) + pad32(o_bls) + pad32(o_br) + sig_words(*g["sig"])
    body = head + enc_bytes(g["bls"]) + beacon_report(dict(g["br"], wc=(0x2222222222222222222222222222222222222222).to_bytes(20,"big")), g["bls"])
    return selector("voluntaryWithdrawal(address,bytes,(bytes,bytes,bool,uint64,uint64,uint64,uint64,uint64,uint64),(uint248,uint8,bytes32,bytes32))") + body

def tr_slashandtopup(**kw):
    g = dict(stakehouse=0x3333333333333333333333333333333333333333, bls=b"\x11"*48,
             slasher=0x5555555555555555555555555555555555555555, buy_amount=10**18,
             br=dict(slashed=False, active_balance=32*10**9, effective_balance=32*10**9,
                     exit_epoch=3, activation_epoch=1, withdrawal_epoch=100, checkpoint_epoch=200),
             sig=(1_000_000_000, 27, b"\x33"*32, b"\x44"*32))
    g.update(kw)
    head_size = (1 + 1 + 1 + 1 + 1 + 4) * 32  # stakehouse + bls_off + slasher + buyAmount + br_off + sig(4)
    o_bls = head_size
    o_br = o_bls + len(enc_bytes(g["bls"]))
    head = (pad32(g["stakehouse"]) + pad32(o_bls) + pad32(g["slasher"]) + pad32(g["buy_amount"]) +
            pad32(o_br) + sig_words(*g["sig"]))
    body = head + enc_bytes(g["bls"]) + beacon_report(dict(g["br"], wc=(0x2222222222222222222222222222222222222222).to_bytes(20,"big")), g["bls"])
    return selector("slashAndTopUpSlot(address,bytes,address,uint256,(bytes,bytes,bool,uint64,uint64,uint64,uint64,uint64,uint64),(uint248,uint8,bytes32,bytes32))") + body

def tr_topup(**kw):
    g = dict(stakehouse=0x3333333333333333333333333333333333333333, bls=b"\x11"*48,
             recipient=0x4444444444444444444444444444444444444444, amount=10**18)
    g.update(kw)
    head_size = (1 + 1 + 1 + 1) * 32
    o_bls = head_size
    head = pad32(g["stakehouse"]) + pad32(o_bls) + pad32(g["recipient"]) + pad32(g["amount"])
    return selector("topUpSlashedSlot(address,bytes,address,uint256)") + head + enc_bytes(g["bls"])

def tr_authorize(rep=0x6666666666666666666666666666666666666666, enabled=True):
    return selector("authorizeRepresentative(address,bool)") + pad32(rep) + pad32(1 if enabled else 0)

if __name__ == "__main__":
    what = sys.argv[1]
    fn = globals()[what]
    print("0x" + fn().hex())
