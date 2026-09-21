# Kernel fsum8, solution: off
#
# Turns expression balancing off for the whole of fsum8. The default never
# balances floats, so this should change nothing at all: off and default are
# predicted to produce the same RTL.
#
# Predicted: seven dependent 11-state FAddSub_fulldsp additions, so the design
# has 11 x 7 = 77 states, sf is written in state 77, the latency is 76 and the
# interval 77.

# Measured: exactly as predicted, 77 states, sf_ap_vld in state 77, latency 76,
# interval 77 -- and byte-identical to both default and on. The estimated clock
# is 2.665 ns rather than the predicted 2.262 ns, because the seven additions
# share one FAddSub_fulldsp core and its seven-way operand multiplexer adds
# 0.403 ns in front of it. See README.md section 7.4.

set_directive_expression_balance -off "fsum8"
