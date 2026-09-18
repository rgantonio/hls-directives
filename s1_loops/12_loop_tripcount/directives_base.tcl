# Solution: base
#
# No directives. VADD_LOOP runs to the run-time bound n, so the latency
# estimator has no trip count and reports the latency as unknown.
# common/part.tcl sets config_compile -pipeline_loops 0, so the loop is not
# pipelined in either solution.