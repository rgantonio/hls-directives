# Kernel fsum8, solution: on
#
# Explicitly enables expression balancing for the whole of fsum8, and this is
# the solution the lesson exists to run.
#
# The documentation does not settle the outcome. The set_directive_expression_
# balance page says the directive enables balancing in its scope, while the
# Optimizing Logic Expressions page names config_compile
# -unsafe_math_optimizations as the way to enable it for floats.
#
# The prediction is that the float sum is NOT regrouped, so latency stays 76.
# If it is regrouped, the design drops to 11 x 3 = 33 states, the latency to
# 32, and cosim fails on regroup_bait. That failure would be the evidence.

# Measured: the float sum is NOT regrouped, and the evidence is stronger than
# a matching latency. This solution prints NO XFORM 203-11 balancing message at
# all -- there are exactly two in the whole run.log and both belong to sum32 --
# and its RTL is byte-identical to off and to default. Every fadd after the
# first takes the previous result and one fresh input port, exactly as line 10
# is written. Cosim passes, including both regroup_bait cases.
#
# So set_directive_expression_balance does not reach floating-point
# expressions in Vitis HLS 2023.2, in either form. See README.md section 7.4.

set_directive_expression_balance "fsum8"
