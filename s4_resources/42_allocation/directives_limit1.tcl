# Solution: limit1
#
# At most one multiplier instance in poly, so all three multiplies share it.
# The instance is pipelined (latency 1, a new operand pair every cycle), so
# lin issues in state 2 while mul_ln24 finishes, and quad in state 3, which
# leaves the latency at 4. That is what the schedule report shows.
#
# Measured: 3 DSP, 234 FF, 178 LUT, latency 4, interval 5, 2.365 ns -- the
# estimated clock does not move, because the operand multiplexer is inserted
# after scheduling and never appears in a state's critical path. That is not
# the same as the multiplexer being free; see README section 7.
#
# Both inputs of the instance get a multiplexer: din0 selects between x, b
# and the registered product (20 LUT), din1 between a and x (14 LUT).

set_directive_allocation -limit 1 -type operation "poly" mul
