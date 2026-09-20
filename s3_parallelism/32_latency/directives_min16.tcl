# Solution: min16
#
# Ask for a minimum function latency of 16 cycles, which is above the natural
# latency for any plausible multiply span S. This is the only solution in the
# lesson that changes the hardware without breaking anything.
#
# The tool keeps the schedule it already had and appends idle states until the
# floor is reached, so the datapath is untouched and the finite state machine
# grows. Vitis encodes that state machine one-hot, so the cost is one flip-flop
# per added state, plus one arm per state in the next-state case statement.
#
# Two outcomes are possible and README.md section 5 predicts the first. Either
# y is written in the same state as in base and the idle states are appended
# after it, or the scheduler pushes the final addition into the last state and
# has to hold the two multiply results in registers meanwhile, which would cost
# about 64 more flip-flops. The schedule report settles it.
#
# Measured: outcome (a). 17 states, latency 16, interval 17. y_ap_vld still
# rises in state 5; only ap_done and ap_ready moved, to state 17. DSP unchanged
# at 9, FF 596 -> 608 (the one-hot state register, 5 bits -> 17), LUT 242 -> 300
# (the ap_NS_fsm decode, 6 case arms -> 18). So padding costs one flip-flop and
# roughly five LUTs per idle cycle, not one flip-flop and nothing.
set_directive_latency -min 16 "poly"
