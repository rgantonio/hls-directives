# Solution: tl_slack
#
# A target of 400 cycles for a loop that already finishes in 224. The goal is
# met on arrival and the naive expectation is that the tool has no reason to
# build anything.
#
# It builds something anyway. This is the first surprise of the lesson and it
# refutes the natural reading of the directive: PERFORMANCE does not compare
# the target against the latency the loop already has and stop when the target
# is slack. It converts the target into an initiation interval, applies
# PIPELINE with it, and reports success.
#
#   INFO: [HLS 214-269] Inferring pragma 'pipeline II=22' ... due to performance pragma
#   INFO: [HLS 214-269] Inferring pragma 'pipeline II=15' ... due to performance pragma
#   INFO: [HLS 200-1470] Pipelining result : Target II = 15, Final II = 14, Depth = 14
#   INFO: [HLS 200-1957] Successfully applied performance pragma with Target TL='400'
#
# The resulting design is pipelined at II = 14, which for a 14-state iteration
# is no overlap at all, so the loop latency is the same 224 as base, the
# function latency is 226 rather than 225, and the flow-control module
# acc_flow_control_loop_pipe.v and 27 extra LUT exist for nothing.
#
# That is the point of this solution: a target with slack in it is not free,
# and it is not a no-op.

set_directive_performance -target_tl 400 -unit cycle "acc/ACC_LOOP"
