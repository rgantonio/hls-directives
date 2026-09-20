# Solution: base
#
# No directives. The scheduler is free to produce whatever schedule it
# considers shortest for a clock period of 3.33 ns, and that schedule is the
# reference that the other three solutions are compared against.
#
# The critical path is one multiply feeding a second multiply feeding the
# additions, so the design is expected to need 2S + 1 states, where S is the
# number of states one 32 bit integer multiply occupies on this part. The
# reported function latency is one less than the state count, and the interval
# is one more than the latency, so latency = 2S and interval = 2S + 1.
#
# Measured: S = 2, so 5 states, a latency of 4 and an interval of 5. Note that
# LLVM reassociates a*(x*x) into (a*x)*x, so the two multiplies that share
# states 3 and 4 are (a*x)*x and b*x, not x*x and b*x as the source reads.
#
# common/part.tcl sets config_compile -pipeline_loops 0, which has nothing to
# act on here because the kernel contains no loop.
