# Solution: default
#
# No directives. Vitis HLS inlines both helpers on its own, because they are
# small, and prints two HLS 214-178 lines saying so.
#
# Measured on this part at a 3.33 ns target: 3 FSM states, iteration latency 2,
# function latency 33, interval 34, estimated clock 2.085 ns, 13 FF, 118 LUT.
#
# With the boundaries gone the scheduler reassociates the three-operand sum and
# builds it as one TAddSub ternary adder, (a + c) + b, at 0.731 ns. Read
# (0.677) + adder (0.731) + write (0.677) = 2.085 ns, so one state carries the
# whole datapath.
#
# The resulting Verilog is byte-identical to the on solution.
