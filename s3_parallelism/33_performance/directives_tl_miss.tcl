# Solution: tl_miss
#
# A target of 160 cycles. The tl_reach design finishes the loop in 145 cycles
# and the function in 147, so a schedule that meets 160 demonstrably exists and
# the tool built it one solution ago from a looser target.
#
# It refuses anyway, and it refuses silently:
#
#   INFO: [HLS 200-1957] Failed to apply performance pragma with Target TL='160'
#
# There is no WARNING, no 214-392, and no message at all in the csynth report.
# The design that comes out is identical to base, 224 / 225 / 226 cycles, with
# the target missed by 65 cycles and nothing louder than an INFO line to say so.
#
# This is the solution that decides how the directive should be used, because
# it shows the failure is not "the tool tried and fell short" but "the tool
# declined the request and left the loop alone". README.md section 9 turns that
# into a build check.

set_directive_performance -target_tl 160 -unit cycle "acc/ACC_LOOP"
