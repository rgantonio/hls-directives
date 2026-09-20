# Solution: tl_reach
#
# A target of 224 cycles, exactly the latency the unpipelined loop already has.
# Measured on this installation it is also the tightest target that Vitis will
# accept on this loop: 223 is accepted, 208 is refused.
#
# The tool infers II = 9, which is below the eleven states the full_dsp adder
# spans, so it cannot get there with that adder. It re-binds the addition to
# acc_fadd_32ns_32ns_32_8_no_dsp_1, an eight-stage fabric implementation, and
# schedules the loop at II = 9 with a depth of 11:
#
#   INFO: [HLS 214-269] Inferring pragma 'pipeline II=9' ... due to performance pragma
#   INFO: [HLS 200-1470] Pipelining result : Target II = 9, Final II = 9, Depth = 11
#   INFO: [HLS 200-1957] Successfully applied performance pragma with Target TL='224'
#
# This is the best design in the lesson by a wide margin -- function latency 147
# against 225, a speed-up of 1.53 -- and it is the only one that changes which
# primitives the arithmetic uses: DSP falls from 2 to 0 and LUT rises from 344
# to 531. The clock still closes, at 2.292 ns against the 2.431 ns budget.
#
# Note what the directive did NOT say. It named no initiation interval, no
# unroll factor, no core and no implementation. It said 224.

set_directive_performance -target_tl 224 -unit cycle "acc/ACC_LOOP"
