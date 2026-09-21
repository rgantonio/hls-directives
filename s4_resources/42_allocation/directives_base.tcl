# Solution: base
#
# No directives. The tool binds and allocates the three 32-bit multiplies
# itself. Measured on this part at a 3.33 ns target: three instances of
# mul_32s_32s_32_2_1, 3 DSP / 165 FF / 49 LUT each, so 9 DSP, 596 FF,
# 242 LUT, 5 states, latency 4, interval 5 and an estimated clock of
# 2.365 ns. Lesson 4.1 measures the same numbers on the same kernel.
#
# The base schedule never has more than two multiplies in flight: mul_ln24
# (x * a) runs alone in states 1 and 2, and quad and lin run together in
# states 3 and 4. The tool still builds three instances, so one of them is
# idle the whole time. The other two solutions remove that slack.
#
# Every instance is wired to its operands directly, so base has no operand
# multiplexer at all; its only Multiplexer row is the FSM's ap_NS_fsm.
#
# common/part.tcl sets config_compile -pipeline_loops 0, which has nothing to
# act on here because the kernel contains no loop.
