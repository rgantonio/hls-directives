# Solution: off
#
# Both helpers are forbidden to inline, so each becomes its own RTL module:
# calls_sum2.v and calls_bias.v appear next to calls.v.
#
# Measured on this part at a 3.33 ns target: 4 FSM states, iteration latency 3,
# function latency 49, interval 50, estimated clock 2.370 ns, 46 FF, 138 LUT.
#
# The scheduler models each call as an opaque 1.016 ns operation, so it cannot
# chain both of them with the port read and the write inside one 2.431 ns
# state. It closes a state after sum2 and stores the sum in tmp_reg_175, which
# is the 32-bit register that the other two solutions do not need. State 4 is
# the critical one: read c (0.677) + call bias (1.016) + write y (0.677) =
# 2.370 ns.
#
# Both submodules have latency 0, so Vitis emits no ap_clk, ap_start or
# ap_done for them; only ap_ready survives, tied to 1'b1. The cost of the kept
# boundary is therefore not a handshake, it is the extra state and the extra
# register.
#
# The tool prints no HLS 214-178 line for this solution, which is correct: it
# inlined nothing.

set_directive_inline -off "sum2"
set_directive_inline -off "bias"
