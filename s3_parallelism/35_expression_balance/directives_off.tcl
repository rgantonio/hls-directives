# Solution: off
#
# Turns expression balancing off for the whole of sum8. The int sum on line 10
# should stay the chain the source writes, seven additions deep, and the float
# sum on line 11 should be unchanged from default, because the default never
# balances floats.
#
# Predicted, at 3.33 ns with 0.90 ns uncertainty (about 2.431 ns per state):
#   int chain: two 1.016 ns adders fit per state, seven adders need 4 states,
#              so si_ap_vld is raised in state 4
#   float:     seven dependent 11-stage adds, 11 x 7 = 77 states, sf written
#              in state 77, latency 76, interval 77
#   estimated clock 2.262 ns (float adder stage), slack +0.169 ns
#
# Measured: the float half is as predicted, the int half is not. Vitis fuses
# each pair of chained additions into a three-input ternary adder at 0.73 ns,
# so the chain becomes one binary adder in state 1 plus three ternary adders
# in series in state 2 (3 x 0.73 = 2.19 ns), and si_ap_vld is raised in
# state 2, not state 4. The estimated clock is 2.665 ns, not 2.262 ns, because
# the seven float additions share one adder core and its operand multiplexer
# adds 0.40 ns in front of the core. See README.md section 7.

set_directive_expression_balance -off "sum8"
