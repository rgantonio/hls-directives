# Solution: default
#
# No directive. This file exists so that every solution sources a directives
# file of the same name pattern, and it is intentionally empty of commands.
#
# By default Vitis balances integer expressions and keeps floating-point
# expressions in source order. The int sum on line 10 should become a tree
# three additions deep, and the float sum on line 11 should stay a chain.
#
# Predicted:
#   int tree: six adds in state 1, the root add and the write in state 2,
#             so si_ap_vld is raised in state 2
#   float:    unchanged from off, latency 76, interval 77
#   estimated clock 2.262 ns, slack +0.169 ns
#
# Measured: the tree is built, as ((a6+a7)+(a4+a5)) + ((a2+a3)+(a0+a1)), and
# si_ap_vld is raised in state 2 as predicted. But "off" also raises it in
# state 2, so balancing buys no cycles here; it costs 14 LUT. The estimated
# clock is 2.665 ns, set by the shared float adder and its operand
# multiplexer. See README.md section 7.
