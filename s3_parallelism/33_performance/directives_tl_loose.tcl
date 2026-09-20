# Solution: tl_loose
#
# A target of 240 cycles, still above the 224 the unpipelined loop already
# takes, but much closer to it than tl_slack's 400.
#
# The tool infers II = 10 and reaches it, so the loop really does get faster:
# 162 cycles against 224. It pays for the tenth cycle by chaining the write of
# sum onto the last stage of the adder instead of giving it a state of its own,
# and that chain is 2.262 ns + 0.427 ns = 2.689 ns against an effective budget
# of 2.431 ns:
#
#   WARNING: [HLS 200-871] Estimated clock period (2.689 ns) exceeds the target
#   WARNING: [HLS 200-1016] The critical path ... 'fadd' ... 'store' ...
#
# So this solution meets its target in cycles and misses the clock. It is the
# same failure lesson 3.2 measured when an impossible LATENCY maximum was met
# by re-binding a multiplier, reproduced here by a directive that was given a
# target with room to spare, and it is why every latency in README.md section 7
# is reported next to the estimated clock period.

set_directive_performance -target_tl 240 -unit cycle "acc/ACC_LOOP"
