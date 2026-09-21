# Solution: on
#
# Explicitly enables expression balancing for the whole of sum8.
#
# For the int sum this restates the default, so the prediction is that this
# solution matches default exactly after suffix normalisation.
#
# For the float sum the documentation does not settle the outcome. The
# directive page says the directive enables balancing in its scope, while the
# Optimizing Logic Expressions page names config_compile
# -unsafe_math_optimizations as the way to enable it for floats. The
# prediction is that the float sum is NOT regrouped (latency 76). If it is
# regrouped, the latency falls to 11 x 3 - 1 = 32 and cosim fails on
# regroup_bait, and that failure is the evidence.
#
# Measured: the float sum is NOT regrouped. Every fadd after the first takes
# the previous result and one fresh input port, exactly as line 11 is written,
# so the directive does not reach floating-point expressions in Vitis HLS
# 2023.2. Cosim passes. The generated RTL is byte-identical to that of the
# default solution, so normalisation is not even needed to compare them.
# See README.md section 7.

set_directive_expression_balance "sum8"
