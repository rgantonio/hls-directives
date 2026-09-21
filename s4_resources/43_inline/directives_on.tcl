# Solution: on
#
# Both helpers are explicitly inlined. The tool would have done this anyway,
# so the RTL is byte-identical to default: 3 FSM states, iteration latency 2,
# function latency 33, interval 34, estimated clock 2.085 ns, 13 FF, 118 LUT.
#
# One surprise worth keeping: this solution prints ZERO HLS 214-178 lines,
# while default prints two. That message reports the heuristic's decision, and
# an explicit directive bypasses the heuristic. Do not use the message as
# proof that a function was inlined; list syn/verilog/ instead. See README
# section 7.

set_directive_inline "sum2"
set_directive_inline "bias"
