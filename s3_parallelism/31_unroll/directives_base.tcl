# Solution: base
#
# No directives. VADD_LOOP keeps its trip count of 16 and runs its iterations
# one after the other, with a single adder reused by all of them. Only one
# element of a and one of b are read per cycle, so the tool is expected to
# give each argument a single ap_memory port.
# common/part.tcl sets config_compile -pipeline_loops 0, so the loop is not
# pipelined either.
# Check run.log: no unrolling message should appear here.