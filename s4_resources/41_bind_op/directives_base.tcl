# Solution: base
#
# No directives. The tool binds each of the three 32-bit multiplies itself.
# Lesson 3.2 measured the choice on this part at 3.33 ns: Core 'Multiplier'
# with Latency = 1, module poly_mul_32s_32s_32_2_1, 3 DSP and 49 LUT each, so
# 9 DSP for the function, 5 states, latency 4 and interval 5.
#
# The Bind Op Report in syn/report/csynth.rpt lists these three multiplies
# with a blank Pragma column. That blank is the reference the other three
# solutions are compared against.
#
# common/part.tcl sets config_compile -pipeline_loops 0, which has nothing to
# act on here because the kernel contains no loop.