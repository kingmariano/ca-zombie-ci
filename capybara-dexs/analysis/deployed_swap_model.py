#!/usr/bin/env python3
"""Deployed swap model: DynamicPoolV2 + HighCovRatioFeePoolV2 semantics.

quotePotentialSwap(from,to,amount):
  sf = P_from * WAD / P_to
  fromCash' = cash_f*sf/WAD; fromLiab' = liab_f*sf/WAD; amount' = amount*sf/WAD
  ideal = swapQuoteFunc(fromCash', toCash, fromLiab', toLiab, amount', A)
  haircut = wmul(ideal, HR); actual = ideal - haircut
  if amount>0:
      final_r = wdiv(cash_f + amount, liab_f)          # raw units
      if final_r > start: hf = wmul(highCovRatioFee(raw_r, final_r, start, end), actual); actual -= hf
  returns actual in WAD
"""
import sys
sys.path.insert(0, '.')
from wombat_math import swap_quote_func, wmul, wdiv, high_cov_ratio_fee


class Q:
    def __init__(self, cash, liab, ts, P, dec):
        self.cash, self.liab, self.ts, self.P, self.dec = cash, liab, ts, P, dec


def deployed_quote(frm: Q, to: Q, amount_wad: int, amp, hr, start_r, end_r):
    sf = (frm.P * 10 ** 18) // to.P
    fc = (frm.cash * sf) // 10 ** 18
    fl = (frm.liab * sf) // 10 ** 18
    fa = (amount_wad * sf) // 10 ** 18
    if fl == 0 or to.liab == 0:
        return "ERR:underflow"
    ideal = swap_quote_func(fc, to.cash, fl, to.liab, fa, amp)
    if to.cash < ideal:
        return "ERR:cash_not_enough"
    haircut = wmul(ideal, hr)
    actual = ideal - haircut
    if amount_wad > 0:
        final_r = wdiv(frm.cash + amount_wad, frm.liab)
        if final_r > start_r:
            try:
                hf = wmul(high_cov_ratio_fee(wdiv(frm.cash, frm.liab), final_r, start_r, end_r), actual)
            except Exception:
                hf = 0
            actual -= hf
            haircut += hf
    return actual, haircut
