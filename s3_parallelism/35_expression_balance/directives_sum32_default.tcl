# Kernel sum32, solution: default
#
# No directive. This file exists so that every solution sources a directives
# file of the same name pattern, and it is intentionally empty of commands.
#
# By default Vitis balances integer expressions, so the 31 additions should
# become a tree five additions deep instead of a chain 31 deep.
#
# Predicted: with ternary fusion the tree's delay path is one binary adder
# followed by three ternary adders,
#   1.016 + 3 x 0.731 = 3.21 ns, which needs ceil(3.21 / 2.431) = 2 states
# so s_ap_vld is raised in state 2, the latency is 1 and the interval 2.
# That is 3 states fewer than off, which is the saving sum8 was too short to
# show: at 8 operands both shapes fit in 2 states.

# Measured: exactly as predicted. 2 states, s_ap_vld in state 2, latency 1,
# interval 2 -- four states better than off, not three, because off needed 6.
# The cost is area: 354 FF against 166, because 11 partial sums cross the one
# state boundary at once where the chain carried 1 across each of 5. LUT rises
# only 1036 -> 1083, since the tree's cheaper FSM refunds 23 of the 70 LUT the
# extra binary adders cost. See README.md section 7.3.
