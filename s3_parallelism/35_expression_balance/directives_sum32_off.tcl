# Kernel sum32, solution: off
#
# Turns expression balancing off for the whole of sum32, so the 31 additions
# on lines 12 to 15 stay the chain the source writes, 31 additions deep.
#
# Predicted, at 3.33 ns with 0.90 ns uncertainty (about 2.431 ns per state).
# Vitis fuses each pair of chained additions into a three-input ternary adder
# at 0.73 ns, as lesson 3.5 measured on sum8, so the chain's delay path is one
# 1.016 ns binary adder followed by 15 ternary adders:
#   1.016 + 15 x 0.731 = 11.98 ns, which needs ceil(11.98 / 2.431) = 5 states
# so s_ap_vld is raised in state 5, the latency is 4 and the interval 5.

# Measured: 6 states, not 5. s_ap_vld is raised in state 6, the latency is 5
# and the interval 6. The model was right about ternary fusion and wrong about
# packing: the scheduler places whole ternary adders, three per state at
# 3 x 0.731 = 2.193 ns, and the one leftover binary adder at the head of the
# chain gets a state to itself at 1.016 ns. So the count is 1 + ceil(15/3) = 6,
# not ceil(11.98/2.431) = 5. Predict in whole operators, not nanoseconds.
# Area: 166 FF, 1036 LUT (999 Expression, 37 Multiplexer). The chain keeps one
# partial sum alive at a time, so 5 registers cross its 5 state boundaries.
# See README.md section 7.2 and 7.3.

set_directive_expression_balance -off "sum32"
