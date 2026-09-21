# Solution: limit2
#
# At most two multiplier instances in poly. Base never has more than two
# multiplies in flight, so this limit shares one instance between mul_ln24
# (states 1 and 2) and quad (states 3 and 4) without moving any operation;
# lin keeps an instance to itself. The schedule is identical to base.
#
# Measured: 6 DSP, 399 FF, 221 LUT, latency 4, interval 5, 2.365 ns.
# The new hardware is a two-source multiplexer on each input of the shared
# instance, 14 LUT apiece. Note that both inputs need one, because x sits on
# din0 of mul_ln24 and on din1 of quad -- see README section 9.
#
# This solution is a roster deviation, added so that the cost of pure sharing
# can be read apart from the cost of rescheduling in limit1.

set_directive_allocation -limit 2 -type operation "poly" mul
